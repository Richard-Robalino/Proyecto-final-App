import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/models.dart';
import '../../state/providers.dart';

class RequestPreviewScreen extends ConsumerStatefulWidget {
  const RequestPreviewScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<RequestPreviewScreen> createState() => _RequestPreviewScreenState();
}

class _RequestPreviewScreenState extends ConsumerState<RequestPreviewScreen> {
  bool _loading = true;
  bool _updating = false;
  
  ServiceRequest? _req;
  bool _hasReviewed = false;
  
  // ✅ NUEVO: Variable para guardar el estado del técnico
  String _techStatus = 'pending'; 

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      
      // ✅ Cargamos Solicitud, Review Y el Estado del Técnico en paralelo
      final results = await Future.wait([
        repo.fetchRequestById(widget.requestId),
        repo.hasReviewed(widget.requestId),
        repo.getCurrentTechnicianStatus(), // <--- Obtenemos el estado aquí
      ]);

      if (!mounted) return;
      
      setState(() {
        _req = results[0] as ServiceRequest;
        _hasReviewed = results[1] as bool;
        _techStatus = results[2] as String; // <--- Guardamos el estado
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.setRequestStatus(requestId: widget.requestId, newStatus: newStatus);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Estado actualizado a: ${_translateStatus(newStatus)}'),
        backgroundColor: Colors.green,
      ));
      
      await _load(); 
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('P0001')) msg = 'Sigue el flujo normal del trabajo.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  String _translateStatus(String s) {
    switch(s) {
      case 'on_the_way': return 'En Camino';
      case 'in_progress': return 'En Progreso';
      case 'completed': return 'Completado';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = _req;
    final cs = Theme.of(context).colorScheme;

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (req == null) return const Scaffold(body: Center(child: Text('Error al cargar solicitud')));

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Gestión del Trabajo'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        children: [
          // 1. TARJETA PRINCIPAL
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(req.description, style: TextStyle(fontSize: 15, color: cs.onSurface.withOpacity(0.7))),
                const SizedBox(height: 16),
                _StatusBadge(status: req.status),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // 2. UBICACIÓN
          if ((req.address ?? '').isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(req.lat, req.lng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all), 
                  ),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(req.lat, req.lng),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(req.address!, style: const TextStyle(color: Colors.grey))),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // 3. TIMELINE
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text('Historial de Eventos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          _TimelineSection(requestId: req.id),
        ],
      ),
      
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: _buildActionButton(req),
        ),
      ),
    );
  }

  Widget _buildActionButton(ServiceRequest req) {
    
    // 1. LÓGICA DE BLOQUEO PARA COTIZAR
    if (req.status == 'requested' || req.status == 'quoted') {
      
      // Si el técnico NO está aprobado ('approved'), mostramos botón bloqueado
      if (_techStatus != 'approved') {
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            backgroundColor: Colors.grey.shade300, // Gris deshabilitado
            foregroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.lock_outline),
          label: const Text('CUENTA NO VERIFICADA'),
          onPressed: () {
            // Mostramos alerta explicativa
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.shield_outlined, size: 40, color: Colors.orange),
                title: const Text('Función Restringida'),
                content: Text(_techStatus == 'pending'
                  ? 'Tu perfil está en revisión. Podrás enviar cotizaciones una vez que un administrador te apruebe.'
                  : 'Tu perfil ha sido rechazado. Contacta a soporte.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
              ),
            );
          },
        );
      }

      // Si ESTÁ aprobado, botón normal
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.request_quote),
        label: const Text('ENVIAR COTIZACIÓN'),
        onPressed: () => context.push('/tech/request/${req.id}/quote'),
      );
    }

    if (req.status == 'accepted') {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.orange,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.directions_car),
        label: _updating 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('INICIAR VIAJE (EN CAMINO)'),
        onPressed: _updating ? null : () => _updateStatus('on_the_way'),
      );
    }

    if (req.status == 'on_the_way') {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.blue,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.play_circle_fill_rounded),
        label: _updating 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('LLEGUÉ / INICIAR TRABAJO'),
        onPressed: _updating ? null : () => _updateStatus('in_progress'),
      );
    }

    if (req.status == 'in_progress') {
      return FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.green,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.check_circle_rounded),
        label: _updating 
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('FINALIZAR TRABAJO'),
        onPressed: _updating ? null : () => _updateStatus('completed'),
      );
    }

    if (req.status == 'completed' || req.status == 'rated') {
      if (_hasReviewed) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text(
                '¡Trabajo finalizado y calificado!',
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      } else {
        return FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.purple,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.star_rounded),
          label: const Text('CALIFICAR CLIENTE'),
          onPressed: () async {
            await context.push('/tech/request/${req.id}/review_client');
            _load(); // Recargar al volver para actualizar el botón a "Ya calificado"
          },
        );
      }
    }

    return const SizedBox.shrink();
  }
}

// --- WIDGETS AUXILIARES ---

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String text;

    switch (status) {
      case 'accepted':
        bg = Colors.blue.shade50; fg = Colors.blue; text = 'ACEPTADO'; break;
      case 'on_the_way':
        bg = Colors.orange.shade50; fg = Colors.orange; text = 'EN CAMINO'; break;
      case 'in_progress':
        bg = Colors.purple.shade50; fg = Colors.purple; text = 'TRABAJANDO'; break;
      case 'completed':
        bg = Colors.green.shade50; fg = Colors.green; text = 'FINALIZADO'; break;
      case 'rated':
        bg = Colors.green.shade50; fg = Colors.green; text = 'CERRADO'; break;
      default:
        bg = Colors.grey.shade100; fg = Colors.grey; text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class _TimelineSection extends ConsumerWidget {
  final String requestId;
  const _TimelineSection({required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(supabaseRepoProvider);

    return StreamBuilder<List<RequestEvent>>(
      stream: repo.streamRequestEvents(requestId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text('Error: ${snapshot.error}');
        if (!snapshot.hasData) return const Center(child: LinearProgressIndicator());
        
        final events = snapshot.data!;
        if (events.isEmpty) return const Text('Sin eventos registrados', style: TextStyle(color: Colors.grey));

        final sorted = events.reversed.toList();

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final e = sorted[index];
            final isFirst = index == 0;
            final isLast = index == sorted.length - 1;
            final date = DateFormat('HH:mm').format(e.createdAt.toLocal());

            return IntrinsicHeight(
              child: Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: isFirst ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                          shape: BoxShape.circle,
                          border: isFirst ? Border.all(color: Colors.white, width: 2) : null,
                          boxShadow: isFirst ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
                        ),
                      ),
                      if (!isLast)
                        Expanded(child: Container(width: 2, color: Colors.grey[200])),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_mapStatus(e.status), style: TextStyle(fontWeight: isFirst ? FontWeight.bold : FontWeight.normal, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(date, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _mapStatus(String s) {
    switch(s) {
      case 'requested': return 'Solicitud creada';
      case 'quoted': return 'Cotización enviada';
      case 'accepted': return 'Cotización aceptada';
      case 'on_the_way': return 'Técnico en camino';
      case 'in_progress': return 'Trabajo iniciado';
      case 'completed': return 'Trabajo finalizado';
      case 'rated': return 'Servicio calificado';
      default: return s;
    }
  }
}