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

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> with SingleTickerProviderStateMixin {
  // Controladores y Estado
  bool _loading = true;
  bool _saving = false;
  bool _aiLoading = false;

  List<ServiceCategory> _categories = const [];
  int? _categoryId;

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  
  // Ubicación
  LatLng? _location;
  String? _address;
  final MapController _mapController = MapController();

  // IA y Fotos
  AiDiagnoseResult? _aiResult;
  final List<_PickedPhoto> _photos = [];

  // Animaciones
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );
    
    _bootstrap();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      // Carga paralela
      final results = await Future.wait([
        repo.fetchCategories(),
        _getLocation(),
      ]);

      _categories = results[0] as List<ServiceCategory>;
      final pos = results[1] as Position;
      _location = LatLng(pos.latitude, pos.longitude);
      
      _animController.forward(); // Iniciar animación de entrada
    } catch (e) {
      if (mounted) _showSnackBar('Error inicializando: $e', isError: true);
      // Fallback location (Quito por defecto para no romper el mapa)
      _location = const LatLng(-0.1807, -78.4678);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('El GPS está desactivado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Permiso denegado');
    }
    if (permission == LocationPermission.deniedForever) throw Exception('Permiso denegado permanentemente');

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 70, maxWidth: 1024);
    if (images.isEmpty) return;

    final picked = <_PickedPhoto>[];
    for (final img in images) {
      final bytes = await img.readAsBytes();
      picked.add(_PickedPhoto(name: img.name, bytes: bytes));
    }

    setState(() => _photos.addAll(picked));
  }

  Future<void> _runAiAssist() async {
    if (_descCtrl.text.trim().length < 10) {
      _showSnackBar('Por favor, describe el problema un poco más para que la IA entienda.', isError: true);
      return;
    }

    setState(() => _aiLoading = true);
    final repo = ref.read(supabaseRepoProvider);

    try {
      final res = await repo.aiDiagnose(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        categories: _categories,
      );

      setState(() {
        _aiResult = res;
        // Auto-seleccionar categoría si la IA está segura
        if (res.suggestedCategoryId != null) {
          _categoryId = res.suggestedCategoryId;
        }
        // Opcional: Auto-completar título si está vacío
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = "Reparación de ${res.suggestedCategoryName ?? 'Servicio'}";
        }
      });
      
      _showAiSuccessDialog();

    } catch (e) {
      _showSnackBar('La IA está descansando: $e', isError: true);
    } finally {
      setState(() => _aiLoading = false);
    }
  }

  void _showAiSuccessDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AiResultSheet(result: _aiResult!),
    );
  }

  Future<void> _submit() async {
    if (_categoryId == null) return _showSnackBar('Selecciona una categoría', isError: true);
    if (_titleCtrl.text.trim().isEmpty) return _showSnackBar('Escribe un título', isError: true);
    if (_location == null) return _showSnackBar('Necesitamos tu ubicación', isError: true);

    setState(() => _saving = true);
    final repo = ref.read(supabaseRepoProvider);

    try {
      final requestId = await repo.createRequest(
        categoryId: _categoryId!,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        lat: _location!.latitude,
        lng: _location!.longitude,
        address: _address,
        aiSummary: _aiResult?.raw,
      );

      // Subir fotos
      for (final p in _photos) {
        final path = 'requests/$requestId/${const Uuid().v4()}.jpg';
        await repo.uploadBytes(bucket: 'request_photos', path: path, bytes: p.bytes);
        await repo.addRequestPhoto(requestId: requestId, path: path);
      }

      if (!mounted) return;
      context.replace('/client/request/$requestId'); // Replace para no volver atrás al formulario
      
    } catch (e) {
      _showSnackBar('Error al crear: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(backgroundColor: cs.surface, body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Nueva Solicitud'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. HEADER IA
                  _AiMagicCard(
                    isLoading: _aiLoading,
                    hasResult: _aiResult != null,
                    onTap: _runAiAssist,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 2. FORMULARIO PRINCIPAL
                  _SectionTitle(title: 'Detalles del Problema', icon: Icons.description_outlined),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _descCtrl,
                    maxLines: 4,
                    decoration: _inputDecoration('Describe el problema detalladamente...'),
                  ),
                  const SizedBox(height: 12),
                  
                  TextField(
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('Título breve (Ej: Grifo goteando)'),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _categoryId,
                        hint: const Text('Selecciona Categoría'),
                        isExpanded: true,
                        items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. FOTOS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const _SectionTitle(title: 'Fotos (Opcional)', icon: Icons.camera_alt_outlined),
                      if (_photos.isNotEmpty)
                        Text('${_photos.length} añadidas', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PhotoPickerList(
                    photos: _photos,
                    onAdd: _pickPhotos,
                    onRemove: (i) => setState(() => _photos.removeAt(i)),
                  ),

                  const SizedBox(height: 24),

                  // 4. UBICACIÓN (MAPA INTERACTIVO TIPO UBER)
                  _SectionTitle(title: '¿Dónde es el servicio?', icon: Icons.location_on_outlined),
                  const SizedBox(height: 12),
                  
                  Container(
                    height: 250, // Un poco más alto para maniobrar
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                      border: Border.all(color: cs.primary.withOpacity(0.3), width: 1.5), // Borde resaltado
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _location!,
                              initialZoom: 15,
                              // ✅ Actualizamos _location mientras el usuario arrastra el mapa
                              onPositionChanged: (camera, hasGesture) {
                                if (hasGesture) {
                                  // Solo actualizar si el usuario lo mueve, no por código
                                  setState(() => _location = camera.center);
                                }
                              },
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                              // ❌ Quitamos el MarkerLayer aquí
                            ],
                          ),
                          
                          // ✅ PIN FIJO EN EL CENTRO (Estilo Uber)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 40), // Elevamos el pin para que la punta toque el centro
                            child: Icon(Icons.location_pin, size: 50, color: cs.primary),
                          ),
                          
                          // Sombra del pin
                          Positioned(
                            child: Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                shape: BoxShape.circle,
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)],
                              ),
                            ),
                          ),

                          // Botón GPS
                          Positioned(
                            bottom: 10,
                            right: 10,
                            child: FloatingActionButton.small(
                              heroTag: 'gps_btn_new_req',
                              onPressed: () async {
                                final pos = await _getLocation();
                                final newLoc = LatLng(pos.latitude, pos.longitude);
                                setState(() => _location = newLoc);
                                _mapController.move(newLoc, 16);
                              },
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.my_location),
                            ),
                          ),
                          
                          // Etiqueta de instrucción
                          Positioned(
                            top: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: const Text('Mueve el mapa para ajustar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleCtrl..text = _address ?? '', // Hack rápido para visualizar, mejor usar otro controller
                    onChanged: (v) => _address = v,
                    decoration: _inputDecoration('Referencia / Dirección (Opcional)', icon: Icons.home_work_outlined),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
            
            // BOTÓN GUARDAR
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('PUBLICAR SOLICITUD', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: cs.primary) : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _AiMagicCard extends StatelessWidget {
  final bool isLoading;
  final bool hasResult;
  final VoidCallback onTap;

  const _AiMagicCard({required this.isLoading, required this.hasResult, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.1), cs.secondary.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.2), blurRadius: 8)],
                  ),
                  child: isLoading
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary))
                      : Icon(Icons.auto_awesome, color: cs.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasResult ? 'Diagnóstico IA Listo' : 'Asistente IA',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.primary),
                      ),
                      Text(
                        hasResult 
                          ? 'Toca para ver el análisis' 
                          : 'Escribe el problema y deja que la IA categorice y diagnostique.',
                        style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (!isLoading)
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.primary.withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _PhotoPickerList extends StatelessWidget {
  final List<_PickedPhoto> photos;
  final VoidCallback onAdd;
  final Function(int) onRemove;

  const _PhotoPickerList({required this.photos, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Botón Agregar (Primero)
          if (index == 0) {
            return GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo, color: Colors.grey),
                    const SizedBox(height: 4),
                    const Text('Agregar', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          // Fotos
          final photoIndex = index - 1;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  photos[photoIndex].bytes,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => onRemove(photoIndex),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Bottom Sheet con resultado IA (Estilizado)
class _AiResultSheet extends StatelessWidget {
  final AiDiagnoseResult result;
  const _AiResultSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.purple),
              const SizedBox(width: 10),
              Text('Análisis Inteligente', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          
          _InfoRow('Categoría Sugerida:', result.suggestedCategoryName ?? 'General'),
          const SizedBox(height: 10),
          _InfoRow('Urgencia:', result.urgency.toUpperCase()),
          const Divider(height: 30),
          
          Text(result.summary, style: const TextStyle(fontSize: 16, height: 1.5)),
          
          if (result.safetyWarnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.warning_amber, color: Colors.red, size: 20), SizedBox(width: 8), Text('Seguridad', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                  const SizedBox(height: 8),
                  ...result.safetyWarnings.map((w) => Text('• $w', style: const TextStyle(color: Colors.red))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Usar esta información'),
          ),
        ],
      ),
    );
  }

  Widget _InfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _PickedPhoto {
  _PickedPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}