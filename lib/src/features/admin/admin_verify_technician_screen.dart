import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/providers.dart';

class AdminVerifyTechnicianScreen extends ConsumerStatefulWidget {
  final String technicianId;
  const AdminVerifyTechnicianScreen({super.key, required this.technicianId});

  @override
  ConsumerState<AdminVerifyTechnicianScreen> createState() => _AdminVerifyTechnicianScreenState();
}

class _AdminVerifyTechnicianScreenState extends ConsumerState<AdminVerifyTechnicianScreen> {
  bool _loading = true;
  Map<String, dynamic>? _techProfile;
  List<Map<String, dynamic>> _certs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Solo mostramos loading si es la primera carga para evitar parpadeos al actualizar
    if (_techProfile == null) setState(() => _loading = true);
    
    final sb = ref.read(supabaseRepoProvider).supabase;

    try {
      // Cargar Perfil Técnico
      final techData = await sb
          .from('technician_profiles')
          .select('*, profiles!inner(*)')
          .eq('id', widget.technicianId)
          .single();

      // Cargar Certificaciones
      final certsData = await sb
          .from('technician_certifications')
          .select()
          .eq('technician_id', widget.technicianId)
          .order('created_at');

      if (mounted) {
        setState(() {
          _techProfile = techData;
          _certs = List<Map<String, dynamic>>.from(certsData);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Lógica para Aprobar/Rechazar un documento específico
  Future<void> _updateCertStatus(String certId, String newStatus) async {
    final sb = ref.read(supabaseRepoProvider).supabase;
    try {
      await sb
          .from('technician_certifications')
          .update({'status': newStatus})
          .eq('id', certId);

      // Recargamos para ver el cambio de estado inmediatamente
      await _loadData();
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' ? 'Documento aprobado' : 'Documento rechazado'),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 1),
          )
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando documento: $e')));
    }
  }

  // Lógica para Ver el documento (Imagen)
  void _viewDocument(String path) {
    final repo = ref.read(supabaseRepoProvider);
    final url = repo.publicUrl('certifications', path);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.broken_image, size: 50, color: Colors.grey),
                        SizedBox(height: 10),
                        Text('No se pudo cargar la imagen'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveTechnician() async {
    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.adminVerifyTechnician(widget.technicianId, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Técnico verificado exitosamente!')),
        );
        context.pop(); // Volver atrás
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading && _techProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verificando...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_techProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('No se encontró el técnico')),
      );
    }

    final p = _techProfile!['profiles'] ?? {};
    final name = p['full_name'] ?? 'Sin nombre';
    final email = p['email'] ?? '-';
    final bio = _techProfile!['bio'] ?? '';
    final baseRate = _techProfile!['base_rate'] ?? 0;
    final radiusKm = _techProfile!['coverage_radius_km'] ?? 0;
    final isTechVerified = _techProfile!['verification_status'] == 'approved';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (!isTechVerified)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilledButton.icon(
                onPressed: _approveTechnician,
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                label: const Text('APROBAR CUENTA'),
              ),
            )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // TARJETA DE PERFIL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(fontSize: 32, color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatItem(label: 'Tarifa', value: '\$$baseRate/h'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _StatItem(label: 'Radio', value: '$radiusKm km'),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _StatItem(
                      label: 'Estado',
                      value: isTechVerified ? 'Verificado' : 'Pendiente',
                      color: isTechVerified ? Colors.green : Colors.orange,
                    ),
                  ],
                ),
                
                const Divider(height: 40),
                
                const Align(alignment: Alignment.centerLeft, child: Text('Biografía', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                Text(
                  bio.isEmpty ? 'El técnico no ha añadido una descripción.' : bio,
                  style: TextStyle(color: Colors.grey[700], height: 1.5),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Documentos y Certificaciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // LISTA DE DOCUMENTOS
          if (_certs.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(child: Text('Este técnico aún no ha subido documentos. No deberías aprobarlo sin ver certificaciones.')),
                ],
              ),
            )
          else
            ..._certs.map((cert) => _CertCard(
              cert: cert,
              onStatusChange: (status) => _updateCertStatus(cert['id'], status),
              onView: () => _viewDocument(cert['file_path']),
            )),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ],
    );
  }
}

class _CertCard extends StatelessWidget {
  final Map<String, dynamic> cert;
  final Function(String) onStatusChange;
  final VoidCallback onView;

  const _CertCard({
    required this.cert, 
    required this.onStatusChange,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = cert['status'] ?? 'pending';
    final title = cert['title'] ?? 'Documento';
    final issuer = cert['issuer'] ?? 'Emisor desconocido';
    
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.hourglass_empty;
    
    if (status == 'approved') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    }

    return Card(
      elevation: 0,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.insert_drive_file_outlined, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if(issuer != null)
                        Text(issuer, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.6))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(status.toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onView,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Ver Documento'),
                ),
                const Spacer(),
                // LÓGICA DE BOTONES: Si ya está aprobado, solo mostramos rechazar (corrección). Si está rechazado, solo aprobar.
                if (status != 'rejected')
                  IconButton(
                    tooltip: 'Rechazar',
                    onPressed: () => onStatusChange('rejected'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1)),
                  ),
                const SizedBox(width: 8),
                if (status != 'approved')
                  IconButton(
                    tooltip: 'Aprobar',
                    onPressed: () => onStatusChange('approved'),
                    icon: const Icon(Icons.check, color: Colors.green),
                    style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}