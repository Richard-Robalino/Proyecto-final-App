import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'state/app_state.dart';
import 'state/providers.dart';

// --- SCREENS ---
import 'features/splash/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/auth/sign_up_screen.dart';
import 'features/auth/reset_password_screen.dart';
import 'features/auth/update_password_screen.dart'; // <--- NUEVO IMPORT

// Client
import 'features/client/client_shell_screen.dart';
import 'features/client/new_request_screen.dart';
import 'features/client/request_details_screen.dart';
import 'features/client/review_screen.dart';
import 'features/client/technician_profile_screen.dart';
import 'features/client/edit_request_screen.dart';

// Technician
import 'features/technician/technician_shell_screen.dart';
import 'features/technician/request_preview_screen.dart';
import 'features/technician/send_quote_screen.dart';
import 'features/technician/tech_review_client_screen.dart';

// Admin
import 'features/admin/admin_shell_screen.dart';
import 'features/admin/admin_verify_technician_screen.dart';
import 'features/admin/admin_requests_screen.dart';
import 'features/admin/admin_request_detail_screen.dart';
import 'features/admin/admin_users_screen.dart';
import 'features/admin/admin_verifications_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final appState = ref.watch(appStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: appState,

    routes: [
      // ==========================================
      // SPLASH & AUTH
      // ==========================================
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (_, __) => const SplashScreen(),
      ),
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
          final role = state.uri.queryParameters['role'];
          return SignUpScreen(initialRole: role);
        },
      ),
      GoRoute(
        path: '/auth/reset_password',
        builder: (_, __) => const ResetPasswordScreen(),
      ),
      // ✅ NUEVA RUTA: CAMBIO DE CONTRASEÑA
      GoRoute(
        path: '/auth/update_password',
        builder: (_, __) => const UpdatePasswordScreen(),
      ),

      // ==========================================
      // CLIENTE
      // ==========================================
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
                TechnicianProfileScreen(techId: state.pathParameters['id']!),
          ),
        ],
      ),

      // ==========================================
      // TÉCNICO
      // ==========================================
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

      // ==========================================
      // ADMINISTRADOR
      // ==========================================
      GoRoute(
        path: '/admin',
        builder: (_, __) => const AdminShellScreen(),
        routes: [
          GoRoute(
            path: 'verifications',
            builder: (_, __) => const AdminVerificationsScreen(),
          ),
          GoRoute(
            path: 'verify/:id',
            builder: (context, state) => AdminVerifyTechnicianScreen(
              technicianId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: 'requests',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>?;
              return AdminRequestsScreen(
                  status: extra?['status'] ?? 'requested');
            },
          ),
          GoRoute(
            path: 'request-detail',
            builder: (context, state) {
              final request = state.extra as Map<String, dynamic>;
              return AdminRequestDetailScreen(request: request);
            },
          ),
          GoRoute(
            path: 'users',
            builder: (_, __) => const AdminUsersScreen(),
          ),
        ],
      ),
    ],

    // ==========================================
    // REDIRECT LOGIC (Security)
    // ==========================================
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isLoggedIn = appState.isLoggedIn;
      final role = appState.role;

      // 1. Siempre permitir Splash
      if (loc == '/splash') return null;

      // 🔥 NUEVA PRIORIDAD: Si va a /auth/update_password, SIEMPRE DEJAR PASAR
      // (El usuario viene del correo de recuperación, Supabase ya lo logueó temporalmente)
      if (loc == '/auth/update_password') return null;

      // 2. Si NO está logueado: Bloquear rutas privadas
      final isAuthRoute = loc.startsWith('/auth') || loc == '/onboarding';
      if (!isLoggedIn && !isAuthRoute) {
        return '/onboarding';
      }

      // 3. Si ESTÁ logueado y está en rutas de auth (excepto update_password que ya pasó):
      if (isLoggedIn && isAuthRoute) {
        if (role == null) return '/splash'; // Cargando perfil
        if (role == UserRole.admin) return '/admin';
        if (role == UserRole.technician) return '/tech';
        return '/client';
      }

      // 4. Protección de Roles
      if (isLoggedIn && role != null) {
        // CLIENTE intentando entrar a Admin o Tech
        if (role == UserRole.client &&
            (loc.startsWith('/admin') || loc.startsWith('/tech'))) {
          return '/client';
        }
        // TÉCNICO intentando entrar a Admin o Client shell
        if (role == UserRole.technician &&
            (loc.startsWith('/admin') || loc.startsWith('/client'))) {
          return '/tech';
        }
        // ADMIN intentando salir de área admin
        if (role == UserRole.admin && (!loc.startsWith('/admin'))) {
          return '/admin';
        }
      }

      return null; // Navegación permitida
    },
  );
});