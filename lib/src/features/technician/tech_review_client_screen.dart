import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/providers.dart';

class TechReviewClientScreen extends ConsumerStatefulWidget {
  const TechReviewClientScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<TechReviewClientScreen> createState() => _TechReviewClientScreenState();
}

class _TechReviewClientScreenState extends ConsumerState<TechReviewClientScreen> {
  bool _loading = true;
  bool _saving = false;

  String? _clientId;
  String? _clientName; // Para mostrar en la UI
  
  double _rating = 5;
  final _commentCtrl = TextEditingController();

  // Tags relevantes para calificar a un CLIENTE
  final List<String> _tags = ['Amable', 'Pago rápido', 'Instrucciones claras', 'Lugar seguro', 'Paciente'];
  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      // Obtenemos la solicitud y el perfil del cliente asociado
      // Nota: asumiendo que 'client_id' es FK a 'profiles'
      final req = await supabase
          .from('service_requests')
          .select('client_id, status, profiles:client_id(full_name)') 
          .eq('id', widget.requestId)
          .single();

      if (req['status'] != 'completed' && req['status'] != 'rated') {
        // Validación suave
      }

      _clientId = req['client_id'] as String?;
      
      // Extraer nombre del cliente de la relación
      final profile = req['profiles'] as Map<String, dynamic>?;
      _clientName = profile?['full_name'] as String? ?? 'el cliente';

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleTag(String tag) {
    setState(() {
      if (_selectedTags.contains(tag)) {
        _selectedTags.remove(tag);
      } else {
        _selectedTags.add(tag);
      }
    });
  }

  Future<void> _submit() async {
    if (_clientId == null) return;

    setState(() => _saving = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      // Construir comentario con tags
      String finalComment = _commentCtrl.text.trim();
      if (_selectedTags.isNotEmpty) {
        final tagsText = _selectedTags.map((t) => '[$t]').join(' ');
        finalComment = finalComment.isEmpty ? tagsText : '$finalComment\n\n$tagsText';
      }

      await supabase.from('reviews').insert({
        'request_id': widget.requestId,
        'reviewer_id': supabase.auth.currentUser!.id,
        'reviewee_id': _clientId,
        'rating': _rating.toInt(),
        'comment': finalComment,
      });

      // Opcional: Marcar algo en la solicitud para saber que el técnico ya calificó
      // Por ahora solo cerramos

      if (!mounted) return;
      
      // Dialogo de éxito
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 60),
          title: const Text('Reseña Enviada'),
          content: const Text('Gracias por calificar al cliente.'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar dialogo
                context.go('/tech'); // Volver al home del técnico
              },
              child: const Text('Volver al inicio'),
            )
          ],
        ),
      );

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Calificar Cliente'),
        centerTitle: true,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Icono / Avatar
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline_rounded, size: 50, color: Colors.blue),
              ),
              const SizedBox(height: 20),

              Text(
                '¿Cómo fue trabajar con $_clientName?',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tu calificación ayuda a otros técnicos.',
                style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
              ),

              const SizedBox(height: 30),

              // 2. Estrellas
              RatingBar.builder(
                initialRating: _rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  setState(() {
                    _rating = rating;
                  });
                },
              ),
              const SizedBox(height: 10),
              Text(
                '$_rating/5',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber[800]),
              ),

              const SizedBox(height: 30),

              // 3. Tags
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Aspectos destacados', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (_) => _toggleTag(tag),
                    checkmarkColor: isSelected ? cs.onPrimary : null,
                    selectedColor: cs.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? cs.onPrimary : cs.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // 4. Comentario
              TextField(
                controller: _commentCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Comentario privado (opcional)',
                  hintText: 'Detalles sobre el pago, trato, etc...',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 30),

              // 5. Botón
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('ENVIAR CALIFICACIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}