import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-8: integridad de la fusión', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required double lastValue,
      required DateTime date,
      required List<PricePoint> history,
      List<FundOperation> operations = const [],
      List<FundCostPeriod> costPeriods = const [],
      List<FundCostCharge> costCharges = const [],
      FundSource? source,
      FundSource? valuationSource,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        operations: operations,
        costPeriods: costPeriods,
        costCharges: costCharges,
        source: source,
        valuationSource: valuationSource,
      );
    }

    test(
      'LF-UI-8.1: para un mismo día prevalece el punto entrante sin duplicar',
      () {
        final existing = fund(
          lastValue: 120,
          date: day22,
          history: [
            PricePoint(day20, 100),
            PricePoint(day21, 110),
            PricePoint(day22, 120),
          ],
        );

        final incoming = fund(
          lastValue: 120,
          date: day22,
          history: [PricePoint(day21, 111), PricePoint(day22, 120)],
        );

        final merged = FundDataMerger.merge(existing, incoming);
        final day21Points = merged.history
            .where((point) => point.date == day21)
            .toList();

        expect(day21Points, hasLength(1));
        expect(day21Points.single.price, 111);
        expect(merged.history, hasLength(3));
      },
    );

    test('LF-UI-8.2: con la misma fecha de valoración prevalece el valor existente', () {
      final existing = fund(
        lastValue: 120,
        date: day22,
        history: [PricePoint(day20, 100), PricePoint(day22, 120)],
        valuationSource: FundSource.yahoo,
      );

      final incoming = fund(
        lastValue: 125,
        date: day22,
        history: [PricePoint(day22, 125)],
        valuationSource: FundSource.financialTimes,
      );

      final merged = FundDataMerger.merge(existing, incoming);

      expect(merged.date, day22);
      expect(merged.lastValue, 120);
      expect(merged.valuationSource, FundSource.yahoo);
      expect(
        merged.history.where((point) => point.date == day22).single.price,
        120,
      );
    });

    test(
      'LF-UI-8.3: conserva las operaciones y los costes de ambas versiones',
      () {
        final operationA = FundOperation(
          id: 1,
          isin: 'ES0123456789',
          date: day20,
          type: OperationType.buy,
          units: 10,
          price: 10,
          amount: 100,
        );

        final operationB = FundOperation(
          id: 2,
          isin: 'ES0123456789',
          date: day21,
          type: OperationType.buy,
          units: 5,
          price: 20,
          amount: 100,
        );

        final existing = fund(
          lastValue: 120,
          date: day22,
          history: [PricePoint(day22, 120)],
          operations: [operationA],
        );

        final incoming = fund(
          lastValue: 120,
          date: day22,
          history: [PricePoint(day22, 120)],
          operations: [operationA, operationB],
        );

        final merged = FundDataMerger.merge(existing, incoming);

        expect(merged.operations, hasLength(2));
        expect(merged.operations.map((operation) => operation.id).toSet(), {
          1,
          2,
        });
        expect(merged.costPeriods, isEmpty);
        expect(merged.costCharges, isEmpty);
      },
    );
  });
}
