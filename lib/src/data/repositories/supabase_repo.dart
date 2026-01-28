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

    final canDelete = (st == 'requested' || st == 'quoted') && (req.acceptedQuoteId == null);
    if (!canDelete) {
      throw Exception('No se puede eliminar: el servicio ya fue iniciado o ya tiene cotización aceptada.');
    }

    // borra fotos + storage
    final photos = await fetchRequestPhotos(requestId);
    for (final p in photos) {
      await deleteRequestPhoto(photoId: p.id, bucket: requestPhotosBucket, path: p.path);
    }

    // borra solicitud (request_photos debería tener FK cascade o ya quedó limpio)
    await supabase.from('service_requests').delete().eq('id', requestId).eq('client_id', userId);
  }

  // =========================
  // REQUEST PHOTOS
  // =========================
  Future<void> addRequestPhoto({
    required String requestId,
    required String path,
  }) async {
    await supabase.from('request_photos').insert({'request_id': requestId, 'path': path});
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
    // =========================
  // ADMIN DASHBOARD COUNTS (COMPATIBLE)
  // =========================
  Future<int> adminCountRequestsByStatus(String status) async {
    final res = await supabase
        .from('service_requests')
        .select('id')
        .eq('status', status);

    return (res as List).length;
  }

  Future<int> adminCountPendingTechVerifications() async {
    // Ajusta el filtro según tu tabla real:
    // - status = 'pending'  ó
    // - verified = false
    final res = await supabase
        .from('technician_certifications')
        .select('id')
        .or('status.eq.pending,verified.eq.false');

    return (res as List).length;
  }

    // =========================
  // TECH PUBLIC PROFILE / REVIEWS / PORTFOLIO
  // =========================
  Future<Map<String, dynamic>> fetchTechnicianPublicProfile(String techId) async {
    final p = await supabase
        .from('profiles')
        .select('id, full_name, avatar_path')
        .eq('id', techId)
        .single();

    final tp = await supabase
        .from('technician_profiles')
        .select('bio, base_rate, coverage_radius_km, verification_status, verified_at')
        .eq('id', techId)
        .maybeSingle();

    final metrics = await supabase
        .from('technician_metrics')
        .select('avg_rating, total_reviews, completed_jobs')
        .eq('technician_id', techId)
        .maybeSingle();

    return {
      ...(p as Map).cast<String, dynamic>(),
      ...((tp as Map?)?.cast<String, dynamic>() ?? {}),
      ...((metrics as Map?)?.cast<String, dynamic>() ?? {}),
    };
  }

  Future<List<ServiceCategory>> fetchTechnicianSpecialties(String techId) async {
    final res = await supabase
        .from('technician_specialties')
        .select('category:service_categories(id, name, icon)')
        .eq('technician_id', techId);

    final list = (res as List).cast<Map<String, dynamic>>();
    return list
        .map((row) => (row['category'] as Map).cast<String, dynamic>())
        .map(ServiceCategory.fromMap)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchTechnicianReviews(String techId) async {
    final res = await supabase
        .from('reviews')
        .select('id, rating, comment, created_at, reviewer:profiles!reviews_reviewer_id_fkey(id, full_name, avatar_path)')
        .eq('reviewee_id', techId)
        .order('created_at', ascending: false);

    return (res as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchTechnicianPortfolio(String techId) async {
    final res = await supabase
        .from('portfolio_items')
        .select('id, title, description, created_at, photos:portfolio_photos(id, path, created_at)')
        .eq('technician_id', techId)
        .order('created_at', ascending: false);

    return (res as List).cast<Map<String, dynamic>>();
  }



  // =========================
  // ADMIN CATEGORIES CRUD
  // =========================
  Future<void> adminUpsertCategory({
    int? id,
    required String name,
    String? icon, // aquí guardaremos el path de storage o emoji si quieres
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'icon': icon,
    };

    if (id == null) {
      await supabase.from('service_categories').insert(data);
    } else {
      await supabase.from('service_categories').update(data).eq('id', id);
    }
  }

  Future<void> adminDeleteCategory(int id) async {
    await supabase.from('service_categories').delete().eq('id', id);
  }

  Future<String> uploadCategoryIcon({
    required Uint8List bytes,
    required String ext, // "png" o "jpg"
  }) async {
    final safeExt = ext.toLowerCase().replaceAll('.', '');
    final fileName = 'cat_${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    final path = 'icons/$fileName';

    final contentType = safeExt == 'png' ? 'image/png' : 'image/jpeg';

    // sube al bucket category_icons
    await supabase.storage.from('category_icons').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    // guardamos SOLO el path dentro del bucket
    return path;
  }

  String categoryIconUrl(String path) {
    return supabase.storage.from('category_icons').getPublicUrl(path);
  }

  // =========================
  // IA DIAGNOSE (NO CAMBIO AQUÍ)
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
        'summary':
            'No hay sesión activa. Inicia sesión para usar la IA.',
        'confidence': 0.4,
        'actions': ['Inicia sesión', 'Vuelve a intentar'],
      });
    }

    final payload = {
      'title': title,
      'description': description,
      'categories': categories.map((c) => {'id': c.id, 'name': c.name}).toList(),
      'locale': 'es',
    };

    final res = await supabase.functions.invoke('ai_diagnose', body: payload);
    final data = (res.data as Map).cast<String, dynamic>();
    return AiDiagnoseResult.fromMap(data);
  }
}
