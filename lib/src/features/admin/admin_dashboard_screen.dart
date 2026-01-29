import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loading = true;

  // Stats
  int requested = 0;
  int accepted = 0;
  int completed = 0;
  int pendingTech = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Si ya hay datos, no mostramos el loading full screen, solo refrescamos
    if (requested == 0 && accepted == 0) setState(() => _loading = true);

    try {
      final repo = ref.read(supabaseRepoProvider);

      // Carga paralela para mayor velocidad (solo 4 llamadas)
      final results = await Future.wait([
        repo.adminCountRequestsByStatus('requested'),
        repo.adminCountRequestsByStatus('accepted'),
        repo.adminCountRequestsByStatus('completed'),
        repo.adminCountPendingTechVerifications(),
      ]);

      if (mounted) {
        setState(() {
          requested = results[0];
          accepted = results[1];
          completed = results[2];
          pendingTech = results[3];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error actualizando dashboard: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Panel de Control'),
        centerTitle: false,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Actualizar datos',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: cs.primary),
          )
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: cs.primary,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 1. HEADER DE BIENVENIDA
                  Text(
                    'Resumen de Actividad',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. TARJETA DE ACCIÓN PRIORITARIA (TÉCNICOS)
                  _SlideInItem(
                    delay: 0,
                    child: _PendingTechCard(
                      count: pendingTech,
                      onTap: () {
                        context.push('/admin/verifications');
                      },
                    ),
                  ),

                  // En admin_dashboard_screen.dart, después del GridView:

                  const SizedBox(height: 24),
                  _SlideInItem(
                    delay: 500,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/admin/users'),
                      icon: const Icon(Icons.people_alt_rounded),
                      label: const Text(
                          'GESTIONAR USUARIOS (Clientes / Técnicos)'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: Colors.blueGrey,
                      ),
                    ),
                  ),

                  // 3. GRID DE ESTADÍSTICAS
                  Text(
                    'Estado de Solicitudes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 12),

                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true, // Importante dentro de ListView
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.3, // Hace las tarjetas más apaisadas
                    children: [
                      _SlideInItem(
                        delay: 100,
                        child: _StatCard(
                          title: 'Solicitadas',
                          count: requested,
                          icon: Icons.pending_actions_rounded,
                          color: Colors.orange, // Naranja: Atención
                          onTap: () {
                            context.push('/admin/requests',
                                extra: {'status': 'requested'});
                          },
                        ),
                      ),
                      _SlideInItem(
                        delay: 200,
                        child: _StatCard(
                          title: 'Aceptadas',
                          count: accepted,
                          icon: Icons.assignment_ind_rounded,
                          color: Colors.blue, // Azul: Info
                          onTap: () {
                            context.push('/admin/requests',
                                extra: {'status': 'accepted'});
                          },
                        ),
                      ),
                      _SlideInItem(
                        delay: 300,
                        child: _StatCard(
                          title: 'Completadas',
                          count: completed,
                          icon: Icons.task_alt_rounded,
                          color: Colors.green, // Verde: Éxito
                          onTap: () {
                            context.push('/admin/requests',
                                extra: {'status': 'completed'});
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40), // Espacio final
                ],
              ),
            ),
    );
  }
}

// --- WIDGETS PERSONALIZADOS ---

// Tarjeta especial ancha para Verificaciones Pendientes
class _PendingTechCard extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _PendingTechCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasPending = count > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Si hay pendientes, usamos un degradado suave naranja/rojo. Si no, gris limpio.
            gradient: hasPending
                ? LinearGradient(
                    colors: [cs.primary, const Color(0xFFFF9F43)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: hasPending ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: hasPending
                    ? cs.primary.withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
            border: hasPending
                ? null
                : Border.all(color: cs.outlineVariant.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: hasPending
                      ? Colors.white.withOpacity(0.2)
                      : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: hasPending ? Colors.white : cs.onSurface,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verificaciones Técnicas',
                      style: TextStyle(
                        color: hasPending
                            ? Colors.white.withOpacity(0.9)
                            : cs.onSurface.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasPending ? '$count Pendientes' : 'Todo al día',
                      style: TextStyle(
                        color: hasPending ? Colors.white : cs.onSurface,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: hasPending
                    ? Colors.white.withOpacity(0.7)
                    : cs.onSurface.withOpacity(0.3),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Tarjeta pequeña para estadísticas del Grid
class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  // Indicador visual opcional (punto)
                  if (count > 0)
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    )
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Animación simple (Reutilizable)
class _SlideInItem extends StatefulWidget {
  final Widget child;
  final int delay;
  const _SlideInItem({required this.child, required this.delay});

  @override
  State<_SlideInItem> createState() => _SlideInItemState();
}

class _SlideInItemState extends State<_SlideInItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

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
