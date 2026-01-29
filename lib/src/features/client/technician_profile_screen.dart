import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart'; // Para formatear fechas (asegúrate de tener intl)

import '../../data/models/models.dart';
import '../../state/providers.dart';

class TechnicianProfileScreen extends ConsumerStatefulWidget {
  const TechnicianProfileScreen({super.key, required this.techId});
  final String techId;

  @override
  ConsumerState<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends ConsumerState<TechnicianProfileScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  Map<String, dynamic>? _profile;
  List<ServiceCategory> _specialties = const [];
  List<Map<String, dynamic>> _reviews = const [];
  List<Map<String, dynamic>> _portfolio = const [];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      // Carga paralela para velocidad
      final results = await Future.wait([
        repo.fetchTechnicianPublicProfile(widget.techId),
        repo.fetchTechnicianSpecialties(widget.techId),
        repo.fetchTechnicianReviews(widget.techId),
        repo.fetchTechnicianPortfolio(widget.techId),
      ]);

      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _specialties = results[1] as List<ServiceCategory>;
        _reviews = results[2] as List<Map<String, dynamic>>;
        _portfolio = results[3] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando perfil: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(backgroundColor: cs.surface, body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }

    if (_profile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil no disponible')),
        body: const Center(child: Text('No se pudo cargar la información.')),
      );
    }

    // Datos seguros
    final p = _profile!;
    final fullName = (p['full_name'] ?? 'Técnico').toString();
    final avatarPath = p['avatar_path']?.toString();
    final bio = (p['bio'] ?? 'Sin biografía disponible.').toString();
    final baseRate = (p['base_rate'] ?? 0).toDouble();
    final radius = (p['coverage_radius_km'] ?? 0).toDouble();
    final avgRating = (p['avg_rating'] ?? 0).toDouble();
    final totalReviews = (p['total_reviews'] ?? 0).toInt();
    final completedJobs = (p['completed_jobs'] ?? 0).toInt();

    final repo = ref.read(supabaseRepoProvider);
    final avatarUrl = avatarPath != null ? repo.publicUrl('avatars', avatarPath) : null;

    return Scaffold(
      backgroundColor: cs.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: cs.primary,
              foregroundColor: Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Fondo degradado
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [cs.primary, cs.primaryContainer],
                        ),
                      ),
                    ),
                    // Info Central
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40), // Espacio para status bar
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? Text(fullName[0].toUpperCase(), style: TextStyle(fontSize: 40, color: cs.primary))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _StatBadge(icon: Icons.star, text: avgRating.toStringAsFixed(1), color: Colors.amber),
                              const SizedBox(width: 12),
                              _StatBadge(icon: Icons.work, text: '$completedJobs Trabajos', color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 4,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: 'PERFIL'),
                  Tab(text: 'RESEÑAS'),
                  Tab(text: 'PORTAFOLIO'),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // 1. INFO PERFIL
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _SectionTitle('Sobre mí'),
                const SizedBox(height: 8),
                Text(bio, style: TextStyle(fontSize: 15, color: cs.onSurface.withOpacity(0.8), height: 1.5)),
                
                const SizedBox(height: 24),
                
                _SectionTitle('Detalles del Servicio'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _InfoCard(icon: Icons.monetization_on, title: 'Tarifa Base', value: '\$${baseRate.toStringAsFixed(0)}/hr')),
                    const SizedBox(width: 12),
                    Expanded(child: _InfoCard(icon: Icons.map, title: 'Cobertura', value: '${radius.toInt()} km')),
                  ],
                ),

                const SizedBox(height: 24),

                _SectionTitle('Especialidades'),
                const SizedBox(height: 12),
                if (_specialties.isEmpty)
                  const Text('Sin especialidades registradas.', style: TextStyle(fontStyle: FontStyle.italic))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _specialties.map((s) => Chip(
                      label: Text(s.name),
                      backgroundColor: cs.primary.withOpacity(0.1),
                      labelStyle: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    )).toList(),
                  ),
              ],
            ),

            // 2. RESEÑAS
            _reviews.isEmpty
                ? const _EmptyTab(icon: Icons.rate_review_outlined, text: 'Aún no tiene reseñas.')
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, i) => _ReviewCard(review: _reviews[i], repo: repo),
                  ),

            // 3. PORTAFOLIO
            _portfolio.isEmpty
                ? const _EmptyTab(icon: Icons.photo_library_outlined, text: 'Sin portafolio.')
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _portfolio.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, i) => _PortfolioCard(item: _portfolio[i], repo: repo),
                  ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES ---

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatBadge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _InfoCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: cs.onSurface.withOpacity(0.6), fontSize: 12)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  final dynamic repo; // Pasamos repo para generar url
  const _ReviewCard({required this.review, required this.repo});

  @override
  Widget build(BuildContext context) {
    final reviewer = (review['reviewer'] as Map?) ?? {};
    final name = reviewer['full_name'] ?? 'Usuario';
    final avatarPath = reviewer['avatar_path'];
    final rating = (review['rating'] ?? 0).toDouble();
    final comment = review['comment'] ?? '';
    final date = DateTime.tryParse(review['created_at'] ?? '') ?? DateTime.now();

    final avatarUrl = avatarPath != null ? repo.publicUrl('avatars', avatarPath) : null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null ? Text(name[0]) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(DateFormat.yMMMd().format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      Text(' $rating', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                    ],
                  ),
                ),
              ],
            ),
            if (comment.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(comment, style: TextStyle(color: Colors.grey.shade800)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final dynamic repo;
  const _PortfolioCard({required this.item, required this.repo});

  @override
  Widget build(BuildContext context) {
    final title = item['title'] ?? 'Sin título';
    final desc = item['description'] ?? '';
    // Adaptar estructura de fotos según venga de tu BD (array directo o tabla relacionada)
    final photos = (item['photos'] as List?) ?? (item['portfolio_photos'] as List?) ?? [];

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 200,
              child: PageView.builder(
                itemCount: photos.length,
                itemBuilder: (context, index) {
                  final path = photos[index]['path'];
                  final url = repo.publicUrl('portfolio', path);
                  return CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(color: Colors.grey[200]),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(desc, style: const TextStyle(color: Colors.grey)),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyTab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }
}