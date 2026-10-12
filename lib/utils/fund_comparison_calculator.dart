import 'dart:math' as math;
import 'dart:math';

import '../models/fund_cost.dart';
import '../models/fund_data.dart';
import 'financial_calculator.dart';

class FundComparisonResult {
  final DateTime asOf;
  final FundComparisonMetrics first;
  final FundComparisonMetrics second;

  const FundComparisonResult({
    required this.asOf,
    required this.first,
    required this.second,
  });
}

class FundComparisonMetrics {
  final FundData fund;
  final DateTime? historyStart;
  final double? latestNav;
  final double? latestChange;
  final double? monthChange;
  final double? sixMonthChange;
  final double? yearChange;
  final double? sinceInceptionChange;
  final double? annualizedVolatility;
  final double? terRate;
  final double? performanceFeeRate;
  final FundMetrics? investment;

  const FundComparisonMetrics({
    required this.fund,
    required this.historyStart,
    required this.latestNav,
    required this.latestChange,
    required this.monthChange,
    required this.sixMonthChange,
    required this.yearChange,
    required this.sinceInceptionChange,
    required this.annualizedVolatility,
    required this.terRate,
    required this.performanceFeeRate,
    required this.investment,
  });
}

enum FundComparisonChartRange { oneMonth, sixMonths, oneYear, all }

class FundComparisonChartPoint {
  final DateTime date;
  final double firstReturn;
  final double secondReturn;

  const FundComparisonChartPoint({
    required this.date,
    required this.firstReturn,
    required this.secondReturn,
  });
}

class FundComparisonCalculator {
  static List<FundComparisonChartPoint> buildChartPoints(
    FundData first,
    FundData second, {
    required FundComparisonChartRange range,
  }) {
    final asOf = _day(
      first.date.isBefore(second.date) ? first.date : second.date,
    );
    final firstHistory = first.history
        .where((point) => !_day(point.date).isAfter(asOf))
        .toList(growable: false);
    final secondHistory = second.history
        .where((point) => !_day(point.date).isAfter(asOf))
        .toList(growable: false);
    if (firstHistory.isEmpty || secondHistory.isEmpty) return [];

    final commonStart = _later(
      _day(firstHistory.first.date),
      _day(secondHistory.first.date),
    );
    final requestedStart = switch (range) {
      FundComparisonChartRange.oneMonth => asOf.subtract(
        const Duration(days: 30),
      ),
      FundComparisonChartRange.sixMonths => asOf.subtract(
        const Duration(days: 182),
      ),
      FundComparisonChartRange.oneYear => asOf.subtract(
        const Duration(days: 365),
      ),
      FundComparisonChartRange.all => commonStart,
    };
    final start = _later(commonStart, requestedStart);
    if (start.isAfter(asOf)) return [];

    final firstBase = _priceAtOrBefore(firstHistory, start);
    final secondBase = _priceAtOrBefore(secondHistory, start);
    if (firstBase == null ||
        secondBase == null ||
        firstBase <= 0 ||
        secondBase <= 0) {
      return [];
    }

    final dates = <DateTime>{start, asOf};
    dates.addAll(
      firstHistory
          .map((point) => _day(point.date))
          .where((date) => !date.isBefore(start)),
    );
    dates.addAll(
      secondHistory
          .map((point) => _day(point.date))
          .where((date) => !date.isBefore(start)),
    );
    final sortedDates = dates.toList()..sort();

    return [
      for (final date in sortedDates)
        if (_priceAtOrBefore(firstHistory, date) case final firstPrice?
            when firstPrice > 0)
          if (_priceAtOrBefore(secondHistory, date) case final secondPrice?
              when secondPrice > 0)
            FundComparisonChartPoint(
              date: date,
              firstReturn: (firstPrice / firstBase - 1) * 100,
              secondReturn: (secondPrice / secondBase - 1) * 100,
            ),
    ];
  }

