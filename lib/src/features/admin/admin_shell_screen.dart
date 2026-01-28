import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dashboard_screen.dart';
import 'admin_verifications_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_profile_screen.dart';

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _index = 0;

  final _pages = const [
    AdminDashboardScreen(),
    AdminVerificationsScreen(),
    AdminCategoriesScreen(),
    AdminProfileScreen(), // ✅ NUEVA pestaña
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.verified_user_rounded), label: 'Verificaciones'),
          NavigationDestination(icon: Icon(Icons.category_rounded), label: 'Categorías'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'), // ✅ NUEVA
        ],
      ),
    );
  }
}
