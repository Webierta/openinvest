import 'dart:math';

import '../models/fund_cost.dart';
import '../services/fund_scraper.dart';

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
    required this.days,
  });
}

class GlobalMetrics {
  final double totalValue;
  final double totalInvested;
  final double profitAbs;
  final double profitRel;
  final bool isAnnualized;

  GlobalMetrics({
    required this.totalValue,
    required this.totalInvested,
    required this.profitAbs,
    required this.profitRel,
    required this.isAnnualized,
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
      if (operation.type == OperationType.buy) {
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
      if (operation.type == OperationType.buy) {
        units += operation.units;
        invested += operation.amount;
      } else {
        units -= operation.units;
        invested -= operation.amount;
      }
    }
    return units * quote.price - invested;
  }

  static FundMetrics calculateFundMetrics(FundData fund) {
    double totalUnits = 0;
    double totalInvested = 0;
    DateTime? firstOpDate;

    for (var op in fund.operations) {
      if (op.type == OperationType.buy) {
        totalUnits += op.units;
        totalInvested += op.amount;
      } else {
        totalUnits -= op.units;
        totalInvested -= op.amount;
      }
      if (op.type == OperationType.buy &&
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

    if (totalInvested > 0 && firstOpDate != null) {
      // days = DateTime.now().difference(firstOpDate).inDays;

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
          if (op.type == OperationType.buy) {
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
                'amount': op.type == OperationType.buy ? -op.amount : op.amount,
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

        /* final flows = fund.operations
            .map(
              (op) => <String, Object>{
                'amount': op.type == OperationType.buy ? -op.amount : op.amount,
                'date': op.date,
              },
            )
            .toList();
        flows.add(<String, Object>{
          'amount': currentValue,
          'date': DateTime.now(),
        });

        final double irr = _calculateIRR(flows);
        if (!irr.isNaN) {
          mwrAnnualized = irr;
          mwrTotal = (pow(1 + irr, years) - 1);
        } */
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
      days: days,
    );
  }

  static GlobalMetrics calculateGlobalMetrics(
    List<FundData> portfolio,
    Map<String, double> exchangeRates,
  ) {
    double totalValue = 0;
    double totalInvested = 0;
    double profitAbs = 0;
    double weightedTaeSum = 0;
    DateTime? firstOpDate;

    for (var fund in portfolio) {
      final metrics = calculateFundMetrics(fund);
      final double rate = exchangeRates[fund.currency] ?? 1.0;

      final fundValueConverted = metrics.currentValue * rate;
      final fundInvestedConverted = metrics.totalInvested * rate;

      totalValue += fundValueConverted;
      totalInvested += fundInvestedConverted;
      profitAbs += (fundValueConverted - fundInvestedConverted);

      if (fundValueConverted > 0) {
        weightedTaeSum += metrics.tae * fundValueConverted;
      }

      if (metrics.firstOpDate != null) {
        if (firstOpDate == null || metrics.firstOpDate!.isBefore(firstOpDate)) {
          firstOpDate = metrics.firstOpDate;
        }
      }
    }

    double profitRel = totalValue > 0 ? weightedTaeSum / totalValue : 0.0;

    if (profitRel == 0 && profitAbs != 0 && totalInvested > 0) {
      profitRel = (profitAbs / totalInvested) * 100;
    }

    bool isAnnualized = false;
    if (firstOpDate != null) {
      isAnnualized = DateTime.now().difference(firstOpDate).inDays >= 30;
    }

    return GlobalMetrics(
      totalValue: totalValue,
      totalInvested: totalInvested,
      profitAbs: profitAbs,
      profitRel: profitRel,
      isAnnualized: isAnnualized,
    );
  }

  static double _calculateIRR(List<Map<String, Object>> flows) {
    if (flows.isEmpty) return double.nan;

    double npv(double rate) {
      double total = 0;
      final start = flows.first['date'] as DateTime;
      for (var f in flows) {
        final time = (f['date'] as DateTime).difference(start).inDays / 365.25;
        total += (f['amount'] as double) / pow(1 + rate, time);
      }
      return total;
    }

    double low = -0.99, high = 2.0;
    for (int i = 0; i < 50; i++) {
      double mid = (low + high) / 2;
      double v = npv(mid);
      if (v > 0) {
        low = mid;
      } else {
        high = mid;
      }
      if ((high - low).abs() < 1e-6) break;
    }
    return (low + high) / 2;
  }
}
