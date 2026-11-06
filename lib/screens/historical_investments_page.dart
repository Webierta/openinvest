import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../services/database_service.dart';
import '../widgets/gradient_background.dart';
import '../widgets/historical_operation_dialog.dart';

class HistoricalInvestmentsPage extends StatefulWidget {
  const HistoricalInvestmentsPage({super.key});

  @override
  State<HistoricalInvestmentsPage> createState() =>
      _HistoricalInvestmentsPageState();
}

class _HistoricalInvestmentsPageState extends State<HistoricalInvestmentsPage> {
  late Future<List<HistoricalInvestment>> _investmentsFuture;

  final _numberFormat = NumberFormat('#,##0.00', 'es_ES');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadInvestments();
  }

  void _loadInvestments() {
    _investmentsFuture = DatabaseService.getHistoricalInvestments();
  }

  Future<void> _refresh() async {
    setState(_loadInvestments);
    await _investmentsFuture;
  }

  String get _locale => Localizations.localeOf(context).toString();

  DateFormat get _dialogDateFormat => DateFormat.yMMMd(_locale);

  double? _parseNumber(String value) {
    var normalized = value.trim().replaceAll(' ', '').replaceAll('€', '');

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  String? _validateNumber(String? value, {required String label}) {
    final number = _parseNumber(value ?? '');

    if (number == null || !number.isFinite || number < 0) {
      return 'Introduce un $label válido';
    }

    return null;
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Fecha de la operación',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
  }

  Future<void> _editOperation(HistoricalOperation operation) async {
    final draft = await showDialog<HistoricalOperationDraft>(
      context: context,
      builder: (_) => HistoricalOperationDialog(
        operation: HistoricalOperationDraft(
          date: operation.date,
          type: operation.type,
          amount: operation.amount,
          units: operation.units,
          price: operation.price,
          description: operation.description,
          transferUid: operation.transferUid,
        ),
        dateFormat: _dialogDateFormat,
        pickDate: _pickDate,
        parseNumber: _parseNumber,
        validateNumber: _validateNumber,
      ),
    );

    if (draft == null || !mounted) return;

    try {
      final updated = operation.copyWith(
        date: draft.date,
        type: draft.type,
        amount: draft.amount,
        units: draft.units,
        price: draft.price,
        description: draft.description,
        transferUid: draft.transferUid,
      );

      await DatabaseService.updateHistoricalOperation(updated);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación histórica actualizada correctamente'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la operación: $error')),
      );
    }
  }

  Future<void> _deleteOperation(HistoricalOperation operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar operación'),
        content: Text(
          '¿Quieres eliminar esta operación histórica?\n\n'
          '${_operationTypeLabel(operation.type)} · '
          '${_numberFormat.format(operation.amount)}\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService.deleteHistoricalOperation(operation);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operación histórica eliminada')),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la operación: $error')),
      );
    }
  }

  String _operationTypeLabel(HistoricalOperationType type) {
    switch (type) {
      case HistoricalOperationType.subscription:
        return 'Suscripción';
      case HistoricalOperationType.redemption:
        return 'Reembolso';
      case HistoricalOperationType.transferIn:
        return 'Traspaso recibido';
      case HistoricalOperationType.transferOut:
        return 'Traspaso enviado';
    }
  }

  IconData _operationTypeIcon(HistoricalOperationType type) {
    switch (type) {
      case HistoricalOperationType.subscription:
        return Icons.add_circle_outline;
      case HistoricalOperationType.redemption:
        return Icons.remove_circle_outline;
      case HistoricalOperationType.transferIn:
        return Icons.call_received;
      case HistoricalOperationType.transferOut:
        return Icons.call_made;
    }
  }

  Widget _buildOperation(HistoricalOperation operation) {
    return ListTile(
      dense: true,
      leading: Icon(_operationTypeIcon(operation.type), size: 21),
      title: Text(_operationTypeLabel(operation.type)),
      subtitle: Text(
        [
          _dateFormat.format(operation.date),
          if (operation.units != null)
            '${_numberFormat.format(operation.units)} participaciones',
          if (operation.price != null)
            'Precio: ${_numberFormat.format(operation.price)}',
          if (operation.description?.isNotEmpty == true) operation.description!,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _numberFormat.format(operation.amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          PopupMenuButton<String>(
            tooltip: 'Acciones de la operación',
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  _editOperation(operation);
                case 'delete':
                  _deleteOperation(operation);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestment(HistoricalInvestment investment) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: FutureBuilder<List<HistoricalOperation>>(
        future: DatabaseService.getHistoricalOperations(investment.uid),
        builder: (context, snapshot) {
          final operations = snapshot.data ?? [];

          return ExpansionTile(
            leading: const Icon(Icons.bar_chart),
            title: Text(
              investment.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              [
                if (investment.isin?.isNotEmpty == true) investment.isin!,
                '${operations.length} operaciones',
              ].join(' · '),
            ),
            children: [
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )
              else if (snapshot.hasError)
                const ListTile(title: Text('Error al cargar las operaciones'))
              else if (operations.isEmpty)
                const ListTile(title: Text('No hay operaciones registradas'))
              else
                ...operations.map(_buildOperation),
              if (investment.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      investment.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de inversiones')),
      body: GradientBackground(
        child: FutureBuilder<List<HistoricalInvestment>>(
          future: _investmentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No se pudo cargar el histórico'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(_loadInvestments);
                      },
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final investments = snapshot.data ?? [];

            if (investments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Todavía no hay inversiones históricas guardadas.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: investments.length,
                itemBuilder: (context, index) {
                  return _buildInvestment(investments[index]);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
