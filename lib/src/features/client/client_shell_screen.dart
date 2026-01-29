import 'package:flutter/material.dart';

// Asegúrate de que estos imports apunten a tus archivos reales
import '../profile/profile_screen.dart';
import 'client_home_map_screen.dart';
import 'my_requests_screen.dart';

class ClientShellScreen extends StatefulWidget {
  const ClientShellScreen({super.key});

  @override
  State<ClientShellScreen> createState() => _ClientShellScreenState();
}

class _ClientShellScreenState extends State<ClientShellScreen> {
  int _index = 0;

  // Instanciamos las pantallas una sola vez (const) para eficiencia
  final _screens = const [
    ClientHomeMapScreen(),
    MyRequestsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      // Usamos IndexedStack para mantener el estado del Mapa (Zoom, Posición)
      // cuando el usuario navega a otras pestañas.
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
          indicatorColor: cs.primary.withOpacity(0.15), // Fondo naranja suave al seleccionar
          surfaceTintColor: Colors.white,
          elevation: 0, // Quitamos elevación por defecto para usar nuestra sombra custom
          height: 70, // Un poco más alta para modernidad
          
          // Animación de etiquetas
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          animationDuration: const Duration(milliseconds: 500),
          
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Explorar',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: false, // Aquí podrías conectar un provider de notificaciones
                child: Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: false,
                child: Icon(Icons.receipt_long_rounded),
              ),
              label: 'Solicitudes',
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