import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

//import 'package:collection/collection.dart';

import '../../models/fund_data.dart';
import '../../models/tax_simulation.dart';
import '../../providers/fund_provider.dart';
import '../../tools/tax_estimator.dart';
import '../../utils/financial_calculator.dart';

class FundOperationsList extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;
  final DateFormat dateFormat;

  const FundOperationsList({
    super.key,
    required this.fund,
    required this.priceFormat,
    required this.dateFormat,
  });

  @override
  State<FundOperationsList> createState() => _FundOperationsListState();
}

class _FundOperationsListState extends State<FundOperationsList> {
  late FundProvider provider;
  late AppLocalizations l10n;
  late String locale;
  late NumberFormat smartFormat;
  late NumberFormat unitsFormat;
  late NumberFormat moneyFormat;
  late NumberFormat percentFormat;
  late FundMetrics metrics;

  FundData? outFund;

  @override
  void initState() {
    super.initState();
    metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    provider = context.read<FundProvider>();
    l10n = AppLocalizations.of(context)!;
    locale = Localizations.localeOf(context).toString();
    smartFormat = NumberFormat('#,##0.####', locale);
    unitsFormat = NumberFormat('#,##0.####', locale);
    moneyFormat = NumberFormat('#,##0.## €', locale);
    percentFormat = NumberFormat('#,##0.00 %', locale);
  }

