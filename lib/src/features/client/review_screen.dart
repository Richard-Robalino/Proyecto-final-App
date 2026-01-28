import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../state/providers.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _loading = true;
  bool _saving = false;

  String? _technicianId;
  double _rating = 5;
  final _comment = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      final req = await supabase
          .from('service_requests')
          .select('accepted_quote_id, status')
          .eq('id', widget.requestId)
          .single();

      if (req['status'] != 'completed') {
        throw Exception('Solo se puede calificar cuando el servicio está completado');
      }

      final quoteId = req['accepted_quote_id'] as String?;
      if (quoteId == null) throw Exception('No hay técnico asignado (accepted_quote_id null)');

      final q = await supabase.from('quotes').select('technician_id').eq('id', quoteId).single();
      _technicianId = q['technician_id'] as String?;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_technicianId == null) return;

    setState(() => _saving = true);
    final supabase = ref.read(supabaseClientProvider);

    try {
      await supabase.from('reviews').insert({
        'request_id': widget.requestId,
        'reviewer_id': supabase.auth.currentUser!.id,
        'reviewee_id': _technicianId,
        'rating': _rating.toInt(),
        'comment': _comment.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Gracias! Reseña enviada.')));
      Navigator.pop(context);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Calificar técnico')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Puntuación', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Center(
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 1,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 36,
                  itemBuilder: (context, _) => const Icon(Icons.star_rounded, color: Colors.amber),
                  onRatingUpdate: (v) => setState(() => _rating = v),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _comment,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Comentario',
                  hintText: '¿Cómo fue el servicio? Puntualidad, calidad, trato...',
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar reseña'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
