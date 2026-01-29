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

      _profile = await supabase
          .from('profiles')
          .select('id, full_name, role, avatar_path')
          .eq('id', uid)
          .single();

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
        _specialtyIds =
            specList.map((m) => (m['category_id'] as num).toInt()).toSet();

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
            .select(
                'id, title, description, created_at, portfolio_photos(path)')
            .eq('technician_id', uid)
            .order('created_at', ascending: false);
        _portfolio = (portRes as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final repo = ref.read(supabaseRepoProvider);

    try {
      final path = 'avatars/${repo.userId}.jpg';
      await repo.uploadBytes(bucket: 'avatars', path: path, bytes: bytes);
      // Forzar actualización simple
      await ref
          .read(supabaseClientProvider)
          .from('profiles')
          .update({'avatar_path': path}).eq('id', repo.userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo subir avatar: $e')));
    }
  }

  Future<void> _editTechInfo() async {
    final supabase = ref.read(supabaseClientProvider);
    final repo = ref.read(supabaseRepoProvider);

    final baseRateCtrl =
        TextEditingController(text: (_tech?['base_rate'] ?? 0).toString());
    final radiusCtrl = TextEditingController(
        text: (_tech?['coverage_radius_km'] ?? 10).toString());
    final bioCtrl =
        TextEditingController(text: (_tech?['bio'] as String?) ?? '');

    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Editar Perfil Técnico',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: baseRateCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Tarifa base (USD/hr)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: radiusCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Radio de cobertura (km)',
                  prefixIcon: const Icon(Icons.map),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bioCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Biografía / Experiencia',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Guardar Cambios'),
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al actualizar: $e')));
    }
  }

  Future<void> _addSpecialty() async {
    final available =
        _categories.where((c) => !_specialtyIds.contains(c.id)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya tienes todas las categorías.')));
      return;
    }

    int? selected = available.first.id;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Agregar Especialidad'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: selected,
                      isExpanded: true, // ✅ ESTO PREVIENE EL OVERFLOW
                      items: available.map((c) {
                        return DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selected = val);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Agregar'),
              ),
            ],
          ),
        );
      },
    );

    if (ok != true) return;

    final repo = ref.read(supabaseRepoProvider);
    try {
      await ref
          .read(supabaseClientProvider)
          .from('technician_specialties')
          .insert({'technician_id': repo.userId, 'category_id': selected});
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Especialidad agregada')),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _removeSpecialty(int id) async {
    try {
      await ref
          .read(supabaseClientProvider)
          .from('technician_specialties')
          .delete()
          .eq('technician_id', ref.read(supabaseRepoProvider).userId)
          .eq('category_id', id);
      await _load();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addCertification() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final titleCtrl = TextEditingController(text: 'Certificación');
    final issuerCtrl = TextEditingController();

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Certificación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: titleCtrl,
                decoration:
                    const InputDecoration(labelText: 'Título del documento')),
            TextField(
                controller: issuerCtrl,
                decoration:
                    const InputDecoration(labelText: 'Emisor (Opcional)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Subir')),
        ],
      ),
    );

    if (ok != true) return;

    final repo = ref.read(supabaseRepoProvider);
    try {
      final filePath = 'certs/${repo.userId}/${const Uuid().v4()}.jpg';
      await repo.uploadBytes(
          bucket: 'certifications', path: filePath, bytes: bytes);

      await ref
          .read(supabaseClientProvider)
          .from('technician_certifications')
          .insert({
        'technician_id': repo.userId,
        'title': titleCtrl.text.trim(),
        'issuer':
            issuerCtrl.text.trim().isEmpty ? null : issuerCtrl.text.trim(),
        'file_path': filePath,
      });

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Certificación subida.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _addPortfolioItem() async {
    final picker = ImagePicker();
    final img =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img == null) return;

    final bytes = await img.readAsBytes();
    final titleCtrl = TextEditingController(text: 'Trabajo Realizado');

    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Item Portafolio'),
        content: TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(labelText: 'Título del trabajo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Subir')),
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
          })
          .select('id')
          .single();

      final itemId = item['id'] as String;
      final photoPath =
          'portfolio/${repo.userId}/$itemId/${const Uuid().v4()}.jpg';
      await repo.uploadBytes(
          bucket: 'portfolio', path: photoPath, bytes: bytes);
      await supabase
          .from('portfolio_photos')
          .insert({'portfolio_id': itemId, 'path': photoPath});

      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Añadido al portafolio')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final repo = ref.read(supabaseRepoProvider);
    final cs = Theme.of(context).colorScheme;

    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_profile == null)
      return const Scaffold(body: Center(child: Text('Error cargando perfil')));

    final p = _profile!;
    final role = p['role'] as String;
    final avatarPath = p['avatar_path'] as String?;
    final avatarUrl =
        avatarPath == null ? null : repo.publicUrl('avatars', avatarPath);
    final categoryById = {for (final c in _categories) c.id: c};

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión',
            onPressed: () => _confirmSignOut(appState),
            icon: Icon(Icons.logout_rounded, color: cs.error),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. HEADER PERFIL
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: cs.primary.withOpacity(0.2), width: 4),
                      image: avatarUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(avatarUrl),
                              fit: BoxFit.cover)
                          : null,
                      color: cs.primaryContainer,
                    ),
                    child: avatarUrl == null
                        ? Icon(Icons.person_rounded,
                            size: 60, color: cs.primary)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAndUploadAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.camera_alt,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              p['full_name'] as String? ?? 'Usuario',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              role == 'technician' ? 'Técnico Profesional' : 'Cliente',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 30),

            // 2. SECCIÓN ESPECÍFICA (Técnico o Cliente)
            if (role == 'technician')
              _TechnicianSection(
                tech: _tech,
                categoryById: categoryById,
                specialtyIds: _specialtyIds,
                certs: _certs,
                portfolio: _portfolio,
                onEditTech: _editTechInfo,
                onAddSpecialty: _addSpecialty,
                onRemoveSpecialty: _removeSpecialty,
                onAddCert: _addCertification,
                onAddPortfolio: _addPortfolioItem,
              )
            else
              _ClientSection(),

            const SizedBox(height: 30),

            // Footer Info
            Center(
                child: Text('TecniGO v1.0.0',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que ingresar tus datos nuevamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Salir')),
        ],
      ),
    );
    if (ok == true) state.signOut();
  }
}

