import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/fund_data.dart';
import '../../models/tax_simulation.dart';
import '../../providers/fund_provider.dart';
import '../../tools/tax_estimator.dart';
import '../../utils/financial_calculator.dart';
import '../../widgets/gradient_background.dart';

class FundOperationFormPage extends StatefulWidget {
  final FundData fund;
  final FundOperation? operation;

  const FundOperationFormPage({super.key, required this.fund, this.operation});

  @override
  State<FundOperationFormPage> createState() => _FundOperationFormPageState();
}

class _FundOperationFormPageState extends State<FundOperationFormPage> {
  late FundProvider provider;

  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String get locale => Localizations.localeOf(context).toString();
  NumberFormat get smartFormat => NumberFormat('#,##0.####', locale);
  NumberFormat get unitsFormat => NumberFormat('#,##0.####', locale);
  NumberFormat get moneyFormat => NumberFormat('#,##0.## €', locale);
  NumberFormat get percentFormat => NumberFormat('#,##0.00 %', locale);
  //NumberFormat get priceFormat => NumberFormat('#,##0.0000', locale);

  bool isTransfer = false;
  DateTime selectedDate = DateTime.now();
  DateTime selectedDate2 = DateTime.now();
  OperationType selectedType = OperationType.buy;
  bool isFiscalSimulation = false;
  String? dialogError;

  double maxUnits = 0;
  double maxAmount = 0;

  FundData? outFund;

  final taxRateController = TextEditingController(text: '19.0');

  final unitsController = TextEditingController();
  final priceController = TextEditingController();
  final amountController = TextEditingController();

  final priceController2 = TextEditingController(text: '0');
  final unitsController2 = TextEditingController(text: '0');
  final amountController2 = TextEditingController();

  @override
  void initState() {
    isTransfer =
        widget.operation?.type == OperationType.outTransfer ||
        widget.operation?.type == OperationType.inTransfer;
    selectedDate = widget.operation?.date ?? DateTime.now();
    selectedDate2 = selectedDate;
    selectedType = widget.operation?.type ?? OperationType.buy;
    unitsController.text =
        widget.operation?.units.toString().replaceAll('.', ',') ?? '';
    priceController.text =
        widget.operation?.price.toString().replaceAll('.', ',') ??
        widget.fund
            .pointByDate(selectedDate)
            ?.price
            .toString()
            .replaceAll('.', ',') ??
        '0';
    amountController.text =
        widget.operation?.amount.toString().replaceAll('.', ',') ?? '';

    amountController2.text = amountController.text;

    if (widget.operation == null) {
      final initialPrice = getPrice(selectedDate) ?? 0;
      maxUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        widget.fund,
        selectedDate,
      );
      maxAmount = maxUnits * initialPrice;
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    provider = context.read<FundProvider>();
  }

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

  double? getPrice(DateTime fecha) {
    final historicalPoint = widget.fund.pointByDate(fecha);
    final price = historicalPoint?.price;
    if (historicalPoint != null) {
      priceController.text = price.toString().replaceAll('.', ',');
    }
    return price;
  }

  void updateMaxValues(DateTime fecha, double price) {
    final partes = FinancialCalculator.calculateMaxOutflowUnitsAt(
      widget.fund,
      fecha,
    );
    final capital = partes * price;
    setState(() {
      maxUnits = partes;
      maxAmount = capital;
    });
  }

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

