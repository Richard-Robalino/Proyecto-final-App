import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  bool _loading = true;

  int requested = 0;
  int accepted = 0;
  int inProgress = 0;
  int completed = 0;
  int pendingTech = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);

      // ⚠️ Ajusta estos strings si tus estados en BD son diferentes.
      requested = await repo.adminCountRequestsByStatus('requested');
      accepted = await repo.adminCountRequestsByStatus('accepted');
      inProgress = await repo.adminCountRequestsByStatus('in_progress');
      completed = await repo.adminCountRequestsByStatus('completed');

      pendingTech = await repo.adminCountPendingTechVerifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Admin dashboard error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Admin'),
        actions: [
          IconButton(
            tooltip: 'Refrescar',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _card(
                  icon: Icons.pending_actions_rounded,
                  title: 'Solicitudes: Requested',
                  value: requested,
                  cs: cs,
                ),
                const SizedBox(height: 10),
                _card(
                  icon: Icons.verified_rounded,
                  title: 'Solicitudes: Accepted',
                  value: accepted,
                  cs: cs,
                ),
                const SizedBox(height: 10),
                _card(
                  icon: Icons.build_circle_outlined,
                  title: 'Solicitudes: In Progress',
                  value: inProgress,
                  cs: cs,
                ),
                const SizedBox(height: 10),
                _card(
                  icon: Icons.task_alt_rounded,
                  title: 'Solicitudes: Completed',
                  value: completed,
                  cs: cs,
                ),
                const SizedBox(height: 10),
                _card(
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Técnicos pendientes de verificación',
                  value: pendingTech,
                  cs: cs,
                ),
              ],
            ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required int value,
    required ColorScheme cs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            color: Colors.black.withOpacity(0.06),
          ),
        ],
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: cs.primaryContainer,
          foregroundColor: cs.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text(
          '$value',
          style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary, fontSize: 18),
        ),
      ),
    );
  }
}
