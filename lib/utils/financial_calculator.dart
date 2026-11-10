import 'dart:math';

import '../models/fund_cost.dart';
import '../models/fund_data.dart';
import '../models/historical_investment.dart';
import '../models/historical_operation.dart';
import '../services/ine_ipc_service.dart';

class FundMetrics {
  final double totalUnits;
  final double totalInvested;
  final DateTime? firstOpDate;
  final double currentValue;
  final double profitAbs;
  final double profitRel;
  final double recordedExternalCosts;
  final double netProfit;
  final double netProfitRel;
  final double tae;
  final bool isAnnualized;
  final double avgPurchasePrice;
  final double moic;
  final double? twrTotal;
  final double? twrAnnualized;
  final double? mwrTotal;
  final double? mwrAnnualized;
  final double? twrRealTotal;
  final double? twrRealAnnualized;
  final double? mwrRealAnnualized;
  final double? mwrRealTotal;
  final int days;

  FundMetrics({
    required this.totalUnits,
    required this.totalInvested,
    this.firstOpDate,
    required this.currentValue,
    required this.profitAbs,
    required this.profitRel,
    required this.recordedExternalCosts,
    required this.netProfit,
    required this.netProfitRel,
    required this.tae,
    required this.isAnnualized,
    required this.avgPurchasePrice,
    required this.moic,
    this.twrTotal,
    this.twrAnnualized,
    this.mwrTotal,
    this.mwrAnnualized,
    this.twrRealAnnualized,
    this.twrRealTotal,
    this.mwrRealAnnualized,
    this.mwrRealTotal,
    required this.days,
  });
}

class GlobalMetrics {
  // Cartera vigente
  final double totalValue;
  final double totalInvested;
  final double profitAbs;
  final double profitRel;
  final bool isAnnualized;
  final double? mwrAnnualized;

  // Trayectoria inversora
  final double totalValueGlobal;
  final double totalInvestedGlobal;
  final double profitAbsGlobal;
  final double profitRelGlobal;
  final bool isAnnualizedGlobal;
  final double? mwrAnnualizedGlobal;

  GlobalMetrics({
    required this.totalValue,
    required this.totalInvested,
    required this.profitAbs,
    required this.profitRel,
    required this.isAnnualized,
    this.mwrAnnualized,
    required this.totalValueGlobal,
    required this.totalInvestedGlobal,
    required this.profitAbsGlobal,
    required this.profitRelGlobal,
    required this.isAnnualizedGlobal,
    this.mwrAnnualizedGlobal,
  });
}

class HistoricalInvestmentMetrics {
  final double totalContributions;
  final double totalReturns;
  final double profitAbs;
  final double? profitRel;
  final double? mwrAnnualized;

  const HistoricalInvestmentMetrics({
    required this.totalContributions,
    required this.totalReturns,
    required this.profitAbs,
    required this.profitRel,
    required this.mwrAnnualized,
  });
}

class FundCostEstimate {
  final double annualRecurringCost;
  final double potentialPerformanceFee;
  final bool hasAnnualRates;
  final bool hasPerformanceRate;

  const FundCostEstimate({
    required this.annualRecurringCost,
    required this.potentialPerformanceFee,
    required this.hasAnnualRates,
    required this.hasPerformanceRate,
  });

  bool get hasEstimates => hasAnnualRates || hasPerformanceRate;
}

class FinancialCalculator {
  static double? calculateAnnualizedVolatility(List<PricePoint> history) {
    if (history.length < 2) return null;

    final returns = <double>[];
    for (var index = 1; index < history.length; index++) {
      final previousPrice = history[index - 1].price;
      if (previousPrice != 0) {
        returns.add((history[index].price - previousPrice) / previousPrice);
      }
    }
    if (returns.isEmpty) return null;

    final meanReturn = returns.reduce((a, b) => a + b) / returns.length;
    final varianceSum = returns
        .map((value) => pow(value - meanReturn, 2).toDouble())
        .reduce((a, b) => a + b);
    return sqrt(varianceSum / returns.length) * sqrt(252);
  }

