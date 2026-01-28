import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class EditRequestScreen extends ConsumerStatefulWidget {
  const EditRequestScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends ConsumerState<EditRequestScreen> {
  static const _bucket = 'request_photos';

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  ServiceRequest? _req;
  List<ServiceCategory> _cats = const [];
  int? _catId;

  LatLng? _picked;

  List<RequestPhoto> _existing = const [];
  final List<RequestPhoto> _toDelete = [];

  final List<XFile> _newPhotos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(supabaseRepoProvider);
    try {
      final req = await repo.fetchRequestById(widget.requestId);
      final cats = await repo.fetchCategories();
      final photos = await repo.fetchRequestPhotos(widget.requestId);

      _titleCtrl.text = req.title;
      _descCtrl.text = req.description;
      _addressCtrl.text = req.address ?? '';
      _catId = req.categoryId;
      _picked = LatLng(req.lat, req.lng);

      if (!mounted) return;
      setState(() {
        _req = req;
        _cats = cats;
        _existing = photos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando: $e')));
    }
  }

  bool get _canEditOrDelete {
    final st = _req?.status ?? '';
    return !{'on_the_way', 'in_progress', 'completed', 'rated'}.contains(st);
  }

  void _toggleDeleteExisting(RequestPhoto p) {
    setState(() {
      final exists = _toDelete.any((x) => x.id == p.id);
      if (exists) {
        _toDelete.removeWhere((x) => x.id == p.id);
      } else {
        _toDelete.add(p);
      }
    });
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _newPhotos.add(x));
  }

  Future<void> _save() async {
    if (!_canEditOrDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede editar: el servicio ya inició o terminó.')));
      return;
    }

    final repo = ref.read(supabaseRepoProvider);
    final catId = _catId;
    final picked = _picked;

    if (catId == null || picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa categoría y ubicación.')));
      return;
    }

    setState(() => _saving = true);

    try {
      // 1) actualizar solicitud
      await repo.updateRequest(
        requestId: widget.requestId,
        categoryId: catId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        lat: picked.latitude,
        lng: picked.longitude,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      // 2) borrar fotos marcadas
      for (final p in _toDelete) {
        await repo.deleteRequestPhoto(photoId: p.id, bucket: _bucket, path: p.path);
      }

      // 3) subir nuevas fotos
      const uuid = Uuid();
      for (final x in _newPhotos) {
        final bytes = await x.readAsBytes();
        final path = 'requests/${widget.requestId}/${uuid.v4()}.jpg';
        await repo.uploadBytes(bucket: _bucket, path: path, bytes: Uint8List.fromList(bytes));
        await repo.addRequestPhoto(requestId: widget.requestId, path: path);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud actualizada.')));
      context.go('/client/request/${widget.requestId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRequest() async {
    if (!_canEditOrDelete) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se puede eliminar: el servicio ya inició o terminó.')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: const Text('¿Seguro? Esto eliminará la solicitud y sus fotos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.delete_outline), label: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    final repo = ref.read(supabaseRepoProvider);
    try {
      await repo.deleteRequest(widget.requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Solicitud eliminada.')));
      context.go('/client');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar solicitud'),
        actions: [
          if (req != null)
            IconButton(
              onPressed: _canEditOrDelete ? _deleteRequest : null,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: SizedBox(height: 28, width: 28, child: CircularProgressIndicator()))
          : (req == null)
              ? const Center(child: Text('No encontrada'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    DropdownButtonFormField<int>(
                      value: _catId,
                      items: _cats
                          .map((c) => DropdownMenuItem<int>(
                                value: c.id,
                                child: Text(c.name),
                              ))
                          .toList(),
                      onChanged: _canEditOrDelete ? (v) => setState(() => _catId = v) : null,
                      decoration: const InputDecoration(labelText: 'Categoría'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleCtrl,
                      enabled: _canEditOrDelete,
                      decoration: const InputDecoration(labelText: 'Título'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      enabled: _canEditOrDelete,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Descripción del problema'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      enabled: _canEditOrDelete,
                      decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
                    ),
                    const SizedBox(height: 12),

                    // MAPA
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ubicación (toca el mapa para mover pin)',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 240,
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter: _picked ?? LatLng(req.lat, req.lng),
                                    initialZoom: 15,
                                    onTap: _canEditOrDelete
                                        ? (tapPosition, point) => setState(() => _picked = point)
                                        : null,
                                    interactionOptions: const InteractionOptions(
                                      flags: InteractiveFlag.drag |
                                          InteractiveFlag.pinchZoom |
                                          InteractiveFlag.doubleTapZoom |
                                          InteractiveFlag.scrollWheelZoom,
                                    ),
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'tecnigo_app',
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _picked ?? LatLng(req.lat, req.lng),
                                          width: 46,
                                          height: 46,
                                          child: const Icon(Icons.location_pin, size: 46),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // FOTOS EXISTENTES
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Fotos',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _canEditOrDelete ? _pickPhoto : null,
                                  icon: const Icon(Icons.add_a_photo_outlined),
                                  label: const Text('Agregar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (_existing.isEmpty && _newPhotos.isEmpty)
                              Text('No hay fotos.', style: Theme.of(context).textTheme.bodySmall),

                            if (_existing.isNotEmpty)
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _existing.map<Widget>((p) {
                                  final url = ref.read(supabaseRepoProvider).publicUrl(_bucket, p.path);
                                  final marked = _toDelete.any((x) => x.id == p.id);

                                  return GestureDetector(
                                    onTap: _canEditOrDelete ? () => _toggleDeleteExisting(p) : null,
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(14),
                                          child: SizedBox(
                                            width: 98,
                                            height: 98,
                                            child: CachedNetworkImage(
                                              imageUrl: url,
                                              fit: BoxFit.cover,
                                              placeholder: (_, __) => Container(color: Colors.black12),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Colors.black12,
                                                child: const Icon(Icons.broken_image_outlined),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (marked)
                                          Positioned.fill(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.delete_forever, color: Colors.white, size: 34),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),

                            if (_newPhotos.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('Nuevas fotos', style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _newPhotos.map<Widget>((x) {
                                  return Container(
                                    width: 98,
                                    height: 98,
                                    decoration: BoxDecoration(
                                      color: Colors.black12,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Center(
                                      child: IconButton(
                                        tooltip: 'Quitar',
                                        onPressed: _canEditOrDelete
                                            ? () => setState(() => _newPhotos.remove(x))
                                            : null,
                                        icon: const Icon(Icons.close),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Guardando...' : 'Guardar cambios'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
