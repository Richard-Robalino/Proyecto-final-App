import 'dart:ui' as ui; // Importante para el efecto blur
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/providers.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  
  bool _loading = false;
  bool _obscure = true;

  // Animación de entrada
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // 1. Validar el formulario antes de llamar a la API
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    // Ocultar teclado para ver el loader
    FocusScope.of(context).unfocus();

    final supabase = ref.read(supabaseClientProvider);
    try {
      await supabase.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) context.go('/splash'); // O a /home directamente
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.message);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Ocurrió un error inesperado. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true, // Para que el fondo cubra todo
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: Stack(
        children: [
          // 1. Fondo Ambiental (Reutilizando el estilo sutil)
          const Positioned.fill(child: _BackgroundAmbience()),

          // 2. Contenido Scrollable (Para evitar error con teclado)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icono Header
                        Center(
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: cs.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.lock_person_rounded, size: 40, color: cs.primary),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        Text(
                          'Hola de nuevo',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Ingresa tus credenciales para continuar',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                        
                        const SizedBox(height: 32),

                        // EMAIL INPUT
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email_rounded, color: cs.onSurface.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'El correo es obligatorio';
                            if (!value.contains('@')) return 'Ingresa un correo válido';
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 16),

                        // PASSWORD INPUT
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
                          style: TextStyle(fontWeight: FontWeight.w500, color: cs.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: cs.onSurface.withOpacity(0.5)),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'La contraseña es obligatoria';
                            if (value.length < 6) return 'Mínimo 6 caracteres';
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),

                        // Olvidé contraseña
                        
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.push('/auth/reset_password'),
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(color: cs.primary),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // BOTÓN PRINCIPAL (Con efecto rebote)
                        _BouncingButton(
                          onTap: _loading ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    'Entrar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // FOOTER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '¿No tienes cuenta?',
                              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
                            ),
                            TextButton(
                              onPressed: () => context.go('/onboarding'),
                              child: const Text(
                                'Regístrate',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES (Estilo TecniGO) ---

class _BackgroundAmbience extends StatelessWidget {
  const _BackgroundAmbience();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Luces más sutiles para no distraer en el login
    final ambientColor = cs.primary.withOpacity(isDark ? 0.1 : 0.05);

    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            height: 300,
            width: 300,
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
      filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: this,
    );
  }
}

// Botón con efecto de rebote (Reutilizado para consistencia)
class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _BouncingButton({required this.child, required this.onTap});

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) {
        _controller.reverse();
        widget.onTap!();
      } : null,
      onTapCancel: widget.onTap != null ? () => _controller.reverse() : null,
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}