  @override
  void didUpdateWidget(covariant FundOperationsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    metrics = FinancialCalculator.calculateFundMetrics(widget.fund);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: provider.isBusy
                ? null
                : () => _showOperationDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.newOperation),
            /* style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ), */
          ),
        ),
        Expanded(
          child: widget.fund.operations.isEmpty
              ? Center(
                  child: Text(
                    l10n.noOperationsRegistered,
                    style: const TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  itemCount: widget.fund.operations.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final operation = widget.fund.operations[index];
                    // NOTE: ajustado a OperationType.outTransfer y inTransfer
                    //final isBuy = operation.type == OperationType.buy;
                    IconData icon = Icons.add_circle;
                    Color color = Colors.greenAccent;
                    String title = l10n.subscription;
                    String signo = '';
                    if (operation.type == OperationType.sell) {
                      icon = Icons.remove_circle;
                      color = Colors.redAccent;
                      title = l10n.redemption;
                      signo = '-';
                    } else if (operation.type == OperationType.outTransfer) {
                      icon = Icons.output_outlined;
                      color = Colors.redAccent;
                      title = l10n.outTransfer;
                      signo = '-';
                    } else if (operation.type == OperationType.inTransfer) {
                      icon = Icons.input_outlined;
                      color = Colors.greenAccent;
                      title = l10n.inTransfer;
                      signo = '';
                    }
                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        //DateFormat('dd/MM/yyyy').format(operation.date),
                        widget.dateFormat.format(operation.date),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$signo${smartFormat.format(operation.amount)} ${widget.fund.currency}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            l10n.unitsAtPrice(
                              smartFormat.format(operation.units),
                              smartFormat.format(operation.price),
                            ),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      onTap: () =>
                          _showOperationDialog(context, operation: operation),
                      onLongPress: () => _confirmDelete(context, operation),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /* Future<void> _confirmDelete(
    BuildContext context,
    FundOperation operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteOperationTitle),
        content: Text(l10n.areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && operation.id != null) {
      try {
        await provider.deleteOperation(operation.id!);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteOperationFailed),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  } */

  Future<void> _confirmDelete(
    BuildContext context,
    FundOperation operation,
  ) async {
    final isTransfer =
        operation.type == OperationType.outTransfer ||
        operation.type == OperationType.inTransfer;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteOperationTitle),
        content: Text(
          isTransfer
              ? '${l10n.areYouSure}\n\n'
                    'Solo se eliminará esta mitad del traspaso. '
                    'La operación del otro fondo permanecerá intacta.'
              : l10n.areYouSure,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && operation.id != null) {
      try {
        await provider.deleteOperation(operation.id!);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteOperationFailed),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteEditedOperation(
    BuildContext context,
    BuildContext dialogContext,
    FundOperation operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (confirmationContext) => AlertDialog(
        title: Text(l10n.deleteOperationTitle),
        content: Text(l10n.deleteOperationConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(confirmationContext, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || operation.id == null || provider.isBusy) return;

    try {
      await provider.deleteOperation(operation.id!);
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.operationDeletedSuccess),
          duration: const Duration(seconds: 4),
          action:
              (operation.type == OperationType.outTransfer ||
                  operation.type == OperationType.inTransfer)
              ? null
              : SnackBarAction(
                  label: l10n.undo,
                  onPressed: () async {
                    try {
                      await provider.restoreOperation(operation);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.deletionUndone),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.restoreOperationError),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                ),
        ),
      );
      /* Future<void>.delayed(
        const Duration(seconds: 4),
        snackBarController.close,
      ); */
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteOperationError),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _saveOperation(
    BuildContext dialogContext,
    FundOperation operation, {
    FundOperation? operation2,
  }) async {
    if (provider.isBusy) return;

    try {
      await provider.addOperation(operation, op2: operation2);
      if (dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
    } catch (_) {
      if (dialogContext.mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          SnackBar(
            content: Text(l10n.saveOperationFailed),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Muestra el diálogo con los resultados del TaxEstimatorService
  void _showFiscalSimulationResult(
    BuildContext context,
    FundData fund,
    double units,
    double price,
    double taxRate,
    DateTime selectedDate,
  ) {
    // Instanciamos el servicio Tax Estimator
    final estimator = TaxEstimator();

    final request = TaxSimulation(
      fund: fund,
      amount: units, // Usamos las participaciones para el cálculo FIFO
      isSharesInput: true, // Indicamos que el 'amount' son participaciones
      taxRate: taxRate,
      targetNav: price, // El precio al que se simula la venta
    );

    final result = estimator.calculate(request);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.blue),
            SizedBox(width: 8),
            Text('Estimación Fiscal (FIFO)'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.warningMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.warningMessage!,
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildInfoRow(
                'Participaciones a vender',
                unitsFormat.format(result.soldShares),
              ),
              _buildInfoRow(
                'Valor de reembolso (Bruto)',
                moneyFormat.format(result.saleValue),
              ),
              _buildInfoRow(
                'Coste de adquisición',
                moneyFormat.format(result.acquisitionCost),
              ),
              const Divider(height: 24),
              _buildInfoRow(
                'Plusvalía estimada',
                moneyFormat.format(result.capitalGain),
                isPositive: result.capitalGain >= 0,
              ),
              _buildInfoRow(
                'Impuesto estimado (${percentFormat.format(taxRate / 100)})',
                '- ${moneyFormat.format(result.estimatedTax)}',
                isNegative: true,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                //'NETO A PERCIBIR',
                l10n.netProfitEstLabel,
                moneyFormat.format(result.netAmount),
                isBold: true,
              ),
              const SizedBox(height: 16),
              Text(
                //'* Estimación orientativa basada en el método FIFO.
                // No constituye asesoramiento fiscal profesional.',
                l10n.fifoDisclaimer,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Cierra el diálogo de simulación
              await _saveOperation(
                context, // Contexto del diálogo de operación
                FundOperation(
                  isin: fund.isin,
                  date: selectedDate,
                  type: OperationType.sell,
                  units: units,
                  price: price,
                  amount: units * price,
                ),
              );
            },
            child: Text(l10n.registerSaleAction),
          ),
        ],
      ),
    );
  }

  // Helper para construir las filas de información de forma consistente
  Widget _buildInfoRow(
    String label,
    String value, {
    bool isPositive = false,
    bool isNegative = false,
    bool isBold = false,
  }) {
    Color? textColor;
    if (isPositive) textColor = Colors.green.shade700;
    if (isNegative) textColor = Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white60),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showOperationDialog(
    BuildContext context, {
    FundOperation? operation,
  }) async {
    final isTransfer =
        operation?.type == OperationType.outTransfer ||
        operation?.type == OperationType.inTransfer;

    DateTime selectedDate = operation?.date ?? DateTime.now();
    OperationType selectedType = operation?.type ?? OperationType.buy;

    DateTime selectedDate2 = selectedDate;

    // Estado para controlar la visibilidad y lógica de la simulación
    bool isFiscalSimulation = false;
    String? dialogError;

    final unitsController = TextEditingController(
      text: operation?.units.toString().replaceAll('.', ',') ?? '',
    );

    final priceController = TextEditingController(
      text:
          operation?.price.toString().replaceAll('.', ',') ??
          //widget.fund.lastValue.toString().replaceAll('.', ','),
          widget.fund
              .pointByDate(selectedDate)
              ?.price
              .toString()
              .replaceAll('.', ',') ??
          '0',
    );

    final amountController = TextEditingController(
      text: operation?.amount.toString().replaceAll('.', ',') ?? '',
    );
    final taxRateController = TextEditingController(text: '19.0');

    void updateAmount() {
      final units =
          double.tryParse(unitsController.text.replaceAll(',', '.')) ?? 0;
      final price =
          double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
      if (units > 0 && price > 0) {
        amountController.text = (units * price).toString().replaceAll('.', ',');
      }
    }

    void updateUnits() {
      final amount =
          double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
      final price =
          double.tryParse(priceController.text.replaceAll(',', '.')) ?? 0;
      if (amount > 0 && price > 0) {
        unitsController.text = (amount / price)
            .toStringAsFixed(6)
            .replaceAll('.', ',');
      }
    }

    final priceController2 = TextEditingController(text: '0');
    final unitsController2 = TextEditingController(text: '0');
    final amountController2 = TextEditingController(
      text: amountController.text,
    );
    void updateTranfer() {
      if (outFund == null) return;

      amountController2.text = amountController.text;
      double? price2 = outFund!.pointByDate(selectedDate2)?.price;

      if (price2 != null) {
        priceController2.text = price2.toString().replaceAll('.', ',');
        final amount =
            double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
        if (amount > 0 && price2 > 0) {
          unitsController2.text = (amount / price2)
              .toStringAsFixed(6)
              .replaceAll('.', ',');
        }
      } else {
        priceController2.text = '0';
        unitsController2.text = '0';
      }
    }

    // Diálogo de Nueva Operación: Compra / Venta / Traspaso
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (formContext, setState) => Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                operation == null
                    ? (isFiscalSimulation
                          ? l10n.fiscalSimulationTitle
                          : l10n.newOperation)
                    : (operation.type == OperationType.outTransfer ||
                          operation.type == OperationType.inTransfer)
                    ? 'Los traspasos no admiten edición'
                    : l10n.editOperation,
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: .all(14),
                child: Column(
                  children: [
                    if (dialogError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<OperationType>(
                            // NOTE: ajustado a OperationType.outTransfer y inTransfer
                            segments: [
                              ButtonSegment(
                                value: OperationType.buy,
                                label: Text(l10n.buy),
                                enabled: operation == null,
                                //enabled: isTransfer,
                              ),
                              ButtonSegment(
                                value: OperationType.sell,
                                label: Text(l10n.sell),
                                enabled: operation == null,
                                //enabled: isTransfer,
                              ),
                              ButtonSegment(
                                value: OperationType.outTransfer,
                                label: Text(l10n.transfer),
                                enabled: operation == null,
                                //enabled: isTransfer,
                              ),
                            ],
                            selected: {selectedType},
                            onSelectionChanged: (selection) => setState(() {
                              selectedType = selection.first;
                              dialogError = null;
                              // Si cambia a Compra, desactivamos la simulación fiscal
                              if (selectedType == OperationType.buy ||
                                  selectedType == OperationType.outTransfer) {
                                isFiscalSimulation = false;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Checkbox de simulación fiscal (solo visible en Venta y si es operación nueva)
                    if (selectedType == OperationType.sell &&
                        operation == null) ...[
                      CheckboxListTile(
                        title: Text(l10n.fiscalSimulationTitle),
                        subtitle: Text(
                          l10n.fiscalSimulationDesc,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        value: isFiscalSimulation,
                        onChanged: (value) {
                          setState(() {
                            isFiscalSimulation = value ?? false;
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        secondary: isFiscalSimulation == true
                            ? SizedBox(
                                width: 75,
                                child: TextField(
                                  controller: taxRateController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Tax %',
                                    isDense: true,
                                  ),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // FECHA 1
                    ListTile(
                      contentPadding: .all(0),
                      title: Text(l10n.dateLabel),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(selectedDate),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: isTransfer
                          ? null
                          : () async {
                              final picked = await showDatePicker(
                                context: formContext,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked == null) return;
                              if (!formContext.mounted) return;
                              setState(() {
                                selectedDate = picked;
                                if (operation == null) {
                                  final historicalPoint = widget.fund
                                      .pointByDate(picked);
                                  if (historicalPoint != null) {
                                    priceController.text = historicalPoint.price
                                        .toString()
                                        .replaceAll('.', ',');
                                    updateAmount();
                                  } else {
                                    priceController.text = '0';
                                    updateAmount();
                                  }
                                }
                              });
                            },
                    ),

                    TextField(
                      readOnly: isTransfer,
                      controller: priceController,
                      decoration: InputDecoration(
                        labelText: l10n.priceNavLabel,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => updateAmount(),
                    ),
                    TextField(
                      readOnly: isTransfer,
                      controller: unitsController,
                      decoration: InputDecoration(
                        labelText: l10n.unitsLabel,
                        helper:
                            selectedType == OperationType.sell ||
                                selectedType == OperationType.outTransfer
                            ? Text(
                                'Max: ${unitsFormat.format(metrics.totalUnits)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => updateAmount(),
                    ),
                    TextField(
                      readOnly: isTransfer,
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: l10n.totalAmountLabel,
                        helper:
                            selectedType == OperationType.sell ||
                                selectedType == OperationType.outTransfer
                            ? Text(
                                'Max: ${smartFormat.format(metrics.currentValue)} ${widget.fund.currency}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              )
                            : SizedBox.shrink(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => updateUnits(),
                    ),

                    // DATOS TRASPASO DE ENTRADA
                    if (selectedType == OperationType.outTransfer &&
                        operation == null &&
                        provider.portfolio.length > 1) ...[
                      const SizedBox(height: 16),
                      DropdownMenu<FundData>(
                        width: double.infinity,
                        label: const Text('Destino'),
                        hintText: 'Selecciona un fondo',
                        requestFocusOnTap: false,
                        dropdownMenuEntries: provider.portfolio
                            .map<DropdownMenuEntry<FundData>>((FundData fondo) {
                              return DropdownMenuEntry<FundData>(
                                value: fondo,
                                label: fondo.name,
                                enabled: fondo != widget.fund,
                              );
                            })
                            .toList(),
                        onSelected: (FundData? destino) {
                          setState(() {
                            outFund = destino;
                            updateTranfer();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: .all(0),
                        title: Text('Fecha Entrada'),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(selectedDate2),
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: formContext,
                            initialDate: selectedDate,
                            firstDate: selectedDate,
                            lastDate: DateTime.now(),
                          );
                          if (picked == null) return;
                          if (!formContext.mounted) return;
                          setState(() {
                            selectedDate2 = picked;
                            if (operation == null) {
                              final historicalPoint = widget.fund.pointByDate(
                                picked,
                              );
                              if (historicalPoint != null) {
                                priceController.text = historicalPoint.price
                                    .toString()
                                    .replaceAll('.', ',');
                                //updateAmount();
                                //updateTranfer();
                              } else {
                                priceController.text = '0';
                              }
                              updateTranfer();
                            }
                          });
                        },
                      ),
                      TextField(
                        controller: priceController2,
                        decoration: InputDecoration(
                          labelText: l10n.priceNavLabel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        //onChanged: (_) => updateAmount(),
                        onChanged: (_) => updateTranfer(),
                      ),

                      TextField(
                        controller: unitsController2,
                        decoration: InputDecoration(labelText: l10n.unitsLabel),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        //onChanged: (_) => updateAmount(),
                        onChanged: (_) => updateTranfer(),
                      ),

                      TextField(
                        controller: amountController2,
                        decoration: InputDecoration(
                          labelText: l10n.totalAmountLabel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        //onChanged: (_) => updateUnits(),
                        onChanged: (_) => updateTranfer(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            persistentFooterDecoration: BoxDecoration(color: Colors.black54),
            persistentFooterButtons: [
              Row(
                mainAxisAlignment: .spaceAround,
                children: [
                  if (operation != null)
                    TextButton(
                      onPressed: provider.isBusy
                          ? null
                          : () => _deleteEditedOperation(
                              context,
                              dialogContext,
                              operation,
                            ),
                      child: Text(
                        l10n.delete,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(l10n.cancel),
                  ),

                  if (operation != null && !isTransfer)
                    ElevatedButton(
                      onPressed: () async {
                        final units =
                            double.tryParse(
                              unitsController.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final price =
                            double.tryParse(
                              priceController.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final amount =
                            double.tryParse(
                              amountController.text.replaceAll(',', '.'),
                            ) ??
                            0;

                        // NOTE: ajustado a OperationType.outTransfer y inTransfer
                        final units2 =
                            double.tryParse(
                              unitsController2.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final price2 =
                            double.tryParse(
                              priceController2.text.replaceAll(',', '.'),
                            ) ??
                            0;
                        final amount2 =
                            double.tryParse(
                              amountController2.text.replaceAll(',', '.'),
                            ) ??
                            0;

                        if (selectedType == OperationType.sell ||
                            selectedType == OperationType.outTransfer) {
                          if (units <= 0 && amount <= 0) {
                            setState(() {
                              dialogError = l10n.specifyUnitsOrAmountError;
                            });
                            return;
                          }
                        }

                        if (units <= 0 || price <= 0 || amount <= 0) {
                          setState(() {
                            dialogError =
                                l10n.allNumericFieldsGreaterThanZeroError;
                          });
                          return;
                        }

                        if (selectedType == OperationType.outTransfer) {
                          if (units2 <= 0 || price2 <= 0 || amount2 <= 0) {
                            setState(() {
                              dialogError =
                                  l10n.allNumericFieldsGreaterThanZeroError;
                            });
                            return;
                          }
                        }

                        if (selectedType == OperationType.sell ||
                            selectedType == OperationType.outTransfer) {
                          if (units > metrics.totalUnits + 0.00001) {
                            setState(() {
                              dialogError = l10n.cannotSellMoreThanOwnedError;
                            });
                            return;
                          }
                          if (amount > metrics.currentValue + 0.01) {
                            setState(() {
                              dialogError =
                                  l10n.saleAmountExceedsCurrentValueError;
                            });
                            return;
                          }
                        }

                        if (selectedType == OperationType.outTransfer &&
                            outFund == null) {
                          setState(() {
                            dialogError =
                                'Selecciona el fondo destino para el traspaso';
                          });
                          return;
                        }

                        // Si es simulación, mostramos el resultado y salimos sin guardar
                        if (isFiscalSimulation) {
                          final taxRate =
                              double.tryParse(
                                taxRateController.text.replaceAll(',', '.'),
                              ) ??
                              19.0;
                          _showFiscalSimulationResult(
                            dialogContext,
                            widget.fund,
                            units,
                            price,
                            taxRate,
                            selectedDate,
                          );
                          return;
                        }
                        // Lógica de guardado (solo se ejecuta si NO es simulación)
                        if (outFund == null) {
                          await _saveOperation(
                            dialogContext,
                            FundOperation(
                              id: operation?.id,
                              isin: widget.fund.isin,
                              date: selectedDate,
                              type: selectedType,
                              units: units,
                              price: price,
                              amount: amount,
                            ),
                          );
                        } else if (outFund != null && context.mounted) {
                          await _saveOperation(
                            dialogContext,
                            FundOperation(
                              id: operation?.id,
                              isin: widget.fund.isin,
                              date: selectedDate,
                              type: selectedType,
                              units: units,
                              price: price,
                              amount: amount,
                            ),
                            operation2: FundOperation(
                              id: operation?.id,
                              isin: outFund!.isin,
                              date: selectedDate2,
                              type: OperationType.inTransfer,
                              units: units2,
                              price: price2,
                              amount: amount2,
                            ),
                          );
                        }
                      },
                      //child: Text(l10n.save),
                      child: Text(
                        isFiscalSimulation
                            ? l10n.calculateEstimationAction
                            : l10n.save,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
