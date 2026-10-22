import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-23: Idempotencia de la fusión de operaciones', () {
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

    test(
      'LF-UI-23.1: repetir la fusión no duplica ni sustituye operaciones',
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

        final firstMerge = FundDataMerger.merge(a, b);
        final secondMerge = FundDataMerger.merge(firstMerge, b);

        // La segunda fusión no duplica las operaciones.
        expect(firstMerge.operations, hasLength(2));
        expect(secondMerge.operations, hasLength(2));

        // Las referencias originales se conservan.
        expect(firstMerge.operations, contains(same(opA)));
        expect(firstMerge.operations, contains(same(opB)));
        expect(secondMerge.operations, contains(same(opA)));
        expect(secondMerge.operations, contains(same(opB)));

        // Los fondos originales no cambian.
        expect(a.operations, hasLength(1));
        expect(identical(a.operations.single, opA), isTrue);
        expect(b.operations, hasLength(1));
        expect(identical(b.operations.single, opB), isTrue);

        // El resultado sigue exponiendo una lista inmutable.
        expect(() => secondMerge.operations.clear(), throwsUnsupportedError);
      },
    );

    test('LF-UI-23.2: repetir la fusión conserva la operación ganadora de la deduplicación', () {
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
        date: day20,
        type: OperationType.buy,
        units: 2,
        price: 10,
        amount: 20,
      );

      final opC = operation(
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
        operations: [opB, opC],
      );

      final firstMerge = FundDataMerger.merge(a, b);
      final secondMerge = FundDataMerger.merge(firstMerge, b);

      // La operación entrante opB prevalece sobre opA.
      expect(firstMerge.operations, hasLength(2));
      expect(firstMerge.operations, contains(same(opB)));
      expect(firstMerge.operations, contains(same(opC)));
      expect(firstMerge.operations, isNot(contains(same(opA))));

      // Repetir la fusión no cambia el resultado.
      expect(secondMerge.operations, hasLength(2));
      expect(secondMerge.operations, contains(same(opB)));
      expect(secondMerge.operations, contains(same(opC)));
      expect(secondMerge.operations, isNot(contains(same(opA))));

      // Los fondos originales conservan sus operaciones.
      expect(a.operations, hasLength(1));
      expect(identical(a.operations.single, opA), isTrue);
      expect(b.operations, hasLength(2));
      expect(identical(b.operations[0], opB), isTrue);
      expect(identical(b.operations[1], opC), isTrue);

      // El resultado sigue siendo inmutable.
      expect(() => secondMerge.operations.clear(), throwsUnsupportedError);
    });
  });
}
