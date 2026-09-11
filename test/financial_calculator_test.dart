import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('FinancialCalculator Tests', () {
    final baseDate = DateTime(2023, 1, 1);
    final mockHistory = [PricePoint(baseDate, 10.0), PricePoint(baseDate.add(const Duration(days: 30)), 12.0)];
    
    test('calculateTotalValue should correctly sum units', () {
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 12.0,
        currency: 'EUR',
        date: baseDate.add(const Duration(days: 30)),
        history: mockHistory,
        operations: [
          FundOperation(isin: 'TEST', date: baseDate, type: OperationType.buy, units: 10, price: 10, amount: 100),
          FundOperation(isin: 'TEST', date: baseDate.add(const Duration(days: 10)), type: OperationType.sell, units: 2, price: 11, amount: 22),
        ],
      );

      final value = FinancialCalculator.calculateTotalValue(fund);
      // (10 - 2) * 12 = 8 * 12 = 96
      expect(value, 96.0);
    });

    test('calculatePerformance should return -999 for no investment', () {
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

      expect(FinancialCalculator.calculatePerformance(fund), -999);
    });
  });
}
