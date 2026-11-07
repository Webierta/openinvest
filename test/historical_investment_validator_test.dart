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

    test('LF-141.1: identifica una inversión cerrada por su última operación cronológica', () {
      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
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

      expect(HistoricalInvestmentValidator.isClosed(operations), isTrue);
    });

    test('LF-141.2: identifica como abierta una inversión cuya última operación es una entrada', () {
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
          amount: 200,
        ),
      ];

      expect(HistoricalInvestmentValidator.isClosed(operations), isFalse);
    });

    test('LF-141.3: considera abierta una inversión sin operaciones', () {
      expect(HistoricalInvestmentValidator.isClosed([]), isFalse);
    });

    test('LF-141.4: desempata el cierre por orden de registro cuando coincide la fecha', () {
      final date = DateTime(2024, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
      ];

      expect(HistoricalInvestmentValidator.isClosed(operations), isTrue);
    });

    test(
      'LF-142.1: rechaza borrar la última salida de una inversión cerrada',
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
            amount: 1000,
          ),
        ];

        // Simula el resultado de eliminar la última operación.
        final remainingOperations = operations
            .where((operation) => operation.uid != 'OP-002')
            .toList();

        expect(
          () => HistoricalInvestmentValidator.validate(remainingOperations),
          throwsArgumentError,
        );
      },
    );

    test('LF-142.2: permite eliminar una operación intermedia si la inversión sigue cerrada', () {
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
          type: HistoricalOperationType.subscription,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.transferOut,
          amount: 900,
        ),
      ];

      final remainingOperations = operations
          .where((operation) => operation.uid != 'OP-002')
          .toList();

      expect(
        () => HistoricalInvestmentValidator.validate(remainingOperations),
        returnsNormally,
      );
    });

    test(
      'LF-142.3: rechaza editar la última salida convirtiéndola en entrada',
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
            amount: 1000,
          ),
        ];

        final updatedOperations = [
          operations.first,
          operations.last.copyWith(type: HistoricalOperationType.subscription),
        ];

        expect(
          () => HistoricalInvestmentValidator.validate(updatedOperations),
          throwsArgumentError,
        );
      },
    );

    test('LF-142.4: rechaza cambiar la fecha de la última salida si deja una entrada al final', () {
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
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.subscription,
          amount: 200,
        ),
      ];

      final updatedOperations = [
        operations[0],
        operations[1].copyWith(date: DateTime(2024, 1, 15)),
        operations[2],
      ];

      expect(
        () => HistoricalInvestmentValidator.validate(updatedOperations),
        throwsArgumentError,
      );
    });

    test('LF-142.5: validateDeletion rechaza eliminar la última salida', () {
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
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        throwsArgumentError,
      );
    });

    test(
      'LF-142.6: validateDeletion permite eliminar una operación intermedia',
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
            amount: 300,
          ),
          HistoricalOperation(
            uid: 'OP-003',
            investmentUid: 'INV-001',
            date: DateTime(2024, 3, 1),
            type: HistoricalOperationType.subscription,
            amount: 200,
          ),
          HistoricalOperation(
            uid: 'OP-004',
            investmentUid: 'INV-001',
            date: DateTime(2024, 4, 1),
            type: HistoricalOperationType.transferOut,
            amount: 900,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validateDeletion(
            operations,
            'OP-002',
          ),
          returnsNormally,
        );
      },
    );

    test(
      'LF-142.7: validateUpdate rechaza convertir la última salida en entrada',
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
            amount: 1000,
          ),
        ];

        final updatedOperation = operations.last.copyWith(
          type: HistoricalOperationType.subscription,
        );

        expect(
          () => HistoricalInvestmentValidator.validateUpdate(
            operations,
            updatedOperation,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'LF-142.8: validateUpdate rechaza actualizar una operación inexistente',
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
            amount: 1000,
          ),
        ];

        final unknownOperation = operations.last.copyWith(uid: 'OP-999');

        expect(
          () => HistoricalInvestmentValidator.validateUpdate(
            operations,
            unknownOperation,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'LF-142.9: validateUpdate rechaza cambiar la inversión de una operación',
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
            amount: 1000,
          ),
        ];

        final updatedOperation = operations.last.copyWith(
          investmentUid: 'INV-002',
        );

        expect(
          () => HistoricalInvestmentValidator.validateUpdate(
            operations,
            updatedOperation,
          ),
          throwsArgumentError,
        );
      },
    );
    test('LF-142.14: permite editar una operación intermedia si la inversión sigue siendo válida', () {
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
          type: HistoricalOperationType.subscription,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.transferOut,
          amount: 900,
        ),
      ];

      final updatedOperation = operations[1].copyWith(amount: 350);

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        returnsNormally,
      );
    });
    test('LF-142.15: rechaza editar la fecha de cierre si deja una entrada al final', () {
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
          type: HistoricalOperationType.subscription,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.transferOut,
          amount: 900,
        ),
      ];

      final updatedOperation = operations.last.copyWith(
        date: DateTime(2024, 2, 15),
      );

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        throwsArgumentError,
      );
    });

    test('LF-142.16: validateUpdate no modifica la lista original', () {
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
          amount: 1000,
        ),
      ];

      final updatedOperation = operations.last.copyWith(amount: 950);

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        returnsNormally,
      );

      expect(operations.last.amount, 1000);
      expect(operations.last.type, HistoricalOperationType.redemption);
      expect(operations.last.uid, 'OP-002');
    });

    test(
      'LF-142.17: permite editar una entrada intermedia conservando el cierre',
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
            type: HistoricalOperationType.transferIn,
            amount: 200,
          ),
          HistoricalOperation(
            uid: 'OP-003',
            investmentUid: 'INV-001',
            date: DateTime(2024, 3, 1),
            type: HistoricalOperationType.transferOut,
            amount: 1200,
          ),
        ];

        final updatedOperation = operations[1].copyWith(amount: 250);

        expect(
          () => HistoricalInvestmentValidator.validateUpdate(
            operations,
            updatedOperation,
          ),
          returnsNormally,
        );
      },
    );

    test('LF-142.18: permite cambiar la fecha de una operación intermedia sin alterar el cierre', () {
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
          date: DateTime(2024, 4, 1),
          type: HistoricalOperationType.subscription,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-001',
          date: DateTime(2024, 5, 1),
          type: HistoricalOperationType.transferOut,
          amount: 900,
        ),
      ];

      final updatedOperation = operations[2].copyWith(
        date: DateTime(2024, 3, 1),
      );

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        returnsNormally,
      );
    });

    test(
      'LF-142.19: validateUpdate rechaza duplicar el UID de otra operación',
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
            amount: 1000,
          ),
        ];

        final updatedOperation = operations.last.copyWith(uid: 'OP-001');

        expect(
          () => HistoricalInvestmentValidator.validateUpdate(
            operations,
            updatedOperation,
          ),
          throwsArgumentError,
        );
      },
    );

    test('LF-142.20: permite editar una operación conservando su UID', () {
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
          amount: 1000,
        ),
      ];

      final updatedOperation = operations.last.copyWith(amount: 950);

      expect(updatedOperation.uid, 'OP-002');
      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        returnsNormally,
      );
    });

    test('LF-142.21: rechaza editar una operación si la secuencia original es inválida', () {
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
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
      ];

      final updatedOperation = operations.last.copyWith(amount: 600);

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        throwsArgumentError,
      );
    });

    test('LF-142.22: rechaza borrar una operación si la secuencia original es inválida', () {
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
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        throwsArgumentError,
      );
    });

    test('LF-142.23: rechaza borrar una operación inexistente', () {
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
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-999',
        ),
        throwsArgumentError,
      );

      expect(operations.length, 2);
      expect(operations.map((operation) => operation.uid).toList(), [
        'OP-001',
        'OP-002',
      ]);
    });

    test('LF-142.24: conserva la operación de cierre al borrar una operación intermedia', () {
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
          type: HistoricalOperationType.transferOut,
          amount: 700,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        returnsNormally,
      );

      expect(operations.last.uid, 'OP-003');
      expect(HistoricalInvestmentValidator.isClosed(operations), isTrue);
    });

    test('LF-142.25: validateDeletion no modifica la lista original', () {
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
          type: HistoricalOperationType.transferOut,
          amount: 700,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        returnsNormally,
      );

      expect(operations.length, 3);
      expect(operations.map((operation) => operation.uid).toList(), [
        'OP-001',
        'OP-002',
        'OP-003',
      ]);
    });

    test(
      'LF-142.26: permite borrar una entrada intermedia conservando el cierre',
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
            type: HistoricalOperationType.transferIn,
            amount: 200,
          ),
          HistoricalOperation(
            uid: 'OP-003',
            investmentUid: 'INV-001',
            date: DateTime(2024, 3, 1),
            type: HistoricalOperationType.transferOut,
            amount: 1200,
          ),
        ];

        expect(
          () => HistoricalInvestmentValidator.validateDeletion(
            operations,
            'OP-002',
          ),
          returnsNormally,
        );
      },
    );

    test('LF-142.27: rechaza borrar la última salida cuando comparte fecha con la entrada', () {
      final date = DateTime(2024, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        throwsArgumentError,
      );
    });

    test('LF-142.28: permite editar una operación con fecha coincidente manteniendo el cierre', () {
      final date = DateTime(2024, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.transferOut,
          amount: 100,
        ),
      ];

      final updatedOperation = operations[1].copyWith(amount: 950);

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        returnsNormally,
      );
    });

    test('LF-142.29: rechaza cambiar la fecha si la entrada queda después del cierre', () {
      final date = DateTime(2024, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.redemption,
          amount: 1000,
        ),
      ];

      final updatedOperation = operations.first.copyWith(
        date: DateTime(2024, 1, 2),
      );

      expect(
        () => HistoricalInvestmentValidator.validateUpdate(
          operations,
          updatedOperation,
        ),
        throwsArgumentError,
      );
    });

    test('LF-142.30: permite borrar una operación intermedia con fecha coincidente', () {
      final date = DateTime(2024, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-001',
          date: date,
          type: HistoricalOperationType.transferIn,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: 'INV-001',
          date: DateTime(2024, 2, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1200,
        ),
      ];

      expect(
        () => HistoricalInvestmentValidator.validateDeletion(
          operations,
          'OP-002',
        ),
        returnsNormally,
      );
    });
  });
}
