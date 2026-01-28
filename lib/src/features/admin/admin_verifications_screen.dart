import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_providers.dart';

class AdminVerificationsScreen extends ConsumerWidget {
  const AdminVerificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingTechniciansProvider);

    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No hay técnicos pendientes 🎉'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final t = list[i];
            final p = (t['profiles'] as Map?) ?? {};
            final name = (p['full_name'] ?? 'Sin nombre').toString();
            final rate = (t['base_rate'] ?? 0).toString();

            return Card(
              child: ListTile(
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('Tarifa base: $rate | Radio: ${t['coverage_radius_km']}km'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/admin/verify/${t['id']}'),
              ),
            );
          },
        );
      },
    );
  }
}
