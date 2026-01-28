import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  bool _loading = true;
  bool _saving = false;

  List<ServiceCategory> _categories = const [];
  int? _categoryId;

  final _title = TextEditingController();
  final _desc = TextEditingController();

  LatLng? _location;
  String? _address;

  AiDiagnoseResult? _ai;
  final List<_PickedPhoto> _photos = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      _categories = await repo.fetchCategories();

      final pos = await _getLocation();
      _location = LatLng(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inicial: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw Exception('Activa el GPS');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 75);
    if (images.isEmpty) return;

    final picked = <_PickedPhoto>[];
    for (final img in images) {
      final bytes = await img.readAsBytes();
      picked.add(_PickedPhoto(name: img.name, bytes: bytes));
    }

    setState(() => _photos.addAll(picked));
  }

  Future<void> _runAiAssist() async {
    if (_desc.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe el problema con más detalle.')));
      return;
    }

    try {
      final repo = ref.read(supabaseRepoProvider);
      final res = await repo.aiDiagnose(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        categories: _categories,
      );

      setState(() {
        _ai = res;
        if (res.suggestedCategoryId != null) {
          _categoryId = res.suggestedCategoryId;
        }
      });

      if (!mounted) return;
      _showAiSheet(res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('IA no disponible: $e')));
    }
  }

  void _showAiSheet(AiDiagnoseResult r) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Asistente IA', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  _pill('Urgencia: ${r.urgency.toUpperCase()}', cs.primaryContainer, cs.onPrimaryContainer),
                  const SizedBox(width: 8),
                  if (r.suggestedCategoryName != null)
                    _pill('Categoría: ${r.suggestedCategoryName}', cs.secondaryContainer, cs.onSecondaryContainer),
                ],
              ),
              const SizedBox(height: 10),
              Text(r.summary, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 10),
              if (r.questions.isNotEmpty) ...[
                Text('Preguntas para afinar:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...r.questions.map((q) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.help_outline_rounded),
                      title: Text(q),
                    )),
              ],
              if (r.safetyWarnings.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Seguridad:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ...r.safetyWarnings.map((w) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.warning_rounded, color: cs.error),
                      title: Text(w),
                    )),
              ],
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Listo'),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Future<void> _submit() async {
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una categoría.')));
      return;
    }
    if (_title.text.trim().isEmpty || _desc.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa título y descripción.')));
      return;
    }
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay ubicación.')));
      return;
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(supabaseRepoProvider);
      final requestId = await repo.createRequest(
        categoryId: _categoryId!,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        lat: _location!.latitude,
        lng: _location!.longitude,
        address: _address,
        aiSummary: _ai?.raw,
      );

      // subir fotos
      for (final p in _photos) {
        final path = 'requests/$requestId/${const Uuid().v4()}.jpg';
        await repo.uploadBytes(bucket: 'request_photos', path: path, bytes: p.bytes);
        await repo.addRequestPhoto(requestId: requestId, path: path);
      }

      if (!mounted) return;
      context.go('/client/request/$requestId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final loc = _location;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva solicitud')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categories
                  .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Título corto',
                hintText: 'Ej: Fuga debajo del lavabo',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Describe el problema',
                hintText: 'Incluye detalles: cuándo empezó, qué intentaste, etc.',
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _runAiAssist,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Asistente IA'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhotos,
                    icon: const Icon(Icons.add_photo_alternate_rounded),
                    label: Text('Fotos (${_photos.length})'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_photos.isNotEmpty)
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final p = _photos[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(p.bytes, height: 96, width: 96, fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: IconButton(
                            onPressed: () => setState(() => _photos.removeAt(i)),
                            icon: const Icon(Icons.close_rounded),
                            style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
            const SizedBox(height: 14),
            Text('Ubicación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (loc != null)
              Container(
                height: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: loc,
                    initialZoom: 15,
                    onTap: (tapPosition, point) => setState(() => _location = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tecnigo',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: loc,
                          width: 46,
                          height: 46,
                          child: Container(
                            decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            child: Icon(Icons.place_rounded, color: cs.onPrimary),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => _address = v.trim(),
              decoration: const InputDecoration(labelText: 'Dirección (opcional)', hintText: 'Ej: Av. Siempre Viva 123'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Publicar solicitud'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Al publicar, técnicos cercanos enviarán cotizaciones. Podrás comparar y aceptar.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          ],
        ),
      ),
    );
  }
}

class _PickedPhoto {
  _PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}
