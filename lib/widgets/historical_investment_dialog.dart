import 'package:flutter/material.dart';

import '../models/historical_investment.dart';

class HistoricalInvestmentDraft {
  final String name;
  final String? isin;
  final String? description;

  const HistoricalInvestmentDraft({
    required this.name,
    this.isin,
    this.description,
  });
}

class HistoricalInvestmentDialog extends StatefulWidget {
  final HistoricalInvestment investment;

  const HistoricalInvestmentDialog({super.key, required this.investment});

  @override
  State<HistoricalInvestmentDialog> createState() =>
      HistoricalInvestmentDialogState();
}

class HistoricalInvestmentDialogState
    extends State<HistoricalInvestmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _isinController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.investment.name);
    _isinController = TextEditingController(text: widget.investment.isin ?? '');
    _descriptionController = TextEditingController(
      text: widget.investment.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isinController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final isin = _isinController.text.trim();
    final description = _descriptionController.text.trim();

    Navigator.pop(
      context,
      HistoricalInvestmentDraft(
        name: _nameController.text.trim(),
        isin: isin.isEmpty ? null : isin.toUpperCase(),
        description: description.isEmpty ? null : description,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.amber),
      ),
      errorMaxLines: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        'Editar inversión',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Nombre de la inversión'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Introduce un nombre para la inversión';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _isinController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('ISIN (opcional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Descripción (opcional)'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
