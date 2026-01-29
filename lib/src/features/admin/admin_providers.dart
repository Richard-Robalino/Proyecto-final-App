import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Proveedor base del cliente Supabase
final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// --- ADMIN STATS (CORREGIDO) ---
final adminStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final sb = ref.watch(supabaseProvider);

  // Función Helper corregida para Supabase v2
  Future<int> count(String table, {String? statusField, String? statusValue}) async {
    // 1. Usamos .count(CountOption.exact) directamente.
    // Esto crea una consulta 'HEAD' que solo devuelve el número (int), muy rápido.
    var query = sb.from(table).count(CountOption.exact);
    
    // 2. Aplicamos filtros si existen
    if (statusField != null && statusValue != null) {
      query = query.eq(statusField, statusValue);
    }
    
    // 3. Al hacer 'await', devuelve el int directamente.
    return await query;
  }

  // Ejecutamos las 5 consultas EN PARALELO
  final results = await Future.wait([
    count('service_requests', statusField: 'status', statusValue: 'requested'),
    count('service_requests', statusField: 'status', statusValue: 'accepted'),
    count('service_requests', statusField: 'status', statusValue: 'in_progress'),
    count('service_requests', statusField: 'status', statusValue: 'completed'),
    count('technician_profiles', statusField: 'verification_status', statusValue: 'pending'),
  ]);

  return {
    'requested': results[0],
    'accepted': results[1],
    'in_progress': results[2],
    'completed': results[3],
    'pending_tech': results[4],
  };
});

// --- TÉCNICOS PENDIENTES ---
final pendingTechniciansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  
  final data = await sb
      .from('technician_profiles')
      .select('id, bio, base_rate, coverage_radius_km, verification_status, profiles(full_name, avatar_path, role)')
      .eq('verification_status', 'pending')
      .order('updated_at', ascending: false);

  return List<Map<String, dynamic>>.from(data);
});

// --- CATEGORÍAS ---
final serviceCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = ref.watch(supabaseProvider);
  
  // Mantenemos viva la caché para evitar parpadeos al navegar
  final link = ref.keepAlive();
  
  final data = await sb
      .from('service_categories')
      .select('id, name, icon, created_at')
      .order('name');
      
  return List<Map<String, dynamic>>.from(data);
});

// ... (código existente) ...

// --- LISTA DE USUARIOS (Clientes o Técnicos) ---
final usersListProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, role) async {
  final sb = ref.watch(supabaseProvider);
  
  // 1. Usamos la vista SQL que creamos (admin_users_view)
  // Esta vista ya tiene los campos: full_name, email, phone, verification_status, etc.
  var query = sb
      .from('admin_users_view') 
      .select()
      .eq('role', role)
      .order('created_at', ascending: false);
  
  final data = await query;

  // 2. Blindaje simple: aseguramos que sea una lista
  return List<Map<String, dynamic>>.from(data);
});

// --- ACCIONES DE ADMIN ---
final adminActionsProvider = Provider((ref) => AdminActions(ref));

class AdminActions {
  final Ref ref;
  AdminActions(this.ref);

  Future<void> toggleUserActiveStatus(String userId, bool isActive) async {
    final sb = ref.read(supabaseProvider);
    // Asumimos que tienes una columna 'is_active' en profiles. Si no, créala en Supabase.
    await sb.from('profiles').update({'is_active': isActive}).eq('id', userId);
    
    // Invalidar caches para refrescar listas
    ref.invalidate(usersListProvider);
    ref.invalidate(pendingTechniciansProvider);
  }
}