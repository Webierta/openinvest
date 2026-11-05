import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';

void main() {
  group('LF-134: Histórico manual con los nuevos modelos', () {
    test('LF-134.1: representa una inversión histórica con suscripción y reembolso', () {
      final investment = HistoricalInvestment(
        uid: 'investment-001',
        name: 'Fondo de prueba',
        isin: 'ES0000000001',
      );

      final subscription = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: investment.uid,
        date: DateTime(2025, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final redemption = HistoricalOperation(
        uid: 'operation-002',
        investmentUid: investment.uid,
        date: DateTime(2025, 12, 31),
        type: HistoricalOperationType.redemption,
        amount: 1250,
      );

      expect(investment.name, 'Fondo de prueba');
      expect(investment.isin, 'ES0000000001');

      expect(subscription.investmentUid, investment.uid);
      expect(subscription.type, HistoricalOperationType.subscription);
      expect(subscription.amount, 1000);

      expect(redemption.investmentUid, investment.uid);
      expect(redemption.type, HistoricalOperationType.redemption);
      expect(redemption.amount, 1250);

      expect(redemption.date.isAfter(subscription.date), isTrue);
    });
  });
}
