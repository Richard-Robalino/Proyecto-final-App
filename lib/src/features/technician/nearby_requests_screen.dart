import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class NearbyRequestsScreen extends ConsumerStatefulWidget {
  const NearbyRequestsScreen({super.key});

  @override
  ConsumerState<NearbyRequestsScreen> createState() =>
      _NearbyRequestsScreenState();
}

class _NearbyRequestsScreenState extends ConsumerState<NearbyRequestsScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  bool _loading = true;
  double _radiusKm = 10;
  int? _categoryId;

  LatLng? _myLocation;

  List<ServiceCategory> _categories = const [];
  List<Map<String, dynamic>> _items = const [];

  // Controlador para el PageView de tarjetas inferiores
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);

      // Cargar categorías y ubicación en paralelo
      final results = await Future.wait([
        repo.fetchCategories(),
        _getLocation(),
      ]);

      _categories = results[0] as List<ServiceCategory>;
      final pos = results[1] as Position;
      _myLocation = LatLng(pos.latitude, pos.longitude);

      // Actualizar ubicación del técnico en BD
      await repo.upsertTechnicianLocation(
          lat: _myLocation!.latitude, lng: _myLocation!.longitude);

      // Cargar solicitudes iniciales
      await _loadRequests();
    } catch (e) {
      if (mounted) _showSnackBar('Error inicializando: $e', isError: true);
      // Fallback location (ej. centro de la ciudad) para no romper el mapa
      _myLocation = const LatLng(-0.1807, -78.4678);
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
      if (permission == LocationPermission.denied)
        throw Exception('Permiso denegado');
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _loadRequests() async {
    if (_myLocation == null) return;

    // Mostrar indicador de carga pequeño si ya tenemos datos previos
    // setState(() => _loading = true);

    try {
      final repo = ref.read(supabaseRepoProvider);
      final res = await repo.getNearbyRequests(
        lat: _myLocation!.latitude,
        lng: _myLocation!.longitude,
        radiusKm: _radiusKm,
        categoryId: _categoryId,
      );

      if (mounted) {
        setState(() {
          _items = res;
          _selectedIndex = -1; // Resetear selección
        });

        // Ajustar zoom del mapa para ver los resultados (opcional)
        // _fitBounds();
      }
    } catch (e) {
      if (mounted) _showSnackBar('Error cargando solicitudes', isError: true);
    }
  }

  void _onMarkerTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
    final item = _items[index];
    // Mover mapa suavemente al marcador seleccionado
    _mapController.move(LatLng(item['lat'], item['lng']), 15);
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
    final appState = ref.watch(appStateProvider);
    final verified = appState.verificationStatus == 'verified';
    final cs = Theme.of(context).colorScheme;

    if (_loading && _myLocation == null) {
      return Scaffold(
          body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }

    return Scaffold(
      body: Stack(
        children: [
          // 1. MAPA DE FONDO
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _myLocation!,
              initialZoom: 14,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
              onTap: (_, __) => setState(
                  () => _selectedIndex = -1), // Deseleccionar al tocar mapa
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tecnigo.app',
              ),

              // Círculo de Radio
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: _myLocation!,
                    radius: _radiusKm * 1000, // Metros
                    useRadiusInMeter: true,
                    color: cs.primary.withOpacity(0.05),
                    borderColor: cs.primary.withOpacity(0.2),
                    borderStrokeWidth: 1,
                  ),
                ],
              ),

              MarkerLayer(
                markers: [
                  // Mi Ubicación (Técnico)
                  Marker(
                    point: _myLocation!,
                    width: 60,
                    height: 60,
                    child: _PulsingMarker(color: cs.secondary),
                  ),

                  // Solicitudes (Oportunidades)
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isSelected = index == _selectedIndex;

                    return Marker(
                      point: LatLng(item['lat'], item['lng']),
                      width: isSelected ? 60 : 40,
                      height: isSelected ? 60 : 40,
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary : cs.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.primary, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4)
                            ],
                          ),
                          child: Icon(Icons.handyman_rounded,
                              color: isSelected ? Colors.white : cs.primary,
                              size: isSelected ? 30 : 20),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. HEADER FLOTANTE (Filtros y Estado)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Aviso de Verificación (Si aplica)
                // ... (dentro del Column del Positioned)
                if (appState.role == UserRole.technician && !verified)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius:
                          BorderRadius.circular(20), // Bordes más suaves
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1), blurRadius: 8)
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.white, size: 24),
                        const SizedBox(width: 12),
                        // ✅ CORRECCIÓN: Expanded evita el overflow
                        const Expanded(
                          child: Text(
                            'Cuenta no verificada. Solo modo lectura. Completa tu perfil.',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
// ...

                // Panel de Filtros
                _FilterCapsule(
                  categories: _categories,
                  selectedCategory: _categoryId,
                  radius: _radiusKm,
                  onCategoryChanged: (id) {
                    setState(() => _categoryId = id);
                    _loadRequests();
                  },
                  onRadiusChanged: (r) {
                    setState(() => _radiusKm = r);
                    // Debounce simple: esperar que suelte (onChangeEnd es mejor para slider)
                    _loadRequests();
                  },
                ),
              ],
            ),
          ),

          // 3. CARRUSEL INFERIOR (Tarjetas de Solicitud)
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            height: 160, // Altura de las tarjetas
            child: _items.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10)
                          ]),
                      child:
                          const Text('No hay solicitudes en esta zona 🤷‍♂️'),
                    ),
                  )
                : PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return _RequestMapCard(
                        item: item,
                        onTap: () =>
                            context.push('/tech/request/${item['request_id']}'),
                      );
                    },
                  ),
          ),

          // Botón Centrar
          Positioned(
            bottom: 200, // Encima del carrusel
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                if (_myLocation != null) _mapController.move(_myLocation!, 14);
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _PulsingMarker extends StatefulWidget {
  final Color color;
  const _PulsingMarker({required this.color});
  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);
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
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: widget.color.withOpacity(0.3)),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 4)
                  ]),
            ),
          ],
        );
      },
    );
  }
}

