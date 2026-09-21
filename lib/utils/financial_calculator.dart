import 'dart:math';
import '../services/fund_scraper.dart';

class FundMetrics {
  final double totalUnits;
  final double totalInvested;
  final DateTime? firstOpDate;
  final double currentValue;
  final double profitAbs;
  final double profitRel;
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

class FinancialCalculator {
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
      if (firstOpDate == null || op.date.isBefore(firstOpDate)) {
        firstOpDate = op.date;
      }
    }

    final double currentValue = totalUnits * fund.lastValue;
    final double profitAbs = currentValue - totalInvested;
    final double profitRel = totalInvested > 0 ? (profitAbs / totalInvested) * 100 : 0.0;
    final double avgPurchasePrice = totalUnits > 0 ? totalInvested / totalUnits : 0.0;
    final double moic = totalInvested > 0 ? currentValue / totalInvested : 0.0;

    double tae = 0.0;
    bool isAnnualized = false;
    double? twrTotal;
    double? twrAnnualized;
    double? mwrTotal;
    double? mwrAnnualized;
    int days = 0;

    if (totalInvested > 0 && firstOpDate != null) {
      days = DateTime.now().difference(firstOpDate).inDays;
      if (days > 0) {
        final double years = days / 365.25;
        
        // 1. Rentabilidad Simple Anualizada
        tae = (pow(currentValue / totalInvested, 1 / years) - 1) * 100;
        isAnnualized = days >= 30;

        // 2. TWR (Time-Weighted Return)
        final firstOpPricePoint = fund.history.cast<PricePoint?>().lastWhere(
          (p) => p!.date.isBefore(firstOpDate!.add(const Duration(days: 1))),
          orElse: () => fund.history.isNotEmpty ? fund.history.first : null,
        );
        if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
          final double calculatedTwr = (fund.lastValue / firstOpPricePoint.price) - 1;
          twrTotal = calculatedTwr;
          twrAnnualized = (pow(1 + calculatedTwr, 1 / years) - 1);
        }

        // 3. MWR (Money-Weighted Return / IRR)
        final flows = fund.operations.map((op) => <String, Object>{
          'amount': op.type == OperationType.buy ? -op.amount : op.amount,
          'date': op.date,
        }).toList();
        flows.add(<String, Object>{'amount': currentValue, 'date': DateTime.now()});

        final double irr = _calculateIRR(flows);
        if (!irr.isNaN) {
          mwrAnnualized = irr;
          mwrTotal = (pow(1 + irr, years) - 1);
        }
      } else {
        tae = profitRel;
      }
    }

    return FundMetrics(
      totalUnits: totalUnits,
      totalInvested: totalInvested,
      firstOpDate: firstOpDate,
      currentValue: currentValue,
      profitAbs: profitAbs,
      profitRel: profitRel,
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

  static GlobalMetrics calculateGlobalMetrics(List<FundData> portfolio, Map<String, double> exchangeRates) {
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
