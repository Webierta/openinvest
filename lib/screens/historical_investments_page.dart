import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../providers/fund_provider.dart';
import '../services/database_service.dart';
import '../utils/financial_calculator.dart';
import '../utils/historical_investment_validator.dart';
import '../widgets/gradient_background.dart';
import '../widgets/historical_investment_dialog.dart';
import '../widgets/historical_operation_dialog.dart';

typedef _HistoricalPageData = ({
  List<HistoricalInvestment> investments,
  List<HistoricalOperation> operations,
  Map<String, List<HistoricalOperation>> operationsByInvestment,
  Map<String, String> names,
  Map<String, HistoricalOperation> counterparts,
});

class HistoricalInvestmentsPage extends StatefulWidget {
  const HistoricalInvestmentsPage({super.key});

  @override
  State<HistoricalInvestmentsPage> createState() =>
      _HistoricalInvestmentsPageState();
}

class _HistoricalInvestmentsPageState extends State<HistoricalInvestmentsPage> {
  late Future<_HistoricalPageData> _pageDataFuture;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;
  String get _locale => Localizations.localeOf(context).toString();
  NumberFormat get _numberFormat => NumberFormat('#,##0.00', _locale);
  DateFormat get _dateFormat => DateFormat('dd/MM/yyyy', _locale);

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
  }

  Future<_HistoricalPageData> _loadPageData() async {
    final investments = await DatabaseService.getHistoricalInvestments();
    final groups = await Future.wait(
      investments.map(
        (investment) => DatabaseService.getHistoricalOperations(investment.uid),
      ),
    );

    final operationsByInvestment = {
      for (var i = 0; i < investments.length; i++)
        investments[i].uid: groups[i],
    };

    final operations = groups.expand((group) => group).toList();

    final names = {
      for (final investment in investments) investment.uid: investment.name,
    };

    final counterparts =
        FinancialCalculator.resolveHistoricalTransferCounterparts(
          operations,
          investments.map((investment) => investment.uid).toSet(),
        );

    return (
      investments: investments,
      operations: operations,
      operationsByInvestment: operationsByInvestment,
      names: names,
      counterparts: counterparts,
    );
  }

  Future<void> _refresh() async {
    final future = _loadPageData();
    setState(() {
      _pageDataFuture = future;
    });
    await future;
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
      final localizedLabel = switch (label) {
        'importe' => _l10n.amountLabel,
        'número de participaciones' => _l10n.unitsLabel,
        'precio' => _l10n.priceLabel,
        _ => label,
      };
      return _l10n.enterValidNumber(localizedLabel);
    }

    return null;
  }

  Future<DateTime?> _pickDate(DateTime initialDate) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: _l10n.operationDateLabel,
      cancelText: _l10n.cancel,
      confirmText: _l10n.accept,
    );
  }

  Future<({List<HistoricalOperation> operations, Map<String, String> names})>
  _loadTransferData({String? excludeOperationUid}) async {
    final data = await _pageDataFuture;

    final operations = data.operations
        .where((operation) => operation.uid != excludeOperationUid)
        .toList();

    return (operations: operations, names: data.names);
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
        sourceInvestmentName: investment.name,
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
      setState(() {
        _pageDataFuture = _loadPageData();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.historicalOperationAdded)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.historicalOperationAddError('$error'))),
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
      setState(() {
        _pageDataFuture = _loadPageData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.historicalInvestmentUpdated)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.historicalInvestmentUpdateError('$error')),
        ),
      );
    }
  }

  Future<void> _deleteInvestment(HistoricalInvestment investment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.deleteHistoricalInvestmentTitle),
        content: Text(_l10n.deleteHistoricalInvestmentConfirm(investment.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(_l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await DatabaseService.deleteHistoricalInvestment(investment.uid);
      await _reloadPortfolio();

      if (!mounted) return;
      setState(() {
        _pageDataFuture = _loadPageData();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.historicalInvestmentDeleted)),
      );
    } catch (error) {
      if (!mounted) return;
      debugPrint(error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n.historicalInvestmentDeleteError('$error')),
        ),
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
        sourceInvestmentName:
            transferData.names[operation.investmentUid] ??
            operation.investmentUid,
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

      final operations = await DatabaseService.getHistoricalOperations(
        operation.investmentUid,
      );

      HistoricalInvestmentValidator.validateUpdate(operations, updated);

      await DatabaseService.updateHistoricalOperation(updated);
      await _reloadPortfolio();

      if (!mounted) return;
      setState(() {
        _pageDataFuture = _loadPageData();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.historicalOperationUpdated)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.historicalOperationUpdateError('$error'))),
      );
    }
  }

  Future<void> _deleteOperation(HistoricalOperation operation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_l10n.deleteOperationTitle),
        content: Text(
          _l10n.deleteHistoricalOperationConfirm(
            _operationTypeLabel(operation.type),
            _numberFormat.format(operation.amount),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(_l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final operations = await DatabaseService.getHistoricalOperations(
        operation.investmentUid,
      );

      HistoricalInvestmentValidator.validateDeletion(operations, operation.uid);

      await DatabaseService.deleteHistoricalOperation(operation);
      await _reloadPortfolio();

      if (!mounted) return;
      setState(() {
        _pageDataFuture = _loadPageData();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.historicalOperationDeleted)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_l10n.historicalOperationDeleteError('$error'))),
      );
    }
  }

  String _operationTypeLabel(HistoricalOperationType type) {
    switch (type) {
      case .subscription:
        return _l10n.subscription;
      case .redemption:
        return _l10n.redemption;
      case .transferIn:
        return _l10n.receivedTransfer;
      case .transferOut:
        return _l10n.sentTransfer;
    }
  }

  IconData _operationTypeIcon(HistoricalOperationType type) {
    switch (type) {
      case .subscription:
        return Icons.add_circle_outline;
      case .redemption:
        return Icons.remove_circle_outline;
      case .transferIn:
        return Icons.call_received;
      case .transferOut:
        return Icons.call_made;
    }
  }

  Widget _buildOperation(
    HistoricalOperation operation,
    _HistoricalPageData data,
  ) {
    final counterpart = data.counterparts[operation.uid];
    final counterpartName = counterpart == null
        ? null
        : data.names[counterpart.investmentUid];

    return ListTile(
      dense: true,
      leading: Icon(_operationTypeIcon(operation.type), size: 21),
      title: Text(_operationTypeLabel(operation.type)),
      subtitle: Text(
        [
          _dateFormat.format(operation.date),
          if (operation.units != null)
            _l10n.unitsPartsFormat(_numberFormat.format(operation.units)),
          if (operation.price != null)
            _l10n.operationPriceLabel(_numberFormat.format(operation.price)),
          if (operation.description?.isNotEmpty == true) operation.description!,
          if (counterpartName != null &&
              operation.type == HistoricalOperationType.transferOut)
            _l10n.transferToLabel(counterpartName),
          if (counterpartName != null &&
              operation.type == HistoricalOperationType.transferIn)
            _l10n.transferFromLabel(counterpartName),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: .min,
        children: [
          Text(
            _numberFormat.format(operation.amount),
            style: const TextStyle(fontWeight: .w600),
          ),
          PopupMenuButton<String>(
            tooltip: _l10n.operationActionsTooltip,
            onSelected: (action) {
              switch (action) {
                case 'edit':
                  _editOperation(operation);
                case 'delete':
                  _deleteOperation(operation);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.edit_outlined),
                  title: Text(_l10n.editOperation),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(_l10n.delete),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestment(
    HistoricalInvestment investment,
    _HistoricalPageData data,
  ) {
    final operations = data.operationsByInvestment[investment.uid] ?? [];
    final isClosed = HistoricalInvestmentValidator.isClosed(operations);

    return Card(
      margin: const .symmetric(horizontal: 12, vertical: 6),
      child: ExpansionTile(
        leading: const Icon(Icons.bar_chart),
        title: Row(
          children: [
            Expanded(
              child: Text(
                investment.name,
                style: const TextStyle(fontWeight: .w600),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: _l10n.investmentActionsTooltip,
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
                if (!isClosed)
                  PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.add_circle_outline),
                      title: Text(_l10n.addOperationTooltip),
                    ),
                  ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text(_l10n.editHistoricalInvestment),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text(
                      _l10n.deleteHistoricalInvestmentAction,
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
            _l10n.historicalOperationsCount(operations.length),
          ].join(' · '),
        ),
        children: [
          if (operations.isEmpty)
            ListTile(title: Text(_l10n.noHistoricalOperationsRegistered))
          else
            ...operations.map((operation) => _buildOperation(operation, data)),

          if (investment.description?.isNotEmpty == true)
            Padding(
              padding: const .fromLTRB(16, 8, 16, 16),
              child: Align(
                alignment: .centerLeft,
                child: Text(
                  investment.description!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_l10n.historicalInvestmentsTitle)),
      body: GradientBackground(
        child: FutureBuilder<_HistoricalPageData>(
          future: _pageDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == .waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    Text(_l10n.historicalInvestmentsLoadError),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _pageDataFuture = _loadPageData();
                        });
                      },
                      child: Text(_l10n.retry),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final investments = data.investments;

            if (investments.isEmpty) {
              return Center(
                child: Padding(
                  padding: .all(24),
                  child: Text(
                    _l10n.noHistoricalInvestmentsSaved,
                    textAlign: .center,
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
                  final investment = investments[index];
                  return _buildInvestment(investment, data);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
