import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../providers/fund_provider.dart';
import '../services/database_service.dart';
import '../utils/historical_investment_validator.dart';
import '../widgets/gradient_background.dart';
import '../widgets/historical_investment_dialog.dart';
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
    _loadInvestments();
    setState(() {});
    await _investmentsFuture;
  }

  Future<void> _reloadPortfolio() async {
    if (!mounted) return;
    await context.read<FundProvider>().loadPortfolio();
  }

  static int _uidCounter = 0;

  String _newUid(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        '_${_uidCounter++}';
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

  Future<({List<HistoricalOperation> operations, Map<String, String> names})>
  _loadTransferData({String? excludeOperationUid}) async {
    final investments = await DatabaseService.getHistoricalInvestments();

    final groups = await Future.wait(
      investments.map(
        (investment) => DatabaseService.getHistoricalOperations(investment.uid),
      ),
    );

    final operations = groups
        .expand((group) => group)
        .where((operation) => operation.uid != excludeOperationUid)
        .toList();

    final names = {
      for (final investment in investments) investment.uid: investment.name,
    };

    return (operations: operations, names: names);
  }

  Future<void> _addOperation(HistoricalInvestment investment) async {
    final transferData = await _loadTransferData();
    if (!mounted) return;
    final draft = await showDialog<HistoricalOperationDraft>(
      context: context,
      builder: (_) => HistoricalOperationDialog(
        operation: null,
        dateFormat: _dialogDateFormat,
        pickDate: _pickDate,
        parseNumber: _parseNumber,
        validateNumber: _validateNumber,
        generateTransferUid: () => _newUid('transfer'),
        receivingInvestmentUid: investment.uid,
        transferOperations: transferData.operations,
        investmentNames: transferData.names,
      ),
    );

    if (draft == null || !mounted) return;

    try {
      final operation = HistoricalOperation(
        uid: _newUid('operation'),
        investmentUid: investment.uid,
        date: draft.date,
        type: draft.type,
        amount: draft.amount,
        units: draft.units,
        price: draft.price,
        description: draft.description,
        transferUid: draft.transferUid,
      );

      await DatabaseService.saveHistoricalOperation(operation);
      await _reloadPortfolio();

      if (!mounted) return;
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operación histórica añadida correctamente'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo añadir la operación: $error')),
      );
    }
  }

  Future<void> _editInvestment(HistoricalInvestment investment) async {
    final draft = await showDialog<HistoricalInvestmentDraft>(
      context: context,
      builder: (_) => HistoricalInvestmentDialog(investment: investment),
    );

    if (draft == null || !mounted) return;

    try {
      final updated = investment.copyWith(
        name: draft.name,
        isin: draft.isin,
        description: draft.description,
      );

      await DatabaseService.updateHistoricalInvestment(updated);
      await _reloadPortfolio();

      if (!mounted) return;
      _loadInvestments();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inversión histórica actualizada correctamente'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la inversión: $error')),
      );
    }
  }

  Future<void> _deleteInvestment(HistoricalInvestment investment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar inversión histórica'),
        content: Text(
          '¿Quieres eliminar "${investment.name}"?\n\n'
          'También se eliminarán todas las operaciones históricas '
          'asociadas a esta inversión.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService.deleteHistoricalInvestment(investment.uid);
      await _reloadPortfolio();

      if (!mounted) return;
      _loadInvestments();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inversión histórica eliminada correctamente'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint(error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la inversión: $error')),
      );
    }
  }

  Future<void> _editOperation(HistoricalOperation operation) async {
    final transferData = await _loadTransferData(
      excludeOperationUid: operation.uid,
    );
    if (!mounted) return;
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
        generateTransferUid: () => _newUid('transfer'),
        receivingInvestmentUid: operation.investmentUid,
        transferOperations: transferData.operations,
        investmentNames: transferData.names,
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

      //await DatabaseService.updateHistoricalOperation(updated);
      final operations = await DatabaseService.getHistoricalOperations(
        operation.investmentUid,
      );

      HistoricalInvestmentValidator.validateUpdate(operations, updated);

      await DatabaseService.updateHistoricalOperation(updated);
      await _reloadPortfolio();

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
      //await DatabaseService.deleteHistoricalOperation(operation);
      final operations = await DatabaseService.getHistoricalOperations(
        operation.investmentUid,
      );

      HistoricalInvestmentValidator.validateDeletion(operations, operation.uid);

      await DatabaseService.deleteHistoricalOperation(operation);
      await _reloadPortfolio();

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
      margin: const .symmetric(horizontal: 12, vertical: 6),
      child: FutureBuilder<List<HistoricalOperation>>(
        future: DatabaseService.getHistoricalOperations(investment.uid),
        builder: (context, snapshot) {
          final operations = snapshot.data ?? [];

          return ExpansionTile(
            leading: const Icon(Icons.bar_chart),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    investment.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                PopupMenuButton<String>(
                  enabled:
                      snapshot.connectionState == ConnectionState.done &&
                      !snapshot.hasError,
                  tooltip: 'Acciones de la inversión',
                  onSelected: (action) {
                    switch (action) {
                      case 'add':
                        _addOperation(investment);
                      case 'edit':
                        _editInvestment(investment);
                      case 'delete':
                        _deleteInvestment(investment);
                    }
                  },
                  itemBuilder: (context) => [
                    if (snapshot.connectionState == ConnectionState.done &&
                        !snapshot.hasError &&
                        !HistoricalInvestmentValidator.isClosed(operations))
                      const PopupMenuItem(
                        value: 'add',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.add_circle_outline),
                          title: Text('Añadir operación'),
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar inversión'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text(
                          'Eliminar inversión',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                        _loadInvestments();
                        setState(() {});
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
                padding: const .symmetric(vertical: 8),
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
