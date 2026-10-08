import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_comparison_calculator.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('FundComparisonCalculator', () {
    test('alinea ambos fondos a una fecha base común sobre días reales', () {
      final asOf = DateTime(2026, 10, 1);
      final first = _fund(
        isin: 'CHART1',
        date: asOf,
        lastValue: 110,
        history: [
          PricePoint(DateTime(2026, 9, 29), 100),
          PricePoint(asOf, 110),
        ],
      );
      final second = _fund(
        isin: 'CHART2',
        date: asOf,
        lastValue: 180,
        history: [
          PricePoint(DateTime(2026, 9, 30), 200),
          PricePoint(asOf, 180),
        ],
      );

      final points = FundComparisonCalculator.buildChartPoints(
        first,
        second,
        range: FundComparisonChartRange.oneYear,
      );

      expect(points, hasLength(2));
      expect(points.first.date, DateTime(2026, 9, 30));
      expect(points.first.firstReturn, 0);
      expect(points.first.secondReturn, 0);
      expect(points.last.date, asOf);
      expect(points.last.firstReturn, closeTo(10, 0.000001));
      expect(points.last.secondReturn, closeTo(-10, 0.000001));
    });

    test(
      'calcula cambios usando la fecha común y valores anteriores al corte',
      () {
        final asOf = DateTime(2026, 10, 1);
        final first = _fund(
          isin: 'FIRST',
          date: DateTime(2026, 10, 2),
          lastValue: 999,
          history: [
            PricePoint(DateTime(2024, 4, 1), 80),
            PricePoint(DateTime(2025, 10, 1), 90),
            PricePoint(DateTime(2026, 4, 1), 100),
            PricePoint(DateTime(2026, 9, 1), 110),
            PricePoint(DateTime(2026, 9, 30), 120),
            PricePoint(asOf, 121),
          ],
        );
        final second = _fund(
          isin: 'SECOND',
          date: asOf,
          lastValue: 55,
          history: [
            PricePoint(DateTime(2026, 4, 1), 50),
            PricePoint(DateTime(2026, 9, 1), 50),
            PricePoint(asOf, 55),
          ],
        );

        final result = FundComparisonCalculator.calculate(first, second);

        expect(result.asOf, asOf);
        expect(result.first.latestNav, 121);
        expect(result.first.latestChange, closeTo(1 / 120, 0.000001));
        expect(result.first.monthChange, closeTo(0.1, 0.000001));
        expect(result.first.sixMonthChange, closeTo(0.21, 0.000001));
        expect(result.first.yearChange, closeTo(31 / 90, 0.000001));
        expect(result.first.sinceInceptionChange, closeTo(41 / 80, 0.000001));
        expect(result.first.historyStart, DateTime(2024, 4, 1));
        expect(result.first.investment, isNull);
      },
    );

    test(
      'deja la volatilidad sin valor cuando el historial es insuficiente',
      () {
        final date = DateTime(2026, 10, 1);
        final result = FundComparisonCalculator.calculate(
          _fund(
            isin: 'SHORT1',
            date: date,
            lastValue: 10,
            history: [PricePoint(date, 10)],
          ),
          _fund(
            isin: 'SHORT2',
            date: date,
            lastValue: 10,
            history: [PricePoint(date, 10)],
          ),
        );

        expect(result.first.annualizedVolatility, isNull);
        expect(result.first.yearChange, isNull);
      },
    );

    test('comparte la volatilidad poblacional con la pestaña Estado', () {
      final date = DateTime(2026, 10, 1);
      final history = [
        PricePoint(date.subtract(const Duration(days: 2)), 100),
        PricePoint(date.subtract(const Duration(days: 1)), 110),
        PricePoint(date, 99),
      ];
      final fund = _fund(
        isin: 'VOLATILITY',
        date: date,
        lastValue: 99,
        history: history,
      );
      final other = _fund(
        isin: 'OTHER',
        date: date,
        lastValue: 99,
        history: history,
      );

      final result = FundComparisonCalculator.calculate(fund, other);
      final expected = FinancialCalculator.calculateAnnualizedVolatility(
        fund.history,
      );

      expect(expected, closeTo(0.1 * math.sqrt(252), 0.000001));
      expect(result.first.annualizedVolatility, expected);
    });

    test('calcula volatilidad cero para una serie sin variaciones', () {
      final date = DateTime(2026, 10, 1);
      final history = List.generate(
        31,
        (index) => PricePoint(date.subtract(Duration(days: 30 - index)), 10),
      );
      final result = FundComparisonCalculator.calculate(
        _fund(isin: 'FLAT1', date: date, lastValue: 10, history: history),
        _fund(isin: 'FLAT2', date: date, lastValue: 10, history: history),
      );

      expect(result.first.annualizedVolatility, 0);
    });

    test('incluye métricas solo para una posición abierta', () {
      final buyDate = DateTime(2026, 9, 1);
      final asOf = DateTime(2026, 10, 1);
      final fund = _fund(
        isin: 'INVESTED',
        date: asOf,
        lastValue: 11,
        history: [PricePoint(buyDate, 10), PricePoint(asOf, 11)],
        operations: [
          FundOperation(
            isin: 'INVESTED',
            date: buyDate,
            type: OperationType.buy,
            units: 2,
            price: 10,
            amount: 20,
          ),
        ],
      );
      final other = _fund(
        isin: 'NO_POSITION',
        date: asOf,
        lastValue: 10,
        history: [PricePoint(buyDate, 10), PricePoint(asOf, 10)],
      );

      final result = FundComparisonCalculator.calculate(fund, other);

      expect(result.first.investment, isNotNull);
      expect(result.first.investment!.totalInvested, 20);
      expect(result.first.investment!.currentValue, 22);
      expect(result.second.investment, isNull);
    });

    test('compara los costes vigentes en la fecha común', () {
      final date = DateTime(2026, 10, 1);
      final fund = _fund(
        isin: 'COSTS',
        date: date,
        lastValue: 10,
        history: [PricePoint(date, 10)],
        ter: 0.8,
        performanceFee: 12,
        costPeriods: [
          _period(FundCostConcept.ter, 0.7, DateTime(2026, 1, 1)),
          _period(FundCostConcept.management, 0.2, DateTime(2026, 1, 1)),
          _period(
            FundCostConcept.depositary,
            0.05,
            DateTime(2025, 1, 1),
            validTo: DateTime(2026, 9, 30),
          ),
          _period(FundCostConcept.operating, 0.1, DateTime(2026, 10, 2)),
        ],
      );
      final other = _fund(
        isin: 'NO_COSTS',
        date: date,
        lastValue: 10,
        history: [PricePoint(date, 10)],
      );

      final result = FundComparisonCalculator.calculate(fund, other);

      expect(result.first.terRate, 0.7);
      expect(result.first.performanceFeeRate, 12);

      final componentsOnlyFund = _fund(
        isin: 'COMPONENTS',
        date: date,
        lastValue: 10,
        history: [PricePoint(date, 10)],
        costPeriods: [
          _period(FundCostConcept.management, 0.2, DateTime(2026, 1, 1)),
          _period(FundCostConcept.depositary, 0.05, DateTime(2026, 1, 1)),
          _period(FundCostConcept.operating, 0.1, DateTime(2026, 1, 1)),
          _period(
            FundCostConcept.management,
            0.4,
            DateTime(2026, 1, 1),
            treatment: FundCostTreatment.chargedSeparately,
          ),
        ],
      );
      final componentsResult = FundComparisonCalculator.calculate(
        componentsOnlyFund,
        other,
      );

      expect(componentsResult.first.terRate, closeTo(0.35, 0.000001));
      expect(componentsResult.first.performanceFeeRate, isNull);

      final expiredTerFund = _fund(
        isin: 'EXPIRED_TER',
        date: date,
        lastValue: 10,
        history: [PricePoint(date, 10)],
        ter: 0.8,
        costPeriods: [
          _period(
            FundCostConcept.ter,
            0.7,
            DateTime(2025, 1, 1),
            validTo: DateTime(2026, 9, 30),
          ),
        ],
      );
      final expiredResult = FundComparisonCalculator.calculate(
        expiredTerFund,
        other,
      );

      expect(expiredResult.first.terRate, isNull);
    });
  });
}

FundData _fund({
  required String isin,
  required DateTime date,
  required double lastValue,
  required List<PricePoint> history,
  List<FundOperation> operations = const [],
  double? ter,
  double? performanceFee,
  List<FundCostPeriod>? costPeriods,
}) => FundData(
  isin: isin,
  symbol: isin,
  name: isin,
  lastValue: lastValue,
  currency: 'EUR',
  date: date,
  history: history,
  operations: operations,
  ter: ter,
  performanceFee: performanceFee,
  costPeriods: costPeriods,
);

FundCostPeriod _period(
  FundCostConcept concept,
  double ratePercent,
  DateTime validFrom, {
  DateTime? validTo,
  FundCostTreatment treatment = FundCostTreatment.includedInNav,
}) => FundCostPeriod(
  concept: concept,
  ratePercent: ratePercent,
  basis: FundCostRateBasis.annualBalance,
  treatment: treatment,
  validFrom: validFrom,
  validTo: validTo,
);
