import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_providers.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface, // Clean background
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: cs.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Técnicos'),
            Tab(text: 'Clientes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _UsersList(role: 'technician'),
          _UsersList(role: 'client'),
        ],
      ),
    );
  }
}

class _UsersList extends ConsumerWidget {
  final String role;
  const _UsersList({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersListProvider(role));

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off_rounded,
                    size: 60, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No hay usuarios registrados',
                    style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final user = users[index];
            return _UserCard(
              user: user,
              role: role,
              onToggleStatus: (isActive) =>
                  _confirmToggleStatus(context, ref, user['id'], isActive),
              onViewDetail: () {
                if (role == 'technician') {
                  context.push('/admin/verify/${user['id']}');
                } else {
                  _showClientDetail(context, user);
                }
              },
            );
          },
        );
      },
    );
  }

  void _showClientDetail(BuildContext context, Map<String, dynamic> user) {
    // Preparamos los datos con seguridad (para que no salga null)
    final name = (user['full_name'] as String? ?? '').isEmpty 
        ? 'Usuario Sin Nombre' 
        : user['full_name'];
    final email = user['email'] ?? 'No registrado';
    final phone = user['phone'] ?? 'No registrado';
    
    // Formateo simple de fecha
    String date = 'Desconocido';
    if (user['created_at'] != null) {
      try {
        date = user['created_at'].toString().substring(0, 10);
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que la hoja crezca si es necesario
      backgroundColor: Colors.white,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5, // Empieza a mitad de pantalla
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView( // <--- ESTO ARREGLA EL ERROR AMARILLO (OVERFLOW)
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. AVATAR GRANDE Y MODERNO
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blue.withOpacity(0.2), width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.blue.shade50,
                      child: Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 36, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.blue.shade700
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 2. NOMBRE Y ETIQUETA
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Cliente Verificado',
                      style: TextStyle(
                        color: Colors.blue.shade800, 
                        fontWeight: FontWeight.w600, 
                        fontSize: 12
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // 3. LISTA DE DETALLES (Usando una tarjeta suave)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        _ModernDetailRow(
                          icon: Icons.email_outlined, 
                          title: 'Correo Electrónico', 
                          value: email,
                          isFirst: true,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 24),
                        _ModernDetailRow(
                          icon: Icons.phone_outlined, 
                          title: 'Teléfono', 
                          value: phone,
                        ),
                        const Divider(height: 1, indent: 56, endIndent: 24),
                        _ModernDetailRow(
                          icon: Icons.calendar_today_outlined, 
                          title: 'Miembro desde', 
                          value: date,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // 4. BOTÓN DE ACCIÓN (Opcional)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmToggleStatus(
      BuildContext context, WidgetRef ref, String uid, bool newStatus) async {
    // Delay fix for popup menu closing
    await Future.delayed(Duration.zero);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(newStatus ? '¿Reactivar cuenta?' : '¿Suspender cuenta?'),
        content: Text(newStatus
            ? 'El usuario recuperará el acceso a la plataforma.'
            : 'El usuario no podrá iniciar sesión mientras esté suspendido.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(
                backgroundColor: newStatus ? Colors.green : Colors.red),
            child: Text(newStatus ? 'Reactivar' : 'Suspender'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(adminActionsProvider)
          .toggleUserActiveStatus(uid, newStatus);
    }
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String role;
  final Function(bool) onToggleStatus;
  final VoidCallback onViewDetail;

  const _UserCard({
    required this.user,
    required this.role,
    required this.onToggleStatus,
    required this.onViewDetail,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['is_active'] ?? true;

    // FIX: Manejar tanto Map (anidado) como null (clientes no tienen tech profile)
    final techProfileData = user['technician_profiles'];
    String? verificationStatus;

    if (techProfileData != null && techProfileData is Map) {
      verificationStatus = techProfileData['verification_status'] as String?;
    } else if (user['verification_status'] != null) {
      // Fallback: a veces viene directamente en el objeto
      verificationStatus = user['verification_status'] as String?;
    }

    final isVerified = verificationStatus == 'approved';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
        border:
            isActive ? null : Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onViewDetail,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar con indicador de estado
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: role == 'technician'
                          ? Colors.orange[50]
                          : Colors.blue[50],
                      child: Text(
                        () {
                          final name = user['full_name'] as String?;
                          // Si el nombre es nulo O está vacío, mostramos 'U'
                          if (name == null || name.isEmpty) return 'U';
                          // Si tiene nombre, mostramos la primera letra
                          return name[0].toUpperCase();
                        }(),
                        style: TextStyle(
                          color: role == 'technician'
                              ? Colors.orange[800]
                              : Colors.blue[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (role == 'technician' && isVerified)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.check_circle,
                              size: 16, color: Colors.blue),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['full_name'] ?? 'Usuario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          decoration:
                              isActive ? null : TextDecoration.lineThrough,
                          color: isActive ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '-',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Menú de Acciones
                PopupMenuButton(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400]),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      onTap: onViewDetail,
                      child: const Row(children: [
                        Icon(Icons.visibility_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Ver Detalle')
                      ]),
                    ),
                    PopupMenuItem(
                      onTap: () => onToggleStatus(!isActive),
                      child: Row(
                        children: [
                          Icon(
                              isActive
                                  ? Icons.block_rounded
                                  : Icons.check_circle_outline,
                              size: 20,
                              color: isActive ? Colors.red : Colors.green),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Suspender' : 'Activar',
                              style: TextStyle(
                                  color: isActive ? Colors.red : Colors.green)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isFirst;
  final bool isLast;

  const _ModernDetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.blue.shade700),
      ),
      title: Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
      ),
    );
  }
}