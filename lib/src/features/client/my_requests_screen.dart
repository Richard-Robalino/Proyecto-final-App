import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  bool _loading = true;
  List<ServiceRequest> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      final res = await repo.fetchMyRequests();
      setState(() => _items = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Aún no tienes solicitudes.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(14),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _RequestTile(item: _items[i]),
                ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.item});
  final ServiceRequest item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateFormat('dd/MM HH:mm').format(item.createdAt.toLocal());

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.go('/client/request/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.build_circle_rounded, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StatusChip(status: item.status),
                        const SizedBox(width: 10),
                        Text(date, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    )
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'requested':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        label = 'Solicitud';
        break;
      case 'quoted':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        label = 'Cotización';
        break;
      case 'accepted':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'Aceptada';
        break;
      case 'on_the_way':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'En camino';
        break;
      case 'in_progress':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        label = 'En progreso';
        break;
      case 'completed':
        bg = cs.surfaceVariant;
        fg = cs.onSurfaceVariant;
        label = 'Completado';
        break;
      case 'rated':
        bg = cs.primary;
        fg = cs.onPrimary;
        label = 'Calificado';
        break;
      case 'cancelled':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        label = 'Cancelada';
        break;
      default:
        bg = cs.surfaceVariant;
        fg = cs.onSurfaceVariant;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