  @override
  Widget build(BuildContext context) {
    provider = context.read<FundProvider>();
    return GradientBackground(
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.operation == null
                  ? (isFiscalSimulation
                        ? l10n.fiscalSimulationTitle
                        : l10n.newOperation)
                  : (widget.operation!.type == .outTransfer ||
                        widget.operation!.type == .inTransfer)
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
                      padding: const .all(10),
                      margin: const .only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        borderRadius: .circular(8),
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
                              enabled: widget.operation == null,
                              //enabled: isTransfer,
                            ),
                            ButtonSegment(
                              value: OperationType.sell,
                              label: Text(l10n.sell),
                              enabled: widget.operation == null,
                              //enabled: isTransfer,
                            ),
                            ButtonSegment(
                              value: OperationType.outTransfer,
                              label: Text(l10n.transfer),
                              enabled: widget.operation == null,
                              //enabled: isTransfer,
                            ),
                          ],
                          selected: {selectedType},
                          onSelectionChanged: (selection) => setState(() {
                            selectedType = selection.first;
                            unitsController.text = '';
                            amountController.text = '';
                            dialogError = null;
                            // Si cambia a Compra, desactivamos la simulación fiscal
                            if (selectedType == .buy ||
                                selectedType == .outTransfer) {
                              isFiscalSimulation = false;
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Checkbox de simulación fiscal
                  // (solo visible en Venta y si es operación nueva)
                  if (selectedType == .sell && widget.operation == null) ...[
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
                      controlAffinity: .leading,
                      contentPadding: .zero,
                      secondary: isFiscalSimulation == true
                          ? SizedBox(
                              width: 75,
                              child: TextField(
                                controller: taxRateController,
                                keyboardType: const .numberWithOptions(
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
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked == null) return;
                            if (!context.mounted) return;
                            setState(() {
                              selectedDate = picked;
                              if (widget.operation == null) {
                                final price = getPrice(picked);
                                if (price != null) {
                                  updateMaxValues(picked, price);
                                } else {
                                  priceController.text = '0';
                                  unitsController.text = '0';
                                  updateMaxValues(picked, 0);
                                }
                                updateAmount();
                              }
                            });
                          },
                  ),
                  // PRECIO (valor liquidativo)
                  TextField(
                    readOnly: isTransfer,
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: l10n.priceNavLabel,
                      helper:
                          priceController.text == '0' ||
                              priceController.text.isEmpty
                          ? Text(
                              'Valor liquidativo no encontrado. Actualiza el fondo o '
                              'introduce el precio manualmente.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            )
                          : SizedBox.shrink(),
                    ),
                    keyboardType: const .numberWithOptions(decimal: true),
                    onChanged: (_) {
                      amountController.text.replaceAll('.', ',');
                      updateMaxValues(
                        selectedDate,
                        double.tryParse(
                              priceController.text.replaceAll(',', '.'),
                            ) ??
                            0,
                      );
                      updateAmount();
                      setState(() {});
                    },
                  ),
                  // PARTICIPACIONES
                  TextField(
                    readOnly: isTransfer,
                    controller: unitsController,
                    decoration: InputDecoration(
                      labelText: l10n.unitsLabel,
                      helper:
                          selectedType == .sell || selectedType == .outTransfer
                          ? Text(
                              'Max: ${unitsFormat.format(maxUnits)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            )
                          : SizedBox.shrink(),
                    ),
                    keyboardType: const .numberWithOptions(decimal: true),
                    onChanged: (_) => updateAmount(),
                  ),
                  // RENDIMIENTO (resultado precio * participaciones)
                  TextField(
                    readOnly: isTransfer,
                    controller: amountController,
                    decoration: InputDecoration(
                      labelText: l10n.totalAmountLabel,
                      helper:
                          selectedType == .sell || selectedType == .outTransfer
                          ? Text(
                              'Max: ${moneyFormat.format(maxAmount)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            )
                          : SizedBox.shrink(),
                    ),
                    keyboardType: const .numberWithOptions(decimal: true),
                    onChanged: (_) => updateUnits(),
                  ),

                  // DATOS TRASPASO DE ENTRADA
                  if (selectedType == .outTransfer &&
                      widget.operation == null &&
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
                          context: context,
                          initialDate: selectedDate,
                          firstDate: selectedDate,
                          lastDate: DateTime.now(),
                        );
                        if (picked == null) return;
                        if (!context.mounted) return;
                        setState(() {
                          selectedDate2 = picked;
                          if (widget.operation == null) {
                            final historicalPoint = widget.fund.pointByDate(
                              picked,
                            );
                            if (historicalPoint != null) {
                              priceController.text = historicalPoint.price
                                  .toString()
                                  .replaceAll('.', ',');
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
                      keyboardType: const .numberWithOptions(decimal: true),
                      onChanged: (_) => updateTranfer(),
                    ),
                    TextField(
                      controller: unitsController2,
                      decoration: InputDecoration(labelText: l10n.unitsLabel),
                      keyboardType: const .numberWithOptions(decimal: true),
                      onChanged: (_) => updateTranfer(),
                    ),
                    TextField(
                      controller: amountController2,
                      decoration: InputDecoration(
                        labelText: l10n.totalAmountLabel,
                      ),
                      keyboardType: const .numberWithOptions(decimal: true),
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
                if (widget.operation != null)
                  TextButton(
                    onPressed: provider.isBusy
                        ? null
                        : () => _deleteEditedOperation(
                            context,
                            widget.operation!,
                          ),
                    child: Text(
                      l10n.delete,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),

                if (!isTransfer)
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

                      if (selectedType == .sell ||
                          selectedType == .outTransfer) {
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

                      if (selectedType == .outTransfer) {
                        if (units2 <= 0 || price2 <= 0 || amount2 <= 0) {
                          setState(() {
                            dialogError =
                                l10n.allNumericFieldsGreaterThanZeroError;
                          });
                          return;
                        }
                      }

                      if (selectedType == .sell ||
                          selectedType == .outTransfer) {
                        //if (units > metrics.totalUnits + 0.00001) {
                        if (units > maxUnits + 0.00001) {
                          setState(() {
                            dialogError = l10n.cannotSellMoreThanOwnedError;
                          });
                          return;
                        }
                        //if (amount > metrics.currentValue + 0.01) {
                        if (amount > maxAmount + 0.01) {
                          setState(() {
                            dialogError =
                                l10n.saleAmountExceedsCurrentValueError;
                          });
                          return;
                        }
                      }

                      if (selectedType == .outTransfer && outFund == null) {
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
                          context,
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
                          context,
                          FundOperation(
                            id: widget.operation?.id,
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
                          context,
                          FundOperation(
                            id: widget.operation?.id,
                            isin: widget.fund.isin,
                            date: selectedDate,
                            type: selectedType,
                            units: units,
                            price: price,
                            amount: amount,
                          ),
                          operation2: FundOperation(
                            id: widget.operation?.id,
                            isin: outFund!.isin,
                            date: selectedDate2,
                            type: .inTransfer,
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
    );
  }

  Future<void> _deleteEditedOperation(
    BuildContext context,
    FundOperation operation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
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
      if (!context.mounted) return;
      Navigator.pop(context);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.operationDeletedSuccess),
          duration: const Duration(seconds: 4),
          action:
              (operation.type == .outTransfer || operation.type == .inTransfer)
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
    BuildContext context,
    FundOperation operation, {
    FundOperation? operation2,
  }) async {
    if (provider.isBusy) return;

    try {
      await provider.addOperation(operation, op2: operation2);
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              if (result.warningMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: .circular(8),
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
                context,
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
      padding: const .symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: .spaceBetween,
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
}
