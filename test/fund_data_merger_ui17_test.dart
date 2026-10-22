import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-17: asociatividad de operaciones y aislamiento', () {
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

    test('LF-UI-17.1: operaciones duplicadas tienen el mismo ganador en ambas agrupaciones', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        operations: [
          operation(
            id: 1,
            date: day20,
            type: OperationType.buy,
            units: 2,
            price: 10,
            amount: 20,
          ),
        ],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        operations: [
          operation(
            id: 2,
            date: day20,
            type: OperationType.buy,
            units: 2,
            price: 10,
            amount: 21,
          ),
        ],
      );

      final c = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121), PricePoint(day22, 122)],
        operations: [
          operation(
            id: 3,
            date: day20,
            type: OperationType.buy,
            units: 2,
            price: 10,
            amount: 22,
          ),
        ],
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      expect(left.operations, hasLength(1));
      expect(right.operations, hasLength(1));

      expect(operationSnapshot(left), operationSnapshot(right));
      expect(left.operations.single.id, 3);
      expect(right.operations.single.id, 3);
      expect(left.operations.single.amount, 22);
      expect(right.operations.single.amount, 22);
    });

    test(
      'LF-UI-17.2: las operaciones distintas de tres versiones se conservan',
      () {
        final a = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: [
            operation(
              id: 1,
              date: day20,
              type: OperationType.buy,
              units: 2,
              price: 10,
              amount: 20,
            ),
          ],
        );

        final b = fund(
          symbol: 'B',
          date: day21,
          lastValue: 121,
          history: [PricePoint(day20, 120), PricePoint(day21, 121)],
          operations: [
            operation(
              id: 2,
              date: day21,
              type: OperationType.buy,
              units: 3,
              price: 11,
              amount: 33,
            ),
          ],
        );

        final c = fund(
          symbol: 'C',
          date: day22,
          lastValue: 122,
          history: [PricePoint(day21, 121), PricePoint(day22, 122)],
          operations: [
            operation(
              id: 3,
              date: day22,
              type: OperationType.sell,
              units: 1,
              price: 12,
              amount: 12,
            ),
          ],
        );

        final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
        final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

        expect(left.operations, hasLength(3));
        expect(right.operations, hasLength(3));
        expect(operationSnapshot(left), operationSnapshot(right));
        expect(left.operations.map((e) => e.id).toSet(), {1, 2, 3});
        expect(right.operations.map((e) => e.id).toSet(), {1, 2, 3});
      },
    );

    test(
      'LF-UI-17.3: las fusiones no modifican las operaciones originales',
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
          type: OperationType.buy,
          units: 3,
          price: 11,
          amount: 33,
        );
        final opC = operation(
          id: 3,
          date: day22,
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
        final c = fund(
          symbol: 'C',
          date: day22,
          lastValue: 122,
          history: [PricePoint(day21, 121), PricePoint(day22, 122)],
          operations: [opC],
        );

        final beforeA = operationSnapshot(a);
        final beforeB = operationSnapshot(b);
        final beforeC = operationSnapshot(c);

        final merged = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
        final regrouped = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

        expect(merged.operations, hasLength(3));
        expect(regrouped.operations, hasLength(3));

        expect(operationSnapshot(a), beforeA);
        expect(operationSnapshot(b), beforeB);
        expect(operationSnapshot(c), beforeC);

        expect(opA.amount, 20);
        expect(opB.amount, 33);
        expect(opC.amount, 12);
      },
    );
  });
}
