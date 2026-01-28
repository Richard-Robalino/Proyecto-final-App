import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class AdminCategoriesScreen extends ConsumerStatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  ConsumerState<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends ConsumerState<AdminCategoriesScreen> {
  bool _loading = true;
  List<ServiceCategory> _cats = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      _cats = await repo.fetchCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando categorías: $e')),
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
        title: const Text('Categorías'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          IconButton(
            tooltip: 'Nueva categoría',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _cats.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final c = _cats[i];
                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 18,
                        color: Colors.black.withOpacity(0.06),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: _CategoryIcon(category: c),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('ID: ${c.id}'),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _openEditor(category: c),
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmDelete(c),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _openEditor({ServiceCategory? category}) async {
    final repo = ref.read(supabaseRepoProvider);
    final picker = ImagePicker();

    final nameCtrl = TextEditingController(text: category?.name ?? '');
    String? iconPath = category?.icon; // aquí guardamos path dentro del bucket
    Uint8List? pickedBytes;
    String pickedExt = 'jpg';

    Future<void> pickImage() async {
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      pickedBytes = await file.readAsBytes();
      final n = file.name.toLowerCase();
      pickedExt = n.endsWith('.png') ? 'png' : 'jpg';

      if (mounted) setState(() {});
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                category == null ? 'Nueva categoría' : 'Editar categoría',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),

              Align(
                alignment: Alignment.centerLeft,
                child: Text('Icono (imagen)', style: Theme.of(ctx).textTheme.labelLarge),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: pickedBytes != null
                          ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                          : (iconPath != null && iconPath!.isNotEmpty)
                              ? Image.network(
                                  repo.categoryIconUrl(iconPath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_rounded),
                                )
                              : const Icon(Icons.category_rounded),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Cargar imagen'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('El nombre es obligatorio')),
                        );
                        return;
                      }

                      // Si el usuario eligió una imagen nueva, la subimos y guardamos path
                      if (pickedBytes != null) {
                        iconPath = await repo.uploadCategoryIcon(bytes: pickedBytes!, ext: pickedExt);
                      }

                      await repo.adminUpsertCategory(
                        id: category?.id,
                        name: name,
                        icon: iconPath,
                      );

                      if (mounted) Navigator.pop(ctx);
                      await _load();
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error guardando: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(ServiceCategory c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Seguro que deseas eliminar "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.adminDeleteCategory(c.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error eliminando: $e')),
        );
      }
    }
  }
}

class _CategoryIcon extends ConsumerWidget {
  const _CategoryIcon({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supabaseRepoProvider);
    final icon = category.icon;

    // Si no hay icon
    if (icon == null || icon.trim().isEmpty) {
      return const CircleAvatar(child: Icon(Icons.category_rounded));
    }

    // Si parece ser path de storage (contiene '/')
    if (icon.contains('/')) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.network(
            repo.categoryIconUrl(icon),
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_rounded),
          ),
        ),
      );
    }

    // Si es emoji/texto
    return CircleAvatar(
      child: Text(icon, style: const TextStyle(fontSize: 18)),
    );
  }
}
