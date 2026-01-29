import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

// Provider específico para esta pantalla (Auto-dispose para liberar memoria)
final myJobsProvider = FutureProvider.autoDispose<List<ServiceRequest>>((ref) async {
  final repo = ref.watch(supabaseRepoProvider);
  return repo.fetchMyJobsAsTechnician();
});

class MyJobsScreen extends ConsumerWidget {
  const MyJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(myJobsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Mis Trabajos'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: jobsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
        error: (err, stack) => _ErrorView(
          error: err.toString(),
          onRetry: () => ref.refresh(myJobsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyJobsView();
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(myJobsProvider),
            color: cs.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                // Animación de entrada en cascada
                return _SlideInItem(
                  delay: index * 100,
                  child: _JobCard(item: item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// --- WIDGETS COMPONENTIZADOS ---

class _JobCard extends StatelessWidget {
  final ServiceRequest item;
  const _JobCard({required this.item});

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
          onTap: () => context.push('/tech/request/${item.id}'), // Asegúrate que esta ruta exista
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono de estado
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.work_outline_rounded, color: cs.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    
                    // Título y Fecha
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
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: cs.outline),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Flecha
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.onSurface.withOpacity(0.3)),
                  ],
                ),
                
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                // Footer: Descripción y Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatusBadge(status: item.status),
                    // Si tienes el precio, podrías mostrarlo aquí
                    // Text('\$50.00', style: TextStyle(fontWeight: FontWeight.bold)), 
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
      case 'accepted':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'Por Iniciar';
        icon = Icons.pending_actions_rounded;
        break;
      case 'on_the_way':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade800;
        label = 'En Camino';
        icon = Icons.directions_car_rounded;
        break;
      case 'in_progress':
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade800;
        label = 'En Progreso';
        icon = Icons.handyman_rounded;
        break;
      case 'completed':
      case 'rated':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Finalizado';
        icon = Icons.check_circle_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade800;
        label = status.toUpperCase();
        icon = Icons.info_outline;
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
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EmptyJobsView extends StatelessWidget {
  const _EmptyJobsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_turned_in_outlined, size: 60, color: Theme.of(context).colorScheme.outline),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin trabajos asignados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cuando acepten tus cotizaciones,\naparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
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
            const Text('No pudimos cargar los trabajos'),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            )
          ],
        ),
      ),
    );
  }
}

// Animación reutilizable
class _SlideInItem extends StatefulWidget {
  final Widget child;
  final int delay;
  const _SlideInItem({required this.child, required this.delay});

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
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600)
    );

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    // FIX: Using a Tween ensures the value stays strictly between 0.0 and 1.0
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
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
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _offsetAnim, child: widget.child),
    );
  }
}