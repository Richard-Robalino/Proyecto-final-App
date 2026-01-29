import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import 'my_jobs_screen.dart';
import 'nearby_requests_screen.dart';

class TechnicianShellScreen extends StatefulWidget {
  const TechnicianShellScreen({super.key});

  @override
  State<TechnicianShellScreen> createState() => _TechnicianShellScreenState();
}

class _TechnicianShellScreenState extends State<TechnicianShellScreen> {
  int _index = 0;

  // Instanciamos las pantallas una sola vez para eficiencia
  final _screens = const [
    NearbyRequestsScreen(), // Mapa de oportunidades (Índice 0)
    MyJobsScreen(),         // Gestión de trabajos activos (Índice 1)
    ProfileScreen(),        // Perfil y configuración (Índice 2)
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // IndexedStack es CRÍTICO aquí para no perder la posición del mapa 
      // ni los filtros cuando el técnico cambia a ver "Mis Trabajos".
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      
      // Barra de Navegación Estilizada "TecniGO"
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5), // Sombra hacia arriba
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (v) => setState(() => _index = v),
          
          // Estilos de Marca
          backgroundColor: Colors.white,
          indicatorColor: cs.primary.withOpacity(0.15), // Fondo suave al seleccionar
          surfaceTintColor: Colors.white,
          height: 70, // Altura moderna
          elevation: 0, // Quitamos elevación default para usar nuestra sombra custom

          // Animación de etiquetas (solo muestra texto al seleccionar)
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 500),

          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.radar_outlined),
              selectedIcon: Icon(Icons.radar_rounded),
              label: 'Oportunidades', // Más atractivo que "Cercanas"
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false, // Espacio para notificaciones futuras
                child: Icon(Icons.work_outline_rounded),
              ),
              selectedIcon: Badge(
                isLabelVisible: false,
                child: Icon(Icons.work_rounded),
              ),
              label: 'Mis Trabajos',
            ),
            NavigationDestination(
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