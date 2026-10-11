import 'package:investing/models/fund_data.dart';

import '../models/tax_simulation.dart';

class TaxEstimator {
  /// Calcula la estimación fiscal de un reembolso usando el método FIFO.
  TaxSimulationResult calculate(TaxSimulation request) {
    final fund = request.fund;
    final navToUse = request.targetNav ?? fund.lastValue;

    // 1. Validación básica de saldo
    final totalUserShares = _calculateTotalShares(fund.operations);
    if (totalUserShares <= 0) {
      return TaxSimulationResult(
        soldShares: 0,
        saleValue: 0,
        acquisitionCost: 0,
        capitalGain: 0,
        estimatedTax: 0,
        netAmount: 0,
        hasSufficientShares: false,
        warningMessage: 'No tienes participaciones actuales en este fondo.',
      );
    }

    // 2. Determinar cuántas participaciones se van a vender
    double sharesToSell = request.isSharesInput
        ? request.amount
        : (request.amount / navToUse);

    if (sharesToSell > totalUserShares) {
      return TaxSimulationResult(
        soldShares: sharesToSell,
        saleValue: sharesToSell * navToUse,
        acquisitionCost: 0,
        capitalGain: 0,
        estimatedTax: 0,
        netAmount: 0,
        hasSufficientShares: false,
        warningMessage:
            'El importe o número de participaciones excede tu saldo actual.',
      );
    }

    // 3. Obtener histórico de COMPRAS ordenado por fecha (FIFO: las más antiguas primero)
    final buyOperations =
        fund.operations.where((op) => op.type == OperationType.buy).toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (buyOperations.isEmpty) {
      // Fallback: Si no hay histórico de compras, no podemos calcular el coste de adquisición real.
      // Asumimos coste 0 (peor escenario fiscal) o el VL actual, pero avisamos al usuario.
      return TaxSimulationResult(
        soldShares: sharesToSell,
        saleValue: sharesToSell * navToUse,
        acquisitionCost: 0,
        capitalGain:
            sharesToSell * navToUse, // Asume 100% plusvalía (conservador)
        estimatedTax: (sharesToSell * navToUse) * (request.taxRate / 100),
        netAmount: (sharesToSell * navToUse) * (1 - (request.taxRate / 100)),
        hasSufficientShares: true,
        warningMessage: 'No se encontró histórico de compras. La estimación asume coste de adquisición 0 (máxima tributación).',
      );
    }

    // 4. Algoritmo FIFO
    double remainingSharesToSell = sharesToSell;
    double totalAcquisitionCost = 0.0;

    for (final operation in buyOperations) {
      if (remainingSharesToSell <= 0) break;

      final availableSharesInThisOp = operation.units;
      //.shares; // Ajusta al nombre real de tu campo (ej: op.participaciones)

      if (availableSharesInThisOp <= remainingSharesToSell) {
        // Vendemos todas las participaciones de esta compra
        totalAcquisitionCost +=
            availableSharesInThisOp *
            operation.price; // Ajusta 'price' a tu campo de VL de compra
        remainingSharesToSell -= availableSharesInThisOp;
      } else {
        // Vendemos solo una parte de esta compra
        totalAcquisitionCost += remainingSharesToSell * operation.price;
        remainingSharesToSell = 0;
      }
    }

    // 5. Cálculos finales
    final saleValue = sharesToSell * navToUse;
    final capitalGain = saleValue - totalAcquisitionCost;

    // Solo se tributa por ganancias. Las minusvalías pueden compensar otras ganancias,
    // pero para una estimación simple de "cuánto pago", si es negativo, el impuesto es 0.
    final estimatedTax = capitalGain > 0
        ? capitalGain * (request.taxRate / 100)
        : 0.0;
    final netAmount = saleValue - estimatedTax;

    return TaxSimulationResult(
      soldShares: sharesToSell,
      saleValue: saleValue,
      acquisitionCost: totalAcquisitionCost,
      capitalGain: capitalGain,
      estimatedTax: estimatedTax,
      netAmount: netAmount,
      hasSufficientShares: true,
      warningMessage: null,
    );
  }

  /// Calcula las participaciones netas actuales (Compras - Ventas)
  double _calculateTotalShares(List<FundOperation> operations) {
    double total = 0.0;
    for (final op in operations) {
      if (op.type == OperationType.buy) {
        total += op.units;
      } else if (op.type == OperationType.sell) {
        total -= op.units;
      }
    }
    return total;
  }
}
