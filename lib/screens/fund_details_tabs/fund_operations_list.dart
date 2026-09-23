import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/fund_provider.dart';
import '../../services/fund_scraper.dart';

class FundOperationsList extends StatelessWidget {
  final FundData fund;
  final NumberFormat priceFormat;

  const FundOperationsList({
    super.key,
    required this.fund,
    required this.priceFormat,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.read<FundProvider>();
    final locale = Localizations.localeOf(context).toString();
    final smartFormat = NumberFormat('#,##0.####', locale);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: provider.isBusy
                ? null
                : () => _showOperationDialog(context, provider),
            icon: const Icon(Icons.add),
            label: Text(l10n.newOperation),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        Expanded(
          child: fund.operations.isEmpty
              ? Center(
                  child: Text(
                    l10n.noOperationsRegistered,
                    style: const TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  itemCount: fund.operations.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final operation = fund.operations[index];
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
                            '${isBuy ? '' : '-'}${smartFormat.format(operation.amount)} ${fund.currency}',
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
                      onTap: () => _showOperationDialog(
                        context,
                        provider,
                        operation: operation,
                      ),
                      onLongPress: () =>
                          _confirmDelete(context, provider, operation),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FundProvider provider,
    FundOperation operation,
  ) async {
    final l10n = AppLocalizations.of(context)!;
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
    FundProvider provider,
    FundOperation operation,
  ) async {
    final l10n = AppLocalizations.of(context)!;
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

  Future<void> _showOperationDialog(
    BuildContext context,
    FundProvider provider, {
    FundOperation? operation,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    DateTime selectedDate = operation?.date ?? DateTime.now();
    OperationType selectedType = operation?.type ?? OperationType.buy;
    final unitsController = TextEditingController(
      text: operation?.units.toString().replaceAll('.', ',') ?? '',
    );
    final priceController = TextEditingController(
      text:
          operation?.price.toString().replaceAll('.', ',') ??
          fund.lastValue.toString().replaceAll('.', ','),
    );
    final amountController = TextEditingController(
      text: operation?.amount.toString().replaceAll('.', ',') ?? '',
    );

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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (formContext, setState) => AlertDialog(
          title: Text(
            operation == null ? l10n.newOperation : l10n.editOperation,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<OperationType>(
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
                  onSelectionChanged: (selection) =>
                      setState(() => selectedType = selection.first),
                ),
                const SizedBox(height: 16),
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
                    setState(() {
                      selectedDate = picked;
                      if (operation == null) {
                        final historicalPoint = fund.history
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
                  decoration: InputDecoration(labelText: l10n.unitsLabel),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => updateAmount(),
                ),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(labelText: l10n.totalAmountLabel),
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
                        provider,
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
                if (units <= 0 ||
                    price <= 0 ||
                    amount <= 0 ||
                    provider.isBusy) {
                  return;
                }
                try {
                  await provider.addOperation(
                    FundOperation(
                      id: operation?.id,
                      isin: fund.isin,
                      date: selectedDate,
                      type: selectedType,
                      units: units,
                      price: price,
                      amount: amount,
                    ),
                  );
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
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