  static FundCostEstimate estimateCurrentFundCosts(
    FundData fund, {
    DateTime? asOf,
  }) {
    final date = asOf ?? DateTime.now();
    final today = DateTime(date.year, date.month, date.day);
    final activePeriods = fund.costPeriods.where((period) {
      if (period.validFrom == null) return false;
      final validFrom = DateTime(
        period.validFrom!.year,
        period.validFrom!.month,
        period.validFrom!.day,
      );
      final validTo = period.validTo == null
          ? null
          : DateTime(
              period.validTo!.year,
              period.validTo!.month,
              period.validTo!.day,
            );
      return !validFrom.isAfter(today) &&
          (validTo == null || !validTo.isBefore(today));
    }).toList();

    final separatelyChargedTer = activePeriods.any(
      (period) =>
          period.concept == FundCostConcept.ter &&
          period.basis == FundCostRateBasis.annualBalance &&
          period.treatment == FundCostTreatment.chargedSeparately,
    );
    final annualPeriods = activePeriods.where(
      (period) =>
          period.basis == FundCostRateBasis.annualBalance &&
          period.treatment == FundCostTreatment.chargedSeparately &&
          !(separatelyChargedTer &&
              {
                FundCostConcept.management,
                FundCostConcept.depositary,
                FundCostConcept.operating,
              }.contains(period.concept)),
    );
    final position = _positionValues(fund);
    final annualCost = annualPeriods.fold<double>(
      0,
      (total, period) =>
          total + position.currentValue * period.ratePercent / 100,
    );

    final performancePeriods = activePeriods
        .where(
          (period) =>
              period.concept == FundCostConcept.performance &&
              period.basis == FundCostRateBasis.positiveProfit &&
              period.treatment == FundCostTreatment.chargedSeparately,
        )
        .toList();
    var potentialPerformanceFee = 0.0;
    var hasPerformanceRate = false;
    if (performancePeriods.length == 1) {
      final period = performancePeriods.single;
      final settlements =
          fund.costCharges
              .where(
                (charge) =>
                    charge.concept == FundCostConcept.performance &&
                    charge.performancePeriodUid == period.uid &&
                    charge.settledThrough != null &&
                    !DateTime(
                      charge.date.year,
                      charge.date.month,
                      charge.date.day,
                    ).isAfter(today),
              )
              .toList()
            ..sort((a, b) => a.settledThrough!.compareTo(b.settledThrough!));
      if (settlements.isNotEmpty) {
        final latestSettlement = settlements.last;
        final settlementDate = latestSettlement.settledThrough!;
        final hasNewerUnclassifiedCharge = fund.costCharges.any((charge) {
          if (charge.concept != FundCostConcept.performance ||
              !DateTime(
                charge.date.year,
                charge.date.month,
                charge.date.day,
              ).isAfter(
                DateTime(
                  latestSettlement.date.year,
                  latestSettlement.date.month,
                  latestSettlement.date.day,
                ),
              ) ||
              DateTime(
                charge.date.year,
                charge.date.month,
                charge.date.day,
              ).isAfter(today)) {
            return false;
          }
          return charge.performancePeriodUid != period.uid ||
              charge.settledThrough == null;
        });
        final profitAtSettlement = _grossProfitAt(fund, settlementDate);
        if (!hasNewerUnclassifiedCharge && profitAtSettlement != null) {
          potentialPerformanceFee =
              max(0, position.grossProfit - profitAtSettlement) *
              period.ratePercent /
              100;
          hasPerformanceRate = true;
        }
      }
    }

    return FundCostEstimate(
      annualRecurringCost: annualCost,
      potentialPerformanceFee: potentialPerformanceFee,
      hasAnnualRates: annualPeriods.isNotEmpty,
      hasPerformanceRate: hasPerformanceRate,
    );
  }

  static ({double currentValue, double grossProfit}) _positionValues(
    FundData fund,
  ) {
    var units = 0.0;
    var invested = 0.0;
    for (final operation in fund.operations) {
      if (operation.type == OperationType.buy ||
          operation.type == OperationType.inTransfer) {
        units += operation.units;
        invested += operation.amount;
      } else {
        units -= operation.units;
        invested -= operation.amount;
      }
    }
    final currentValue = units * fund.lastValue;
    return (currentValue: currentValue, grossProfit: currentValue - invested);
  }

  static double? _grossProfitAt(FundData fund, DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final currentQuoteDate = DateTime(
      fund.date.year,
      fund.date.month,
      fund.date.day,
    );
    if (currentQuoteDate.isBefore(target)) return null;

    PricePoint? quote;
    for (final point in fund.history) {
      final pointDate = DateTime(
        point.date.year,
        point.date.month,
        point.date.day,
      );
      if (pointDate.isAfter(target)) break;
      quote = point;
    }
    if (quote == null) return null;

    var units = 0.0;
    var invested = 0.0;
    for (final operation in fund.operations) {
      final operationDate = DateTime(
        operation.date.year,
        operation.date.month,
        operation.date.day,
      );
      if (operationDate.isAfter(target)) continue;
      if (operation.type == OperationType.buy ||
          operation.type == OperationType.inTransfer) {
        units += operation.units;
        invested += operation.amount;
      } else {
        units -= operation.units;
        invested -= operation.amount;
      }
    }
    return units * quote.price - invested;
  }

  /// Calcula la rentabilidad real de una inversión descontando la inflación
  /// utilizando la Ecuación de Fisher (estándar financiero).
  ///
  /// [nominalReturnPercent]: Rentabilidad del fondo en porcentaje (ej. 15.5 para 15.5%): TWR /MWR
  /// [inflationPercent]: Variación del IPC en porcentaje (ej. 4.2 para 4.2%).
  ///
  /// Devuelve la rentabilidad real en porcentaje (ej. 10.84).