// --- WIDGETS DE SECCIÓN ---

class _ClientSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 0,
          color: Colors.blue.shade50,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.sentiment_satisfied_rounded,
                    size: 40, color: Colors.blue),
                const SizedBox(height: 12),
                const Text(
                  '¡Bienvenido!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  'Desde aquí puedes gestionar tu cuenta. Para pedir servicios, ve a la pestaña "Mapa" o "Solicitudes".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Menú Genérico
        _ProfileMenuOptions(),
      ],
    );
  }
}

class _TechnicianSection extends StatelessWidget {
  const _TechnicianSection({
    required this.tech,
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
  final Map<int, ServiceCategory> categoryById;
  final Set<int> specialtyIds;
  final List<Map<String, dynamic>> certs;
  final List<Map<String, dynamic>> portfolio;
  final VoidCallback onEditTech;
  final VoidCallback onAddSpecialty;
  final Function(int) onRemoveSpecialty;
  final VoidCallback onAddCert;
  final VoidCallback onAddPortfolio;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (tech?['verification_status'] as String?) ?? 'pending';
    final baseRate = (tech?['base_rate'] as num?) ?? 0;

    // Color de estado
    Color statusColor = Colors.orange;
    if (status == 'verified') statusColor = Colors.green;
    if (status == 'rejected') statusColor = Colors.red;

    return Column(
      children: [
        // TARJETA DE ESTADO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estado de Cuenta',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tarifa Base',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12)),
                      Text('\$$baseRate/hr',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: onEditTech,
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar Datos'),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ESPECIALIDADES
        _SectionHeader(
            title: 'Especialidades',
            actionLabel: 'Agregar',
            onAction: onAddSpecialty),
        const SizedBox(height: 10),
        if (specialtyIds.isEmpty)
          const _EmptyStateText('No has seleccionado especialidades.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialtyIds.map((id) {
              return Chip(
                label: Text(categoryById[id]?.name ?? 'Cat #$id'),
                backgroundColor: cs.secondaryContainer.withOpacity(0.3),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => onRemoveSpecialty(id),
              );
            }).toList(),
          ),

        const SizedBox(height: 24),

        // CERTIFICACIONES
        _SectionHeader(
            title: 'Certificaciones',
            actionLabel: 'Subir',
            onAction: onAddCert),
        const SizedBox(height: 10),
        if (certs.isEmpty)
          const _EmptyStateText('Sube documentos para verificarte.')
        else
          Column(
            children: certs
                .map((c) => Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.verified_user_outlined),
                        title: Text(c['title'] ?? 'Documento',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c['status'] ?? 'pending'),
                        trailing: Icon(
                          c['status'] == 'approved'
                              ? Icons.check_circle
                              : Icons.hourglass_empty,
                          color: c['status'] == 'approved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ))
                .toList(),
          ),

        const SizedBox(height: 24),

        // PORTAFOLIO
        _SectionHeader(
            title: 'Portafolio',
            actionLabel: 'Nuevo',
            onAction: onAddPortfolio),
        const SizedBox(height: 10),
        if (portfolio.isEmpty)
          const _EmptyStateText('Muestra tus mejores trabajos.')
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: portfolio.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final item = portfolio[i];
                final title = item['title'] ?? 'Sin título';

                // Lógica para obtener la URL de la primera foto
                // La estructura suele ser: item['portfolio_photos'] -> List<Map> -> ['path']
                String? photoUrl;
                final photos = item['portfolio_photos'] as List?;
                if (photos != null && photos.isNotEmpty) {
                  final firstPhoto = photos[0] as Map;
                  final path = firstPhoto['path'] as String?;
                  if (path != null) {
                    // Usamos ref para leer el repo, pero como este es un Stateless sin ref,
                    // necesitamos pasar el repo o usar ConsumerWidget.
                    // TRUCO RÁPIDO: Pasar el repositorio como argumento a _TechnicianSection
                    // O asumimos que tienes acceso.
                    // -> Lo mejor: Asumo que en ProfileScreen pasaste 'repo' a esta clase o usas Supabase.instance
                    // Vamos a usar una URL genérica si no pasamos el repo, pero lo ideal es pasar el repo.
                  }
                }

                // CORRECCIÓN: Para que funcione limpio, necesitamos el repositorio aquí.
                // Asumiendo que agregas `final SupabaseRepo repo;` al constructor de _TechnicianSection
                // y lo pasas desde el padre.

                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.05), blurRadius: 4)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: _PortfolioImage(
                              item: item), // Widget auxiliar abajo
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 20),
        // Menú Genérico también para técnicos
        _ProfileMenuOptions(),
      ],
    );
  }
}

