import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class SendQuoteScreen extends ConsumerStatefulWidget {
  const SendQuoteScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<SendQuoteScreen> createState() => _SendQuoteScreenState();
}

class _SendQuoteScreenState extends ConsumerState<SendQuoteScreen> {
  final _price = TextEditingController();
  final _minutes = TextEditingController(text: '60');
  final _message = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _price.dispose();
    _minutes.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = num.tryParse(_price.text.replaceAll(',', '.'));
    final minutes = int.tryParse(_minutes.text);

    if (price == null || price <= 0 || minutes == null || minutes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Precio y tiempo deben ser válidos')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.sendQuote(
        requestId: widget.requestId,
        price: price,
        estimatedMinutes: minutes,
        message: _message.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cotización enviada')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar cotización')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              TextField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Precio (USD)', prefixText: '\$ '),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Tiempo estimado (min)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensaje (opcional)',
                  hintText: 'Incluye lo que cubre, materiales, etc.',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tip pro: puedes usar IA para generar una cotización mejor (Edge Function adicional).',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }
}
