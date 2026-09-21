import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('FinancialCalculator Tests', () {
    final baseDate = DateTime(2023, 1, 1);
    final mockHistory = [
      PricePoint(baseDate, 10.0),
      PricePoint(baseDate.add(const Duration(days: 30)), 12.0),
    ];

    test('calculateFundMetrics should correctly calculate units and value', () {
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 12.0,
        currency: 'EUR',
        date: baseDate.add(const Duration(days: 30)),
        history: mockHistory,
        operations: [
          FundOperation(
            isin: 'TEST',
            date: baseDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
          FundOperation(
            isin: 'TEST',
            date: baseDate.add(const Duration(days: 10)),
            type: OperationType.sell,
            units: 2,
            price: 11,
            amount: 22,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateFundMetrics(fund);
      // (10 - 2) * 12 = 8 * 12 = 96
      expect(metrics.currentValue, 96.0);
      expect(metrics.totalUnits, 8.0);
    });

    test('calculateFundMetrics should handle no investment correctly', () {
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 12.0,
        currency: 'EUR',
        date: baseDate,
        history: mockHistory,
        operations: [],
      );

      final metrics = FinancialCalculator.calculateFundMetrics(fund);
      expect(metrics.tae, 0);
      expect(metrics.currentValue, 0);
    });
  });
}
