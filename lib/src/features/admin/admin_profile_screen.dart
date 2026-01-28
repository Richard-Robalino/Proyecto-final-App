import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  bool _loading = true;
  Map<String, dynamic>? _profile; // profiles row
  String? _email;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sb = Supabase.instance.client;
    final user = sb.auth.currentUser;

    if (user == null) {
      if (mounted) context.go('/onboarding');
      return;
    }

    _email = user.email;

    // Lee tabla profiles (asegúrate de tener policy select own/admin)
    final row = await sb
        .from('profiles')
        .select('id, full_name, role, avatar_path, is_active, created_at')
        .eq('id', user.id)
        .maybeSingle();

    final p = (row as Map?)?.cast<String, dynamic>();

    // Si tu bucket avatars es público, esto te da URL directa
    // Si avatar_path es null, no muestra avatar
    String? avatarUrl;
    final avatarPath = p?['avatar_path']?.toString();
    if (avatarPath != null && avatarPath.isNotEmpty) {
      avatarUrl = sb.storage.from('avatars').getPublicUrl(avatarPath);
    }

    if (!mounted) return;
    setState(() {
      _profile = p;
      _avatarUrl = avatarUrl;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    final sb = Supabase.instance.client;

    try {
      await sb.auth.signOut();

      if (!mounted) return;
      // Te manda a splash; tu router redirige a onboarding si no hay sesión
      context.go('/splash');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cerrar sesión: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final name = (_profile?['full_name'] ?? 'Admin').toString();
    final role = (_profile?['role'] ?? 'admin').toString();
    final active = (_profile?['is_active'] ?? true) == true;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null ? const Icon(Icons.person_rounded, size: 28) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(_email ?? '-', style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Chip(label: 'Rol: $role', icon: Icons.admin_panel_settings_rounded),
                          _Chip(
                            label: active ? 'Activo' : 'Inactivo',
                            icon: active ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tip: si vas a probar roles, puedes cambiar tu rol en la tabla profiles (admin/client/technician).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _Chip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    );
  }
}
