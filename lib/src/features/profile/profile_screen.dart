import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/models.dart';
import '../../state/app_state.dart';
import '../../state/providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loading = true;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _tech;

  List<ServiceCategory> _categories = const [];
  Set<int> _specialtyIds = {};

  List<Map<String, dynamic>> _certs = const [];
  List<Map<String, dynamic>> _portfolio = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    try {
      final uid = supabase.auth.currentUser!.id;

      _categories = await repo.fetchCategories();

      _profile = await supabase.from('profiles').select('id, full_name, role, avatar_path').eq('id', uid).single();

      if ((_profile?['role'] as String?) == 'technician') {
        _tech = await supabase
            .from('technician_profiles')
            .select('verification_status, base_rate, coverage_radius_km, bio')
            .eq('id', uid)
            .single();

        // Especialidades
        final specRes = await supabase
            .from('technician_specialties')
            .select('category_id')
            .eq('technician_id', uid);

        final specList = (specRes as List).cast<Map<String, dynamic>>();
        _specialtyIds = specList.map((m) => (m['category_id'] as num).toInt()).toSet();

        // Certificaciones
        final certRes = await supabase
            .from('technician_certifications')
            .select('*')
            .eq('technician_id', uid)
            .order('created_at', ascending: false);
        _certs = (certRes as List).cast<Map<String, dynamic>>();

        // Portafolio
        final portRes = await supabase
            .from('portfolio_items')
            .select('id, title, description, created_at, portfolio_photos(path)')
            .eq('technician_id', uid)
            .order('created_at', ascending: false);
        _portfolio = (portRes as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final repo = ref.read(supabaseRepoProvider);

    try {
      final path = 'avatars/${repo.userId}.jpg';
      await repo.uploadBytes(bucket: 'avatars', path: path, bytes: bytes);
      await ref.read(supabaseClientProvider).from('profiles').update({'avatar_path': path}).eq('id', repo.userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir avatar: $e')));
    }
  }

  Future<void> _editTechInfo() async {
    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    final baseRateCtrl = TextEditingController(text: (_tech?['base_rate'] ?? 0).toString());
    final radiusCtrl = TextEditingController(text: (_tech?['coverage_radius_km'] ?? 10).toString());
    final bioCtrl = TextEditingController(text: (_tech?['bio'] as String?) ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Editar perfil técnico', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: baseRateCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tarifa base (USD)', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Radio de cobertura (km)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Bio / Descripción'),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Guardar'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    final baseRate = num.tryParse(baseRateCtrl.text.replaceAll(',', '.')) ?? 0;
    final radius = num.tryParse(radiusCtrl.text.replaceAll(',', '.')) ?? 10;

    try {
      await supabase.from('technician_profiles').update({
        'base_rate': baseRate,
        'coverage_radius_km': math.max(1, radius),
        'bio': bioCtrl.text.trim().isEmpty ? null : bioCtrl.text.trim(),
      }).eq('id', repo.userId);

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil técnico actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo actualizar: $e')));
    }
  }

  Future<void> _addSpecialty() async {
    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    final available = _categories.where((c) => !_specialtyIds.contains(c.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya tienes todas las categorías.')));
      return;
    }

    int selected = available.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar especialidad'),
        content: DropdownButtonFormField<int>(
          value: selected,
          items: available.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          onChanged: (v) => selected = v ?? selected,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Agregar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await supabase.from('technician_specialties').insert({'technician_id': repo.userId, 'category_id': selected});
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo agregar: $e')));
    }
  }

  Future<void> _removeSpecialty(int categoryId) async {
    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    try {
      await supabase.from('technician_specialties').delete().eq('technician_id', repo.userId).eq('category_id', categoryId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo quitar: $e')));
    }
  }

  Future<void> _addCertification() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final titleCtrl = TextEditingController(text: 'Certificación');
    final issuerCtrl = TextEditingController(text: 'Institución');
    final issuedCtrl = TextEditingController(text: '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva certificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 10),
            TextField(controller: issuerCtrl, decoration: const InputDecoration(labelText: 'Emisor (opcional)')),
            const SizedBox(height: 10),
            TextField(controller: issuedCtrl, decoration: const InputDecoration(labelText: 'Fecha (YYYY-MM-DD, opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;

    final repo = ref.read(supabaseRepoProvider);
    try {
      final filePath = 'certs/${repo.userId}/${const Uuid().v4()}.jpg';
      await repo.uploadBytes(bucket: 'certifications', path: filePath, bytes: bytes);

      await ref.read(supabaseClientProvider).from('technician_certifications').insert({
        'technician_id': repo.userId,
        'title': titleCtrl.text.trim(),
        'issuer': issuerCtrl.text.trim().isEmpty ? null : issuerCtrl.text.trim(),
        'issued_date': issuedCtrl.text.trim().isEmpty ? null : issuedCtrl.text.trim(),
        'file_path': filePath,
      });

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Certificación enviada a verificación')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo subir: $e')));
    }
  }

  Future<void> _addPortfolioItem() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();

    final titleCtrl = TextEditingController(text: 'Trabajo realizado');
    final descCtrl = TextEditingController(text: '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo item de portafolio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 10),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descripción (opcional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;

    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    try {
      final item = await supabase
          .from('portfolio_items')
          .insert({
            'technician_id': repo.userId,
            'title': titleCtrl.text.trim(),
            'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
          })
          .select('id')
          .single();

      final itemId = item['id'] as String;
      final photoPath = 'portfolio/${repo.userId}/$itemId/${const Uuid().v4()}.jpg';
      await repo.uploadBytes(bucket: 'portfolio', path: photoPath, bytes: bytes);

      await supabase.from('portfolio_photos').insert({'portfolio_id': itemId, 'path': photoPath});

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Portafolio actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final repo = ref.read(supabaseRepoProvider);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = _profile;
    if (p == null) {
      return const Scaffold(body: Center(child: Text('Sin perfil')));
    }

    final role = p['role'] as String;
    final avatarPath = p['avatar_path'] as String?;
    final avatarUrl = avatarPath == null ? null : repo.publicUrl('avatars', avatarPath);

    final categoryById = {for (final c in _categories) c.id: c};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => appState.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  InkWell(
                    onTap: _pickAndUploadAvatar,
                    borderRadius: BorderRadius.circular(20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 60,
                        width: 60,
                        color: Theme.of(context).colorScheme.primaryContainer,
                        child: avatarUrl == null
                            ? Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.onPrimaryContainer)
                            : CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['full_name'] as String? ?? 'Usuario',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('Rol: $role', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('Tip: toca el avatar para cambiarlo', style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (role == 'technician') ...[
            _TechnicianSection(
              tech: _tech,
              categories: _categories,
              categoryById: categoryById,
              specialtyIds: _specialtyIds,
              certs: _certs,
              portfolio: _portfolio,
              onEditTech: _editTechInfo,
              onAddSpecialty: _addSpecialty,
              onRemoveSpecialty: _removeSpecialty,
              onAddCert: _addCertification,
              onAddPortfolio: _addPortfolioItem,
            ),
          ],

          if (role == 'client') ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cliente', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text(
                      'Crea solicitudes, compara cotizaciones y califica al técnico.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Checklist para el 20/20', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    '✅ Roles + Auth (cliente / técnico)\n'
                    '✅ Verificación de técnico (certificaciones)\n'
                    '✅ Portafolio con fotos\n'
                    '✅ Geolocalización + mapa (OSM)\n'
                    '✅ Solicitud → cotización → aceptar → estados\n'
                    '✅ Reseñas bidireccionales\n'
                    '⭐ Extra: IA (Asistente de diagnóstico)\n',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianSection extends StatelessWidget {
  const _TechnicianSection({
    required this.tech,
    required this.categories,
    required this.categoryById,
    required this.specialtyIds,
    required this.certs,
    required this.portfolio,
    required this.onEditTech,
    required this.onAddSpecialty,
    required this.onRemoveSpecialty,
    required this.onAddCert,
    required this.onAddPortfolio,
  });

  final Map<String, dynamic>? tech;
  final List<ServiceCategory> categories;
  final Map<int, ServiceCategory> categoryById;
  final Set<int> specialtyIds;
  final List<Map<String, dynamic>> certs;
  final List<Map<String, dynamic>> portfolio;

  final Future<void> Function() onEditTech;
  final Future<void> Function() onAddSpecialty;
  final Future<void> Function(int categoryId) onRemoveSpecialty;
  final Future<void> Function() onAddCert;
  final Future<void> Function() onAddPortfolio;

  @override
  Widget build(BuildContext context) {
    final status = (tech?['verification_status'] as String?) ?? 'pending';
    final baseRate = (tech?['base_rate'] as num?) ?? 0;
    final radius = (tech?['coverage_radius_km'] as num?) ?? 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Perfil técnico', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    OutlinedButton.icon(
                      onPressed: onEditTech,
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Editar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Verificación: $status'),
                const SizedBox(height: 4),
                Text('Tarifa base: \$${baseRate.toString()}'),
                const SizedBox(height: 4),
                Text('Cobertura: ${radius.toString()} km'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Especialidades
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Especialidades', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                    FilledButton.icon(
                      onPressed: onAddSpecialty,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (specialtyIds.isEmpty)
                  Text('Aún no agregas especialidades.', style: Theme.of(context).textTheme.bodySmall),
                if (specialtyIds.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: specialtyIds.map((id) {
                      final name = categoryById[id]?.name ?? 'Categoría $id';
                      return GestureDetector(
                        onLongPress: () => onRemoveSpecialty(id),
                        child: Chip(
                          label: Text(name),
                          avatar: const Icon(Icons.check_circle_rounded, size: 18),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Text('Tip: mantén presionada una especialidad para quitarla.', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Certificaciones
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Certificaciones', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: onAddCert,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Subir certificación'),
                  ),
                ),
                const SizedBox(height: 8),
                if (certs.isEmpty) Text('Aún no has subido certificaciones.', style: Theme.of(context).textTheme.bodySmall),
                if (certs.isNotEmpty)
                  ...certs.take(3).map((c) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_rounded),
                        title: Text(c['title'] as String? ?? 'Certificación'),
                        subtitle: Text('Estado: ${c['status']}'),
                      )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Portafolio
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Portafolio', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  'Muestra trabajos previos con fotos para aumentar confianza.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: onAddPortfolio,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Agregar al portafolio'),
                  ),
                ),
                const SizedBox(height: 10),
                if (portfolio.isNotEmpty)
                  ...portfolio.take(2).map((p) {
                    final title = p['title'] as String? ?? 'Trabajo';
                    final photos = (p['portfolio_photos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.photo_library_rounded),
                      title: Text(title),
                      subtitle: Text('${photos.length} foto(s)'),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
