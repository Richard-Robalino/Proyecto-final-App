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
    // Solo mostramos loading full screen si la lista está vacía
    if (_cats.isEmpty) setState(() => _loading = true);
    
    try {
      final repo = ref.read(supabaseRepoProvider);
      final newCats = await repo.fetchCategories();
      if (mounted) {
        setState(() {
          _cats = newCats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showSnackBar('Error cargando categorías: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? cs.error : cs.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface, // Fondo limpio
      appBar: AppBar(
        title: const Text('Gestión de Categorías'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva Categoría'),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: cs.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: cs.primary,
              child: _cats.isEmpty
                  ? _EmptyState(onRetry: _load)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // Espacio para el FAB
                      itemCount: _cats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final c = _cats[i];
                        // Usamos el widget de animación personalizado incluido abajo
                        return _SlideInItem(
                          delay: i * 50, // Efecto cascada
                          child: _CategoryCard(
                            category: c,
                            onEdit: () => _openEditor(category: c),
                            onDelete: () => _confirmDelete(c),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Future<void> _openEditor({ServiceCategory? category}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryEditorSheet(
        category: category,
        onSave: (name, bytes, ext) async {
          await _handleSave(category, name, bytes, ext);
        },
      ),
    );
  }

  Future<void> _handleSave(
      ServiceCategory? originalCat, String name, Uint8List? bytes, String ext) async {
    try {
      final repo = ref.read(supabaseRepoProvider);
      String? iconPath = originalCat?.icon;

      // Si hay nueva imagen, subirla
      if (bytes != null) {
        iconPath = await repo.uploadCategoryIcon(bytes: bytes, ext: ext);
      }

      await repo.adminUpsertCategory(
        id: originalCat?.id,
        name: name,
        icon: iconPath,
      );

      if (mounted) Navigator.pop(context); // Cerrar sheet
      _showSnackBar(originalCat == null ? 'Categoría creada' : 'Categoría actualizada');
      _load(); // Recargar lista
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error guardando: $e', isError: true);
      }
    }
  }

  Future<void> _confirmDelete(ServiceCategory c) async {
    final cs = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar categoría?'),
        content: Text('Se eliminará permanentemente "${c.name}".'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: cs.onSurface.withOpacity(0.6))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.adminDeleteCategory(c.id);
      _showSnackBar('Categoría eliminada');
      _load();
    } catch (e) {
      if (mounted) _showSnackBar('Error: $e', isError: true);
    }
  }
}

// --- WIDGETS AUXILIARES ---

class _CategoryCard extends StatelessWidget {
  final ServiceCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryCard({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Hero(
            tag: 'cat_${category.id}',
            child: _CategoryIcon(category: category, size: 50),
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Text(
            'ID: ${category.id}',
            style: TextStyle(color: cs.onSurface.withOpacity(0.4), fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.blueGrey),
                onPressed: onEdit,
                tooltip: 'Editar',
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: cs.error.withOpacity(0.8)),
                onPressed: onDelete,
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends ConsumerWidget {
  const _CategoryIcon({required this.category, this.size = 40});

  final ServiceCategory category;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(supabaseRepoProvider);
    final icon = category.icon;
    final cs = Theme.of(context).colorScheme;

    Widget child;

    // Caso 1: No hay icono -> Icono por defecto
    if (icon == null || icon.trim().isEmpty) {
      child = Icon(Icons.category_rounded, color: cs.primary, size: size * 0.6);
    } 
    // Caso 2: Es un archivo subido (empieza con "cat_") O es una URL completa (http)
    // También aceptamos si contiene "/" por compatibilidad con iconos viejos
    else if (icon.startsWith('cat_') || icon.startsWith('http') || icon.contains('/')) {
      
      // Obtenemos la URL pública correcta
      // Si ya es http, la usamos tal cual. Si no, pedimos la URL al repo.
      final imageUrl = icon.startsWith('http') ? icon : repo.categoryIconUrl(icon);

      child = Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          // Si falla la carga, mostramos icono roto pero sutil
          return Center(
            child: Icon(Icons.broken_image_rounded, size: size * 0.5, color: Colors.grey),
          );
        },
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Center(
             child: SizedBox(
               width: size * 0.4, 
               height: size * 0.4, 
               child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary.withOpacity(0.3))
             )
          );
        },
      );
    } 
    // Caso 3: Es un nombre de icono de Material (ej: "bolt", "lock")
    else {
      // Intentamos mapear nombres comunes a iconos reales, o mostramos texto
      IconData? iconData;
      switch(icon) {
        case 'bolt': iconData = Icons.bolt; break;
        case 'lock': iconData = Icons.lock; break;
        case 'plumbing': iconData = Icons.plumbing; break;
        case 'construction': iconData = Icons.construction; break;
        case 'ac_unit': iconData = Icons.ac_unit; break;
        case 'home_repair_service': iconData = Icons.home_repair_service; break;
      }
      
      if (iconData != null) {
        child = Icon(iconData, color: cs.primary, size: size * 0.6);
      } else {
        // Si no es un icono conocido, mostramos las primeras letras
        child = Text(
          icon.substring(0, icon.length > 3 ? 3 : icon.length).toUpperCase(), 
          style: TextStyle(
            fontSize: size * 0.4, 
            fontWeight: FontWeight.bold,
            color: cs.primary
          )
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Center(child: child),
      ),
    );
  }
}

// --- EDITOR SHEET ---
class _CategoryEditorSheet extends StatefulWidget {
  final ServiceCategory? category;
  final Function(String name, Uint8List? bytes, String ext) onSave;

  const _CategoryEditorSheet({this.category, required this.onSave});

  @override
  State<_CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<_CategoryEditorSheet> {
  late TextEditingController _nameCtrl;
  final ImagePicker _picker = ImagePicker();
  
  Uint8List? _pickedBytes;
  String _pickedExt = 'jpg';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    
    setState(() {
      _pickedBytes = bytes;
      _pickedExt = name.endsWith('.png') ? 'png' : 'jpg';
    });
  }

  void _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isSaving = true);
    await widget.onSave(name, _pickedBytes, _pickedExt);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                widget.category == null ? 'Nueva Categoría' : 'Editar Categoría',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre de la categoría',
              prefixIcon: const Icon(Icons.label_outline_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: _pickedBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(_pickedBytes!, fit: BoxFit.cover),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_rounded, size: 40, color: cs.primary),
                        const SizedBox(height: 8),
                        Text('Subir Icono', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: _isSaving ? null : _submit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Guardar cambios', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('No hay categorías creadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Recargar'),
          )
        ],
      ),
    );
  }
}

// --- ANIMACIÓN PERSONALIZADA (SIN PAQUETES EXTRA) ---
class _SlideInItem extends StatefulWidget {
  final Widget child;
  final int delay;
  const _SlideInItem({required this.child, required this.delay});

  @override
  State<_SlideInItem> createState() => _SlideInItemState();
}

class _SlideInItemState extends State<_SlideInItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 600)
    );

    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    // FIX: Using a Tween ensures the value stays strictly between 0.0 and 1.0
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _offsetAnim, child: widget.child),
    );
  }
}