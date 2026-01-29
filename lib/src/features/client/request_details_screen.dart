import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class RequestDetailsScreen extends ConsumerStatefulWidget {
  const RequestDetailsScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends ConsumerState<RequestDetailsScreen> {
  bool _loading = true;
  ServiceRequest? _request;
  List<RequestPhoto> _photos = const [];
  static const _bucket = 'request_photos';

  // Para saber si ya calificó
  bool _hasReviewed = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      
      // Carga paralela: Request, Fotos, y si ya hizo review
      final results = await Future.wait([
        repo.fetchRequestById(widget.requestId),
        repo.fetchRequestPhotos(widget.requestId),
        repo.hasReviewed(widget.requestId),
      ]);
      
      if (!mounted) return;
      setState(() {
        _request = results[0] as ServiceRequest;
        _photos = results[1] as List<RequestPhoto>;
        _hasReviewed = results[2] as bool;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Solo se puede borrar si no ha sido aceptada ni iniciada
  bool get _canDelete {
    final s = _request?.status ?? '';
    return (s == 'requested' || s == 'quoted') && _request?.acceptedQuoteId == null;
  }

  // Solo se puede calificar si está completado y NO ha calificado aún
  bool get _canReview {
    final s = _request?.status ?? '';
    return (s == 'completed' || s == 'rated') && !_hasReviewed;
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Eliminar solicitud?'),
        content: const Text('Se borrará permanentemente y cancelará las cotizaciones.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.deleteRequest(widget.requestId);
      if (!mounted) return;
      context.pop(); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final req = _request;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (req == null) return const Scaffold(body: Center(child: Text('Solicitud no encontrada')));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Detalle de Servicio'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _loadAll, icon: const Icon(Icons.refresh_rounded)),
          if (_canDelete)
            PopupMenuButton(
              itemBuilder: (context) => [
                PopupMenuItem(
                  onTap: () => context.push('/client/request/${req.id}/edit'),
                  child: const Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Editar')]),
                ),
                PopupMenuItem(
                  onTap: _confirmDelete,
                  child: const Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))]),
                ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. ESTADO
            Center(child: _StatusBadgeLarge(status: req.status)),
            const SizedBox(height: 20),

            // 2. INFO PRINCIPAL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(req.description, style: TextStyle(fontSize: 15, color: cs.onSurface.withOpacity(0.8))),
                  
                  const Divider(height: 24),

                  // FOTOS
                  if (_photos.isNotEmpty) ...[
                    const Text('Fotos adjuntas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final url = ref.read(supabaseRepoProvider).publicUrl(_bucket, _photos[i].path);
                          return GestureDetector(
                            onTap: () => _showPhotoDialog(context, url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: url, 
                                width: 80, height: 80, 
                                fit: BoxFit.cover,
                                placeholder: (_,__) => Container(color: Colors.grey[200]),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // UBICACIÓN
                  if (req.address != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: cs.primary),
                        const SizedBox(width: 4),
                        Expanded(child: Text(req.address!, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. COTIZACIONES (LO MÁS IMPORTANTE PARA EL CLIENTE)
            _QuotesList(
              requestId: req.id,
              acceptedQuoteId: req.acceptedQuoteId,
              onQuoteAccepted: _loadAll, // Recargar al aceptar
            ),

            const SizedBox(height: 24),

            // 4. HISTORIAL
            const Text('Seguimiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _TimelineSection(requestId: req.id),

            const SizedBox(height: 40),

            // 5. BOTÓN CALIFICAR (Si aplica)
            if (_canReview)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.push('/client/request/${req.id}/review');
                    _loadAll();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.star_rounded),
                  label: const Text('CALIFICAR TÉCNICO', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            
            // Si ya calificó
            if (req.status == 'rated' && _hasReviewed)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('¡Servicio finalizado y calificado!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _showPhotoDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(child: CachedNetworkImage(imageUrl: url)),
      ),
    );
  }
}

// --- COMPONENTES ---

class _QuotesList extends ConsumerWidget {
  final String requestId;
  final String? acceptedQuoteId;
  final VoidCallback onQuoteAccepted;

  const _QuotesList({required this.requestId, this.acceptedQuoteId, required this.onQuoteAccepted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(supabaseRepoProvider);
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<List<Quote>>(
      stream: repo.streamQuotes(requestId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator());

        final quotes = snapshot.data ?? [];
        if (quotes.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 12),
                const Expanded(child: Text('Esperando cotizaciones de técnicos cercanos...')),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cotizaciones (${quotes.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            ...quotes.map((q) => _QuoteCard(
              quote: q,
              isAccepted: acceptedQuoteId == q.id,
              isDisabled: acceptedQuoteId != null && acceptedQuoteId != q.id,
              onAccept: () => _handleAccept(context, ref, q),
              onViewProfile: () => context.push('/client/tech/${q.technicianId}'),
            )),
          ],
        );
      },
    );
  }

  Future<void> _handleAccept(BuildContext context, WidgetRef ref, Quote q) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Aceptar cotización?'),
        content: Text('Aceptarás la oferta de \$${q.price} y el técnico será notificado para iniciar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Aceptar Oferta')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(supabaseRepoProvider).acceptQuote(q.id);
        onQuoteAccepted();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

class _QuoteCard extends StatelessWidget {
  final Quote quote;
  final bool isAccepted;
  final bool isDisabled;
  final VoidCallback onAccept;
  final VoidCallback onViewProfile;

  const _QuoteCard({
    required this.quote,
    required this.isAccepted,
    required this.isDisabled,
    required this.onAccept,
    required this.onViewProfile,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (isDisabled) return const SizedBox.shrink(); // Ocultar las rechazadas para limpiar la vista

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAccepted ? Colors.green[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isAccepted ? Border.all(color: Colors.green, width: 2) : Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Precio
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${quote.price}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: cs.primary)),
                    Text('${quote.estimatedMinutes} min aprox.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                // Ver Perfil
                TextButton(
                  onPressed: onViewProfile,
                  child: const Text('Ver Técnico'),
                ),
              ],
            ),
          ),
          if (quote.message != null && quote.message!.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: cs.surfaceContainerHighest.withOpacity(0.3),
              child: Text('"${quote.message}"', style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
          
          if (!isAccepted)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('ACEPTAR Y CONTRATAR'),
                ),
              ),
            ),
          
          if (isAccepted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.green,
              child: const Text('OFERTA ACEPTADA', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
        ],
      ),
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  final String requestId;
  const _TimelineSection({required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(supabaseRepoProvider);

    return StreamBuilder<List<RequestEvent>>(
      stream: repo.streamRequestEvents(requestId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) return const Text('Esperando actividad...', style: TextStyle(color: Colors.grey));

        final sorted = events.reversed.toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final e = sorted[index];
            final isLast = index == sorted.length - 1;
            final date = DateFormat('HH:mm').format(e.createdAt.toLocal());

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(child: Container(width: 2, color: Colors.grey[300])),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_mapStatus(e.status), style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _mapStatus(String s) {
    switch(s) {
      case 'requested': return 'Solicitud creada';
      case 'quoted': return 'Nueva cotización recibida';
      case 'accepted': return 'Has aceptado una cotización';
      case 'on_the_way': return 'El técnico va en camino';
      case 'in_progress': return 'El trabajo ha comenzado';
      case 'completed': return 'Trabajo finalizado';
      case 'rated': return 'Calificación enviada';
      default: return s;
    }
  }
}

class _StatusBadgeLarge extends StatelessWidget {
  final String status;
  const _StatusBadgeLarge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'requested':
        color = Colors.orange; label = 'Buscando Técnicos'; icon = Icons.search; break;
      case 'quoted':
        color = Colors.blue; label = 'Tienes Cotizaciones'; icon = Icons.notifications_active; break;
      case 'accepted':
        color = Colors.purple; label = 'Técnico Asignado'; icon = Icons.check; break;
      case 'on_the_way':
        color = Colors.purple; label = 'Técnico en Camino'; icon = Icons.directions_car; break;
      case 'in_progress':
        color = Colors.purple; label = 'Trabajo en Curso'; icon = Icons.handyman; break;
      case 'completed':
        color = Colors.green; label = 'Trabajo Completado'; icon = Icons.check_circle; break;
      case 'rated':
        color = Colors.grey; label = 'Finalizado'; icon = Icons.done_all; break;
      default:
        color = Colors.grey; label = status; icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}