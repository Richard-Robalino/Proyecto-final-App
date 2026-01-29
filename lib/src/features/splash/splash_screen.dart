import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AudioPlayer _audioPlayer;

  // Definimos las animaciones individuales
  late Animation<double> _logoScaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _footerFadeAnim;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initSequence();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // Duración total de la intro
      vsync: this,
    );

    _audioPlayer = AudioPlayer();

    // 1. El Logo entra rebotando (0% a 50% del tiempo)
    _logoScaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    // 2. El Texto desliza hacia arriba y aparece (30% a 70% del tiempo)
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    // 3. El footer aparece al final (70% a 100%)
    _footerFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  Future<void> _initSequence() async {
    _controller.forward();

    if (!kIsWeb) {
      try {
        await _audioPlayer.setAsset('assets/sounds/splash_sound.mp3');
        await _audioPlayer.play();
      } catch (e) {
        // Ignorar error de audio si falta el archivo
      }
    }

    final minWait = Future.delayed(const Duration(seconds: 4)); // Un segundo más para disfrutar la animación
    final dataLoad = _checkSessionAndRole();

    await Future.wait([minWait, dataLoad]);

    if (mounted) {
      final route = await dataLoad;
      context.go(route);
    }
  }

  Future<String> _checkSessionAndRole() async {
    try {
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;
      if (session == null) return '/onboarding';

      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null) return '/onboarding';

      final role = profile['role'] as String?;
      switch (role) {
        case 'admin': return '/admin';
        case 'technician': return '/tech';
        case 'client': return '/client';
        default: return '/onboarding';
      }
    } catch (e) {
      return '/onboarding';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. FORMAS DECORATIVAS DE FONDO (Blobs)
          Positioned(
            top: -100,
            right: -100,
            child: _AnimatedBlob(color: cs.primary.withOpacity(0.1), size: 400),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _AnimatedBlob(color: cs.secondary.withOpacity(0.05), size: 300),
          ),

          // 2. CONTENIDO CENTRAL
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo con efecto rebote
                ScaleTransition(
                  scale: _logoScaleAnim,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: Image.asset(
                        'assets/animations/splash_animation.gif',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(Icons.flash_on_rounded, size: 80, color: cs.primary),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),

                // Texto con Slide y Fade
                FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        // Nombre con degradado (Simulado con ShaderMask)
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [cs.primary, Colors.orange.shade800],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'TecniGO',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white, // El color lo da el ShaderMask
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Soluciones expertas en tu puerta,\nal instante.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. FOOTER ELEGANTE
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _footerFadeAnim,
              child: Column(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Hecho con ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const Icon(Icons.favorite, size: 14, color: Colors.red),
                        const Text(' en Ecuador 🇪🇨', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Widget decorativo para el fondo (Círculo difuminado)
class _AnimatedBlob extends StatefulWidget {
  final Color color;
  final double size;
  const _AnimatedBlob({required this.color, required this.size});

  @override
  State<_AnimatedBlob> createState() => _AnimatedBlobState();
}

class _AnimatedBlobState extends State<_AnimatedBlob> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animación lenta de "respiración" para el fondo
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.1), // Crece un 10%
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(color: widget.color, blurRadius: 60, spreadRadius: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}