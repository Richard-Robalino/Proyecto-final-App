import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart';

class SupabaseRepo {
  SupabaseRepo(this.supabase);

  final SupabaseClient supabase;

  String get userId => supabase.auth.currentUser!.id;

  // Cambia si tu bucket se llama diferente:
  static const String requestPhotosBucket = 'requests';

  // =========================
  // CATEGORIES
  // =========================
  Future<List<ServiceCategory>> fetchCategories() async {
    final res = await supabase
        .from('service_categories')
        .select('id, name, icon')
        .order('name');
    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(ServiceCategory.fromMap).toList();
  }

  // =========================
  // NEARBY TECHS / REQUESTS
  // =========================
  Future<List<TechnicianSummary>> getNearbyTechnicians({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int? categoryId,
  }) async {
    final res = await supabase.rpc('get_nearby_technicians', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
      'p_category_id': categoryId,
    });

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(TechnicianSummary.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getNearbyRequests({
    required double lat,
    required double lng,
    double radiusKm = 10,
    int? categoryId,
  }) async {
    final res = await supabase.rpc('get_nearby_requests', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_km': radiusKm,
      'p_category_id': categoryId,
    });

    return (res as List).cast<Map<String, dynamic>>();
  }

  // =========================
  // REQUESTS
  // =========================
  Future<ServiceRequest> fetchRequestById(String requestId) async {
    final res = await supabase
        .from('service_requests')
        .select(
          'id, client_id, category_id, title, description, address, lat, lng, status, accepted_quote_id, created_at',
        )
        .eq('id', requestId)
        .single();

    return ServiceRequest.fromMap((res as Map).cast<String, dynamic>());
  }

// En lib/src/data/repositories/supabase_repo.dart

  Future<bool> hasReviewed(String requestId) async {
    final count = await supabase
        .from('reviews')
        .count(CountOption.exact)
        .eq('request_id', requestId)
        .eq('reviewer_id', userId);

    return count > 0;
  }

  Stream<List<ServiceRequest>> streamMyRequests() {
    return supabase
        .from('service_requests')
        .stream(primaryKey: ['id']) // Escucha cambios en esta tabla
        .eq('client_id', userId) // Solo mis solicitudes
        .map((data) {
          // Convertimos los datos crudos a objetos
          final requests = data.map((e) => ServiceRequest.fromMap(e)).toList();
          // Ordenamos por fecha (las más nuevas arriba), ya que stream no siempre garantiza orden
          requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return requests;
        });
  }

  Future<List<ServiceRequest>> fetchMyRequests() async {
    final res = await supabase
        .from('service_requests')
        .select(
          'id, client_id, category_id, title, description, address, lat, lng, status, accepted_quote_id, created_at',
        )
        .order('created_at', ascending: false);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(ServiceRequest.fromMap).toList();
  }

  Future<List<ServiceRequest>> fetchMyJobsAsTechnician() async {
    final quotesRes = await supabase
        .from('quotes')
        .select('id')
        .eq('technician_id', userId)
        .eq('status', 'accepted');

    final qList = (quotesRes as List).cast<Map<String, dynamic>>();
    final ids = qList.map((e) => e['id'] as String).toList();
    if (ids.isEmpty) return [];

    final reqRes = await supabase
        .from('service_requests')
        .select(
          'id, client_id, category_id, title, description, address, lat, lng, status, accepted_quote_id, created_at',
        )
        .inFilter('accepted_quote_id', ids)
        .order('created_at', ascending: false);

    final list = (reqRes as List).cast<Map<String, dynamic>>();
    return list.map(ServiceRequest.fromMap).toList();
  }

  Future<String> createRequest({
    required int categoryId,
    required String title,
    required String description,
    required double lat,
    required double lng,
    String? address,
    Map<String, dynamic>? aiSummary,
  }) async {
    final res = await supabase
        .from('service_requests')
        .insert({
          'client_id': userId,
          'category_id': categoryId,
          'title': title,
          'description': description,
          'lat': lat,
          'lng': lng,
          'address': address,
          'ai_summary': aiSummary,
        })
        .select('id')
        .single();

    return (res['id'] as String);
  }

