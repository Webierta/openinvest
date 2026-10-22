import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  group('LF-UI-20: Integridad del contrato de operaciones', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    //final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundOperation> operations = const [],
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        operations: operations,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
    }

    FundOperation operation({
      int? id,
      String isin = 'ES0123456789',
      required DateTime date,
      required OperationType type,
      required double units,
      required double price,
      required double amount,
    }) {
      return FundOperation(
        id: id,
        isin: isin,
        date: date,
        type: type,
        units: units,
        price: price,
        amount: amount,
      );
    }

    /* List<String> operationSnapshot(FundData fund) {
      final result = fund.operations.map((op) {
        return [
          op.id,
          op.isin,
          op.date.toIso8601String(),
          op.type.name,
          op.units,
          op.price,
          op.amount,
        ].join('|');
      }).toList()..sort();

      return result;
    } */

    test(
      'LF-UI-20.1: copyWith conserva las operaciones si no se sustituyen',
      () {
        final opA = operation(
          id: 1,
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final originalOperations = <FundOperation>[opA];

        final original = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: originalOperations,
        );

        final copy = original.copyWith(lastValue: 125);

        // La copia conserva la operación y su identidad.
        expect(copy.operations, hasLength(1));
        expect(identical(copy.operations.single, opA), isTrue);

        // Ambas listas están protegidas frente a modificaciones.
        expect(
          () => copy.operations.add(
            operation(
              id: 2,
              date: day21,
              type: OperationType.buy,
              units: 1,
              price: 11,
              amount: 11,
            ),
          ),
          throwsUnsupportedError,
        );

        expect(() => original.operations.clear(), throwsUnsupportedError);

        // La copia cambia la valoración, pero no las operaciones.
        expect(copy.lastValue, 125);
        expect(original.lastValue, 120);
        expect(original.operations, hasLength(1));
        expect(copy.operations, hasLength(1));
      },
    );

    test(
      'LF-UI-20.2: copyWith copia y protege la nueva lista de operaciones',
      () {
        final opA = operation(
          id: 1,
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final opB = operation(
          id: 2,
          date: day21,
          type: OperationType.sell,
          units: 1,
          price: 12,
          amount: 12,
        );

        final original = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: [opA],
        );

        final replacementOperations = <FundOperation>[opB];

        final copy = original.copyWith(operations: replacementOperations);

        // La copia utiliza las nuevas operaciones.
        expect(copy.operations, hasLength(1));
        expect(identical(copy.operations.single, opB), isTrue);

        // La lista recibida no se comparte con la copia.
        replacementOperations.clear();

        expect(copy.operations, hasLength(1));
        expect(identical(copy.operations.single, opB), isTrue);

        // La nueva lista expuesta por la copia es inmutable.
        expect(() => copy.operations.add(opA), throwsUnsupportedError);

        // El fondo original mantiene sus operaciones.
        expect(original.operations, hasLength(1));
        expect(identical(original.operations.single, opA), isTrue);
      },
    );
  });

  group('LF-UI-21: Independencia entre copias', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundOperation> operations = const [],
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        operations: operations,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
    }

    FundOperation operation({
      int? id,
      String isin = 'ES0123456789',
      required DateTime date,
      required OperationType type,
      required double units,
      required double price,
      required double amount,
    }) {
      return FundOperation(
        id: id,
        isin: isin,
        date: date,
        type: type,
        units: units,
        price: price,
        amount: amount,
      );
    }

    test('LF-UI-21.1: dos copias mantienen sus operaciones independientes', () {
      final opA = operation(
        id: 1,
        date: day20,
        type: OperationType.buy,
        units: 2,
        price: 10,
        amount: 20,
      );

      final opB = operation(
        id: 2,
        date: day21,
        type: OperationType.sell,
        units: 1,
        price: 12,
        amount: 12,
      );

      final opC = operation(
        id: 3,
        date: day21,
        type: OperationType.buy,
        units: 3,
        price: 8,
        amount: 24,
      );

      final original = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        operations: [opA],
      );

      final copyA = original.copyWith(operations: [opB]);
      final copyB = original.copyWith(operations: [opC]);

      // Cada fondo conserva únicamente su conjunto de operaciones.
      expect(original.operations, hasLength(1));
      expect(identical(original.operations.single, opA), isTrue);

      expect(copyA.operations, hasLength(1));
      expect(identical(copyA.operations.single, opB), isTrue);

      expect(copyB.operations, hasLength(1));
      expect(identical(copyB.operations.single, opC), isTrue);

      // Las listas de las tres instancias están protegidas.
      expect(() => original.operations.add(opB), throwsUnsupportedError);
      expect(() => copyA.operations.clear(), throwsUnsupportedError);
      expect(() => copyB.operations.remove(opC), throwsUnsupportedError);

      // Las operaciones y sus referencias permanecen intactas.
      expect(original.operations, hasLength(1));
      expect(identical(original.operations.single, opA), isTrue);

      expect(copyA.operations, hasLength(1));
      expect(identical(copyA.operations.single, opB), isTrue);

      expect(copyB.operations, hasLength(1));
      expect(identical(copyB.operations.single, opC), isTrue);
    });

    test('LF-UI-21.2: una cadena de copyWith conserva el aislamiento de operaciones', () {
      final opA = operation(
        id: 1,
        date: day20,
        type: OperationType.buy,
        units: 2,
        price: 10,
        amount: 20,
      );

      final opB = operation(
        id: 2,
        date: day21,
        type: OperationType.sell,
        units: 1,
        price: 12,
        amount: 12,
      );

      final opC = operation(
        id: 3,
        date: day21,
        type: OperationType.buy,
        units: 3,
        price: 8,
        amount: 24,
      );

      final original = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        operations: [opA],
      );

      final firstCopy = original.copyWith(operations: [opB]);
      final secondCopy = firstCopy.copyWith(operations: [opC]);
      final thirdCopy = secondCopy.copyWith(lastValue: 130);

      // Cada generación conserva su propio conjunto de operaciones.
      expect(original.operations, hasLength(1));
      expect(identical(original.operations.single, opA), isTrue);

      expect(firstCopy.operations, hasLength(1));
      expect(identical(firstCopy.operations.single, opB), isTrue);

      expect(secondCopy.operations, hasLength(1));
      expect(identical(secondCopy.operations.single, opC), isTrue);

      // Si no se sustituyen las operaciones, se conservan las de la generación anterior.
      expect(thirdCopy.operations, hasLength(1));
      expect(identical(thirdCopy.operations.single, opC), isTrue);

      expect(thirdCopy.lastValue, 130);
      expect(secondCopy.lastValue, 120);

      // Todas las listas siguen siendo inmutables.
      expect(() => original.operations.clear(), throwsUnsupportedError);
      expect(() => firstCopy.operations.clear(), throwsUnsupportedError);
      expect(() => secondCopy.operations.clear(), throwsUnsupportedError);
      expect(() => thirdCopy.operations.clear(), throwsUnsupportedError);
    });
  });
}
