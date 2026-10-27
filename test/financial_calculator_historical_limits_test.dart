import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('LF-130: límites cronológicos de salida', () {
    const isin = 'TEST123';

    FundOperation operation(DateTime date, OperationType type, double units) {
      return FundOperation(
        isin: isin,
        date: date,
        type: type,
        units: units,
        price: 10,
        amount: units * 10,
      );
    }

    FundData fundWith(List<FundOperation> operations) {
      return FundData(
        isin: isin,
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 10,
        currency: 'EUR',
        date: DateTime(2026, 12, 31),
        history: const [],
        operations: operations,
      );
    }

    test(
      'LF-130.1: limita una salida histórica según el saldo mínimo posterior',
      () {
        final fund = fundWith([
          operation(DateTime(2026, 1, 10), OperationType.buy, 100),
          operation(DateTime(2026, 3, 10), OperationType.sell, 70),
          operation(DateTime(2026, 6, 10), OperationType.inTransfer, 20),
          operation(DateTime(2026, 7, 10), OperationType.outTransfer, 5),
        ]);

        final maxUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
          fund,
          DateTime(2026, 1, 10),
        );

        // Saldos posteriores: 100, 30, 50 y 45.
        // Una salida histórica de 30 dejaría el saldo mínimo en cero.
        expect(maxUnits, 30);
      },
    );

    test('LF-130.2: no permite usar compras futuras para justificar una salida anterior', () {
      final fund = fundWith([
        operation(DateTime(2026, 1, 10), OperationType.buy, 100),
        operation(DateTime(2026, 3, 10), OperationType.buy, 500),
        operation(DateTime(2026, 6, 10), OperationType.sell, 550),
      ]);

      final maxUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        DateTime(2026, 1, 10),
      );

      // Saldo tras la última operación: 50.
      // Una salida anterior superior a 50 rompería la cronología.
      expect(maxUnits, 50);
    });

    test('LF-130.3: respeta el saldo disponible en la fecha seleccionada', () {
      final fund = fundWith([
        operation(DateTime(2026, 1, 10), OperationType.buy, 100),
        operation(DateTime(2026, 3, 10), OperationType.sell, 80),
        operation(DateTime(2026, 6, 10), OperationType.inTransfer, 50),
      ]);

      final maxUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        DateTime(2026, 3, 10),
      );

      // Saldo tras las operaciones del 10 de marzo: 20.
      // El traspaso posterior lo aumenta a 70, pero no justifica
      // una salida de más de 20 con fecha de marzo.
      expect(maxUnits, 20);
    });

    test('LF-130.4: devuelve cero antes de que existan participaciones', () {
      final fund = fundWith([
        operation(DateTime(2026, 3, 10), OperationType.buy, 100),
      ]);

      final maxUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        DateTime(2026, 1, 10),
      );

      expect(maxUnits, 0);
    });
  });
}
