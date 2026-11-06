import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/utils/historical_investment_validator.dart';

void main() {
  group('LF-140: HistoricalInvestmentValidator', () {
    test(
      'LF-140.5: rechaza una inversión cuya primera operación es de salida',
      () {
        final operations = [
          HistoricalOperation(
            uid: 'OP-001',
            investmentUid: 'INV-001',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-002',
            investmentUid: 'INV-001',
            date: DateTime(2024, 2, 1),
            type: HistoricalOperationType.subscription,
            amount: 2000,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validate(operations),
          throwsArgumentError,
        );
      },
    );
    test(
      'LF-140.6: rechaza una inversión cuya última operación es de entrada',
      () {
        final operations = [
          HistoricalOperation(
            uid: 'OP-001',
            investmentUid: 'INV-001',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-002',
            investmentUid: 'INV-001',
            date: DateTime(2024, 2, 1),
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-003',
            investmentUid: 'INV-001',
            date: DateTime(2024, 3, 1),
            type: HistoricalOperationType.subscription,
            amount: 200,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validate(operations),
          throwsArgumentError,
        );
      },
    );

    test('LF-140.7: acepta entradas y salidas intermedias combinadas', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.redemption,
          amount: 300,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: 'INV-001',
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.transferIn,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1200,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        returnsNormally,
      );
    });

    test('LF-140.8: valida según fecha y no según orden de registro', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.redemption,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        returnsNormally,
      );
    });

    test(
      'LF-140.9: desempata operaciones de la misma fecha por orden de registro',
      () {
        final operations = [
          HistoricalOperation(
            uid: 'OP-001',
            investmentUid: 'INV-001',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-002',
            investmentUid: 'INV-001',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validate(operations),
          throwsArgumentError,
        );
      },
    );

    test('LF-140.10: rechaza una inversión sin operaciones', () {
      expect(
        () => HistoricalInvestmentValidator.validate([]),
        throwsArgumentError,
      );
    });

    test('LF-140.11: acepta una inversión con una entrada y una salida', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.transferIn,
          amount: 1500,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.redemption,
          amount: 1500,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        returnsNormally,
      );
    });

    test('LF-140.12: rechaza operaciones de inversiones diferentes', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-002',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        throwsArgumentError,
      );
    });
    test('LF-140.14: rechaza operaciones con UID duplicados', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        throwsArgumentError,
      );
    });

    test('LF-140.16: no modifica el orden original de las operaciones', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.redemption,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        returnsNormally,
      );

      expect(operations[0].uid, 'OP-001');
      expect(operations[1].uid, 'OP-002');
    });

    test(
      'LF-140.17: conserva el orden de registro cuando coinciden fecha y hora',
      () {
        final date = DateTime(2024, 1, 1, 12, 30);

        final operations = [
          HistoricalOperation(
            uid: 'OP-001',
            investmentUid: 'INV-001',
            date: date,
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-002',
            investmentUid: 'INV-001',
            date: date,
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validate(operations),
          throwsArgumentError,
        );
      },
    );

    test('LF-140.18: acepta las cuatro clases de operación', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.transferOut,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: 'INV-001',
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.transferIn,
          amount: 300,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(operations),
        returnsNormally,
      );
    });
  });
}
