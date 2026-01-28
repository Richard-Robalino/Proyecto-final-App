// lib/src/data/models/models.dart
class ServiceCategory {
  final int id;
  final String name;
  final String icon;

  const ServiceCategory({required this.id, required this.name, required this.icon});

  factory ServiceCategory.fromMap(Map<String, dynamic> m) => ServiceCategory(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '').toString(),
        icon: (m['icon'] ?? '').toString(),
      );
}

class TechnicianSummary {
  TechnicianSummary({
    required this.technicianId,
    required this.fullName,
    required this.avatarPath,
    required this.bio,
    required this.baseRate,
    required this.coverageRadiusKm,
    required this.verificationStatus,
    required this.verifiedAt,
    required this.avgRating,
    required this.totalReviews,
    required this.completedJobs,
    required this.lat,
    required this.lng,
    required this.distanceKm,
  });

  final String technicianId;
  final String fullName;
  final String? avatarPath;
  final String? bio;

  final double baseRate;
  final double coverageRadiusKm;

  final String verificationStatus; // pending|verified|rejected
  final DateTime? verifiedAt;

  final double avgRating;
  final int totalReviews;
  final int completedJobs;

  final double lat;
  final double lng;
  final double distanceKm;

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0; // ✅ numeric -> String
    return 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0; // ✅ numeric/int -> String
    return 0;
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  factory TechnicianSummary.fromMap(Map<String, dynamic> m) {
    return TechnicianSummary(
      technicianId: (m['technician_id'] ?? m['id']).toString(),
      fullName: (m['full_name'] ?? '').toString(),
      avatarPath: m['avatar_path']?.toString(),
      bio: m['bio']?.toString(),
      baseRate: _toDouble(m['base_rate']),
      coverageRadiusKm: _toDouble(m['coverage_radius_km']),
      verificationStatus: (m['verification_status'] ?? 'pending').toString(),
      verifiedAt: _toDate(m['verified_at']),
      avgRating: _toDouble(m['avg_rating']),
      totalReviews: _toInt(m['total_reviews']),
      completedJobs: _toInt(m['completed_jobs']),
      lat: _toDouble(m['lat']),
      lng: _toDouble(m['lng']),
      distanceKm: _toDouble(m['distance_km']),
    );
  }
  
}


class ServiceRequest {
  final String id;
  final String clientId;
  final int categoryId;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final String status;
  final String? acceptedQuoteId;
  final String? address; // ✅ NUEVO
  final DateTime createdAt;
// ✅ AGREGA ESTE CAMPO en ServiceRequest


  const ServiceRequest({
    required this.id,
    required this.clientId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    required this.status,
    required this.acceptedQuoteId,
    required this.address,
  
    required this.createdAt,
  });

  factory ServiceRequest.fromMap(Map<String, dynamic> m) => ServiceRequest(
        id: (m['id'] ?? '').toString(),
        clientId: (m['client_id'] ?? '').toString(),
        categoryId: (m['category_id'] as num).toInt(),
        title: (m['title'] ?? '').toString(),
        description: (m['description'] ?? '').toString(),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        status: (m['status'] ?? '').toString(),
        acceptedQuoteId: m['accepted_quote_id']?.toString(),
        address: m['address']?.toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

class Quote {
  final String id;
  final String requestId;
  final String technicianId;
  final num price;
  final int estimatedMinutes;
  final String? message;
  final String status;
  final DateTime createdAt;

  const Quote({
    required this.id,
    required this.requestId,
    required this.technicianId,
    required this.price,
    required this.estimatedMinutes,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory Quote.fromMap(Map<String, dynamic> m) => Quote(
        id: (m['id'] ?? '').toString(),
        requestId: (m['request_id'] ?? '').toString(),
        technicianId: (m['technician_id'] ?? '').toString(),
        price: (m['price'] ?? 0) as num,
        estimatedMinutes: (m['estimated_minutes'] ?? 0 as num).toInt(),
        message: m['message']?.toString(),
        status: (m['status'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

class RequestEvent {
  final String id;
  final String requestId;
  final String status;
  final String? note;
  final DateTime createdAt;

  const RequestEvent({
    required this.id,
    required this.requestId,
    required this.status,
    required this.note,
    required this.createdAt,
  });

  factory RequestEvent.fromMap(Map<String, dynamic> m) => RequestEvent(
        id: (m['id'] ?? '').toString(),
        requestId: (m['request_id'] ?? '').toString(),
        status: (m['status'] ?? '').toString(),
        note: m['note']?.toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

// ✅ NUEVO: Fotos de solicitud
class RequestPhoto {
  final String id;
  final String requestId;
  final String path;
  final DateTime createdAt;

  const RequestPhoto({
    required this.id,
    required this.requestId,
    required this.path,
    required this.createdAt,
  });

  factory RequestPhoto.fromMap(Map<String, dynamic> m) => RequestPhoto(
        id: (m['id'] ?? '').toString(),
        requestId: (m['request_id'] ?? '').toString(),
        path: (m['path'] ?? '').toString(),
        createdAt: DateTime.parse(m['created_at'].toString()),
      );
}

class AiDiagnoseResult {
  final String urgency; // low|medium|high
  final String summary;
  final List<String> questions;
  final List<String> safetyWarnings;
  final Map<String, dynamic> raw;
  final int? suggestedCategoryId;
  final String? suggestedCategoryName;

  const AiDiagnoseResult({
    required this.urgency,
    required this.summary,
    required this.questions,
    required this.safetyWarnings,
    required this.raw,
    required this.suggestedCategoryId,
    required this.suggestedCategoryName,
  });

  factory AiDiagnoseResult.fromMap(Map<String, dynamic> m) => AiDiagnoseResult(
        urgency: (m['urgency'] as String?) ?? 'medium',
        summary: (m['summary'] as String?) ?? '',
        questions: ((m['questions'] as List?) ?? []).map((e) => e.toString()).toList(),
        safetyWarnings: ((m['safety_warnings'] as List?) ?? []).map((e) => e.toString()).toList(),
        raw: m,
        suggestedCategoryId: (m['category_suggested'] is Map)
            ? ((m['category_suggested']['id'] as num?)?.toInt())
            : null,
        suggestedCategoryName: (m['category_suggested'] is Map)
            ? (m['category_suggested']['name'] as String?)
            : null,
      );
}
