import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  final String status;

  const AdminRequestsScreen({super.key, required this.status});

  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      
      print('🔄 Cargando solicitudes para estado: ${widget.status}'); // DEBUG
      
      final requests = await repo.adminGetRequestsByStatus(widget.status);
      
      print('📊 Total de solicitudes cargadas: ${requests.length}'); // DEBUG

      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (e) {
      print('❌ Error en _loadRequests: $e'); // DEBUG
      
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando solicitudes: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5), // Más tiempo para leer
          ),
        );
      }
    }
  }

  String _getTitle() {
    switch (widget.status) {
      case 'requested':
        return 'Solicitudes Pendientes';
      case 'accepted':
        return 'Solicitudes Aceptadas';
      case 'completed':
        return 'Solicitudes Completadas';
      default:
        return 'Solicitudes';
    }
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case 'requested':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadRequests,
            icon: Icon(Icons.refresh_rounded, color: cs.primary),
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_rounded,
                        size: 64,
                        color: cs.onSurface.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay solicitudes',
                        style: TextStyle(
                          fontSize: 16,
                          color: cs.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: cs.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final request = _requests[index];
                      return _RequestCard(
                        request: request,
                        statusColor: _getStatusColor(),
                        onTap: () {
                          context.push('/admin/request-detail', extra: request);
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final Color statusColor;
  final VoidCallback onTap;

  const _RequestCard({
    required this.request,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABECERA: TIPO DE SERVICIO Y FLECHA
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      request['service_type'] ?? 'Servicio',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: cs.onSurface.withOpacity(0.3),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // TÍTULO (NUEVO)
              Text(
                request['title'] ?? 'Solicitud Sin Título',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 4),
              
              // ID y DESCRIPCIÓN
              Text(
                'ID: ${request['id']?.toString().substring(0, 8) ?? 'N/A'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.5),
                  fontFamily: 'monospace',
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                request['description'] ?? 'Sin descripción',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              // TÉCNICO ASIGNADO
              if (request['technician_name'] != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.handyman_rounded,
                      size: 16,
                      color: cs.primary.withOpacity(0.7),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Técnico: ${request['technician_name']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}