class _FilterCapsule extends StatelessWidget {
  final List<ServiceCategory> categories;
  final int? selectedCategory;
  final double radius;
  final Function(int?) onCategoryChanged;
  final Function(double) onRadiusChanged;

  const _FilterCapsule({
    required this.categories,
    required this.selectedCategory,
    required this.radius,
    required this.onCategoryChanged,
    required this.onRadiusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Márgenes laterales para que no toque los bordes de la pantalla
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. DROPDOWN (Le damos un peso flexible de 3)
          Expanded(
            flex: 3,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedCategory,
                isDense: true,
                hint: const Text('Categoría', overflow: TextOverflow.ellipsis),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                isExpanded: true, // Importante para evitar overflow interno
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w600,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todas')),
                  ...categories.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: onCategoryChanged,
              ),
            ),
          ),

          // 2. DIVISOR VERTICAL
          Container(
            width: 1,
            height: 24,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // 3. SLIDER DE RADIO (Le damos un peso flexible de 4 para que tenga más espacio)
          Expanded(
            flex: 4,
            child: Row(
              children: [
                // Texto compacto del km
                Text(
                  '${radius.toInt()}km',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                // Slider expandido
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      trackHeight: 2,
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12), // Reduce el área de toque visual
                    ),
                    child: Slider(
                      value: radius,
                      min: 1,
                      max: 50,
                      onChanged: onRadiusChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.search_off_rounded, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'No hay solicitudes en esta zona',
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestMapCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _RequestMapCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Solicitud';
    final desc = item['description'] ?? '';
    final dist = (item['distance_km'] as num).toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.build_rounded,
                  color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.near_me, size: 14, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Text('${dist.toStringAsFixed(1)} km de ti',
                          style: TextStyle(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
