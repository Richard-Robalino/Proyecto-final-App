import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router.dart';

class TecniGoApp extends ConsumerStatefulWidget {
  const TecniGoApp({super.key});

  @override
  ConsumerState<TecniGoApp> createState() => _TecniGoAppState();
}

class _TecniGoAppState extends ConsumerState<TecniGoApp> {
  
  @override
  void initState() {
    super.initState();
    // ✅ ESCUCHA DE EVENTOS MAGICOS (Deep Links de Auth)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // ¡Detectamos que viene de "Recuperar Contraseña"!
        ref.read(appRouterProvider).push('/auth/update_password');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // Tu color Naranja Vibrante (extraído de tu dashboard)
    const brandColor = Color(0xFFFF9F43); 

    return MaterialApp.router(
      title: 'TecniGO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Forzamos el color primario para que no se vea "apagado"
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: brandColor, // 🔥 RESTAURA EL COLOR INTENSO
          secondary: brandColor,
          surface: Colors.grey[50], // Fondo limpio
        ),
        // Personalización de botones para que siempre sean naranjas
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandColor,
            foregroundColor: Colors.white,
          ),
        ),
        // fontFamily: 'Montserrat', // Descomenta si ya agregaste la fuente
      ),
      routerConfig: router,
    );
  }
}