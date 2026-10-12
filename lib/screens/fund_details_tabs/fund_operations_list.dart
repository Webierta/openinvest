import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/fund_data.dart';
import '../../models/tax_simulation.dart';
import '../../providers/fund_provider.dart';
import '../../tools/tax_estimator.dart';
import '../../utils/financial_calculator.dart';

class FundOperationsList extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;

  const FundOperationsList({
    super.key,
    required this.fund,
    required this.priceFormat,
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
  late NumberFormat percentFormat ;
  late FundMetrics metrics;

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
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
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
                    final isBuy = operation.type == OperationType.buy;
                    return ListTile(
                      leading: Icon(
                        isBuy ? Icons.add_circle : Icons.remove_circle,
                        color: isBuy
                            ? Colors.greenAccent[400]
                            : Colors.redAccent[200],
                      ),
                      title: Text(
                        isBuy ? l10n.subscription : l10n.redemption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(operation.date),
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
                            '${isBuy ? '' : '-'}${smartFormat.format(operation.amount)} ${widget.fund.currency}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isBuy
                                  ? Colors.greenAccent[400]
                                  : Colors.redAccent[200],
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

  Future<void> _confirmDelete(
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
      final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.operationDeletedSuccess),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
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
      Future<void>.delayed(
        const Duration(seconds: 4),
        snackBarController.close,
      );
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
    FundOperation operation,
  ) async {
    if (provider.isBusy) return;
    try {
      await provider.addOperation(operation);
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
    DateTime selectedDate = operation?.date ?? DateTime.now();
    OperationType selectedType = operation?.type ?? OperationType.buy;

    // Estado para controlar la visibilidad y lógica de la simulación
    bool isFiscalSimulation = false;
    String? dialogError;

    final unitsController = TextEditingController(
      text: operation?.units.toString().replaceAll('.', ',') ?? '',
    );
    final priceController = TextEditingController(
      text:
          operation?.price.toString().replaceAll('.', ',') ??
          widget.fund.lastValue.toString().replaceAll('.', ','),
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

    // Diálogo de Nueva Operación: Compra / Venta
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (formContext, setState) => AlertDialog(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(formContext).size.width - 40,
            maxWidth: MediaQuery.of(formContext).size.width - 40,
          ),
          title: Text(
            operation == null
                ? (isFiscalSimulation ? l10n.fiscalSimulationTitle : l10n.newOperation)
                : l10n.editOperation,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        segments: [
                          ButtonSegment(
                            value: OperationType.buy,
                            label: Text(l10n.buy),
                          ),
                          ButtonSegment(
                            value: OperationType.sell,
                            label: Text(l10n.sell),
                          ),
                        ],
                        selected: {selectedType},
                        onSelectionChanged: (selection) => setState(() {
                          selectedType = selection.first;
                          dialogError = null;
                          // Si cambia a Compra, desactivamos la simulación fiscal
                          if (selectedType == OperationType.buy) {
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
                              keyboardType: const TextInputType.numberWithOptions(
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
                ListTile(
                  title: Text(l10n.dateLabel),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
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
                        final historicalPoint = widget.fund.history
                            .cast<PricePoint?>()
                            .firstWhere(
                              (point) =>
                                  point!.date.year == picked.year &&
                                  point.date.month == picked.month &&
                                  point.date.day == picked.day,
                              orElse: () => null,
                            );
                        if (historicalPoint != null) {
                          priceController.text = historicalPoint.price
                              .toString()
                              .replaceAll('.', ',');
                          updateAmount();
                        }
                      }
                    });
                  },
                ),
                TextField(
                  controller: priceController,
                  decoration: InputDecoration(labelText: l10n.priceNavLabel),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => updateAmount(),
                ),
                TextField(
                  controller: unitsController,
                  decoration: InputDecoration(
                    labelText: l10n.unitsLabel,
                    helper: selectedType == OperationType.sell
                        ? Text(
                            'Max: ${unitsFormat.format(metrics.totalUnits)}',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          )
                        : SizedBox.shrink(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => updateAmount(),
                ),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: l10n.totalAmountLabel,
                    helper: selectedType == OperationType.sell
                        ? Text(
                            'Max: ${smartFormat.format(metrics.profitAbs)} ${widget.fund.currency}',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          )
                        : SizedBox.shrink(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => updateUnits(),
                ),
              ],
            ),
          ),
          actions: [
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
                if (selectedType == OperationType.sell) {
                  if (units <= 0 && amount <= 0) {
                    setState(() {
                      dialogError = l10n.specifyUnitsOrAmountError;
                    });
                    return;
                  }
                }

                if (units <= 0 || price <= 0 || amount <= 0) {
                  setState(() {
                    dialogError = l10n.allNumericFieldsGreaterThanZeroError;
                  });
                  return;
                }

                if (selectedType == OperationType.sell) {
                  if (units > metrics.totalUnits + 0.00001) {
                    setState(() {
                      dialogError = l10n.cannotSellMoreThanOwnedError;
                    });
                    return;
                  }
                  if (amount > metrics.currentValue + 0.01) {
                    setState(() {
                      dialogError = l10n.saleAmountExceedsCurrentValueError;
                    });
                    return;
                  }
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
              },
              //child: Text(l10n.save),
              child: Text(
                isFiscalSimulation ? l10n.calculateEstimationAction : l10n.save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
