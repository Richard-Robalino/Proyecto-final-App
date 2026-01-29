import 'dart:ui' as ui; // Necesario para efectos visuales
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/providers.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key, this.initialRole});

  final String? initialRole; // client | technician

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  late String _role;

  // Animaciones de entrada
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    // Inicializar rol
    _role = (widget.initialRole == 'technician') ? 'technician' : 'client';

    // Configurar animación de entrada
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
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    FocusScope.of(context).unfocus(); // Ocultar teclado

    final supabase = ref.read(supabaseClientProvider);

    try {
      final res = await supabase.auth.signUp(
        email: _email.text.trim(),
        password: _password.text,
        data: {
          'role': _role,
          'full_name': _fullName.text.trim(),
          'phone': _phone.text.trim(),
        },
        // ❌ ELIMINAMOS emailRedirectTo para que use el Dashboard de Supabase
        // emailRedirectTo: 'tecnigo://login-callback', 
      );

      if (!mounted) return;

      // ✅ CORREGIDO: Mostrar diálogo de verificación
      if (res.user == null) {
        _showVerificationDialog();
      } else {
        // Si Supabase devuelve el usuario pero sin sesión, significa que requiere verificación
        if (res.session == null) {
           _showVerificationDialog();
        } else {
           context.go('/splash');
        }
      }
    } on AuthException catch (e) {
      if (mounted) _showSnackBar(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnackBar('Error inesperado: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ✅ NUEVO: Diálogo de verificación de correo
  void _showVerificationDialog() {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mail_outline_rounded,
            size: 40,
            color: cs.primary,
          ),
        ),
        title: const Text(
          'Verifica tu correo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              'Te hemos enviado un enlace de verificación a:',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _email.text.trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Revisa tu bandeja de entrada (y la carpeta de spam) y haz clic en el enlace para confirmar tu cuenta.',
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Luego podrás iniciar sesión normalmente.',
              style: TextStyle(
                fontSize: 12,
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.go('/auth/sign_in');
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ir a Iniciar Sesión'),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? cs.error : cs.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTech = _role == 'technician';

    return Scaffold(
      extendBodyBehindAppBar: true,
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
        title: Text(
          'Crear Cuenta',
          style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 1. Fondo Ambiental (Reutilizable)
          const Positioned.fill(child: _BackgroundAmbience()),

          // 2. Contenido
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100), // Padding extra por el AppBar transparente
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Icono Dinámico según Rol
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                          child: Container(
                            key: ValueKey(_role),
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: isTech ? cs.primary.withOpacity(0.1) : cs.secondary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isTech ? Icons.handyman_rounded : Icons.person_rounded,
                              size: 40,
                              color: isTech ? cs.primary : cs.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Selector de Rol
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cs.outline.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _RoleChip(
                                  label: 'Cliente',
                                  icon: Icons.person_outline_rounded,
                                  isSelected: !isTech,
                                  onTap: () => setState(() => _role = 'client'),
                                  activeColor: cs.secondary,
                                ),
                              ),
                              Expanded(
                                child: _RoleChip(
                                  label: 'Técnico',
                                  icon: Icons.handyman_outlined,
                                  isSelected: isTech,
                                  onTap: () => setState(() => _role = 'technician'),
                                  activeColor: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // CAMPOS DE TEXTO
                        TextFormField(
                          controller: _fullName,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.badge_outlined, color: cs.onSurface.withOpacity(0.5)),
                          ),
                          validator: (v) => v!.isEmpty ? 'Ingresa tu nombre' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Teléfono (Opcional)',
                            prefixIcon: Icon(Icons.phone_iphone_rounded, color: cs.onSurface.withOpacity(0.5)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.alternate_email_rounded, color: cs.onSurface.withOpacity(0.5)),
                          ),
                          validator: (v) => !v!.contains('@') ? 'Correo inválido' : null,
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _password,
                          obscureText: _obscure,
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
                          validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                        ),

                        const SizedBox(height: 24),

                        // Aviso Informativo
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isTech ? cs.primary.withOpacity(0.08) : cs.secondary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTech ? cs.primary.withOpacity(0.2) : cs.secondary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded, 
                                size: 20, 
                                color: isTech ? cs.primary : cs.secondary
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isTech
                                      ? 'Como técnico, deberás verificar tus credenciales más adelante para recibir trabajos.'
                                      : 'Al registrarte podrás cotizar servicios y calificar a los profesionales.',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Botón de Registro (Bouncing)
                        _BouncingButton(
                          onTap: _loading ? null : _submit,
                          child: Container(
                            width: double.infinity,
                            height: 56,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              // El color cambia sutilmente según el rol
                              color: isTech ? cs.primary : cs.secondary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (isTech ? cs.primary : cs.secondary).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _loading
                                ? const SizedBox(
                                    height: 24, 
                                    width: 24, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                                  )
                                : const Text(
                                    'Crear cuenta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),
                        
                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('¿Ya tienes cuenta?', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
                            TextButton(
                              onPressed: () => context.go('/auth/sign_in'),
                              child: Text(
                                'Inicia sesión',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isTech ? cs.primary : cs.secondary,
                                ),
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

// --- WIDGETS AUXILIARES ---

// Chip de Selección de Rol Mejorado
class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected 
            ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
            : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              size: 20, 
              color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fondo Ambiental (Copia para mantener consistencia visual sin depender de otro archivo)
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
          left: -50,
          child: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(shape: BoxShape.circle, color: ambientColor),
          ).animateBlur(),
        ),
        Positioned(
          bottom: -50,
          right: -50,
          child: Container(
            height: 250,
            width: 250,
            decoration: BoxDecoration(shape: BoxShape.circle, color: cs.secondary.withOpacity(0.05)),
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