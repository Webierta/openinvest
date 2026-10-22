import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-13: integridad de las fusiones encadenadas', () {
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

    test('LF-UI-13.1: tres versiones conservan todos los costes únicos', () {
      final versionA = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        costPeriods: [period('period-a', 0.10)],
        costCharges: [charge('charge-a', 1.0)],
      );

      final versionB = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        costPeriods: [period('period-a', 0.15), period('period-b', 0.20)],
        costCharges: [charge('charge-a', 1.5), charge('charge-b', 2.0)],
      );

      final versionC = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121), PricePoint(day22, 122)],
        costPeriods: [period('period-c', 0.30)],
        costCharges: [charge('charge-c', 3.0)],
      );

      final merged = FundDataMerger.merge(
        FundDataMerger.merge(versionA, versionB),
        versionC,
      );

      expect(merged.costPeriods, hasLength(3));
      expect(merged.costPeriods.map((e) => e.uid).toSet(), {
        'period-a',
        'period-b',
        'period-c',
      });
      expect(
        merged.costPeriods.singleWhere((e) => e.uid == 'period-a').ratePercent,
        0.15,
      );

      expect(merged.costCharges, hasLength(3));
      expect(merged.costCharges.map((e) => e.uid).toSet(), {
        'charge-a',
        'charge-b',
        'charge-c',
      });
      expect(
        merged.costCharges.singleWhere((e) => e.uid == 'charge-a').amount,
        1.5,
      );
    });

    test('LF-UI-13.2: una versión antigua posterior no hace retroceder la valoración', () {
      final newest = fund(
        symbol: 'NEWEST',
        date: day22,
        lastValue: 122,
        history: [
          PricePoint(day20, 120),
          PricePoint(day21, 121),
          PricePoint(day22, 122),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.queFondos,
      );

      final intermediate = fund(
        symbol: 'INTERMEDIATE',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
      );

      final oldest = fund(
        symbol: 'OLDEST',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
      );

      final merged = FundDataMerger.merge(
        FundDataMerger.merge(newest, intermediate),
        oldest,
      );

      expect(merged.lastValue, 122);
      expect(merged.date, day22);
      expect(merged.valuationSource, FundSource.queFondos);
      expect(merged.source, FundSource.cnmv);
      expect(merged.history, hasLength(3));
    });

    test(
      'LF-UI-13.3: los conflictos del historial respetan el orden de fusión',
      () {
        final versionA = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          source: FundSource.cnmv,
          valuationSource: FundSource.yahoo,
        );

        final versionB = fund(
          symbol: 'B',
          date: day21,
          lastValue: 121,
          history: [PricePoint(day20, 120.5), PricePoint(day21, 121)],
          source: FundSource.yahoo,
          valuationSource: FundSource.yahoo,
        );

        final versionC = fund(
          symbol: 'C',
          date: day22,
          lastValue: 122,
          history: [
            PricePoint(day20, 119.5),
            PricePoint(day21, 121.5),
            PricePoint(day22, 122),
          ],
          source: FundSource.queFondos,
          valuationSource: FundSource.queFondos,
        );

        final merged = FundDataMerger.merge(
          FundDataMerger.merge(versionA, versionB),
          versionC,
        );

        expect(merged.source, FundSource.cnmv);
        expect(merged.valuationSource, FundSource.queFondos);
        expect(merged.lastValue, 122);
        expect(merged.date, day22);
        expect(merged.history, hasLength(3));

        expect(merged.history.singleWhere((e) => e.date == day20).price, 119.5);
        expect(merged.history.singleWhere((e) => e.date == day21).price, 121.5);
        expect(merged.history.singleWhere((e) => e.date == day22).price, 122);
      },
    );
  });
}
