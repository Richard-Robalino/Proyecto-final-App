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

class _EditRequestScreenState extends ConsumerState<EditRequestScreen> with SingleTickerProviderStateMixin {
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

  // Animación de entrada
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _addressCtrl.dispose();
    _animController.dispose();
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
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando: $e')));
    }
  }

  bool get _canEditOrDelete {
    final st = _req?.status ?? '';
    // Solo se puede editar si está solicitada (pending)
    // Ajusta según tus estados ('requested' suele ser el inicial)
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
    if (!_canEditOrDelete) return;

    final repo = ref.read(supabaseRepoProvider);
    final catId = _catId;
    final picked = _picked;

    if (catId == null || picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Faltan datos obligatorios.')));
      return;
    }

    setState(() => _saving = true);

    try {
      // 1. Actualizar datos
      await repo.updateRequest(
        requestId: widget.requestId,
        categoryId: catId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        lat: picked.latitude,
        lng: picked.longitude,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      );

      // 2. Borrar fotos
      for (final p in _toDelete) {
        await repo.deleteRequestPhoto(photoId: p.id, bucket: _bucket, path: p.path);
      }

      // 3. Subir nuevas fotos
      const uuid = Uuid();
      for (final x in _newPhotos) {
        final bytes = await x.readAsBytes();
        final path = 'requests/${widget.requestId}/${uuid.v4()}.jpg';
        await repo.uploadBytes(bucket: _bucket, path: path, bytes: Uint8List.fromList(bytes));
        await repo.addRequestPhoto(requestId: widget.requestId, path: path);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambios guardados con éxito')));
      context.pop(); // Volver atrás
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteRequest() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar solicitud?'),
        content: const Text('Esta acción no se puede deshacer.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final repo = ref.read(supabaseRepoProvider);
    try {
      await repo.deleteRequest(widget.requestId);
      if (!mounted) return;
      context.go('/client'); // Volver al home
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final req = _req;

    if (_loading || req == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(backgroundColor: cs.surface),
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Editar Solicitud'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          if (_canEditOrDelete)
            IconButton(
              tooltip: 'Eliminar solicitud',
              onPressed: _deleteRequest,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Aviso si no es editable
              if (!_canEditOrDelete)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El servicio está en curso. No se pueden realizar cambios.',
                          style: TextStyle(color: Colors.amber[900], fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              // 1. DETALLES
              _SectionLabel(icon: Icons.article_rounded, label: 'Detalles del Servicio'),
              const SizedBox(height: 10),
              
              // Categoría
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonFormField<int>(
                  value: _catId,
                  decoration: const InputDecoration(
                    labelText: 'Categoría',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: _canEditOrDelete ? (v) => setState(() => _catId = v) : null,
                ),
              ),
              const SizedBox(height: 12),
              
              _StyledTextField(
                controller: _titleCtrl,
                label: 'Título breve (Ej. Fuga en lavabo)',
                enabled: _canEditOrDelete,
              ),
              const SizedBox(height: 12),
              _StyledTextField(
                controller: _descCtrl,
                label: 'Descripción detallada',
                maxLines: 4,
                enabled: _canEditOrDelete,
              ),

              const SizedBox(height: 24),

              // 2. UBICACIÓN
              _SectionLabel(icon: Icons.location_on_rounded, label: 'Ubicación'),
              const SizedBox(height: 10),
              
              _StyledTextField(
                controller: _addressCtrl,
                label: 'Referencia / Dirección',
                enabled: _canEditOrDelete,
                icon: Icons.directions_rounded,
              ),
              const SizedBox(height: 12),
              
              // Mapa
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: _picked ?? LatLng(req.lat, req.lng),
                          initialZoom: 15,
                          onTap: _canEditOrDelete 
                            ? (_, p) => setState(() => _picked = p) 
                            : null,
                        ),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _picked ?? LatLng(req.lat, req.lng),
                                width: 50,
                                height: 50,
                                child: const Icon(Icons.location_pin, size: 50, color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_canEditOrDelete)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                            ),
                            child: const Text(
                              'Toca para mover',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. FOTOS
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SectionLabel(icon: Icons.camera_alt_rounded, label: 'Fotos'),
                  if (_canEditOrDelete)
                    TextButton.icon(
                      onPressed: _pickPhoto,
                      icon: const Icon(Icons.add_circle_rounded),
                      label: const Text('Agregar'),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (_existing.isEmpty && _newPhotos.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.5), style: BorderStyle.solid),
                  ),
                  child: Center(
                    child: Text('Sin fotos adjuntas', style: TextStyle(color: cs.onSurfaceVariant)),
                  ),
                ),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Fotos Existentes
                  ..._existing.map((p) {
                    final isDeleted = _toDelete.any((x) => x.id == p.id);
                    return GestureDetector(
                      onTap: _canEditOrDelete ? () => _toggleDeleteExisting(p) : null,
                      child: Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: CachedNetworkImageProvider(
                                  ref.read(supabaseRepoProvider).publicUrl(_bucket, p.path),
                                ),
                                fit: BoxFit.cover,
                                colorFilter: isDeleted 
                                  ? const ColorFilter.mode(Colors.grey, BlendMode.saturation) 
                                  : null,
                              ),
                            ),
                          ),
                          if (isDeleted)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Icon(Icons.delete_forever_rounded, color: Colors.white, size: 32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Nuevas Fotos
                  ..._newPhotos.map((x) {
                    return Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.secondary),
                          ),
                          child: const Center(child: Icon(Icons.image, color: Colors.white)),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkWell(
                            onTap: () => setState(() => _newPhotos.remove(x)),
                            child: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.close, size: 16, color: Colors.black),
                            ),
                          ),
                        )
                      ],
                    );
                  }),
                ],
              ),

              const SizedBox(height: 40),

              // BOTÓN GUARDAR
              if (_canEditOrDelete)
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: cs.primary.withOpacity(0.4),
                    ),
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Guardar Cambios',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.onSurface.withOpacity(0.8)),
        ),
      ],
    );
  }
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final int maxLines;
  final IconData? icon;

  const _StyledTextField({
    required this.controller,
    required this.label,
    this.enabled = true,
    this.maxLines = 1,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: cs.outline) : null,
        filled: true,
        fillColor: enabled ? cs.surfaceContainerHighest.withOpacity(0.3) : cs.surfaceContainerHighest.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}