  static double? _priceAtOrBefore(List<PricePoint> history, DateTime date) {
    for (var index = history.length - 1; index >= 0; index--) {
      if (!_day(history[index].date).isAfter(date)) return history[index].price;
    }
    return null;
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _later(DateTime first, DateTime second) =>
      first.isAfter(second) ? first : second;

  static FundComparisonResult calculate(FundData first, FundData second) {
    final asOf = first.date.isBefore(second.date) ? first.date : second.date;
    return FundComparisonResult(
      asOf: asOf,
      first: _calculateFund(first, asOf),
      second: _calculateFund(second, asOf),
    );
  }

  static FundComparisonMetrics _calculateFund(FundData fund, DateTime asOf) {
    final history = fund.history
        .where((point) => !point.date.isAfter(asOf))
        .toList(growable: false);
    final latest = history.isEmpty ? null : history.last;
    final previous = history.length < 2 ? null : history[history.length - 2];
    final investment = FinancialCalculator.calculateFundMetrics(fund);

    return FundComparisonMetrics(
      fund: fund,
      historyStart: history.isEmpty ? null : history.first.date,
      latestNav: latest?.price,
      latestChange: _change(previous?.price, latest?.price),
      monthChange: _periodChange(history, asOf, 1),
      sixMonthChange: _periodChange(history, asOf, 6),
      yearChange: _periodChange(history, asOf, 12),
      sinceInceptionChange: _change(
        history.isEmpty ? null : history.first.price,
        latest?.price,
      ),
      annualizedVolatility: FinancialCalculator.calculateAnnualizedVolatility(
        history,
      ),
      terRate: _terRate(fund, asOf),
      performanceFeeRate: _currentCostRate(
        fund,
        FundCostConcept.performance,
        asOf,
        legacyRate: fund.performanceFee,
      ),
      investment: investment.totalUnits > 0 && investment.totalInvested > 0
          ? investment
          : null,
    );
  }

  static double? _periodChange(
    List<PricePoint> history,
    DateTime asOf,
    int months,
  ) {
    final end = _pointAtOrBefore(history, asOf);
    final start = _pointAtOrBefore(history, _subtractMonths(asOf, months));
    return _change(start?.price, end?.price);
  }

  static PricePoint? _pointAtOrBefore(List<PricePoint> history, DateTime date) {
    for (var index = history.length - 1; index >= 0; index--) {
      if (!history[index].date.isAfter(date)) return history[index];
    }
    return null;
  }

  static double? _change(double? start, double? end) {
    if (start == null || end == null || start <= 0) return null;
    final change = end / start - 1;
    return change.isFinite ? change : null;
  }

  static double? _activeCostRate(
    FundData fund,
    FundCostConcept concept,
    DateTime asOf,
  ) {
    final target = DateTime(asOf.year, asOf.month, asOf.day);
    final activePeriods = fund.costPeriods.where((period) {
      if (period.concept != concept || period.validFrom == null) return false;
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
      return !validFrom.isAfter(target) &&
          (validTo == null || !validTo.isBefore(target));
    }).toList()..sort((a, b) => b.validFrom!.compareTo(a.validFrom!));
    return activePeriods.isEmpty ? null : activePeriods.first.ratePercent;
  }

  static double? _currentCostRate(
    FundData fund,
    FundCostConcept concept,
    DateTime asOf, {
    required double? legacyRate,
  }) {
    final hasDatedPeriods = fund.costPeriods.any(
      (period) => period.concept == concept && period.validFrom != null,
    );
    if (hasDatedPeriods) return _activeCostRate(fund, concept, asOf);
    return _activeCostRate(fund, concept, asOf) ?? legacyRate;
  }

  static double? _terRate(FundData fund, DateTime asOf) {
    final declaredTer = _currentCostRate(
      fund,
      FundCostConcept.ter,
      asOf,
      legacyRate: fund.ter,
    );
    if (declaredTer != null) return declaredTer;

    const terComponents = {
      FundCostConcept.management,
      FundCostConcept.depositary,
      FundCostConcept.operating,
      FundCostConcept.distributor,
      FundCostConcept.custody,
    };
    final components = fund.costPeriods.where((period) {
      if (!terComponents.contains(period.concept) ||
          period.basis != FundCostRateBasis.annualBalance ||
          period.treatment != FundCostTreatment.includedInNav ||
          period.validFrom == null) {
        return false;
      }
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
      final target = DateTime(asOf.year, asOf.month, asOf.day);
      return !validFrom.isAfter(target) &&
          (validTo == null || !validTo.isBefore(target));
    });
    final total = components.fold<double>(
      0,
      (sum, period) => sum + period.ratePercent,
    );
    return total > 0 ? total : null;
  }

  static DateTime _subtractMonths(DateTime date, int months) {
    final monthIndex = date.year * 12 + date.month - 1 - months;
    final year = monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, math.min(date.day, lastDayOfMonth));
  }

