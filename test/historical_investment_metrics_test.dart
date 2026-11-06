import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('Historical investment metrics', () {
    test('calcula el resultado y MWR de una inversión cerrada', () {
      final investment = HistoricalInvestment(
        uid: 'INV-001',
        name: 'Inversión de prueba',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1000);
      expect(metrics.totalReturns, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(10, 0.0001));
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test('trata los traspasos como aportaciones y retornos', () {
      final investment = HistoricalInvestment(
        uid: 'INV-002',
        name: 'Inversión con traspasos',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: investment.uid,
          date: DateTime(2023, 6, 1),
          type: HistoricalOperationType.transferIn,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: investment.uid,
          date: DateTime(2023, 9, 1),
          type: HistoricalOperationType.redemption,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1450,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1500);
      expect(metrics.totalReturns, 1650);
      expect(metrics.profitAbs, 150);
      expect(metrics.profitRel, closeTo(10, 0.0001));
    });
  });
}