  // ECUACIÓN DE FISHER
  /* static double calculateRealReturn(
    double nominalReturnAnnualized,
    double inflationPercent,
  ) {
    // 1. Convertir porcentajes a decimales (ej. 15.5 -> 0.155)
    final double r = nominalReturnAnnualized; // / 100  (NO NECESARIO);
    final double i = inflationPercent / 100;

    // 2. Aplicar la Ecuación de Fisher: (1 + r) / (1 + i) - 1
    final double realReturnDecimal = ((1 + r) / (1 + i)) - 1;

    // 3. Devolver el resultado en formato porcentaje
    return realReturnDecimal * 100;
  } */

  static double? calculateIpcVariation(
    int startYear,
    int startMonth,
    int endYear,
    int endMonth,
    List<IpcDataPoint> ipcHistory,
  ) {
    // Los meses deben estar entre 1 (Enero) y 12 (Diciembre)
    if (startMonth < 1 || startMonth > 12 || endMonth < 1 || endMonth > 12) {
      return null;
    }
    // IPC VARIATION: Fallo -> El historial está vacío
    if (ipcHistory.isEmpty) return null;

    try {
      // Buscamos los valores del índice para ambas fechas
      final startData = ipcHistory.firstWhere(
        (data) => data.year == startYear && data.month == startMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );
      final endData = ipcHistory.firstWhere(
        (data) => data.year == endYear && data.month == endMonth,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );
      // Validamos que ambas fechas tengan datos publicados
      if (startData.year == 0 || endData.year == 0) return null;
      // Calculamos la variación porcentual
      // final variation = ((endData.value - startData.value) / startData.value) * 100;
      final variation = ((endData.value / startData.value) - 1) * 100;
      return variation;
    } catch (e) {
      return null;
    }
  }

  // Obtiene el numero de participaciones en una fecha
  static double calculateUnitsAt(FundData fund, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    var units = 0.0;

    for (final operation in fund.operations) {
      final operationDate = DateTime(
        operation.date.year,
        operation.date.month,
        operation.date.day,
      );

      if (operationDate.isAfter(targetDate)) continue;

      if (operation.type == OperationType.buy ||
          operation.type == OperationType.inTransfer) {
        units += operation.units;
      } else {
        units -= operation.units;
      }
    }

    return units;
  }

  /// Calcula el máximo de participaciones que se pueden retirar
  /// en una fecha sin dejar ningún saldo cronológico posterior
  /// en negativo.
  ///
  /// La nueva salida se considera posterior a todas las operaciones
  /// ya registradas en la fecha seleccionada.
  static double calculateMaxOutflowUnitsAt(FundData fund, DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);

    DateTime dateOnly(DateTime value) =>
        DateTime(value.year, value.month, value.day);

    final operations = fund.operations.toList()
      ..sort((a, b) {
        final dateComparison = dateOnly(a.date).compareTo(dateOnly(b.date));
        if (dateComparison != 0) return dateComparison;

        // El orden de las operaciones del mismo día se conserva.
        return fund.operations.indexOf(a).compareTo(fund.operations.indexOf(b));
      });

    var balance = 0.0;
    var balanceAtTarget = 0.0;
    var minimumFutureBalance = double.infinity;
    var foundTarget = false;

    for (final operation in operations) {
      final operationDate = dateOnly(operation.date);

      // El saldo disponible en la fecha seleccionada debe incluir
      // las operaciones ya registradas para ese mismo día.
      if (operationDate.isAfter(targetDate)) {
        if (!foundTarget) {
          balanceAtTarget = balance;
          foundTarget = true;
        }
      }

      if (operation.type == OperationType.buy ||
          operation.type == OperationType.inTransfer) {
        balance += operation.units;
      } else {
        balance -= operation.units;
      }

      if (!operationDate.isBefore(targetDate)) {
        minimumFutureBalance = minimumFutureBalance < balance
            ? minimumFutureBalance
            : balance;
      }
    }

    if (!foundTarget) {
      balanceAtTarget = balance;
    }

    if (operations.every((op) => dateOnly(op.date).isBefore(targetDate))) {
      balanceAtTarget = balance;
    }

    // Si no existen operaciones en la fecha o después, el saldo
    // disponible es el saldo acumulado hasta esa fecha.
    if (minimumFutureBalance == double.infinity) {
      minimumFutureBalance = balanceAtTarget;
    }

    final maxUnits = balanceAtTarget < minimumFutureBalance
        ? balanceAtTarget
        : minimumFutureBalance;

