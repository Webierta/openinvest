import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-22: Integridad de operaciones en FundDataMerger', () {
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

    test('LF-UI-22.1: fusiona operaciones de fondos con listas inmutables', () {
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

      // La fusión conserva ambas operaciones y sus referencias.
      expect(merged.operations, hasLength(2));
      expect(merged.operations, contains(same(opA)));
      expect(merged.operations, contains(same(opB)));

      // Las listas de los fondos originales permanecen intactas.
      expect(a.operations, hasLength(1));
      expect(identical(a.operations.single, opA), isTrue);
      expect(b.operations, hasLength(1));
      expect(identical(b.operations.single, opB), isTrue);

      // El resultado también protege su lista de operaciones.
      expect(
        () => merged.operations.add(
          operation(
            id: 3,
            date: day21,
            type: OperationType.buy,
            units: 3,
            price: 8,
            amount: 24,
          ),
        ),
        throwsUnsupportedError,
      );

      expect(merged.operations, hasLength(2));
    });

    test(
      'LF-UI-22.2: deduplica operaciones sin modificar los fondos originales',
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

        final merged = FundDataMerger.merge(a, b);

        // opB sustituye a opA por compartir la clave de deduplicación.
        expect(merged.operations, hasLength(2));
        expect(merged.operations, contains(same(opB)));
        expect(merged.operations, contains(same(opC)));
        expect(merged.operations, isNot(contains(same(opA))));

        // La fusión no altera las listas ni las referencias originales.
        expect(a.operations, hasLength(1));
        expect(identical(a.operations.single, opA), isTrue);

        expect(b.operations, hasLength(2));
        expect(identical(b.operations[0], opB), isTrue);
        expect(identical(b.operations[1], opC), isTrue);

        // La lista fusionada permanece inmutable.
        expect(() => merged.operations.clear(), throwsUnsupportedError);
        expect(merged.operations, hasLength(2));
      },
    );
  });
}
