import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/historical_operation.dart';

class HistoricalOperationDraft {
  final DateTime date;
  final HistoricalOperationType type;
  final double amount;
  final double? units;
  final double? price;
  final String? description;
  final String? transferUid;

  const HistoricalOperationDraft({
    required this.date,
    required this.type,
    required this.amount,
    this.units,
    this.price,
    this.description,
    this.transferUid,
  });
}

class HistoricalOperationDialog extends StatefulWidget {
  final HistoricalOperationDraft? operation;
  final DateFormat dateFormat;
  final Future<DateTime?> Function(DateTime) pickDate;
  final double? Function(String) parseNumber;
  final String? Function(String?, {required String label}) validateNumber;
  final String Function() generateTransferUid;

  const HistoricalOperationDialog({
    super.key,
    required this.operation,
    required this.dateFormat,
    required this.pickDate,
    required this.parseNumber,
    required this.validateNumber,
    required this.generateTransferUid,
  });

  @override
  State<HistoricalOperationDialog> createState() =>
      HistoricalOperationDialogState();
}

class HistoricalOperationDialogState extends State<HistoricalOperationDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _unitsController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _transferController;

  late HistoricalOperationType _selectedType;
  late DateTime _selectedDate;

  String? _generatedTransferUid;

  @override
  void initState() {
    super.initState();

    final operation = widget.operation;

    _amountController = TextEditingController(
      text: operation?.amount.toString() ?? '',
    );
    _unitsController = TextEditingController(
      text: operation?.units?.toString() ?? '',
    );
    _priceController = TextEditingController(
      text: operation?.price?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: operation?.description ?? '',
    );
    _transferController = TextEditingController(
      text: operation?.transferUid ?? '',
    );

    _selectedType = operation?.type ?? HistoricalOperationType.subscription;
    if (_selectedType == HistoricalOperationType.transferOut) {
      _generatedTransferUid = operation?.transferUid;
    }
    _selectedDate = operation?.date ?? DateTime.now();

    _unitsController.addListener(_updateCalculatedAmount);
    _priceController.addListener(_updateCalculatedAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _unitsController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _transferController.dispose();
    super.dispose();
  }

  void _updateCalculatedAmount() {
    final unitsText = _unitsController.text.trim();
    final priceText = _priceController.text.trim();

    // Si falta alguno de los dos datos, no calculamos.
    if (unitsText.isEmpty || priceText.isEmpty) return;

    final units = widget.parseNumber(unitsText);
    final price = widget.parseNumber(priceText);

    if (units == null ||
        price == null ||
        !units.isFinite ||
        !price.isFinite ||
        units < 0 ||
        price < 0) {
      return;
    }

    final amount = units * price;
    if (!amount.isFinite) return;

    // Formato español con dos decimales.
    final calculated = amount.toStringAsFixed(2).replaceAll('.', ',');

    if (_amountController.text != calculated) {
      _amountController.value = TextEditingValue(
        text: calculated,
        selection: TextSelection.collapsed(offset: calculated.length),
      );
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = widget.parseNumber(_amountController.text);
    final units = _unitsController.text.trim().isEmpty
        ? null
        : widget.parseNumber(_unitsController.text);
    final price = _priceController.text.trim().isEmpty
        ? null
        : widget.parseNumber(_priceController.text);

    if (amount == null) return;

    if (units != null &&
        price != null &&
        (amount - units * price).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El importe debe coincidir con participaciones × precio',
          ),
        ),
      );
      return;
    }

    Navigator.pop(
      context,
      HistoricalOperationDraft(
        date: _selectedDate,
        type: _selectedType,
        amount: amount,
        units: units,
        price: price,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        /* transferUid: _transferController.text.trim().isEmpty
            ? null
            : _transferController.text.trim(), */
        transferUid: switch (_selectedType) {
          HistoricalOperationType.transferOut => _generatedTransferUid,
          HistoricalOperationType.transferIn =>
            _transferController.text.trim().isEmpty
                ? null
                : _transferController.text.trim(),
          _ => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    return AlertDialog(
      actionsAlignment: .spaceAround,
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        widget.operation == null ? 'Nueva operación' : 'Editar operación',
        style: const TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: screenWidth * 0.8,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<HistoricalOperationType>(
                  initialValue: _selectedType,
                  dropdownColor: const Color(0xFF1E293B),
                  decoration: const InputDecoration(
                    labelText: 'Tipo de operación',
                  ),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: HistoricalOperationType.subscription,
                      child: Text('Suscripción'),
                    ),
                    DropdownMenuItem(
                      value: HistoricalOperationType.redemption,
                      child: Text('Reembolso'),
                    ),
                    DropdownMenuItem(
                      value: HistoricalOperationType.transferIn,
                      child: Text('Traspaso de entrada'),
                    ),
                    DropdownMenuItem(
                      value: HistoricalOperationType.transferOut,
                      child: Text('Traspaso de salida'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      if (value == HistoricalOperationType.transferOut) {
                        _generatedTransferUid ??= widget.generateTransferUid();
                        _transferController.text = _generatedTransferUid!;
                      } else if (_selectedType ==
                          HistoricalOperationType.transferOut) {
                        _transferController.clear();
                      }
                      _selectedType = value;
                    });
                  },
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                  ),
                  title: const Text(
                    'Fecha',
                    style: TextStyle(color: Colors.white70),
                  ),
                  subtitle: Text(
                    widget.dateFormat.format(_selectedDate),
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(
                    Icons.edit_calendar,
                    color: Colors.amber,
                  ),
                  onTap: () async {
                    final date = await widget.pickDate(_selectedDate);
                    if (date != null && mounted) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Importe'),
                  validator: (value) =>
                      widget.validateNumber(value, label: 'importe'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unitsController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Participaciones (opcional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return widget.validateNumber(
                      value,
                      label: 'número de participaciones',
                    );
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Precio (opcional)',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    return widget.validateNumber(value, label: 'precio');
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                /* TextFormField(
                  controller: _transferController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'UID de transferencia (opcional)',
                  ),
                ), */
                if (_selectedType == HistoricalOperationType.transferOut)
                  TextFormField(
                    key: const ValueKey('generated-transfer-uid'),
                    initialValue: _generatedTransferUid,
                    readOnly: true,
                    style: const TextStyle(color: Colors.white70),
                    decoration: const InputDecoration(
                      labelText: 'UID de transferencia (generado)',
                      helperText: 'Identificador que deberá asociarse al traspaso recibido',
                    ),
                  )
                else if (_selectedType == HistoricalOperationType.transferIn)
                  TextFormField(
                    controller: _transferController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'UID de transferencia',
                    ),
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
        FilledButton(onPressed: _submit, child: const Text('Aceptar')),
      ],
    );
  }
}
