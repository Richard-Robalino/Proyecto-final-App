import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final adminStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final sb = ref.read(supabaseProvider);

  Future<int> countEq(String status) async {
    final res = await sb.from('service_requests').select('id').eq('status', status);
    return (res as List).length;
  }

  final requested = await countEq('requested');
  final accepted = await countEq('accepted');
  final inProgress = await countEq('in_progress');
  final completed = await countEq('completed');

  final pendingTech = await sb
      .from('technician_profiles')
      .select('id')
      .eq('verification_status', 'pending');

  return {
    'requested': requested,
    'accepted': accepted,
    'in_progress': inProgress,
    'completed': completed,
    'pending_tech': (pendingTech as List).length,
  };
});

final pendingTechniciansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = ref.read(supabaseProvider);
  final data = await sb
      .from('technician_profiles')
      .select('id, bio, base_rate, coverage_radius_km, verification_status, profiles(full_name, avatar_path, role)')
      .eq('verification_status', 'pending')
      .order('updated_at', ascending: false);

  return (data as List).cast<Map<String, dynamic>>();
});

final serviceCategoriesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final sb = ref.read(supabaseProvider);
  final data = await sb.from('service_categories').select('id, name, icon, created_at').order('name');
  return (data as List).cast<Map<String, dynamic>>();
});
