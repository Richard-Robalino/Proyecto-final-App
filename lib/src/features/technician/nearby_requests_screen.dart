import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class NearbyRequestsScreen extends ConsumerStatefulWidget {
  const NearbyRequestsScreen({super.key});

  @override
  ConsumerState<NearbyRequestsScreen> createState() => _NearbyRequestsScreenState();
}

class _NearbyRequestsScreenState extends ConsumerState<NearbyRequestsScreen> {
  bool _loading = true;

  double _radiusKm = 10;
  int? _categoryId;

  double? _lat;
  double? _lng;

  List<ServiceCategory> _categories = const [];
  List<Map<String, dynamic>> _items = const [];

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
      _lat = pos.latitude;
      _lng = pos.longitude;

      // Actualizar ubicación del técnico (para mapa del cliente y rutas)
      await repo.upsertTechnicianLocation(lat: _lat!, lng: _lng!);

      _categories = await repo.fetchCategories();

      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ubicación: $e')));
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
      throw Exception('Permiso denegado');
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _load() async {
    if (_lat == null || _lng == null) return;

    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      final res = await repo.getNearbyRequests(
        lat: _lat!,
        lng: _lng!,
        radiusKm: _radiusKm,
        categoryId: _categoryId,
      );
      setState(() => _items = res);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final verified = appState.verificationStatus == 'approved';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes cercanas'),
        actions: [
          IconButton(onPressed: _bootstrap, icon: const Icon(Icons.my_location_rounded)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          if (appState.role == UserRole.technician && !verified)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Tu cuenta está en verificación (${appState.verificationStatus}). '
                          'Sube certificaciones en tu perfil. No podrás cotizar hasta ser aprobado.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: _categoryId,
                    decoration: const InputDecoration(labelText: 'Filtrar categoría'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                      ..._categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: (v) async {
                      setState(() => _categoryId = v);
                      await _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 130,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Radio: ${_radiusKm.toStringAsFixed(0)} km', style: Theme.of(context).textTheme.bodySmall),
                      Slider(
                        value: _radiusKm,
                        min: 2,
                        max: 25,
                        divisions: 23,
                        onChanged: (v) => setState(() => _radiusKm = v),
                        onChangeEnd: (_) => _load(),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No hay solicitudes cercanas por ahora.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return _RequestCard(
                            title: it['title'] as String,
                            description: it['description'] as String,
                            distanceKm: (it['distance_km'] as num).toDouble(),
                            onTap: () => context.go('/tech/request/${it['request_id']}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.title,
    required this.description,
    required this.distanceKm,
    required this.onTap,
  });

  final String title;
  final String description;
  final double distanceKm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.assignment_rounded, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.near_me_rounded, color: cs.outline, size: 18),
                        const SizedBox(width: 4),
                        Text('${distanceKm.toStringAsFixed(1)} km', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    )
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
