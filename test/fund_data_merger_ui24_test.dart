import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-24: Orden e independencia de las fusiones', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

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

    List<String> operationSnapshot(FundData fund) {
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
    }

    test(
      'LF-UI-24.1: comparar el orden de fusión con operaciones duplicadas',
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
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final fundA = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: [opA],
        );

        final fundB = fund(
          symbol: 'B',
          date: day20,
          lastValue: 121,
          history: [PricePoint(day20, 121)],
          operations: [opB],
        );

        final fundC = fund(
          symbol: 'C',
          date: day20,
          lastValue: 122,
          history: [PricePoint(day20, 122)],
          operations: [opC],
        );

        final leftGrouped = FundDataMerger.merge(
          FundDataMerger.merge(fundA, fundB),
          fundC,
        );

        final rightGrouped = FundDataMerger.merge(
          fundA,
          FundDataMerger.merge(fundB, fundC),
        );

        // En ambos casos queda una única operación por clave.
        expect(leftGrouped.operations, hasLength(1));
        expect(rightGrouped.operations, hasLength(1));

        // Con esta regla de deduplicación, prevalece la operación
        // entrante en cada llamada: ambas agrupaciones deben acabar en opC.
        expect(identical(leftGrouped.operations.single, opC), isTrue);
        expect(identical(rightGrouped.operations.single, opC), isTrue);

        // Los fondos de origen permanecen intactos.
        expect(identical(fundA.operations.single, opA), isTrue);
        expect(identical(fundB.operations.single, opB), isTrue);
        expect(identical(fundC.operations.single, opC), isTrue);

        // Los resultados mantienen la lista inmutable.
        expect(() => leftGrouped.operations.clear(), throwsUnsupportedError);
        expect(() => rightGrouped.operations.clear(), throwsUnsupportedError);
      },
    );

    test(
      'LF-UI-24.2: conserva operaciones únicas con duplicados parciales',
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

        final fundA = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: [opA],
        );

        final fundB = fund(
          symbol: 'B',
          date: day20,
          lastValue: 121,
          history: [PricePoint(day20, 121)],
          operations: [opB],
        );

        final fundC = fund(
          symbol: 'C',
          date: day21,
          lastValue: 122,
          history: [PricePoint(day20, 121), PricePoint(day21, 122)],
          operations: [opC],
        );

        final leftGrouped = FundDataMerger.merge(
          FundDataMerger.merge(fundA, fundB),
          fundC,
        );

        final rightGrouped = FundDataMerger.merge(
          fundA,
          FundDataMerger.merge(fundB, fundC),
        );

        // En ambos órdenes quedan dos operaciones.
        expect(leftGrouped.operations, hasLength(2));
        expect(rightGrouped.operations, hasLength(2));

        // La operación de B prevalece sobre la duplicada de A.
        expect(leftGrouped.operations, contains(same(opB)));
        expect(rightGrouped.operations, contains(same(opB)));
        expect(leftGrouped.operations, isNot(contains(same(opA))));
        expect(rightGrouped.operations, isNot(contains(same(opA))));

        // La operación única de C se conserva en ambos resultados.
        expect(leftGrouped.operations, contains(same(opC)));
        expect(rightGrouped.operations, contains(same(opC)));

        // Los fondos originales permanecen intactos.
        expect(identical(fundA.operations.single, opA), isTrue);
        expect(identical(fundB.operations.single, opB), isTrue);
        expect(identical(fundC.operations.single, opC), isTrue);

        // Ambos resultados exponen listas inmutables.
        expect(() => leftGrouped.operations.clear(), throwsUnsupportedError);
        expect(() => rightGrouped.operations.clear(), throwsUnsupportedError);
      },
    );
  });
}
