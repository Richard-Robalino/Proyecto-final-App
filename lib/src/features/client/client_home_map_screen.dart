import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class ClientHomeMapScreen extends ConsumerStatefulWidget {
  const ClientHomeMapScreen({super.key});

  @override
  ConsumerState<ClientHomeMapScreen> createState() => _ClientHomeMapScreenState();
}

class _ClientHomeMapScreenState extends ConsumerState<ClientHomeMapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  LatLng? _me;
  bool _loading = true;

  // Filtros
  List<ServiceCategory> _categories = const [];
  int? _selectedCategoryId;
  double _radiusKm = 5;

  List<TechnicianSummary> _techs = const [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      
      _categories = await repo.fetchCategories();
      final pos = await _getLocation();
      _me = LatLng(pos.latitude, pos.longitude);

      await _loadTechs();
    } catch (e) {
      if (mounted) {
        // Ubicación por defecto si falla (Quito)
        _me = const LatLng(-0.1807, -78.4678); 
        _loadTechs(); // Intentar cargar en la ubicación por defecto
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('GPS desactivado');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw Exception('Permiso denegado');
    }
    if (permission == LocationPermission.deniedForever) throw Exception('Permiso denegado permanentemente');

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _loadTechs() async {
    if (_me == null) return;
    final repo = ref.read(supabaseRepoProvider);
    
    try {
      final res = await repo.getNearbyTechnicians(
        lat: _me!.latitude,
        lng: _me!.longitude,
        radiusKm: _radiusKm,
        categoryId: _selectedCategoryId,
      );
      if (mounted) setState(() => _techs = res);
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error cargando técnicos');
    }
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _me == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _me!,
              initialZoom: 14.5,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tecnigo.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _me!,
                    radius: _radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: cs.primary.withOpacity(0.08),
                    borderColor: cs.primary.withOpacity(0.3),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _me!,
                    width: 60, height: 60,
                    child: _MyLocationMarker(color: cs.primary),
                  ),
                  ..._techs.map((t) => Marker(
                        point: LatLng(t.lat, t.lng),
                        width: 50, height: 50,
                        child: _TechnicianMarker(
                          tech: t,
                          onTap: () => _showTechBottomSheet(t),
                        ),
                      )),
                ],
              ),
            ],
          ),

          // 2. PANEL SUPERIOR FLOTANTE
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _FilterPanel(
                categories: _categories,
                selectedCategory: _selectedCategoryId,
                radius: _radiusKm,
                onCategoryChanged: (id) async {
                  setState(() => _selectedCategoryId = id);
                  await _loadTechs();
                },
                onRadiusChanged: (r) async {
                  setState(() => _radiusKm = r);
                  await _loadTechs();
                },
              ),
            ),
          ),

          // 3. BOTÓN FLOTANTE "CENTRAR"
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'center_client_map',
              onPressed: () {
                if (_me != null) _mapController.move(_me!, 15);
              },
              backgroundColor: Colors.white,
              foregroundColor: cs.onSurface,
              child: const Icon(Icons.my_location),
            ),
          ),

          // 4. PANEL INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomSummaryPanel(
              techCount: _techs.length,
              onNewRequest: () => context.go('/client/request/new'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTechBottomSheet(TechnicianSummary t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TechDetailSheet(tech: t),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _MyLocationMarker extends StatefulWidget {
  final Color color;
  const _MyLocationMarker({required this.color});
  @override
  State<_MyLocationMarker> createState() => _MyLocationMarkerState();
}

class _MyLocationMarkerState extends State<_MyLocationMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.6, end: 1.0).animate(_controller);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 60 * _animation.value,
              height: 60 * _animation.value,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withOpacity(0.3)),
            ),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle, 
                color: widget.color, 
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TechnicianMarker extends StatelessWidget {
  final TechnicianSummary tech;
  final VoidCallback onTap;
  const _TechnicianMarker({required this.tech, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(tech.fullName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
          ClipPath(
            clipper: _TriangleClipper(),
            child: Container(color: Colors.white, width: 10, height: 6),
          )
        ],
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<ui.Path> {
  @override
  ui.Path getClip(Size size) {
    final path = ui.Path();
    path.lineTo(size.width / 2, size.height);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<ui.Path> oldClipper) => false;
}

class _FilterPanel extends StatelessWidget {
  final List<ServiceCategory> categories;
  final int? selectedCategory;
  final double radius;
  final Function(int?) onCategoryChanged;
  final Function(double) onRadiusChanged;

  const _FilterPanel({
    required this.categories,
    required this.selectedCategory,
    required this.radius,
    required this.onCategoryChanged,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // ✅ FIX DE OVERFLOW
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selector de Categoría
          DropdownButtonFormField<int?>(
            value: selectedCategory,
            isDense: true,
            isExpanded: true, // ✅ ESTO EVITA EL OVERFLOW HORIZONTAL
            decoration: InputDecoration(
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              prefixIcon: Icon(Icons.category_outlined, color: cs.primary),
              labelText: 'Filtrar por categoría',
              labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.6)),
            ),
            items: [
              const DropdownMenuItem(
                value: null, 
                child: Text('Todos los servicios', overflow: TextOverflow.ellipsis) // ✅ Control de texto largo
              ),
              ...categories.map((c) => DropdownMenuItem(
                value: c.id, 
                child: Text(c.name, overflow: TextOverflow.ellipsis) // ✅ Control de texto largo
              )),
            ],
            onChanged: onCategoryChanged,
          ),
          const Divider(height: 20),
          // Slider de Radio
          Row(
            children: [
              Icon(Icons.radar_rounded, color: cs.secondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Radio de búsqueda', style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                        Text('${radius.toInt()} km', style: TextStyle(fontWeight: FontWeight.bold, color: cs.secondary)),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 2,
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), // Reduce área táctil visual para que no desborde
                      ),
                      child: Slider(
                        value: radius,
                        min: 1,
                        max: 30,
                        activeColor: cs.secondary,
                        onChanged: onRadiusChanged,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomSummaryPanel extends StatelessWidget {
  final int techCount;
  final VoidCallback onNewRequest;

  const _BottomSummaryPanel({required this.techCount, required this.onNewRequest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$techCount Técnicos',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
                Text(
                  'disponibles en tu zona',
                  style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onNewRequest,
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
            ),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Cotizar'),
          ),
        ],
      ),
    );
  }
}

class _TechDetailSheet extends StatelessWidget {
  final TechnicianSummary tech;
  const _TechDetailSheet({required this.tech});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: cs.primaryContainer,
                child: Text(tech.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tech.fullName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                        Text(
                          ' ${tech.avgRating.toStringAsFixed(1)} (${tech.totalReviews} reseñas)',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
                child: Text('\$${tech.baseRate}/h', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800])),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/client/tech/${tech.technicianId}');
              },
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Ver Perfil Completo'),
            ),
          ),
        ],
      ),
    );
  }
}