class _ProfileMenuOptions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MenuTile(icon: Icons.security, title: 'Seguridad', onTap: () {}),
        _MenuTile(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
            onTap: () {}),
        _MenuTile(
            icon: Icons.help_outline, title: 'Ayuda y Soporte', onTap: () {}),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration:
            BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.grey[700]),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader(
      {required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _EmptyStateText extends StatelessWidget {
  final String text;
  const _EmptyStateText(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Text(text,
          style: TextStyle(color: Colors.grey[600]),
          textAlign: TextAlign.center),
    );
  }
}


class _PortfolioImage extends ConsumerWidget {
  final Map<String, dynamic> item;
  const _PortfolioImage({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supabaseRepoProvider);
    
    // Parseo seguro de la ruta
    String? path;
    try {
      final photos = item['portfolio_photos'] as List?;
      if (photos != null && photos.isNotEmpty) {
        path = photos[0]['path'] as String?;
      }
    } catch (_) {}

    if (path == null) {
      return Container(
        color: Colors.grey[200],
        child: const Icon(Icons.image_not_supported_rounded, color: Colors.grey),
      );
    }

    final url = repo.publicUrl('portfolio', path); // Asegúrate que el bucket se llame 'portfolio'

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[200]),
      errorWidget: (_, __, ___) => Container(
        color: Colors.grey[100],
        child: const Icon(Icons.broken_image, color: Colors.grey),
      ),
    );
  }
}