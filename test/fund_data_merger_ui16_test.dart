import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-16: garantías de asociatividad', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundCostPeriod> costPeriods = const [],
      List<FundCostCharge> costCharges = const [],
      FundSource? source = FundSource.cnmv,
      FundSource? valuationSource = FundSource.yahoo,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        costPeriods: costPeriods,
        costCharges: costCharges,
        source: source,
        valuationSource: valuationSource,
      );
    }

    FundCostPeriod period(String uid, double ratePercent) {
      return FundCostPeriod(
        uid: uid,
        concept: FundCostConcept.ter,
        ratePercent: ratePercent,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );
    }

    FundCostCharge charge(String uid, double amount) {
      return FundCostCharge(
        uid: uid,
        concept: FundCostConcept.ter,
        date: day20,
        amount: amount,
        description: 'Cargo $uid',
      );
    }

    List<String> periodSnapshot(FundData fund) {
      final result =
          fund.costPeriods.map((e) => '${e.uid}:${e.ratePercent}').toList()
            ..sort();
      return result;
    }

    List<String> chargeSnapshot(FundData fund) {
      final result =
          fund.costCharges.map((e) => '${e.uid}:${e.amount}').toList()..sort();
      return result;
    }

    List<String> historySnapshot(FundData fund) {
      final result =
          fund.history
              .map((e) => '${e.date.toIso8601String()}:${e.price}')
              .toList()
            ..sort();
      return result;
    }

    test('LF-UI-16.1: costes idénticos en ambas agrupaciones', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        costPeriods: [period('period-shared', 0.10), period('period-a', 0.11)],
        costCharges: [charge('charge-shared', 1.0), charge('charge-a', 1.1)],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        costPeriods: [period('period-shared', 0.20), period('period-b', 0.21)],
        costCharges: [charge('charge-shared', 2.0), charge('charge-b', 2.1)],
      );

      final c = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121), PricePoint(day22, 122)],
        costPeriods: [period('period-shared', 0.30), period('period-c', 0.31)],
        costCharges: [charge('charge-shared', 3.0), charge('charge-c', 3.1)],
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      expect(periodSnapshot(left), periodSnapshot(right));
      expect(chargeSnapshot(left), chargeSnapshot(right));

      expect(
        left.costPeriods
            .singleWhere((e) => e.uid == 'period-shared')
            .ratePercent,
        0.30,
      );
      expect(
        left.costCharges.singleWhere((e) => e.uid == 'charge-shared').amount,
        3.0,
      );
    });

    test(
      'LF-UI-16.2: historial idéntico, precio por precio y fecha por fecha',
      () {
        final a = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
        );

        final b = fund(
          symbol: 'B',
          date: day21,
          lastValue: 121,
          history: [PricePoint(day20, 120.5), PricePoint(day21, 121)],
        );

        final c = fund(
          symbol: 'C',
          date: day22,
          lastValue: 122,
          history: [
            PricePoint(day20, 119.5),
            PricePoint(day21, 121.5),
            PricePoint(day22, 122),
          ],
        );

        final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
        final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

        expect(historySnapshot(left), historySnapshot(right));
        expect(left.history, hasLength(3));
        expect(right.history, hasLength(3));

        expect(left.history.singleWhere((e) => e.date == day20).price, 119.5);
        expect(left.history.singleWhere((e) => e.date == day21).price, 121.5);
        expect(left.history.singleWhere((e) => e.date == day22).price, 122);
      },
    );

    test(
      'LF-UI-16.3: fuentes y valoración final idénticas en ambas agrupaciones',
      () {
        final a = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          source: FundSource.cnmv,
          valuationSource: FundSource.yahoo,
        );

        final b = fund(
          symbol: 'B',
          date: day21,
          lastValue: 121,
          history: [PricePoint(day20, 120.5), PricePoint(day21, 121)],
          source: FundSource.yahoo,
          valuationSource: FundSource.yahoo,
        );

        final c = fund(
          symbol: 'C',
          date: day22,
          lastValue: 122,
          history: [PricePoint(day21, 121.5), PricePoint(day22, 122)],
          source: FundSource.queFondos,
          valuationSource: FundSource.queFondos,
        );

        final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
        final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

        expect(left.source, right.source);
        expect(left.valuationSource, right.valuationSource);
        expect(left.lastValue, right.lastValue);
        expect(left.date, right.date);

        expect(left.source, FundSource.cnmv);
        expect(left.valuationSource, FundSource.queFondos);
        expect(left.lastValue, 122);
        expect(left.date, day22);
      },
    );
  });
}
