import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  const RequestDetailsScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<RequestDetailsScreen> createState() =>
      _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  bool _loading = true;
  ServiceRequest? _request;
  List<RequestPhoto> _photos = const [];

  static const _bucket = 'request_photos';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      final req = await repo.fetchRequestById(widget.requestId);
      final photos = await repo.fetchRequestPhotos(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = req;
        _photos = photos;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _canDelete {
    final s = _request?.status ?? '';
    return s == 'requested' || s == 'quoted';
  }

  bool get _canReview {
    final s = _request?.status ?? '';
    return s == 'completed';
  }

  Future<void> _confirmDelete() async {
    if (!_canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No se puede eliminar: el trabajo ya inició.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar solicitud'),
        content: const Text('¿Seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.deleteRequest(widget.requestId);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Solicitud eliminada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'requested':
        return 'Solicitada';
      case 'quoted':
        return 'Cotización';
      case 'accepted':
        return 'Aceptada';
      case 'on_the_way':
        return 'En camino';
      case 'in_progress':
        return 'En progreso';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return s;
    }
  }

  Color _statusColor(BuildContext context, String s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case 'requested':
        return cs.secondaryContainer;
      case 'quoted':
        return cs.tertiaryContainer;
      case 'accepted':
        return cs.primaryContainer;
      case 'on_the_way':
        return cs.secondaryContainer;
      case 'in_progress':
        return cs.primaryContainer;
      case 'completed':
        return Colors.green.withOpacity(0.15);
      case 'cancelled':
        return Colors.red.withOpacity(0.12);
      default:
        return cs.surfaceContainerHighest;
    }
  }

  Future<void> _openPhoto(String url) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  void _openQuotesBottomSheet(ServiceRequest req) {
    final repo = ref.read(supabaseRepoProvider);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: StreamBuilder<List<Quote>>(
              stream: repo.streamQuotes(widget.requestId),
              builder: (context, snap) {
                final quotes = snap.data ?? const <Quote>[];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (quotes.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(child: Text('Aún no hay cotizaciones.')),
                  );
                }

                final acceptedId = req.acceptedQuoteId;

                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  child: ListView.separated(
                    itemCount: quotes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final q = quotes[i];
                      final isAccepted =
                          acceptedId != null && acceptedId == q.id;

                      final canAccept = acceptedId == null &&
                          (req.status == 'quoted' || req.status == 'requested');

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(' \$${q.price}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isAccepted
                                          ? Colors.green.withOpacity(0.15)
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      isAccepted
                                          ? 'ACEPTADA'
                                          : q.status.toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12),
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('${q.estimatedMinutes} min'),
                                ],
                              ),
                              if ((q.message ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(q.message!,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium),
                              ],
                              const SizedBox(height: 12),
                              if (isAccepted)
                                const Text('Esta cotización ya fue aceptada.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700))
                              else if (canAccept)
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: FilledButton.icon(
                                    icon: const Icon(Icons.check_rounded),
                                    label: const Text('Aceptar cotización'),
                                    onPressed: () async {
                                      final ok = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          title:
                                              const Text('Aceptar cotización'),
                                          content: const Text(
                                              '¿Confirmas que deseas aceptar esta cotización?'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, false),
                                                child: const Text('Cancelar')),
                                            FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Aceptar')),
                                          ],
                                        ),
                                      );
                                      if (ok != true) return;

                                      try {
                                        await repo.acceptQuote(q.id);
                                        if (!mounted) return;
                                        Navigator.pop(
                                            ctx); // cerrar bottomsheet
                                        await _loadAll(); // refrescar detalle
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Cotización aceptada.')));
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text(
                                                    'No se pudo aceptar: $e')));
                                      }
                                    },
                                  ),
                                )
                              else
                                const Text(
                                    'No se puede aceptar en este estado.',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(supabaseRepoProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: const Center(child: Text('No se pudo cargar la solicitud.')),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final loc = LatLng(request.lat, request.lng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: () => context.go('/client/request/${request.id}/edit'),
            icon: const Icon(Icons.edit_rounded),
          ),
          IconButton(
            tooltip: 'Eliminar',
            onPressed: _confirmDelete,
            icon: Icon(Icons.delete_outline_rounded,
                color: _canDelete ? null : cs.outline),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== Header =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(request.description),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusColor(context, request.status),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Estado: ${_statusLabel(request.status)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                              'Fecha: ${request.createdAt.day.toString().padLeft(2, '0')}/${request.createdAt.month.toString().padLeft(2, '0')} ${request.createdAt.hour.toString().padLeft(2, '0')}:${request.createdAt.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ===== Ubicación + Mapa =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ubicación',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    if ((request.address ?? '').trim().isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.place_rounded, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(request.address!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis)),
                        ],
                      )
                    else
                      Row(
                        children: const [
                          Icon(Icons.place_rounded, size: 18),
                          SizedBox(width: 6),
                          Expanded(
                              child: Text('Sin dirección (solo coordenadas).')),
                        ],
                      ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 170,
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: loc,
                            initialZoom: 15,
                            interactionOptions: const InteractionOptions(
                                flags: InteractiveFlag.none),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.tecnigo',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: loc,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: cs.primary,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            blurRadius: 14,
                                            color:
                                                cs.primary.withOpacity(0.25)),
                                      ],
                                    ),
                                    child: Icon(Icons.location_on_rounded,
                                        color: cs.onPrimary, size: 22),
                                  ),
                                )
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

            const SizedBox(height: 14),

            // ===== Fotos =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fotos',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    if (_photos.isEmpty)
                      const Text('No hay fotos subidas.')
                    else
                      SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _photos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final p = _photos[i];
                            final url = repo.publicUrl(_bucket, p.path);
                            return GestureDetector(
                              onTap: () => _openPhoto(url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: 120,
                                  height: 92,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    width: 120,
                                    height: 92,
                                    color: cs.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    width: 120,
                                    height: 92,
                                    color: cs.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child:
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ✅ ===== Flujo / Estados (REGRESÓ) =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flujo / Estados',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    StreamBuilder<List<RequestEvent>>(
                      stream: repo.streamRequestEvents(widget.requestId),
                      builder: (context, snap) {
                        final events = snap.data ?? const <RequestEvent>[];
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (events.isEmpty) {
                          return const Text('Aún no hay eventos registrados.');
                        }

                        // Mostramos del más reciente al más antiguo
                        final list = events.reversed.toList();

                        return Column(
                          children: list.map((e) {
                            final time =
                                '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.show_chart_rounded,
                                      color: cs.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _statusLabel(e.status),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w900),
                                              ),
                                            ),
                                            Text(time,
                                                style: TextStyle(
                                                    color: cs.outline)),
                                          ],
                                        ),
                                        if ((e.note ?? '').trim().isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 2),
                                            child: Text(e.note!,
                                                style: TextStyle(
                                                    color:
                                                        cs.onSurfaceVariant)),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ✅ ===== Cotizaciones (BOTÓN) =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cotizaciones',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    StreamBuilder<List<Quote>>(
                      stream: repo.streamQuotes(widget.requestId),
                      builder: (context, snap) {
                        final quotes = snap.data ?? const <Quote>[];
                        final count = quotes.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recibidas: $count'),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: () =>
                                    _openQuotesBottomSheet(request),
                                icon: const Icon(Icons.receipt_long_rounded),
                                label: Text(count == 0
                                    ? 'Ver cotizaciones'
                                    : 'Ver cotizaciones ($count)'),
                              ),
                            ),
                            if (request.acceptedQuoteId != null) ...[
                              const SizedBox(height: 10),
                              const Text('✅ Ya aceptaste una cotización.',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

// ✅ ===== Calificar técnico =====
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Calificación',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _canReview
                          ? 'El servicio fue completado. Ya puedes calificar al técnico.'
                          : 'La calificación se habilita cuando el técnico complete el servicio.',
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _canReview
                            ? () => context
                                .go('/client/request/${request.id}/review')
                            : null,
                        icon: const Icon(Icons.star_rate_rounded),
                        label: const Text('Calificar técnico'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
