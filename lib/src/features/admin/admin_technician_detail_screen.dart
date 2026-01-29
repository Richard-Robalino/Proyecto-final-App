import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../state/providers.dart';
import 'admin_providers.dart';



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
    setState(() => _loading = true);
    final sb = ref.read(supabaseProvider);

    try {
      final techData = await sb
          .from('technician_profiles')
          .select('*, profiles(full_name, avatar_path, email, phone)')
          .eq('id', widget.technicianId)
          .single();

      final certsData = await sb
          .from('technician_certifications')
          .select()
          .eq('technician_id', widget.technicianId)
          .order('created_at', ascending: false);

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

  // Lógica de tu archivo anterior: Generar URL temporal segura
  Future<String?> _getSignedUrl(String path) async {
    try {
      final sb = ref.read(supabaseProvider);
      // El bucket se llama 'certifications' según tu código anterior
      final res = await sb.storage.from('certifications').createSignedUrl(path, 60 * 60); 
      return res;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateCertStatus(String certId, String newStatus) async {
    final sb = ref.read(supabaseProvider);
    try {
      await sb
          .from('technician_certifications')
          .update({'status': newStatus})
          .eq('id', certId);
      await _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveTechnician() async {
    final sb = ref.read(supabaseProvider);
    try {
      await sb
          .from('technician_profiles')
          .update({'verification_status': 'verified'})
          .eq('id', widget.technicianId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Técnico verificado')));
        context.pop(); 
        ref.refresh(adminStatsProvider);
        ref.refresh(pendingTechniciansProvider);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Diálogo de rechazo (de tu código anterior, estilizado)
  Future<void> _rejectTechnician() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar técnico'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Motivo del rechazo',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      // Aquí puedes usar tu RPC si prefieres, o update directo
      final sb = ref.read(supabaseProvider);
      await sb.from('technician_profiles').update({
        'verification_status': 'rejected',
        // 'rejection_reason': c.text // Si tienes esa columna
      }).eq('id', widget.technicianId);
      
      if(mounted) {
        context.pop();
        ref.refresh(pendingTechniciansProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_techProfile == null) return const Scaffold(body: Center(child: Text('Error de carga')));

    final p = _techProfile!['profiles'] ?? {};
    final name = p['full_name'] ?? 'Sin nombre';
    final email = p['email'] ?? '-';
    final bio = _techProfile!['bio'] ?? '';
    final status = _techProfile!['verification_status'];

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(name),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. HEADER PERFIL
          _ProfileHeaderCard(name: name, email: email, bio: bio, status: status),
          
          const SizedBox(height: 24),
          
          // 2. DOCUMENTOS
          Row(
            children: [
              Icon(Icons.folder_shared_rounded, color: cs.primary),
              const SizedBox(width: 8),
              Text('Documentación Enviada', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          if (_certs.isEmpty)
            const Center(child: Text('No hay documentos cargados.'))
          else
            ..._certs.map((cert) {
              return _CertCardEnhanced(
                cert: cert,
                onStatusChange: (s) => _updateCertStatus(cert['id'], s),
                urlFuture: _getSignedUrl(cert['file_path'] ?? ''),
              );
            }),

          const SizedBox(height: 40),

          // 3. ACCIONES FINALES
          if (status == 'pending')
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _rejectTechnician,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('RECHAZAR'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _approveTechnician,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('APROBAR'),
                  ),
                ),
              ],
            ),
             const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// --- WIDGETS AUXILIARES MEJORADOS ---

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String email;
  final String bio;
  final String status;

  const _ProfileHeaderCard({required this.name, required this.email, required this.bio, required this.status});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(radius: 35, child: Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 24))),
            const SizedBox(height: 12),
            Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(email, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: status == 'pending' ? Colors.orange[100] : (status == 'verified' ? Colors.green[100] : Colors.red[100]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: status == 'pending' ? Colors.orange[800] : (status == 'verified' ? Colors.green[800] : Colors.red[800]),
                ),
              ),
            ),
            if (bio.isNotEmpty) ...[
              const Divider(height: 30),
              Text(bio, textAlign: TextAlign.center, style: const TextStyle(fontStyle: FontStyle.italic)),
            ]
          ],
        ),
      ),
    );
  }
}

class _CertCardEnhanced extends StatelessWidget {
  final Map<String, dynamic> cert;
  final Function(String) onStatusChange;
  final Future<String?> urlFuture;

  const _CertCardEnhanced({required this.cert, required this.onStatusChange, required this.urlFuture});

  @override
  Widget build(BuildContext context) {
    final title = cert['title'] ?? 'Documento';
    final status = cert['status'] ?? 'pending';
    final cs = Theme.of(context).colorScheme;

    Color statusColor = status == 'approved' ? Colors.green : (status == 'rejected' ? Colors.red : Colors.orange);
    IconData statusIcon = status == 'approved' ? Icons.check_circle : (status == 'rejected' ? Icons.cancel : Icons.hourglass_top);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant.withOpacity(0.5))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER DEL DOCUMENTO
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Icon(statusIcon, color: statusColor),
              ],
            ),
          ),
          
          const Divider(),

          // PREVISUALIZACIÓN (IMAGEN)
          FutureBuilder<String?>(
            future: urlFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
              }
              final url = snapshot.data;
              if (url == null) {
                return Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: const Center(child: Text('No se pudo cargar imagen')),
                );
              }

              // Intentamos mostrar imagen. Si es PDF, cached_network_image fallará y mostrará errorWidget
              return GestureDetector(
                onTap: () => launchUrl(Uri.parse(url)), // Al tocar, abre en navegador completo
                child: Hero(
                  tag: url,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    height: 200,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (_, __, ___) => Container(
                      height: 150,
                      color: Colors.grey[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf, size: 40, color: Colors.red),
                          const SizedBox(height: 8),
                          const Text('Documento PDF (Toque para abrir)', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // ACCIONES
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status != 'rejected')
                  TextButton.icon(
                    onPressed: () => onStatusChange('rejected'),
                    icon: const Icon(Icons.close, color: Colors.red, size: 18),
                    label: const Text('Rechazar', style: TextStyle(color: Colors.red)),
                  ),
                if (status != 'approved')
                  TextButton.icon(
                    onPressed: () => onStatusChange('approved'),
                    icon: const Icon(Icons.check, color: Colors.green, size: 18),
                    label: const Text('Aprobar', style: TextStyle(color: Colors.green)),
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }
}