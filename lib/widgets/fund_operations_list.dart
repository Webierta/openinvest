import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/fund_provider.dart';
import '../services/fund_scraper.dart';

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
    final provider = context.read<FundProvider>();
    final smartFormat = NumberFormat('#,##0.####', 'es_ES');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: provider.isBusy
                ? null
                : () => _showOperationDialog(context, provider),
            icon: const Icon(Icons.add),
            label: const Text('Nueva Operación'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        Expanded(
          child: fund.operations.isEmpty
              ? const Center(
                  child: Text(
                    'No hay operaciones registradas',
                    style: TextStyle(color: Colors.white38),
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
                        isBuy ? 'Suscripción' : 'Reembolso',
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
                            '${smartFormat.format(operation.units)} part. @ ${smartFormat.format(operation.price)}',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar Operación'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
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
            const SnackBar(
              content: Text('No se pudo eliminar la operación'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _showOperationDialog(
    BuildContext context,
    FundProvider provider, {
    FundOperation? operation,
  }) async {
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

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              operation == null ? 'Nueva Operación' : 'Editar Operación',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<OperationType>(
                    segments: const [
                      ButtonSegment(
                        value: OperationType.buy,
                        label: Text('Compra'),
                      ),
                      ButtonSegment(
                        value: OperationType.sell,
                        label: Text('Venta'),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (selection) =>
                        setState(() => selectedType = selection.first),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text('Fecha'),
                    subtitle: Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
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
                    decoration: const InputDecoration(labelText: 'Precio (VL)'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => updateAmount(),
                  ),
                  TextField(
                    controller: unitsController,
                    decoration: const InputDecoration(
                      labelText: 'Participaciones',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => updateAmount(),
                  ),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Importe Total',
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
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
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
                        const SnackBar(
                          content: Text('No se pudo guardar la operación'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );
    } finally {
      unitsController.dispose();
      priceController.dispose();
      amountController.dispose();
    }
  }
}