  Future<void> updateRequest({
    required String requestId,
    required int categoryId,
    required String title,
    required String description,
    required double lat,
    required double lng,
    String? address,
  }) async {
    await supabase
        .from('service_requests')
        .update({
          'category_id': categoryId,
          'title': title,
          'description': description,
          'lat': lat,
          'lng': lng,
          'address': address,
        })
        .eq('id', requestId)
        .eq('client_id', userId);
  }

  Future<void> deleteRequest(String requestId) async {
    // Condición: solo si NO está iniciado
    final req = await fetchRequestById(requestId);
    final st = (req.status).toString();

    final canDelete =
        (st == 'requested' || st == 'quoted') && (req.acceptedQuoteId == null);
    if (!canDelete) {
      throw Exception(
          'No se puede eliminar: el servicio ya fue iniciado o ya tiene cotización aceptada.');
    }

    // borra fotos + storage
    final photos = await fetchRequestPhotos(requestId);
    for (final p in photos) {
      await deleteRequestPhoto(
          photoId: p.id, bucket: requestPhotosBucket, path: p.path);
    }

    // borra solicitud (request_photos debería tener FK cascade o ya quedó limpio)
    await supabase
        .from('service_requests')
        .delete()
        .eq('id', requestId)
        .eq('client_id', userId);
  }

  // =========================
  // REQUEST PHOTOS
  // =========================
  Future<void> addRequestPhoto({
    required String requestId,
    required String path,
  }) async {
    await supabase
        .from('request_photos')
        .insert({'request_id': requestId, 'path': path});
  }

  Future<List<RequestPhoto>> fetchRequestPhotos(String requestId) async {
    final res = await supabase
        .from('request_photos')
        .select('id, request_id, path, created_at')
        .eq('request_id', requestId)
        .order('created_at', ascending: true);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list.map(RequestPhoto.fromMap).toList();
  }

  Future<void> deleteRequestPhoto({
    required String photoId,
    required String bucket,
    required String path,
  }) async {
    // 1) storage remove (no revienta si falla)
    try {
      await supabase.storage.from(bucket).remove([path]);
    } catch (_) {}

    // 2) row delete
    await supabase.from('request_photos').delete().eq('id', photoId);
  }

