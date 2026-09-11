import '../services/fund_scraper.dart';

class FinancialCalculator {
  static double calculateTotalValue(FundData fund) {
    double totalUnits = 0;
    for (var op in fund.operations) {
      if (op.type == OperationType.buy) {
        totalUnits += op.units;
      } else {
        totalUnits -= op.units;
      }
    }
    return totalUnits * fund.lastValue;
  }

  static double calculatePerformance(FundData fund) {
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

    if (totalInvested <= 0 || firstOpDate == null) return -999;

    final currentValue = totalUnits * fund.lastValue;
    
    // Intentar TWR (simplificado como ROI total inicial para este ejemplo)
    final firstOpPricePoint = fund.history.cast<PricePoint?>().lastWhere(
      (p) => p!.date.isBefore(firstOpDate!.add(const Duration(days: 1))),
      orElse: () => null,
    );

    double performanceTotal = 0;
    if (firstOpPricePoint != null && firstOpPricePoint.price > 0) {
      performanceTotal = (fund.lastValue / firstOpPricePoint.price) - 1;
    } else {
      performanceTotal = (currentValue / totalInvested) - 1;
    }
    
    return performanceTotal;
  }
}
