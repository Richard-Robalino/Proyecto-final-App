import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'state/providers.dart';

// Screens
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';

// Client
import 'features/client/client_shell_screen.dart';
import 'features/client/new_request_screen.dart';
import 'features/client/request_details_screen.dart';
import 'features/client/review_screen.dart';
import 'features/client/technician_profile_screen.dart';

// ✅ NUEVO: Editar solicitud
import 'features/client/edit_request_screen.dart';

// Technician
import 'features/technician/technician_shell_screen.dart';
import 'features/technician/request_preview_screen.dart';
import 'features/technician/send_quote_screen.dart';
import 'features/technician/tech_review_client_screen.dart';

// Admin
import 'features/admin/admin_shell_screen.dart';
import 'features/admin/admin_technician_detail_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final appState = ref.watch(appStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: appState,
    routes: [
      // ===== Splash =====
      GoRoute(
        path: '/splash',
        builder: (_, __) => const _SplashScreen(),
      ),

      // ===== Onboarding/Auth =====
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth/sign_in',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign_up',
        builder: (context, state) {
          final role = state.uri.queryParameters['role']; // client|technician|admin(optional)
          return SignUpScreen(initialRole: role);
        },
      ),

      // ===== Client =====
      GoRoute(
        path: '/client',
        builder: (_, __) => const ClientShellScreen(),
        routes: [
          GoRoute(
            path: 'request/new',
            builder: (_, __) => const NewRequestScreen(),
          ),
          GoRoute(
            path: 'request/:id',
            builder: (context, state) =>
                RequestDetailsScreen(requestId: state.pathParameters['id']!),
          ),

          // ✅ NUEVO: editar solicitud
          GoRoute(
            path: 'request/:id/edit',
            builder: (context, state) =>
                EditRequestScreen(requestId: state.pathParameters['id']!),
          ),

          GoRoute(
            path: 'request/:id/review',
            builder: (context, state) =>
                ReviewScreen(requestId: state.pathParameters['id']!),
          ),
                    GoRoute(
            path: 'tech/:id',
            builder: (context, state) => 
                TechnicianProfileScreen(techId: state.pathParameters['id']!,
            ),
          ),

        ],
      ),

      // ===== Technician =====
      GoRoute(
        path: '/tech',
        builder: (_, __) => const TechnicianShellScreen(),
        routes: [
          GoRoute(
            path: 'request/:id',
            builder: (context, state) =>
                RequestPreviewScreen(requestId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'request/:id/quote',
            builder: (context, state) =>
                SendQuoteScreen(requestId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'request/:id/review_client',
            builder: (context, state) =>
                TechReviewClientScreen(requestId: state.pathParameters['id']!),
          ),
        ],
      ),

      // ===== Admin =====
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShellScreen(),
        routes: [
          GoRoute(
            path: 'verify/:id',
            builder: (context, state) => AdminTechnicianDetailScreen(
              techId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],

    redirect: (context, state) {
      final loc = state.matchedLocation; // ✅ evita problemas con query/hash

      // ---------- 1) Splash decide a dónde ir ----------
      if (loc == '/splash') {
        // No logueado -> onboarding
        if (!appState.isLoggedIn) return '/onboarding';

        // Logueado pero aún cargando perfil/rol -> quedarse en splash
        if (appState.loading || appState.role == null) return null;

        // Ya con rol -> ir a su zona
        if (appState.role == UserRole.admin) return '/admin';
        return appState.role == UserRole.technician ? '/tech' : '/client';
      }

      // ---------- 2) No logueado: solo onboarding y auth ----------
      if (!appState.isLoggedIn) {
        if (loc.startsWith('/auth') || loc.startsWith('/onboarding')) return null;
        return '/onboarding';
      }

      // ---------- 3) Logueado pero cargando rol/perfil ----------
      if (appState.loading || appState.role == null) {
        return '/splash';
      }

      // ---------- 4) Logueado: bloquear volver a auth/onboarding ----------
      if (loc.startsWith('/auth') || loc.startsWith('/onboarding')) {
        if (appState.role == UserRole.admin) return '/admin';
        return appState.role == UserRole.technician ? '/tech' : '/client';
      }

      // ---------- 5) Enrutamiento por rol ----------
      if (appState.role == UserRole.admin) {
        if (!loc.startsWith('/admin')) return '/admin';
        if (loc == '/' || loc.isEmpty) return '/admin';
        return null;
      }

      if (appState.role == UserRole.technician) {
        if (loc.startsWith('/client')) return '/tech';
        if (loc.startsWith('/admin')) return '/tech';
        if (loc == '/' || loc.isEmpty) return '/tech';
      } else {
        // client
        if (loc.startsWith('/tech')) return '/client';
        if (loc.startsWith('/admin')) return '/client';
        if (loc == '/' || loc.isEmpty) return '/client';
      }

      return null;
    },
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          height: 28,
          width: 28,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
