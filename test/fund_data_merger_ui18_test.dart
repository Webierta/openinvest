import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-18: Inmutabilidad y aislamiento profundo de operaciones', () {
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

    test('LF-UI-18.1: modificar la lista fusionada no altera las listas originales', () {
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

      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        operations: [opA],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        operations: [opB],
      );

      final merged = FundDataMerger.merge(a, b);

      expect(merged.operations, hasLength(2));
      expect(a.operations, hasLength(1));
      expect(b.operations, hasLength(1));

      // La lista fusionada también debe ser inmutable.
      expect(
        () => merged.operations.removeWhere((op) => op.id == 1),
        throwsUnsupportedError,
      );

      // La operación y las listas originales siguen intactas.
      expect(merged.operations, hasLength(2));
      expect(a.operations, hasLength(1));
      expect(b.operations, hasLength(1));

      expect(identical(a.operations.single, opA), isTrue);
      expect(identical(b.operations.single, opB), isTrue);
    });

    test(
      'LF-UI-18.2: la fusión conserva los datos de las operaciones originales',
      () {
        final opA = operation(
          id: 1,
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final opDuplicada = operation(
          id: 2,
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final opB = operation(
          id: 3,
          date: day21,
          type: OperationType.sell,
          units: 1,
          price: 12,
          amount: 12,
        );

        final a = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: [opA],
        );

        final b = fund(
          symbol: 'B',
          date: day21,
          lastValue: 121,
          history: [PricePoint(day20, 120), PricePoint(day21, 121)],
          operations: [opDuplicada, opB],
        );

        final merged = FundDataMerger.merge(a, b);

        // La operación duplicada entrante prevalece según la clave de fusión.
        expect(merged.operations, hasLength(2));
        expect(merged.operations, contains(same(opDuplicada)));
        expect(merged.operations, contains(same(opB)));
        expect(merged.operations, isNot(contains(same(opA))));

        // La fusión no modifica las operaciones ni sus listas originales.
        expect(a.operations, hasLength(1));
        expect(b.operations, hasLength(2));

        expect(identical(a.operations.single, opA), isTrue);
        expect(identical(b.operations[0], opDuplicada), isTrue);
        expect(identical(b.operations[1], opB), isTrue);

        expect(opA.id, 1);
        expect(opA.units, 2);
        expect(opA.price, 10);
        expect(opA.amount, 20);

        expect(opDuplicada.id, 2);
        expect(opDuplicada.units, 2);
        expect(opDuplicada.price, 10);
        expect(opDuplicada.amount, 20);

        expect(opB.id, 3);
        expect(opB.units, 1);
        expect(opB.price, 12);
        expect(opB.amount, 12);
      },
    );

    test('LF-UI-18.3: modificar las listas de entrada no altera la lista fusionada', () {
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

      final operationsA = <FundOperation>[opA];
      final operationsB = <FundOperation>[opB];

      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        operations: operationsA,
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        operations: operationsB,
      );

      final merged = FundDataMerger.merge(a, b);

      expect(merged.operations, hasLength(2));
      expect(merged.operations, contains(same(opA)));
      expect(merged.operations, contains(same(opB)));

      // Las listas originales siguen siendo mutables.
      operationsA.clear();

      operationsB.add(
        operation(
          id: 3,
          date: day21,
          type: OperationType.buy,
          units: 3,
          price: 8,
          amount: 24,
        ),
      );

      // Modificar las listas originales no cambia los fondos,
      // porque FundData conserva copias inmutables.
      expect(a.operations, hasLength(1));
      expect(b.operations, hasLength(1));

      expect(identical(a.operations.single, opA), isTrue);
      expect(identical(b.operations.single, opB), isTrue);

      // La fusión también permanece intacta.
      expect(merged.operations, hasLength(2));
      expect(merged.operations, contains(same(opA)));
      expect(merged.operations, contains(same(opB)));
      expect(merged.operations.any((op) => op.id == 3), isFalse);
    });
  });
}
