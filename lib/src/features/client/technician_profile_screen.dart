import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class TechnicianProfileScreen extends ConsumerStatefulWidget {
  const TechnicianProfileScreen({super.key, required this.techId});
  final String techId;

  @override
  ConsumerState<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends ConsumerState<TechnicianProfileScreen> {
  bool _loading = true;

  Map<String, dynamic>? _profile; // merged
  List<ServiceCategory> _specialties = const [];
  List<Map<String, dynamic>> _reviews = const [];
  List<Map<String, dynamic>> _portfolio = const [];

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);

      final p = await repo.fetchTechnicianPublicProfile(widget.techId);
      final specs = await repo.fetchTechnicianSpecialties(widget.techId);
      final reviews = await repo.fetchTechnicianReviews(widget.techId);
      final portfolio = await repo.fetchTechnicianPortfolio(widget.techId);

      if (!mounted) return;
      setState(() {
        _profile = p;
        _specialties = specs;
        _reviews = reviews;
        _portfolio = portfolio;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cargando perfil: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = _profile;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil técnico')),
        body: const Center(child: Text('No se pudo cargar el perfil.')),
      );
    }

    final fullName = (p['full_name'] ?? '').toString();
    final avatarPath = p['avatar_path']?.toString();
    final bio = (p['bio'] ?? '').toString();
    final baseRate = _asDouble(p['base_rate']);
    final radius = _asDouble(p['coverage_radius_km']);
    final avgRating = _asDouble(p['avg_rating']);
    final totalReviews = _asInt(p['total_reviews']);
    final completedJobs = _asInt(p['completed_jobs']);

    final repo = ref.read(supabaseRepoProvider);
    final avatarUrl = (avatarPath == null || avatarPath.isEmpty)
        ? null
        : repo.publicUrl('avatars', avatarPath);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Perfil del técnico'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Info'),
              Tab(text: 'Reseñas'),
              Tab(text: 'Portafolio'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // ========= TAB INFO =========
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: cs.surfaceContainerHighest,
                      backgroundImage: avatarUrl == null ? null : CachedNetworkImageProvider(avatarUrl),
                      child: avatarUrl == null ? const Icon(Icons.person_rounded, size: 34) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18),
                              const SizedBox(width: 4),
                              Text(
                                totalReviews == 0 ? 'Sin reseñas' : '${avgRating.toStringAsFixed(1)} ($totalReviews)',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(width: 12),
                              const Icon(Icons.check_circle_outline_rounded, size: 18),
                              const SizedBox(width: 4),
                              Text('Trabajos: $completedJobs'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (bio.trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(bio),
                  ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tarifa base', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('\$${baseRate.toStringAsFixed(2)}'),
                      const SizedBox(height: 10),
                      Text('Cobertura', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text('${radius.toStringAsFixed(0)} km'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Text('Especialidades', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (_specialties.isEmpty)
                  Text('No registra especialidades.', style: Theme.of(context).textTheme.bodyMedium)
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specialties
                        .map((c) => Chip(
                              label: Text(c.name),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ))
                        .toList(),
                  ),
              ],
            ),

            // ========= TAB RESEÑAS =========
            _reviews.isEmpty
                ? const Center(child: Text('Aún no tiene reseñas.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final r = _reviews[i];
                      final reviewer = (r['reviewer'] as Map?)?.cast<String, dynamic>() ?? {};
                      final name = (reviewer['full_name'] ?? 'Usuario').toString();
                      final avatar = reviewer['avatar_path']?.toString();

                      final rating = _asDouble(r['rating']);
                      final comment = (r['comment'] ?? '').toString();

                      final avatarUrl2 = (avatar == null || avatar.isEmpty)
                          ? null
                          : repo.publicUrl('avatars', avatar);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: cs.surfaceContainerHighest,
                              backgroundImage: avatarUrl2 == null ? null : CachedNetworkImageProvider(avatarUrl2),
                              child: avatarUrl2 == null ? const Icon(Icons.person_rounded, size: 18) : null,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded, size: 18),
                                      const SizedBox(width: 4),
                                      Text(rating.toStringAsFixed(1)),
                                    ],
                                  ),
                                  if (comment.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(comment),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

            // ========= TAB PORTAFOLIO =========
            _portfolio.isEmpty
                ? const Center(child: Text('No tiene portafolio aún.'))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _portfolio.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = _portfolio[i];
                      final title = (item['title'] ?? '').toString();
                      final desc = (item['description'] ?? '').toString();

                      final photos = ((item['photos'] ?? item['portfolio_photos']) as List? ?? [])
                          .cast<Map>()
                          .map((e) => e.cast<String, dynamic>())
                          .toList();

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title.trim().isNotEmpty)
                              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            if (desc.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(desc),
                            ],
                            if (photos.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 92,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: photos.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                                  itemBuilder: (context, j) {
                                    final path = (photos[j]['path'] ?? '').toString();
                                    final url = repo.publicUrl('portfolio', path);

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: AspectRatio(
                                        aspectRatio: 1,
                                        child: CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: cs.surfaceContainerHighest),
                                          errorWidget: (_, __, ___) => Container(
                                            color: cs.surfaceContainerHighest,
                                            child: const Icon(Icons.broken_image_rounded),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
