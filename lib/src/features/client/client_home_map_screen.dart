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

class _ClientHomeMapScreenState extends ConsumerState<ClientHomeMapScreen> {
  LatLng? _me;
  bool _loading = true;

  List<ServiceCategory> _categories = const [];
  int? _selectedCategoryId;
  double _radiusKm = 8;

  List<TechnicianSummary> _techs = const [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      final pos = await _getLocation();
      _me = LatLng(pos.latitude, pos.longitude);

      _categories = await repo.fetchCategories();
      await _loadTechs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ubicación/Backend: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _getLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Activa el GPS / ubicación del dispositivo');
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _loadTechs() async {
    final repo = ref.read(supabaseRepoProvider);
    if (_me == null) return;

    final res = await repo.getNearbyTechnicians(
      lat: _me!.latitude,
      lng: _me!.longitude,
      radiusKm: _radiusKm,
      categoryId: _selectedCategoryId,
    );
    setState(() => _techs = res);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (me == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mapa')),
        body: const Center(child: Text('No se pudo obtener ubicación.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Técnicos'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loadTechs,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Todas'),
                      ),
                      ..._categories.map(
                        (c) => DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (v) async {
                      setState(() => _selectedCategoryId = v);
                      await _loadTechs();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Radio: ${_radiusKm.toStringAsFixed(0)} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Slider(
                        value: _radiusKm,
                        min: 2,
                        max: 25,
                        divisions: 23,
                        label: '${_radiusKm.toStringAsFixed(0)} km',
                        onChanged: (v) => setState(() => _radiusKm = v),
                        onChangeEnd: (_) => _loadTechs(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: me,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tecnigo',
                    ),
                    MarkerLayer(
                      markers: [
                        // Yo
                        Marker(
                          point: me,
                          width: 46,
                          height: 46,
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 14,
                                  color: cs.primary.withOpacity(0.25),
                                )
                              ],
                            ),
                            child: Icon(Icons.my_location_rounded, color: cs.onPrimary, size: 20),
                          ),
                        ),
                        // Técnicos
                        ..._techs.map(
                          (t) => Marker(
                            point: LatLng(t.lat, t.lng),
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () => _showTechBottomSheet(t),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.secondary, width: 1.2),
                                ),
                                child: Icon(Icons.handyman_rounded, color: cs.onSecondaryContainer, size: 20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 20,
                          color: Colors.black.withOpacity(0.07),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Técnicos disponibles: ${_techs.length}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => context.go('/client/request/new'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Nueva solicitud'),
                        )
                      ],
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

  void _showTechBottomSheet(TechnicianSummary t) {
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ MOD: tocar nombre -> ir a perfil del técnico
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  context.go('/client/tech/${t.technicianId}');
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    t.fullName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ),

              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.star_rounded, color: cs.tertiary, size: 20),
                  const SizedBox(width: 4),

                  // ✅ MOD: si no hay reseñas, mostrar "Sin reseñas"
                  Text(
                    t.totalReviews == 0
                        ? 'Sin reseñas'
                        : '${t.avgRating.toStringAsFixed(1)} (${t.totalReviews})',
                  ),

                  const SizedBox(width: 12),
                  Icon(Icons.near_me_rounded, color: cs.outline, size: 18),
                  const SizedBox(width: 4),
                  Text('${t.distanceKm.toStringAsFixed(1)} km'),
                ],
              ),
              const SizedBox(height: 10),
              Text('Tarifa base: \$${t.baseRate}', style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/client/request/new');
                  },
                  child: const Text('Crear solicitud (cotizar)'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
