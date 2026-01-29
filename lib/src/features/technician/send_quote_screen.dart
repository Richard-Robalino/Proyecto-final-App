import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class SendQuoteScreen extends ConsumerStatefulWidget {
  const SendQuoteScreen({super.key, required this.requestId});
  final String requestId;

  @override
  ConsumerState<SendQuoteScreen> createState() => _SendQuoteScreenState();
}

class _SendQuoteScreenState extends ConsumerState<SendQuoteScreen> {
  final _priceCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController(text: '60');
  final _messageCtrl = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _priceCtrl.dispose();
    _minutesCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Normalizamos la coma a punto por si acaso
    final priceText = _priceCtrl.text.replaceAll(',', '.');
    final price = num.tryParse(priceText);
    final minutes = int.tryParse(_minutesCtrl.text);

    if (price == null || price <= 0) {
      _showSnackBar('Ingresa un precio válido', isError: true);
      return;
    }
    if (minutes == null || minutes <= 0) {
      _showSnackBar('El tiempo debe ser mayor a 0', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(supabaseRepoProvider);
      await repo.sendQuote(
        requestId: widget.requestId,
        price: price,
        estimatedMinutes: minutes,
        message: _messageCtrl.text.trim(),
      );

      if (!mounted) return;
      _showSnackBar('¡Cotización enviada con éxito!');
      Navigator.pop(context); // Volver atrás
    } catch (e) {
      if (mounted) _showSnackBar('Error enviando: $e', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Crear Cotización'),
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. HEADER ILUSTRATIVO
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.request_quote_rounded, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Define tu oferta',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'El cliente verá este precio final.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.6)),
            ),
            
            const SizedBox(height: 30),

            // 2. INPUTS PRINCIPALES (Precio y Tiempo)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRECIO
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Precio Total', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: TextStyle(color: cs.primary, fontSize: 24, fontWeight: FontWeight.bold),
                          hintText: '0.00',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // TIEMPO
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Duración', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _minutesCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          suffixText: 'min',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 3. MENSAJE / DESGLOSE
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Detalles (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _messageCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Describe qué incluye: materiales, mano de obra, garantías...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 4. TIP CARD
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Las cotizaciones detalladas tienen un 40% más de probabilidad de ser aceptadas.',
                      style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 5. BOTÓN ENVIAR
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: _saving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
                label: Text(
                  _saving ? 'Enviando...' : 'ENVIAR COTIZACIÓN',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}