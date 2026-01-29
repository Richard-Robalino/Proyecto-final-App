import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_dashboard_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_profile_screen.dart';
// Asegúrate de tener este archivo creado, o comenta la línea si aún no lo hacemos
import 'admin_verifications_screen.dart'; 

class AdminShellScreen extends ConsumerStatefulWidget {
  const AdminShellScreen({super.key});

  @override
  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {
  int _index = 0;

  // Lista de páginas
  final _pages = const [
    AdminDashboardScreen(),
    AdminVerificationsScreen(), // Asegúrate de que este widget exista
    AdminCategoriesScreen(),
    AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // ⚠️ ELIMINÉ EL APPBAR AQUÍ: 
      // Las pantallas hijas ya tienen su propio AppBar. Esto evita la doble barra.
      
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // Efecto de transición suave entre pestañas
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: KeyedSubtree(
          // La key hace que AnimatedSwitcher sepa que cambió el widget
          key: ValueKey<int>(_index), 
          child: _pages[_index],
        ),
      ),
      
      bottomNavigationBar: Container(
        // Sombra sutil superior para separar el contenido del menú
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          indicatorColor: cs.primary.withOpacity(0.15), // Naranja suave
          surfaceTintColor: Colors.white,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 600),
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            // Badge para notificar verificaciones pendientes (Opcional visualmente)
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false, // Podrías conectarlo al provider de 'pendingTech'
                child: const Icon(Icons.verified_user_outlined),
              ),
              selectedIcon: const Icon(Icons.verified_user_rounded),
              label: 'Verif.',
            ),
            const NavigationDestination(
              icon: Icon(Icons.category_outlined),
              selectedIcon: Icon(Icons.category_rounded),
              label: 'Categorías',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}