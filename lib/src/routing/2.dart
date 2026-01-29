import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/home/home_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_requests_screen.dart';
import '../features/admin/admin_verifications_screen.dart';
import '../features/admin/admin_request_detail_screen.dart';
import '../../state/providers.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isLoginRoute = state.matchedLocation == '/login' || 
                          state.matchedLocation == '/register';

      if (!isLoggedIn && !isLoginRoute) {
        return '/login';
      }
      if (isLoggedIn && isLoginRoute) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      
      // ADMIN ROUTES
      GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/verifications',
        builder: (context, state) => const AdminVerificationsScreen(),
      ),
      GoRoute(
        path: '/admin/requests',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?
          final status = extra?['status'] as String? ?? 'requested';
          return AdminRequestsScreen(status: status);
        },
      ),
      GoRoute(
        path: '/admin/request-detail',
        builder: (context, state) {
          final request = state.extra as Map<String, dynamic>;
          return AdminRequestDetailScreen(request: request);
        },
      ),
    ],
  );
});