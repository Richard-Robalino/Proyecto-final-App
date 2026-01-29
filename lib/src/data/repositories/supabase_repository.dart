import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class SupabaseRepo {
  SupabaseRepo(this.supabase);

  final SupabaseClient supabase;

  String get userId => supabase.auth.currentUser!.id;

  static const String requestPhotosBucket = 'requests';

  // =========================
  // ADMIN DASHBOARD COUNTS
  // =========================
  Future<int> adminCountRequestsByStatus(String status) async {
    try {
      final response = await supabase.rpc(
        'admin_count_requests_by_status',
        params: {'p_status': status},
      );
      return response as int;
    } catch (e) {
      throw Exception('Error contando solicitudes: $e');
    }
  }

  Future<int> adminCountPendingTechVerifications() async {
    try {
      final response = await supabase.rpc('admin_count_pending_verifications');
      return response as int;
    } catch (e) {
      throw Exception('Error contando verificaciones: $e');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetRequestsByStatus(String status) async {
    try {
      final response = await supabase.rpc(
        'admin_get_requests_by_status',
        params: {'p_status': status},
      ) as List;
      
      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      throw Exception('Error obteniendo solicitudes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetPendingTechVerifications() async {
    try {
      final response = await supabase.rpc('admin_get_pending_verifications') as List;
      
      return response.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      throw Exception('Error obteniendo verificaciones: $e');
    }
  }

  Future<void> adminVerifyTechnician(String userId, bool approve) async {
    try {
      await supabase.rpc(
        'admin_verify_technician',
        params: {
          'p_user_id': userId,
          'p_approve': approve,
        },
      );
    } catch (e) {
      throw Exception('Error verificando técnico: $e');
    }
  }
}