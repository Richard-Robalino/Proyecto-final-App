import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_providers.dart';

class AdminTechnicianDetailScreen extends ConsumerStatefulWidget {
  final String techId;
  const AdminTechnicianDetailScreen({super.key, required this.techId});

  @override
  ConsumerState<AdminTechnicianDetailScreen> createState() => _AdminTechnicianDetailScreenState();
}

class _AdminTechnicianDetailScreenState extends ConsumerState<AdminTechnicianDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _tech;
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _certs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sb = ref.read(supabaseProvider);

    final tech = await sb
        .from('technician_profiles')
        .select('id, bio, base_rate, coverage_radius_km, verification_status, profiles(full_name, avatar_path, role)')
        .eq('id', widget.techId)
        .maybeSingle();

    final certs = await sb
        .from('technician_certifications')
        .select('id, technician_id, title, file_path, status, rejection_reason, created_at')
        .eq('technician_id', widget.techId)
        .order('created_at', ascending: false);

    setState(() {
      _tech = (tech as Map?)?.cast<String, dynamic>();
      _profile = ((_tech?['profiles'] as Map?)?.cast<String, dynamic>());
      _certs = (certs as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<String?> _signedUrl(String path) async {
    final sb = ref.read(supabaseProvider);
    final res = await sb.storage.from('certifications').createSignedUrl(path, 60 * 60);
    return res;
  }

  Future<void> _setStatus(String status, {String? reason}) async {
    final sb = ref.read(supabaseProvider);

    await sb.rpc('admin_set_technician_verification', params: {
      '_technician_id': widget.techId,
      '_new_status': status, // 'approved' | 'rejected'
      '_reason': reason,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Actualizado: $status')));
    ref.invalidate(pendingTechniciansProvider);
    await _load();
  }

  Future<void> _rejectDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rechazar técnico'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Rechazar')),
        ],
      ),
    );

    if (ok == true) {
      await _setStatus('rejected', reason: c.text.trim().isEmpty ? null : c.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final name = (_profile?['full_name'] ?? 'Sin nombre').toString();
    final status = (_tech?['verification_status'] ?? 'pending').toString();
    final bio = (_tech?['bio'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text('Verificar: $name')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Estado: $status'),
                  const SizedBox(height: 10),
                  if (bio.isNotEmpty) Text(bio),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: status == 'approved' ? null : () => _setStatus('approved'),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Aprobar'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: status == 'rejected' ? null : _rejectDialog,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rechazar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          Text('Certificaciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),

          if (_certs.isEmpty)
            const Card(child: Padding(padding: EdgeInsets.all(14), child: Text('No ha subido certificados.')))
          else
            ..._certs.map((c) {
              final title = (c['title'] ?? 'Certificado').toString();
              final filePath = (c['file_path'] ?? '').toString();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (filePath.isNotEmpty)
                        FutureBuilder<String?>(
                          future: _signedUrl(filePath),
                          builder: (_, snap) {
                            final url = snap.data;
                            if (snap.connectionState != ConnectionState.done) {
                              return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
                            }
                            if (url == null) return const Text('No se pudo generar URL firmada');
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                                errorWidget: (_, __, ___) => const SizedBox(height: 200, child: Center(child: Text('Error al cargar imagen'))),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
