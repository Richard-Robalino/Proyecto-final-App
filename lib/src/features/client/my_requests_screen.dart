import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

// ✅ CAMBIO 1: Usamos StreamProvider en lugar de FutureProvider
// Esto mantiene la lista "viva" y escuchando cambios.
final myRequestsProvider = StreamProvider.autoDispose<List<ServiceRequest>>((ref) {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.streamMyRequests();
});

class MyRequestsScreen extends ConsumerWidget {
  const MyRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(myRequestsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Mis Solicitudes'),
        backgroundColor: cs.surface,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        // ✅ CAMBIO 2: Botón explícito para recargar
        actions: [
          IconButton(
            tooltip: 'Recargar lista',
            onPressed: () => ref.refresh(myRequestsProvider), // Fuerza la recarga
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: requestsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (err, stack) => _ErrorView(
          error: err.toString(),
          onRetry: () => ref.refresh(myRequestsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyRequestsView();
          }

          // Nota: RefreshIndicator sigue siendo útil para reiniciar la conexión si falla el internet
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myRequestsProvider),
            color: cs.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                // Usamos key para que Flutter sepa qué carta actualizar si cambia el estado
                return _SlideInItem(
                  key: ValueKey(item.id), 
                  delay: index * 50, // Retraso más corto para que se sienta ágil
                  child: _RequestCard(item: item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// --- WIDGETS COMPONENTIZADOS (Sin cambios, solo se incluyen para que compile completo) ---

class _RequestCard extends StatelessWidget {
  final ServiceRequest item;
  const _RequestCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('d MMM, HH:mm').format(item.createdAt.toLocal());

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/client/request/${item.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.handyman_rounded, color: cs.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(date, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.onSurface.withOpacity(0.3)),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.description,
                        style: TextStyle(color: cs.onSurface.withOpacity(0.7), fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: item.status),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (status) {
      case 'requested':
        bg = Colors.orange.shade50; fg = Colors.orange.shade800; label = 'Solicitado'; icon = Icons.hourglass_empty_rounded; break;
      case 'quoted':
        bg = Colors.blue.shade50; fg = Colors.blue.shade800; label = 'Cotizado'; icon = Icons.attach_money_rounded; break;
      case 'accepted':
      case 'on_the_way':
      case 'in_progress':
        bg = Colors.purple.shade50; fg = Colors.purple.shade800; label = 'En Curso'; icon = Icons.rocket_launch_rounded; break;
      case 'completed':
      case 'rated':
        bg = Colors.green.shade50; fg = Colors.green.shade800; label = 'Finalizado'; icon = Icons.check_circle_rounded; break;
      case 'cancelled':
        bg = Colors.red.shade50; fg = Colors.red.shade800; label = 'Cancelado'; icon = Icons.cancel_rounded; break;
      default:
        bg = Colors.grey.shade100; fg = Colors.grey.shade800; label = status; icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EmptyRequestsView extends StatelessWidget {
  const _EmptyRequestsView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, size: 60, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('Aún no tienes solicitudes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('¿Necesitas ayuda con algo hoy?', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => context.go('/client/request/new'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Solicitar Servicio'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
          )
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Ocurrió un problema de conexión'),
            const SizedBox(height: 24),
            TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar'))
          ],
        ),
      ),
    );
  }
}

class _SlideInItem extends StatefulWidget {
  final Widget child;
  final int delay;
  const _SlideInItem({super.key, required this.child, required this.delay});
  @override
  State<_SlideInItem> createState() => _SlideInItemState();
}

class _SlideInItemState extends State<_SlideInItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));
    // Corrección para evitar el error rojo de opacidad
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 1.0, curve: Curves.easeOut)),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _offsetAnim, child: widget.child));
  }
}