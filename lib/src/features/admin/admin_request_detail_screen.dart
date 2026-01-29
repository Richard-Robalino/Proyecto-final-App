import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';

// Convertimos a ConsumerStatefulWidget para cargar datos (reseñas)
class AdminRequestDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;

  const AdminRequestDetailScreen({super.key, required this.request});

  @override
  ConsumerState<AdminRequestDetailScreen> createState() => _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends ConsumerState<AdminRequestDetailScreen> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingReviews = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final status = widget.request['status'];
    // Solo cargamos reseñas si el estado es 'completed' o 'rated'
    if (status != 'completed' && status != 'rated') return;

    setState(() => _loadingReviews = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      final reviews = await repo.getReviewsByRequestId(widget.request['id']);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _loadingReviews = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReviews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final request = widget.request;
    final status = request['status'] ?? 'requested';
    final statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Detalle de Solicitud'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER ESTADO
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(_getStatusIcon(status), size: 48, color: statusColor),
                  const SizedBox(height: 12),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      color: statusColor, 
                      fontWeight: FontWeight.w800, 
                      fontSize: 20,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      'ID: ${request['id'].toString().toUpperCase().substring(0, 8)}...',
                      style: TextStyle(color: statusColor.withOpacity(0.8), fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // 2. DETALLES
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request['title'] ?? 'Sin título', 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.2)
                  ),
                  const SizedBox(height: 12),
                  Text(
                    request['description'] ?? 'Sin descripción', 
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 15)
                  ),
                  
                  const Divider(height: 32),
                  
                  _ParticipantRow(
                    label: 'Cliente',
                    name: request['client_name'] ?? 'Desconocido',
                    icon: Icons.person_rounded,
                    color: Colors.blueGrey,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _ParticipantRow(
                    label: 'Técnico Asignado',
                    name: request['technician_name'] ?? 'Pendiente',
                    icon: Icons.handyman_rounded,
                    color: request['technician_name'] != null ? Colors.orange : Colors.grey,
                    isHighlight: request['technician_name'] != null,
                  ),

                  if (request['price'] != null) ...[
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Valor del Servicio:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '\$${request['price']}', 
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.primary)
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // 3. SECCIÓN DE RESEÑAS (NUEVO)
            if (_loadingReviews)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_reviews.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Reseñas del Servicio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._reviews.map((review) => _ReviewAdminCard(review: review)),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Helpers visuales ---
  String _formatDate(String? dateStr) { /* ... (Igual que antes) ... */ return dateStr ?? '-'; }
  Color _getStatusColor(String status) {
    switch (status) {
      case 'requested': return Colors.orange;
      case 'quoted': return Colors.blueAccent;
      case 'accepted': return Colors.indigo;
      case 'on_the_way': return Colors.deepPurple;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rated': return const Color(0xFFD32F2F);
      default: return Colors.grey;
    }
  }
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'requested': return Icons.hourglass_top_rounded;
      case 'rated': return Icons.star_rounded;
      default: return Icons.info_outline;
    }
  }
  String _getStatusText(String status) {
    if (status == 'rated') return 'Servicio Calificado';
    if (status == 'on_the_way') return 'Técnico en Camino';
    return status.toUpperCase();
  }
}

// Widget para mostrar cada reseña
class _ReviewAdminCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewAdminCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final reviewer = review['reviewer'] ?? {};
    final name = reviewer['full_name'] ?? 'Usuario';
    final role = reviewer['role'] == 'technician' ? 'Técnico' : 'Cliente';
    final rating = review['rating'] ?? 0;
    final comment = review['comment'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: role == 'Técnico' ? Colors.orange.shade100 : Colors.blue.shade100,
                child: Icon(
                  role == 'Técnico' ? Icons.handyman : Icons.person,
                  size: 16,
                  color: role == 'Técnico' ? Colors.orange.shade800 : Colors.blue.shade800,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(role, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
              const Spacer(),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: Colors.amber,
                )),
              )
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(comment, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
            ),
          ]
        ],
      ),
    );
  }
}

// Widget auxiliar de filas (igual que antes)
class _ParticipantRow extends StatelessWidget {
  final String label, name;
  final IconData icon;
  final Color color;
  final bool isHighlight;
  const _ParticipantRow({required this.label, required this.name, required this.icon, this.color = Colors.grey, this.isHighlight = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}