  // =========================
  // STORAGE
  // =========================
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return path;
  }

  String publicUrl(String bucket, String path) {
    return supabase.storage.from(bucket).getPublicUrl(path);
  }

  // =========================
  // QUOTES
  // =========================
  Stream<List<Quote>> streamQuotes(String requestId) {
    return supabase
        .from('quotes')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((rows) => rows.map((m) => Quote.fromMap(m)).toList());
  }

  Future<void> sendQuote({
    required String requestId,
    required num price,
    required int estimatedMinutes,
    String? message,
  }) async {
    await supabase.from('quotes').insert({
      'request_id': requestId,
      'technician_id': userId,
      'price': price,
      'estimated_minutes': estimatedMinutes,
      'message': message,
    });
  }

  Future<void> acceptQuote(String quoteId) async {
    await supabase.rpc('accept_quote', params: {'p_quote_id': quoteId});
  }

  // =========================
  // EVENTS / STATUS
  // =========================
  Stream<List<RequestEvent>> streamRequestEvents(String requestId) {
    return supabase
        .from('request_events')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((rows) => rows.map((m) => RequestEvent.fromMap(m)).toList());
  }

  Future<void> setRequestStatus({
    required String requestId,
    required String newStatus,
    String? note,
  }) async {
    await supabase.rpc('set_request_status', params: {
      'p_request_id': requestId,
      'p_new_status': newStatus,
      'p_note': note,
    });
  }

  Future<void> upsertTechnicianLocation({
    required double lat,
    required double lng,
  }) async {
    await supabase.from('technician_locations').upsert({
      'technician_id': userId,
      'lat': lat,
      'lng': lng,
    });
  }

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



  Future<List<Map<String, dynamic>>> getReviewsByRequestId(String requestId) async {
    try {
      final res = await supabase
          .from('reviews')
          .select('''
            *,
            reviewer:profiles!reviewer_id(full_name, role, avatar_path)
          ''')
          .eq('request_id', requestId);
      
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
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

  Future<List<Map<String, dynamic>>> adminGetRequestsByStatus(
      String status) async {
    try {
      // 1. TRADUCCIÓN: UI -> Base de Datos
      // Si en tu UI usas "En Progreso", aquí lo convertimos a "in_progress"
      String dbStatus = status;
      switch (status) {
        case 'Solicitadas':
          dbStatus = 'requested';
          break;
        case 'Aceptadas':
          dbStatus = 'accepted';
          break;
        case 'En Progreso':
          dbStatus = 'in_progress';
          break;
        case 'Completadas':
          dbStatus = 'completed';
          break;
        // Si ya viene en inglés o minúsculas, lo dejamos igual
        default:
          dbStatus = status.toLowerCase();
      }

      print('🔍 Consultando DB con estado: $dbStatus');

      final response = await supabase.rpc(
        'admin_get_requests_by_status',
        params: {'p_status': dbStatus},
      );

      // 2. BLINDAJE: Verificamos si es lista, nulo o mapa
      if (response == null) return [];

      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else {
        print('⚠️ Formato inesperado en adminGetRequestsByStatus: $response');
        return [];
      }
    } catch (e) {
      print('❌ ERROR en adminGetRequestsByStatus: $e');
      return []; // Retornamos lista vacía en vez de explotar
    }
  }

  Future<List<Map<String, dynamic>>> adminGetPendingTechVerifications() async {
    try {
      final response = await supabase.rpc('admin_get_pending_verifications');

      if (response == null) return [];

      // Si es una lista normal, perfecto
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }

      // Si no es lista, retornamos vacío (ya no intentamos convertir Map)
      print('⚠️ Formato desconocido en Verificaciones: $response');
      return [];
    } catch (e) {
      print('❌ Error obteniendo verificaciones: $e');
      return [];
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

  // =========================
  // ADMIN CATEGORIES
  // =========================
  Future<String> uploadCategoryIcon({required Uint8List bytes, required String ext}) async {
    final filename = 'cat_${DateTime.now().millisecondsSinceEpoch}.$ext';
    
    // CORRECCIÓN 1: Como ya vamos a entrar al bucket 'categories', 
    // no hace falta poner la carpeta 'categories/' en el nombre del archivo.
    // Solo usamos el nombre del archivo.
    final path = filename; 

    // CORRECCIÓN 2: Cambiamos 'public' por 'categories' (el nombre real de tu bucket)
    await supabase.storage.from('categories').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
        );

    return path;
  }

  String categoryIconUrl(String path) {
    // Si por alguna razón el path ya es una URL completa, la devolvemos
    if (path.startsWith('http')) return path;

    // CORRECCIÓN 3: Leemos del bucket 'categories', no de 'public'
    return supabase.storage.from('categories').getPublicUrl(path);
  }

  Future<void> adminUpsertCategory({
    int? id,
    required String name,
    String? icon,
  }) async {
    if (id == null) {
      // Insert
      await supabase.from('service_categories').insert({
        'name': name,
        'icon': icon,
      });
    } else {
      // Update
      await supabase.from('service_categories').update({
        'name': name,
        'icon': icon,
      }).eq('id', id);
    }
  }


  Future<String> getCurrentTechnicianStatus() async {
    try {
      final res = await supabase
          .from('technician_profiles')
          .select('verification_status')
          .eq('id', userId)
          .maybeSingle();
      
      if (res == null) return 'pending'; // Si no existe perfil, asumimos pendiente
      return res['verification_status'] as String;
    } catch (e) {
      print('Error fetching tech status: $e');
      return 'pending'; // Ante cualquier error, bloqueamos por seguridad
    }
  }
  Future<void> adminDeleteCategory(int id) async {
    await supabase.from('service_categories').delete().eq('id', id);
  }

  // =========================
  // TECHNICIAN PROFILE (PUBLIC)
  // =========================
  Future<Map<String, dynamic>?> fetchTechnicianPublicProfile(
      String techId) async {
    final res = await supabase.from('profiles').select('''
          id, full_name, avatar_path,
          technician_profiles!inner(bio, base_rate, coverage_radius_km)
        ''').eq('id', techId).eq('role', 'technician').maybeSingle();

    if (res == null) return null;

    final profile = Map<String, dynamic>.from(res);
    final techData = profile['technician_profiles'] as Map?;

    if (techData != null) {
      profile['bio'] = techData['bio'];
      profile['base_rate'] = techData['base_rate'];
      profile['coverage_radius_km'] = techData['coverage_radius_km'];
    }

    profile.remove('technician_profiles');

    // Obtener métricas
    final metrics = await supabase
        .from('technician_metrics')
        .select('avg_rating, total_reviews, completed_jobs')
        .eq('technician_id', techId)
        .maybeSingle();

    if (metrics != null) {
      profile['avg_rating'] = metrics['avg_rating'] ?? 0;
      profile['total_reviews'] = metrics['total_reviews'] ?? 0;
      profile['completed_jobs'] = metrics['completed_jobs'] ?? 0;
    }

    return profile;
  }

  Future<List<ServiceCategory>> fetchTechnicianSpecialties(
      String techId) async {
    final res = await supabase
        .from('technician_specialties')
        .select('service_categories!inner(id, name, icon)')
        .eq('technician_id', techId);

    return (res as List).map((item) {
      final cat = item['service_categories'];
      return ServiceCategory.fromMap(Map<String, dynamic>.from(cat));
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchTechnicianReviews(
      String techId) async {
    try {
      final res = await supabase.from('reviews').select('''
            id, rating, comment, created_at,
            reviewer:profiles!reviews_reviewer_id_fkey(full_name, avatar_path)
          ''').eq('reviewee_id', techId).order('created_at', ascending: false);

      if (res == null) return [];

      // Seguridad extra por si Supabase cambia el tipo de retorno
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
      return [];
    } catch (e) {
      print('Error en fetchTechnicianReviews: $e');
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> getAdminUsers(String roleFilter) async {
    try {
      // Usamos la vista que creamos en SQL
      var query = supabase.from('admin_users_view').select();

      if (roleFilter == 'technician') {
        query = query.eq('role', 'technician');
      } else if (roleFilter == 'client') {
        query = query.eq('role', 'client');
      }

      final response = await query;

      if (response == null) return [];
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      }
      
      return [];
    } catch (e) {
      print('❌ Error cargando usuarios ($roleFilter): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTechnicianPortfolio(
      String techId) async {
    final res = await supabase.from('portfolio_items').select('''
          id, title, description, created_at,
          portfolio_photos(id, path)
        ''').eq('technician_id', techId).order('created_at', ascending: false);

    return (res as List).map((item) {
      final portfolio = Map<String, dynamic>.from(item);
      portfolio['photos'] = portfolio['portfolio_photos'] ?? [];
      portfolio.remove('portfolio_photos');
      return portfolio;
    }).toList();
  }

  // En SupabaseRepo...

  Future<void> adminToggleUserStatus(String userId, bool isActive) async {
    try {
      await supabase.from('profiles').update({
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      throw Exception('Error actualizando estado del usuario: $e');
    }
  }

  // =========================
  // IA DIAGNOSE
  // =========================
  Future<AiDiagnoseResult> aiDiagnose({
    required String title,
    required String description,
    required List<ServiceCategory> categories,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return AiDiagnoseResult.fromMap({
        'ok': true,
        'summary': 'No hay sesión activa. Inicia sesión para usar la IA.',
        'confidence': 0.4,
        'actions': ['Inicia sesión', 'Vuelve a intentar'],
      });
    }

    final payload = {
      'title': title,
      'description': description,
      'categories':
          categories.map((c) => {'id': c.id, 'name': c.name}).toList(),
      'locale': 'es',
    };

    final res = await supabase.functions.invoke('ai_diagnose', body: payload);
    final data = (res.data as Map).cast<String, dynamic>();
    return AiDiagnoseResult.fromMap(data);
  }
}

