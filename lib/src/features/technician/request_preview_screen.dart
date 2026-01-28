import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../data/repositories/supabase_repo.dart';
import '../../state/providers.dart';

class RequestPreviewScreen extends ConsumerStatefulWidget {
  const RequestPreviewScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<RequestPreviewScreen> createState() => _RequestPreviewScreenState();
}

class _RequestPreviewScreenState extends ConsumerState<RequestPreviewScreen> {
  bool _loading = true;
  ServiceRequest? _req;
  List<RequestPhoto> _photos = const [];

  SupabaseRepo get _repo => ref.read(supabaseRepoProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final req = await _repo.fetchRequestById(widget.requestId);
      final photos = await _repo.fetchRequestPhotos(widget.requestId);
      if (!mounted) return;
      setState(() {
        _req = req;
        _photos = photos;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando detalle: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitud'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : req == null
              ? const Center(child: Text('No se pudo cargar la solicitud'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  children: [
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(req.description),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _chip('Estado: ${req.status}'),
                              _chip('Fecha: ${req.createdAt.toString().substring(0, 16)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ✅ Ubicación + mapa
                    _card(
                      title: 'Ubicación',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((req.address ?? '').trim().isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.place_rounded, color: cs.primary),
                                const SizedBox(width: 6),
                                Expanded(child: Text(req.address!, maxLines: 2, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              height: 220,
                              child: FlutterMap(
                                options: MapOptions(
                                  initialCenter: LatLng(req.lat, req.lng),
                                  initialZoom: 15,
                                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.tecnigo',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: LatLng(req.lat, req.lng),
                                        width: 46,
                                        height: 46,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: cs.primary,
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(blurRadius: 14, color: cs.primary.withOpacity(0.25)),
                                            ],
                                          ),
                                          child: Icon(Icons.place_rounded, color: cs.onPrimary, size: 22),
                                        ),
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
                    const SizedBox(height: 12),

                    // ✅ Fotos + zoom
                    /*_card(
                      title: 'Fotos',
                      child: _photos.isEmpty
                          ? const Text('No hay fotos.')
                          : Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _photos.map((p) {
                                final url = _repo.publicUrl(SupabaseRepo.requestPhotosBucket, p.path);
                                return GestureDetector(
                                  onTap: () => _openImage(url),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(url, width: 90, height: 90, fit: BoxFit.cover),
                                  ),
                                );
                              }).toList(),
                            ),
                    ),*/
                  ],
                ),

      // ✅ NO QUITAMOS: Botón enviar cotización
      bottomSheet: req == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.request_quote_rounded),
                        label: const Text('Enviar cotización'),
                        onPressed: () => context.go('/tech/request/${widget.requestId}/quote'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Refrescar'),
                        onPressed: _load,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _card({String? title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}
