import 'package:flutter/material.dart';

import '../profile/profile_screen.dart';
import 'nearby_requests_screen.dart';
import 'my_jobs_screen.dart';

class TechnicianShellScreen extends StatefulWidget {
  const TechnicianShellScreen({super.key});

  @override
  State<TechnicianShellScreen> createState() => _TechnicianShellScreenState();
}

class _TechnicianShellScreenState extends State<TechnicianShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          NearbyRequestsScreen(),
          MyJobsScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.radar_rounded), label: 'Cercanas'),
          NavigationDestination(icon: Icon(Icons.work_rounded), label: 'Trabajos'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}
