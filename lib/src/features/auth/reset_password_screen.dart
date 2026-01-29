import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Necesario para OtpType
import '../../state/providers.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  // Controladores
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController(); // Para el código de 6 dígitos

  bool _loading = false;
  bool _codeSent = false; // Controla si mostramos el campo de código

  // 1. Enviar el Código al Correo
  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Ingresa un correo válido', isError: true);
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(supabaseRepoProvider);

    try {
      // Usamos resetPasswordForEmail.
      // Supabase enviará el correo configurado en el Dashboard.
      await repo.supabase.auth.resetPasswordForEmail(email);

      if (!mounted) return;
      setState(() {
        _codeSent = true; // Cambiamos la UI para pedir el código
        _loading = false;
      });
      
      _showMessage('¡Código enviado! Revisa tu correo.', isError: false);
      
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Error al enviar: $e', isError: true);
    }
  }

  // 2. Verificar el Código
  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (code.length < 8) {
      _showMessage('El código debe tener al menos 8 dígitos', isError: true);
      return;
    }

    setState(() => _loading = true);
    final repo = ref.read(supabaseRepoProvider);

    try {
      // Verificamos el OTP de tipo "recovery"
      final response = await repo.supabase.auth.verifyOTP(
        token: code,
        type: OtpType.recovery,
        email: email,
      );

      if (response.session != null) {
        // ✅ Éxito! El usuario ya tiene sesión iniciada temporalmente.
        // 🔥 CLAVE: Guardamos un flag local para que el router sepa que debe dejarlo pasar
        if (!mounted) return;
        
        // Usamos shared_preferences o un provider temporal, pero la forma más rápida:
        // Lo enviamos a update_password CON REPLACE (no push) para que no pueda volver atrás
        context.go('/auth/update_password');
        
      } else {
        throw Exception('Código inválido o expirado');
      }

    } catch (e) {
      if (!mounted) return;
      _showMessage('Error verificando código: $e', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Recuperar Contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              _codeSent ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
              size: 80,
              color: cs.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            
            Text(
              _codeSent 
                ? 'Hemos enviado un código de 8 dígitos a tu correo. Ingrésalo abajo.'
                : 'Ingresa tu correo y te enviaremos un código para restablecer tu acceso.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: cs.onSurface.withOpacity(0.7)),
            ),
            
            const SizedBox(height: 32),

            // CAMPO DE EMAIL (Se deshabilita si ya enviamos el código)
            TextField(
              controller: _emailCtrl,
              enabled: !_codeSent, 
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Correo Electrónico',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: _codeSent ? Colors.grey[200] : null,
              ),
            ),

            // CAMPO DE CÓDIGO (Solo aparece si _codeSent es true)
            if (_codeSent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 8,
                style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'Código de 8 dígitos',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // BOTÓN DE ACCIÓN (Cambia según el estado)
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _loading 
                    ? null 
                    : (_codeSent ? _verifyCode : _sendCode),
                child: _loading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_codeSent ? 'Verificar Código' : 'Enviar Código'),
              ),
            ),

            // BOTÓN "CAMBIAR CORREO" (Si se equivocó)
            if (_codeSent)
              TextButton(
                onPressed: () {
                  setState(() {
                    _codeSent = false;
                    _codeCtrl.clear();
                  });
                },
                child: const Text('Cambiar correo o reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}