    return maxUnits > 0 ? maxUnits : 0.0;
  }

  static HistoricalInvestmentMetrics calculateHistoricalInvestmentMetrics(
    HistoricalInvestment investment,
    List<HistoricalOperation> operations,
  ) {
    final investmentOperations = operations
        .where((operation) => operation.investmentUid == investment.uid)
        .toList();

    var totalContributions = 0.0;
    var totalReturns = 0.0;

    final cashFlows = <Map<String, Object>>[];

    for (final operation in investmentOperations) {
      final isContribution =
          operation.type == HistoricalOperationType.subscription ||
          operation.type == HistoricalOperationType.transferIn;

      if (isContribution) {
        totalContributions += operation.amount;
        cashFlows.add({'amount': -operation.amount, 'date': operation.date});
      } else {
        totalReturns += operation.amount;
        cashFlows.add({'amount': operation.amount, 'date': operation.date});
      }
    }

    final profitAbs = totalReturns - totalContributions;

    final double? profitRel = totalContributions > 0
        ? (profitAbs / totalContributions) * 100
        : totalReturns == 0
        ? 0.0
        : null;

    final irr = _calculateIRR(cashFlows);
    final double? mwrAnnualized = irr.isNaN ? null : irr;

    return HistoricalInvestmentMetrics(
      totalContributions: totalContributions,
      totalReturns: totalReturns,
      profitAbs: profitAbs,
      profitRel: profitRel,
      mwrAnnualized: mwrAnnualized,
    );
  }

  static HistoricalInvestmentMetrics calculateHistoricalInvestmentsMetrics(
    List<HistoricalInvestment> investments,
    List<HistoricalOperation> operations,
  ) {
    var totalContributions = 0.0;
    var totalReturns = 0.0;

    final uniqueInvestments = {
      for (final investment in investments) investment.uid: investment,
    }.values;

    for (final investment in uniqueInvestments) {
      final metrics = calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      totalContributions += metrics.totalContributions;
      totalReturns += metrics.totalReturns;
    }

    final profitAbs = totalReturns - totalContributions;

    final double? profitRel = totalContributions > 0
        ? (profitAbs / totalContributions) * 100
        : totalReturns == 0
        ? 0.0
        : null;

    final cashFlows = <Map<String, Object>>[];

    for (final operation in operations) {
      if (!investments.any(
        (investment) => investment.uid == operation.investmentUid,
      )) {
        continue;
      }

      final isContribution =
          operation.type == HistoricalOperationType.subscription ||
          operation.type == HistoricalOperationType.transferIn;

      cashFlows.add({
        'amount': isContribution ? -operation.amount : operation.amount,
        'date': operation.date,
      });
    }

    final irr = _calculateIRR(cashFlows);
    final double? mwrAnnualized = irr.isNaN ? null : irr;

    return HistoricalInvestmentMetrics(
      totalContributions: totalContributions,
      totalReturns: totalReturns,
      profitAbs: profitAbs,
      profitRel: profitRel,
      mwrAnnualized: mwrAnnualized,
    );
  }

  static FundMetrics calculateFundMetrics(
    FundData fund, {
    double? inflationPercent,
    List<IpcDataPoint>? ipcHistory,
  }) {
    double totalUnits = 0;
    double totalInvested = 0;
    DateTime? firstOpDate;

    for (var op in fund.operations) {
      if (op.type == OperationType.buy || op.type == OperationType.inTransfer) {
        totalUnits += op.units;
        totalInvested += op.amount;
      } else {
        totalUnits -= op.units;
        totalInvested -= op.amount;
      }
      if ((op.type == OperationType.buy ||
              op.type == OperationType.inTransfer) &&
          (firstOpDate == null || op.date.isBefore(firstOpDate))) {
        firstOpDate = op.date;
      }
    }

    final double currentValue = totalUnits * fund.lastValue;
    final double profitAbs = currentValue - totalInvested;
    final double profitRel = totalInvested > 0
        ? (profitAbs / totalInvested) * 100
        : 0.0;
    final double avgPurchasePrice = totalUnits > 0
        ? totalInvested / totalUnits
        : 0.0;
    final double moic = totalInvested > 0 ? currentValue / totalInvested : 0.0;

    double tae = 0.0;
    bool isAnnualized = false;
    double? twrTotal;
    double? twrAnnualized;
    double? mwrTotal;
    double? mwrAnnualized;
    int days = 0;
    double? twrRealTotal;
    double? twrRealAnnualized;
    double? mwrRealAnnualized;
    double? mwrRealTotal;

    if (totalInvested > 0 && firstOpDate != null) {
      // 1. Calcula los días basándote en la fecha del fondo, no en la fecha del sistema
      days = fund.date.difference(firstOpDate).inDays;

      if (days > 0) {
        final double years = days / 365.25;

        // 1. Rentabilidad Simple Anualizada
        tae = (pow(currentValue / totalInvested, 1 / years) - 1) * 100;
        isAnnualized = days >= 30;

        // 2. TWR (Time-Weighted Return)
        /* final firstOpPricePoint = fund.history.cast<PricePoint?>().lastWhere(
          (p) => p!.date.isBefore(firstOpDate!.add(const Duration(days: 1))),
          orElse: () => fund.history.isNotEmpty ? fund.history.first : null,
        );
        if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
          final double calculatedTwr = (fund.lastValue / firstOpPricePoint.price) - 1;
          twrTotal = calculatedTwr;
          twrAnnualized = (pow(1 + calculatedTwr, 1 / years) - 1);
        } */

        //El algoritmo anterior calcula (Precio Final / Precio Inicial) - 1,
        //lo cual mide la rentabilidad del activo, pero no es el TWR financiero real si hubo depósitos o reembolsos intermedios
        //(el TWR real debe segmentar la rentabilidad en subperiodos cada vez que hay un flujo de caja)

        // TWR vinculado (Linked IRR), que calcula la rentabilidad de cada subperiodo entre flujos de caja y las multiplica

        // 2. TWR (Time-Weighted Return) Real con segmentación por flujos de caja
        double calculatedTwrMultiplier = 1.0;
        DateTime lastPeriodDate = firstOpDate;
        double lastPeriodValue = totalInvested; // Valor inicial de la cartera

        // Ordenar operaciones por fecha para procesarlas cronológicamente
        final sortedOps = List<FundOperation>.from(fund.operations)
          ..sort((a, b) => a.date.compareTo(b.date));

        for (var op in sortedOps) {
          // 1. Calcular rentabilidad del subperiodo ANTES de este nuevo flujo de caja
          // Buscamos el precio del fondo en la fecha de la operación
          final priceAtOp =
              fund.history
                  .cast<PricePoint?>()
                  .lastWhere(
                    (p) => p != null && !p.date.isAfter(op.date),
                    orElse: () =>
                        fund.history.isNotEmpty ? fund.history.first : null,
                  )
                  ?.price ??
              op.price; // Fallback al precio de la operación si no hay historial

          if (priceAtOp > 0 && lastPeriodValue > 0) {
            // Valor de la cartera justo antes del flujo = (unidades anteriores) * precio actual
            // Pero como no guardamos unidades por periodo, usamos una aproximación:
            // El valor antes del flujo es el valor anterior revalorizado al precio actual
            final double valueBeforeFlow =
                lastPeriodValue *
                (priceAtOp /
                    (fund.history
                        .firstWhere(
                          (p) => p.date == lastPeriodDate,
                          orElse: () => PricePoint(lastPeriodDate, priceAtOp),
                        )
                        .price));

            final double periodReturn =
                (valueBeforeFlow / lastPeriodValue) - 1.0;
            calculatedTwrMultiplier *= (1.0 + periodReturn);
          }

          // 2. Actualizar el valor base para el siguiente periodo sumando/restando el flujo
          if (op.type == OperationType.buy ||
              op.type == OperationType.inTransfer) {
            lastPeriodValue += op.amount;
          } else {
            lastPeriodValue -= op.amount;
          }
          lastPeriodDate = op.date;
        }

        // Subperiodo final: desde la última operación hasta hoy
        final finalPrice = fund.history.isNotEmpty
            ? fund.history.last.price
            : fund.lastValue;
        final initialPriceForFinalPeriod =
            fund.history
                .cast<PricePoint?>()
                .lastWhere(
                  (p) => p != null && !p.date.isAfter(lastPeriodDate),
                  orElse: () => PricePoint(lastPeriodDate, finalPrice),
                )
                ?.price ??
            finalPrice;

        if (initialPriceForFinalPeriod > 0 && lastPeriodValue > 0) {
          final double valueAtEnd =
              lastPeriodValue * (finalPrice / initialPriceForFinalPeriod);
          final double finalPeriodReturn = (valueAtEnd / lastPeriodValue) - 1.0;
          calculatedTwrMultiplier *= (1.0 + finalPeriodReturn);
        }

        final double calculatedTwr = calculatedTwrMultiplier - 1.0;
        twrTotal = calculatedTwr;
        twrAnnualized = days > 0
            ? (pow(1 + calculatedTwr, 1 / (days / 365.25)) - 1)
            : 0.0;

        // 3. MWR (Money-Weighted Return / IRR)
        final flows = fund.operations
            .map(
              (op) => <String, Object>{
                'amount':
                    op.type == OperationType.buy ||
                        op.type == OperationType.inTransfer
                    ? -op.amount
                    : op.amount,
                'date': op.date,
              },
            )
            .toList();

        // ✅ CAMBIO CRÍTICO: Usar fund.date en lugar de DateTime.now()
        flows.add(<String, Object>{'amount': currentValue, 'date': fund.date});

        final double irr = _calculateIRR(flows);

        if (!irr.isNaN) {
          mwrAnnualized = irr;
          mwrTotal = (pow(1 + irr, years) - 1);
        }

        // ---------------------------------------------------------------------
        // 1. TWR REAL (Time-Weighted Return Real)
        // ---------------------------------------------------------------------
        // El TWR mide el crecimiento de 1 unidad monetaria desde el inicio hasta el final,
        // ignorando los flujos intermedios. Por tanto, se ajusta el multiplicador total
        // del TWR por la inflación total acumulada en ese mismo periodo.

        final DateTime endDate = fund.date; // Fecha final de valoración

        final double? startIpc = _getIpcValueForDate(firstOpDate, ipcHistory);
        final double? endIpc = _getIpcValueForDate(endDate, ipcHistory);

        if (startIpc != null && endIpc != null && startIpc > 0) {
          // Inflación total en decimal (ej. 0.05 para 5%)
          final double totalInflationDecimal = (endIpc / startIpc) - 1.0;

          // Ecuación de Fisher aplicada al multiplicador total del TWR
          final double realTwrDecimal =
              ((1.0 + calculatedTwr) / (1.0 + totalInflationDecimal)) - 1.0;

          twrRealTotal = realTwrDecimal;
          twrRealAnnualized = years > 0
              ? (pow(1.0 + realTwrDecimal, 1.0 / years) - 1.0).toDouble()
              : realTwrDecimal;
        }

        // ---------------------------------------------------------------------
        // 2. MWR REAL (Money-Weighted Return Real / TIR Real)
        // ---------------------------------------------------------------------
        // Para el MWR, la inflación afecta de forma distinta a cada euro invertido
        // (un euro de 2021 ha sufrido más inflación que uno de 2025).
        // La solución profesional es "deflactar" cada flujo a una moneda constante
        // (la de la primera inversión) y luego calcular la TIR sobre esos flujos reales.

        final double? baseIpc = _getIpcValueForDate(firstOpDate, ipcHistory);

        if (baseIpc != null && baseIpc > 0) {
          final List<Map<String, Object>> realFlows = [];

          // Ajustamos cada operación histórica
          for (var op in sortedOps) {
            final double? flowIpc = _getIpcValueForDate(op.date, ipcHistory);
            if (flowIpc != null && flowIpc > 0) {
              // Flujo nominal: negativo para compra (salida de dinero), positivo para reembolso (entrada)
              final double nominalFlow =
                  op.type == OperationType.buy ||
                      op.type == OperationType.inTransfer
                  ? -op.amount
                  : op.amount;

              // Ajustamos el flujo a la capacidad adquisitiva de la fecha base
              final double realFlow = nominalFlow * (baseIpc / flowIpc);

              realFlows.add({'amount': realFlow, 'date': op.date});
            }
          }

          // Ajustamos el valor final de la cartera como un flujo positivo en la fecha final
          final double? finalIpc = _getIpcValueForDate(endDate, ipcHistory);
          if (finalIpc != null && finalIpc > 0) {
            final double realFinalValue = currentValue * (baseIpc / finalIpc);
            realFlows.add({'amount': realFinalValue, 'date': endDate});
          }

          // Calculamos la TIR sobre los flujos ya ajustados por inflación
          if (realFlows.isNotEmpty) {
            final double realIrr = _calculateIRR(realFlows);
            if (!realIrr.isNaN) {
              mwrRealAnnualized = realIrr;
              mwrRealTotal = years > 0
                  ? (pow(1.0 + realIrr, years) - 1.0).toDouble()
                  : 0.0;
            }
          }
        }
      } else {
        tae = profitRel;
      }
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final firstOpDateOnly = firstOpDate == null
        ? null
        : DateTime(firstOpDate.year, firstOpDate.month, firstOpDate.day);
    final recordedExternalCosts = fund.costCharges
        .where(
          (charge) =>
              !DateTime(
                charge.date.year,
                charge.date.month,
                charge.date.day,
              ).isAfter(todayDate) &&
              (firstOpDateOnly == null ||
                  !DateTime(
                    charge.date.year,
                    charge.date.month,
                    charge.date.day,
                  ).isBefore(firstOpDateOnly)),
        )
        .fold<double>(0, (total, charge) => total + charge.amount);
    final netProfit = profitAbs - recordedExternalCosts;
    final netProfitRel = totalInvested > 0
        ? (netProfit / totalInvested) * 100
        : 0.0;

    return FundMetrics(
      totalUnits: totalUnits,
      totalInvested: totalInvested,
      firstOpDate: firstOpDate,
      currentValue: currentValue,
      profitAbs: profitAbs,
      profitRel: profitRel,
      recordedExternalCosts: recordedExternalCosts,
      netProfit: netProfit,
      netProfitRel: netProfitRel,
      tae: tae,
      isAnnualized: isAnnualized,
      avgPurchasePrice: avgPurchasePrice,
      moic: moic,
      twrTotal: twrTotal,
      twrAnnualized: twrAnnualized,
      mwrTotal: mwrTotal,
      mwrAnnualized: mwrAnnualized,
      twrRealTotal: twrRealTotal,
      twrRealAnnualized: twrRealAnnualized,
      mwrRealTotal: mwrRealTotal,
      mwrRealAnnualized: mwrRealAnnualized,
      days: days,
    );
  }

  // =====================================================================
  // CÁLCULOS DE RENTABILIDAD REAL (AJUSTADA POR INFLACIÓN)
  // =====================================================================

  /// Obtiene el valor del IPC más reciente disponible hasta la fecha dada.
  /// Es más robusto que la coincidencia exacta: si falta el mes exacto (ej. desfase
  /// de publicación del INE), toma el último dato disponible anterior a esa fecha.
  /// Asume que `ipcHistory` está ordenado de más reciente a más antiguo.
  static double? _getIpcValueForDate(
    DateTime targetDate,
    List<IpcDataPoint>? ipcHistory,
  ) {
    final targetYearMonth = DateTime(targetDate.year, targetDate.month);

    if (ipcHistory == null) return null;

    for (final ipc in ipcHistory) {
      final ipcYearMonth = DateTime(ipc.year, ipc.month);
      // Buscamos el primer dato del IPC que sea igual o anterior a la fecha objetivo
      if (ipcYearMonth.isBefore(targetYearMonth) ||
          ipcYearMonth.isAtSameMomentAs(targetYearMonth)) {
        return ipc.value;
      }
    }
    return null;
    // La fecha objetivo es anterior a cualquier dato de IPC disponible
  }

  static GlobalMetrics calculateGlobalMetrics(
    List<FundData> portfolio,
    Map<String, double> exchangeRates, {
    List<HistoricalInvestment> historicalInvestments = const [],
    List<HistoricalOperation> historicalOperations = const [],
  }) {
    double totalValue = 0;
    double portfolioValue = 0;
    double totalInvested = 0;
    double profitAbs = 0;
    //double weightedTaeSum = 0;
    DateTime? firstOpDate;
    DateTime? firstPortfolioOpDate;
    DateTime? valuationDate;

    final cashFlows = <Map<String, Object>>[];
    final portfolioCashFlows = <Map<String, Object>>[];

    double portfolioInvested = 0;
    double portfolioProfitAbs = 0;
    double totalInvestedGlobal = 0;

    for (var fund in portfolio) {
      final metrics = calculateFundMetrics(fund);
      final double rate = exchangeRates[fund.currency] ?? 1.0;

      final fundValueConverted = metrics.currentValue * rate;

      portfolioValue += fundValueConverted;

      final fundInvestedConverted = metrics.totalInvested * rate;

      totalValue += fundValueConverted;
      totalInvested += fundInvestedConverted;
      profitAbs += (fundValueConverted - fundInvestedConverted);

      portfolioInvested += fundInvestedConverted;
      portfolioProfitAbs += fundValueConverted - fundInvestedConverted;

      if (valuationDate == null || fund.date.isAfter(valuationDate)) {
        valuationDate = fund.date;
      }

      for (final operation in fund.operations) {
        final isInvestment =
            operation.type == OperationType.buy ||
            operation.type == OperationType.inTransfer;

        if (isInvestment) {
          totalInvestedGlobal += operation.amount * rate;
        }

        final cashFlow = {
          'amount':
              (isInvestment ? -operation.amount : operation.amount) * rate,
          'date': operation.date,
        };

        portfolioCashFlows.add(cashFlow);
        cashFlows.add(cashFlow);

        if (valuationDate == null || operation.date.isAfter(valuationDate)) {
          valuationDate = operation.date;
        }
      }

      if (metrics.firstOpDate != null) {
        if (firstPortfolioOpDate == null ||
            metrics.firstOpDate!.isBefore(firstPortfolioOpDate)) {
          firstPortfolioOpDate = metrics.firstOpDate;
        }

        if (firstOpDate == null || metrics.firstOpDate!.isBefore(firstOpDate)) {
          firstOpDate = metrics.firstOpDate;
        }
      }
    }

    // Integra las inversiones históricas cerradas.
    final now = DateTime.now();

    final historicalInvestmentUids = historicalInvestments
        .map((investment) => investment.uid)
        .toSet();

    for (final investment in historicalInvestments) {
      final investmentOperations = historicalOperations
          .where(
            (operation) =>
                operation.investmentUid == investment.uid &&
                !operation.date.isAfter(now),
          )
          .toList();

      final metrics = calculateHistoricalInvestmentMetrics(
        investment,
        investmentOperations,
      );

      totalInvested += metrics.totalContributions;
      totalValue += metrics.totalReturns;
      profitAbs += metrics.profitAbs;

      for (final operation in investmentOperations) {
        final isContribution =
            operation.type == HistoricalOperationType.subscription ||
            operation.type == HistoricalOperationType.transferIn;

        final isTransferOperation =
            operation.type == HistoricalOperationType.transferIn ||
            operation.type == HistoricalOperationType.transferOut;

        final matchingTransferOuts = operation.transferUid == null
            ? <HistoricalOperation>[]
            : historicalOperations.where(
                (candidate) =>
                    historicalInvestmentUids.contains(
                      candidate.investmentUid,
                    ) &&
                    candidate.transferUid == operation.transferUid &&
                    candidate.type == HistoricalOperationType.transferOut &&
                    candidate.date.year == operation.date.year &&
                    candidate.date.month == operation.date.month &&
                    candidate.date.day == operation.date.day,
                //candidate.date.isAtSameMomentAs(operation.date),
              );

        final matchingTransferIns = operation.transferUid == null
            ? <HistoricalOperation>[]
            : historicalOperations.where(
                (candidate) =>
                    historicalInvestmentUids.contains(
                      candidate.investmentUid,
                    ) &&
                    candidate.transferUid == operation.transferUid &&
                    candidate.type == HistoricalOperationType.transferIn &&
                    candidate.date.year == operation.date.year &&
                    candidate.date.month == operation.date.month &&
                    candidate.date.day == operation.date.day,
                //candidate.date.isAtSameMomentAs(operation.date),
              );

        final isInternalTransfer =
            isTransferOperation &&
            matchingTransferOuts.length == 1 &&
            matchingTransferIns.length == 1 &&
            matchingTransferOuts.first.investmentUid !=
                matchingTransferIns.first.investmentUid &&
            matchingTransferOuts.first.amount ==
                matchingTransferIns.first.amount;

        if (isContribution && !isInternalTransfer) {
          totalInvestedGlobal += operation.amount;
        }

        final isExternalCashFlow =
            !isInternalTransfer &&
            operation.type != HistoricalOperationType.transferOut;

        if (isExternalCashFlow) {
          cashFlows.add({
            'amount': isContribution ? -operation.amount : operation.amount,
            'date': operation.date,
          });
        }

        /* if (valuationDate == null || operation.date.isAfter(valuationDate)) {
          valuationDate = operation.date;
        } */

        if (isExternalCashFlow &&
            (valuationDate == null || operation.date.isAfter(valuationDate))) {
          valuationDate = operation.date;
        }

        if (isContribution &&
            //!isInternalTransfer &&
            operation.amount > 0 &&
            (firstOpDate == null || operation.date.isBefore(firstOpDate))) {
          firstOpDate = operation.date;
        }
      }
    }

    final double profitRel = portfolioInvested > 0
        ? (portfolioProfitAbs / portfolioInvested) * 100
        : totalInvested > 0
        ? (profitAbs / totalInvested) * 100
        : 0.0;

    bool isAnnualized = false;
    if (firstPortfolioOpDate != null) {
      isAnnualized =
          DateTime.now().difference(firstPortfolioOpDate).inDays >= 30;
    }

    double? mwrAnnualized;

    final flowsForPortfolio = portfolioCashFlows.isNotEmpty
        ? portfolioCashFlows
        : cashFlows;

    if (flowsForPortfolio.isNotEmpty) {
      final portfolioFlows = List<Map<String, Object>>.from(flowsForPortfolio);

      if (portfolioValue > 0 && valuationDate != null) {
        portfolioFlows.add({'amount': portfolioValue, 'date': valuationDate});
      }

      portfolioFlows.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

      final irr = _calculateIRR(portfolioFlows);
      if (!irr.isNaN) {
        mwrAnnualized = irr;
      }
    }

    final bool isAnnualizedGlobal =
        firstOpDate != null &&
        DateTime.now().difference(firstOpDate).inDays >= 30;

    double? mwrAnnualizedGlobal;

    if (cashFlows.isNotEmpty) {
      final globalCashFlows = List<Map<String, Object>>.from(cashFlows);

      if (portfolioValue > 0 && valuationDate != null) {
        globalCashFlows.add({'amount': portfolioValue, 'date': valuationDate});
      }

      globalCashFlows.sort(
        (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime),
      );

      final irr = _calculateIRR(globalCashFlows);
      if (!irr.isNaN) {
        mwrAnnualizedGlobal = irr;
      }
    }

    return GlobalMetrics(
      totalValue: totalValue,
      totalInvested: totalInvested,
      profitAbs: profitAbs,
      profitRel: profitRel,
      isAnnualized: isAnnualized,
      mwrAnnualized: mwrAnnualized,
      totalValueGlobal: portfolioValue,
      totalInvestedGlobal: totalInvestedGlobal,
      profitAbsGlobal: profitAbs,
      profitRelGlobal: totalInvestedGlobal > 0
          ? profitAbs / totalInvestedGlobal
          : 0.0,
      isAnnualizedGlobal: isAnnualizedGlobal,
      mwrAnnualizedGlobal: mwrAnnualizedGlobal,
    );
  }

  static double _calculateIRR(List<Map<String, Object>> flows) {
    if (flows.isEmpty) return double.nan;

    final sortedFlows = List<Map<String, Object>>.from(
      flows,
    )..sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final hasPositiveFlow = sortedFlows.any(
      (flow) => (flow['amount'] as double) > 0,
    );
    final hasNegativeFlow = sortedFlows.any(
      (flow) => (flow['amount'] as double) < 0,
    );
    if (!hasPositiveFlow || !hasNegativeFlow) return double.nan;

    double npv(double rate) {
      double total = 0;
      final start = sortedFlows.first['date'] as DateTime;
      for (var f in sortedFlows) {
        final time = (f['date'] as DateTime).difference(start).inDays / 365.25;
        total += (f['amount'] as double) / pow(1 + rate, time);
      }
      return total;
    }

    double low = -0.99;
    double high = 2.0;

    final lowNpv = npv(low);
    if (lowNpv == 0) return low;

    var highNpv = npv(high);
    if (highNpv == 0) return high;

    // Amplía progresivamente el límite superior hasta encontrar
    // un intervalo que contenga una raíz.
    while (lowNpv.sign == highNpv.sign && high < 1e9) {
      high = (high * 2 + 1).clamp(2.0, 1e9).toDouble();
      highNpv = npv(high);
      if (highNpv == 0) return high;
    }

    if (lowNpv.sign == highNpv.sign) return double.nan;

    for (int i = 0; i < 50; i++) {
      double mid = (low + high) / 2;
      double v = npv(mid);
      if (v.sign == lowNpv.sign) {
        low = mid;
      } else {
        high = mid;
      }
      if ((high - low).abs() < 1e-6) break;
    }
    return (low + high) / 2;
  }
}