  /// Calcula el coeficiente de correlación de Pearson entre los históricos de dos fondos.
  /// Devuelve `null` si no hay suficientes datos superpuestos para un cálculo fiable.
  static double? calculateFundCorrelation(
    FundData fundA,
    FundData fundB, {
    int minDataPoints = 30,
  }) {
    // 1. Crear mapas de fecha (normalizada a día) a precio para acceso rápido O(1)
    final Map<DateTime, double> pricesA = {};
    for (final point in fundA.history) {
      final normalizedDate = DateTime(
        point.date.year,
        point.date.month,
        point.date.day,
      );
      pricesA[normalizedDate] = point.price;
    }

    final Map<DateTime, double> pricesB = {};
    for (final point in fundB.history) {
      final normalizedDate = DateTime(
        point.date.year,
        point.date.month,
        point.date.day,
      );
      pricesB[normalizedDate] = point.price;
    }

    // 2. Encontrar fechas comunes y ordenarlas cronológicamente
    final commonDates = pricesA.keys
        .where((date) => pricesB.containsKey(date))
        .toList();
    commonDates.sort((a, b) => a.compareTo(b));

    // 3. Calcular los retornos porcentuales para las fechas comunes
    final List<double> returnsA = [];
    final List<double> returnsB = [];

    for (int i = 1; i < commonDates.length; i++) {
      final prevDate = commonDates[i - 1];
      final currDate = commonDates[i];

      final priceAPrev = pricesA[prevDate]!;
      final priceACurr = pricesA[currDate]!;
      final priceBPrev = pricesB[prevDate]!;
      final priceBCurr = pricesB[currDate]!;

      // Evitar división por cero (aunque un VL debería ser siempre > 0)
      if (priceAPrev <= 0 || priceBPrev <= 0) continue;

      // Retorno porcentual: (PrecioHoy - PrecioAyer) / PrecioAyer
      final returnA = (priceACurr - priceAPrev) / priceAPrev;
      final returnB = (priceBCurr - priceBPrev) / priceBPrev;

      returnsA.add(returnA);
      returnsB.add(returnB);
    }

    // 4. Validar que tenemos suficientes puntos de datos (ej. al menos 30 días de superposición)
    if (returnsA.length < minDataPoints) {
      return null; // Datos insuficientes para una correlación estadísticamente válida
    }

    // 5. Calcular y devolver la correlación de Pearson
    return _calculatePearsonCorrelation(returnsA, returnsB);
  }

  /// Función auxiliar matemática para el coeficiente de correlación de Pearson
  /// Calcula el coeficiente de correlación de Pearson entre dos series de retornos.
  /// Asume que ambas listas tienen la misma longitud y están alineadas por fecha.
  /// (Nota: Hay pasarle a esta función las listas de retornos porcentuales diarios o mensuales,
  /// no los valores liquidativos absolutos, para que la correlación sea estadísticamente válida).
  static double _calculatePearsonCorrelation(
    List<double> returnsA,
    List<double> returnsB,
  ) {
    if (returnsA.length != returnsB.length || returnsA.length < 2) {
      return 0.0; // Datos insuficientes
    }

    final n = returnsA.length;
    double sumA = 0, sumB = 0, sumAB = 0, sumA2 = 0, sumB2 = 0;

    for (int i = 0; i < n; i++) {
      sumA += returnsA[i];
      sumB += returnsB[i];
      sumAB += returnsA[i] * returnsB[i];
      sumA2 += returnsA[i] * returnsA[i];
      sumB2 += returnsB[i] * returnsB[i];
    }

    final numerator = (n * sumAB) - (sumA * sumB);
    final denominator = sqrt(
      ((n * sumA2) - (sumA * sumA)) * ((n * sumB2) - (sumB * sumB)),
    );

    if (denominator == 0) return 0.0;
    //return numerator / denominator;
    final correlation = numerator / denominator;
    return correlation.clamp(-1.0, 1.0);
  }
}
