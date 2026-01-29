import 'dart:ui' as ui; // <--- ESTO FALTABA ARRIBA
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // 1. CAPA DE AMBIENTE (Luces naranjas de fondo)
          const Positioned.fill(child: _BackgroundAmbience()),

          // 2. CONTENIDO PRINCIPAL
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 1),

                  // LOGO ANIMADO
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                            opacity: value.clamp(0.0, 1.0), child: child),
                      );
                    },
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: isDark
                                ? cs.primary.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: cs.primary.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Título
                  Text(
                    'TecniGO',
                    textAlign: TextAlign.center,
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      letterSpacing: -1.0,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Slogan
                  Text(
                    'Soluciones expertas en tu puerta,\nal instante.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: cs.onSurface.withOpacity(isDark ? 0.9 : 0.7),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // SELECCIÓN DE ROL
                  Text(
                    '¿Cómo quieres ingresar?',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tarjeta Cliente
                  _BouncingCard(
                    onTap: () => context.go('/auth/sign_up?role=client'),
                    child: _RoleCardContent(
                      icon: Icons.person_search_rounded,
                      title: 'Busco un servicio',
                      subtitle: 'Plomeros, electricistas y más...',
                      color: cs.secondary,
                      isDark: isDark,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tarjeta Profesional
                  _BouncingCard(
                    onTap: () => context.go('/auth/sign_up?role=technician'),
                    child: _RoleCardContent(
                      icon: Icons.handyman_rounded,
                      title: 'Soy Profesional',
                      subtitle: 'Quiero ofrecer mis servicios',
                      color: cs.primary,
                      isDark: isDark,
                    ),
                  ),

                  const Spacer(flex: 2),

                  // FOOTER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '¿Ya tienes cuenta?',
                        style: textTheme.bodyMedium
                            ?.copyWith(color: cs.onSurface.withOpacity(0.8)),
                      ),
                      TextButton(
                        onPressed: () => context.go('/auth/sign_in'),
                        style: TextButton.styleFrom(
                            foregroundColor: cs.primary,
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        child: const Text('Iniciar Sesión'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _BackgroundAmbience extends StatelessWidget {
  const _BackgroundAmbience();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ambientColor = cs.primary.withOpacity(isDark ? 0.15 : 0.08);

    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ambientColor,
            ),
          ).animateBlur(),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ambientColor,
            ),
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

class _BouncingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _BouncingCard({required this.child, required this.onTap});

  @override
  State<_BouncingCard> createState() => _BouncingCardState();
}

class _BouncingCardState extends State<_BouncingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

class _RoleCardContent extends StatelessWidget {
  const _RoleCardContent({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: isDark
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1))
          : null,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.6),
                          fontSize: 13,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: cs.primary.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
