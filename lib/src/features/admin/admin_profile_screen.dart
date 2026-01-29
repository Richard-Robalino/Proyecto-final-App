import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  String? _email;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;

    if (user == null) {
      if (mounted) context.go('/onboarding');
      return;
    }

    _email = user.email;

    try {
      final row = await sb
          .from('profiles')
          .select('id, full_name, role, avatar_path, is_active, created_at')
          .eq('id', user.id)
          .maybeSingle();

      final p = (row as Map?)?.cast<String, dynamic>();

      String? avatarUrl;
      final avatarPath = p?['avatar_path']?.toString();
      if (avatarPath != null && avatarPath.isNotEmpty) {
        avatarUrl = sb.storage.from('avatars').getPublicUrl(avatarPath);
      }

      if (mounted) {
        setState(() {
          _profile = p;
          _avatarUrl = avatarUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Manejo silencioso o snackbar
      }
    }
  }

  Future<void> _logout() async {
    // 1. Confirmación visual
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que ingresar tus credenciales nuevamente.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 2. Proceso de logout
    final sb = Supabase.instance.client;
    try {
      await sb.auth.signOut();
      if (mounted) context.go('/splash');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Datos seguros
    final name = (_profile?['full_name'] ?? 'Administrador').toString();
    final role = (_profile?['role'] ?? 'admin').toString().toUpperCase();
    final isActive = (_profile?['is_active'] ?? true) == true;
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A';

    if (_loading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(child: CircularProgressIndicator(color: cs.primary)),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // 1. Fondo Ambiental (Sutil)
          const Positioned.fill(child: _BackgroundAmbience()),

          // 2. Contenido
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                title: const Text('Mi Perfil'),
                centerTitle: true,
                pinned: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Configuraciones: Próximamente')),
                      );
                    },
                  )
                ],
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Column(
                    children: [
                      // --- AVATAR ---
                      _SlideInItem(
                        delay: 0,
                        child: Center(
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.primary.withOpacity(0.2), width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: cs.primary.withOpacity(0.15),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    )
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 60,
                                  backgroundColor: cs.primaryContainer,
                                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                                  child: _avatarUrl == null
                                      ? Text(
                                          initials,
                                          style: TextStyle(
                                            fontSize: 40,
                                            fontWeight: FontWeight.bold,
                                            color: cs.primary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: cs.surface, width: 3),
                                  ),
                                  child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // --- INFO PRINCIPAL ---
                      _SlideInItem(
                        delay: 100,
                        child: Column(
                          children: [
                            Text(
                              name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _email ?? '',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Badges
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _StatusBadge(
                                  label: role,
                                  color: cs.primary,
                                  icon: Icons.shield_rounded,
                                ),
                                const SizedBox(width: 12),
                                _StatusBadge(
                                  label: isActive ? 'ACTIVO' : 'INACTIVO',
                                  color: isActive ? Colors.green : Colors.grey,
                                  icon: isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    
                    _SlideInItem(
                      delay: 200,
                      child: Text(
                        'General',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // --- MENU ITEMS ---
                    _SlideInItem(
                      delay: 250,
                      child: _ProfileMenuCard(
                        items: [
                          _MenuItem(
                            icon: Icons.person_outline_rounded,
                            title: 'Información Personal',
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.notifications_outlined,
                            title: 'Notificaciones',
                            onTap: () {},
                          ),
                          _MenuItem(
                            icon: Icons.security_rounded,
                            title: 'Seguridad y Contraseña',
                            onTap: () {},
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    
                    // --- LOGOUT BUTTON ---
                    _SlideInItem(
                      delay: 300,
                      child: Container(
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
                        child: ListTile(
                          onTap: _logout,
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.error.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.logout_rounded, color: cs.error),
                          ),
                          title: Text(
                            'Cerrar Sesión',
                            style: TextStyle(
                              color: cs.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: cs.error.withOpacity(0.5)),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer Info
                    Center(
                      child: Text(
                        'TecniGO Admin v1.0.0',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusBadge({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _ProfileMenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: items.map((item) {
          final isLast = items.last == item;
          return Column(
            children: [
              ListTile(
                onTap: item.onTap,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: Theme.of(context).colorScheme.onSurface),
                ),
                title: Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 70,
                  endIndent: 20,
                  color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  _MenuItem({required this.icon, required this.title, required this.onTap});
}

// Background Ambience (Reutilizable)
class _BackgroundAmbience extends StatelessWidget {
  const _BackgroundAmbience();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ambientColor = cs.primary.withOpacity(isDark ? 0.1 : 0.05);
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -50,
          child: Container(
            height: 400,
            width: 400,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ambientColor),
          ).animateBlur(),
        ),
      ],
    );
  }
}

extension BlurExtension on Widget {
  Widget animateBlur() {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: this,
    );
  }
}

// Animation Slide (Reutilizable)
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