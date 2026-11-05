import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../services/database_service.dart';
import '../widgets/gradient_background.dart';
import 'fund_search_page.dart';

class HistoricalInvestmentFormPage extends StatefulWidget {
  const HistoricalInvestmentFormPage({super.key});

  @override
  State<HistoricalInvestmentFormPage> createState() =>
      _HistoricalInvestmentFormPageState();
}

class _HistoricalInvestmentFormPageState
    extends State<HistoricalInvestmentFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _isinController = TextEditingController();
  final _descriptionController = TextEditingController();

  final List<_HistoricalOperationDraft> _operations = [];

  bool _saving = false;
  static int _uidCounter = 0;

  String get _locale => Localizations.localeOf(context).toString();

  DateFormat get _dateFormat => DateFormat.yMMMd(_locale);

  String _newUid(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '_${_uidCounter++}';
  }

  double? _parseNumber(String value) {
    final normalized = value
        .trim()
        .replaceAll(' ', '')
        .replaceAll('€', '')
        .replaceAll('.', '')
        .replaceAll(',', '.');

    return double.tryParse(normalized);
  }

  String? _validateNumber(String? value, {required String label}) {
    final number = _parseNumber(value ?? '');

    if (number == null || !number.isFinite || number < 0) {
      return 'Introduce un $label válido';
    }

    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _isinController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _searchFund() async {
    final fund = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FundSearchPage(isOnlySearch: true),
      ),
    );

    if (fund == null || !mounted) return;

    setState(() {
      _nameController.text = fund.name ?? '';
      _isinController.text = fund.isin ?? '';
    });
  }

  Future<DateTime?> _pickDate(DateTime initialDate) async {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha de la operación',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.amber,
              onPrimary: Colors.black,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  Future<void> _addOperation() async {
    final draft = await _showOperationDialog();

    if (draft == null || !mounted) return;

    setState(() => _operations.add(draft));
  }

  Future<void> _editOperation(int index) async {
    final draft = await _showOperationDialog(operation: _operations[index]);

    if (draft == null || !mounted) return;

    setState(() => _operations[index] = draft);
  }

  Future<_HistoricalOperationDraft?> _showOperationDialog({
    _HistoricalOperationDraft? operation,
  }) {
    return showDialog<_HistoricalOperationDraft>(
      context: context,
      builder: (_) => _HistoricalOperationDialog(
        operation: operation,
        dateFormat: _dateFormat,
        pickDate: _pickDate,
        parseNumber: _parseNumber,
        validateNumber: _validateNumber,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    if (_operations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos una operación histórica')),
      );
      return;
    }

    setState(() => _saving = true);

    final investmentUid = _newUid('investment');

    try {
      final investment = HistoricalInvestment(
        uid: investmentUid,
        name: _nameController.text,
        isin: _isinController.text.trim().isEmpty
            ? null
            : _isinController.text.trim().toUpperCase(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      for (final draft in _operations) {
        final operation = HistoricalOperation(
          uid: _newUid('operation'),
          investmentUid: investmentUid,
          date: draft.date,
          type: draft.type,
          amount: draft.amount,
          units: draft.units,
          price: draft.price,
          description: draft.description,
          transferUid: draft.transferUid,
        );

        await DatabaseService.saveHistoricalOperation(operation);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inversión histórica guardada correctamente'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el histórico: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // if (action != null) action,
              ?action,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildInvestmentFields() {
    return Column(
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
    );
  }

  Widget _buildOperationList() {
    if (_operations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'Todavía no hay operaciones.\nAñade la primera para construir el histórico.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(_operations.length, (index) {
        final operation = _operations[index];

        final title = switch (operation.type) {
          HistoricalOperationType.subscription => 'Suscripción',
          HistoricalOperationType.redemption => 'Reembolso',
          HistoricalOperationType.transferIn => 'Traspaso de entrada',
          HistoricalOperationType.transferOut => 'Traspaso de salida',
        };

        return Card(
          color: const Color(0xFF0F172A),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.withValues(alpha: 0.12),
              child: Icon(
                operation.type == HistoricalOperationType.redemption ||
                        operation.type == HistoricalOperationType.transferOut
                    ? Icons.south_west
                    : Icons.north_east,
                color: Colors.amber,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${_dateFormat.format(operation.date)}'
              '${operation.description == null ? '' : '\n${operation.description}'}',
              style: const TextStyle(color: Colors.white60),
            ),
            isThreeLine: operation.description != null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  NumberFormat.currency(
                    locale: _locale,
                    symbol: '€',
                  ).format(operation.amount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editOperation(index);
                    } else if (value == 'delete') {
                      setState(() => _operations.removeAt(index));
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        title: const Text('Nueva inversión histórica'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                _buildSection(
                  title: 'Identificación',
                  icon: Icons.account_balance,
                  action: IconButton(
                    tooltip: 'Buscar fondo',
                    onPressed: _searchFund,
                    icon: const Icon(Icons.search, color: Colors.amber),
                  ),
                  child: _buildInvestmentFields(),
                ),
                const SizedBox(height: 16),
                _buildSection(
                  title: 'Operaciones históricas',
                  icon: Icons.history,
                  action: IconButton(
                    tooltip: 'Añadir operación',
                    onPressed: _addOperation,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.amber,
                    ),
                  ),
                  child: _buildOperationList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _saving ? 'Guardando…' : 'Guardar inversión histórica',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoricalOperationDraft {
  final DateTime date;
  final HistoricalOperationType type;
  final double amount;
  final double? units;
  final double? price;
  final String? description;
  final String? transferUid;

  const _HistoricalOperationDraft({
    required this.date,
    required this.type,
    required this.amount,
    this.units,
    this.price,
    this.description,
    this.transferUid,
  });
}

class _HistoricalOperationDialog extends StatefulWidget {
  final _HistoricalOperationDraft? operation;
  final DateFormat dateFormat;
  final Future<DateTime?> Function(DateTime) pickDate;
  final double? Function(String) parseNumber;
  final String? Function(String?, {required String label}) validateNumber;

  const _HistoricalOperationDialog({
    required this.operation,
    required this.dateFormat,
    required this.pickDate,
    required this.parseNumber,
    required this.validateNumber,
  });

  @override
  State<_HistoricalOperationDialog> createState() =>
      _HistoricalOperationDialogState();
}

class _HistoricalOperationDialogState
    extends State<_HistoricalOperationDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _unitsController;
  late final TextEditingController _priceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _transferController;

  late HistoricalOperationType _selectedType;
  late DateTime _selectedDate;

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
    _selectedDate = operation?.date ?? DateTime.now();
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
      _HistoricalOperationDraft(
        date: _selectedDate,
        type: _selectedType,
        amount: amount,
        units: units,
        price: price,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        transferUid: _transferController.text.trim().isEmpty
            ? null
            : _transferController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        widget.operation == null ? 'Nueva operación' : 'Editar operación',
        style: const TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
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
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
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
                trailing: const Icon(Icons.edit_calendar, color: Colors.amber),
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
              TextFormField(
                controller: _transferController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'UID de transferencia (opcional)',
                ),
              ),
            ],
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
