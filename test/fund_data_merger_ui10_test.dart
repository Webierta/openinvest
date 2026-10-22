import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-10: aislamiento de datos', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required List<FundCostPeriod> costPeriods,
      required List<FundCostCharge> costCharges,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: 120,
        date: day22,
        history: [PricePoint(day22, 120)],
        costPeriods: costPeriods,
        costCharges: costCharges,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
    }

    FundCostPeriod period(String uid, DateTime date) {
      return FundCostPeriod(
        uid: uid,
        concept: FundCostConcept.ter,
        ratePercent: 0.20,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: date,
      );
    }

    FundCostCharge charge(String uid, DateTime date, double amount) {
      return FundCostCharge(
        uid: uid,
        concept: FundCostConcept.ter,
        date: date,
        amount: amount,
      );
    }

    test(
      'LF-UI-10.1: la fusión no modifica los costes del fondo existente',
      () {
        final existing = fund(
          symbol: 'EXISTING',
          costPeriods: [period('period-a', day20)],
          costCharges: [charge('charge-a', day20, 2.0)],
        );

        final incoming = fund(
          symbol: 'INCOMING',
          costPeriods: [period('period-b', day21)],
          costCharges: [charge('charge-b', day21, 3.0)],
        );

        final originalPeriodUids = existing.costPeriods
            .map((p) => p.uid)
            .toList();
        final originalChargeValues = existing.costCharges
            .map((c) => (c.uid, c.amount, c.date))
            .toList();

        FundDataMerger.merge(existing, incoming);

        expect(
          existing.costPeriods.map((p) => p.uid).toList(),
          originalPeriodUids,
        );
        expect(
          existing.costCharges.map((c) => (c.uid, c.amount, c.date)).toList(),
          originalChargeValues,
        );
      },
    );

    test('LF-UI-10.2: la fusión no modifica los costes del fondo entrante', () {
      final existing = fund(
        symbol: 'EXISTING',
        costPeriods: [period('period-a', day20)],
        costCharges: [charge('charge-a', day20, 2.0)],
      );

      final incoming = fund(
        symbol: 'INCOMING',
        costPeriods: [period('period-b', day21)],
        costCharges: [charge('charge-b', day21, 3.0)],
      );

      final originalPeriodUids = incoming.costPeriods
          .map((p) => p.uid)
          .toList();
      final originalChargeValues = incoming.costCharges
          .map((c) => (c.uid, c.amount, c.date))
          .toList();

      FundDataMerger.merge(existing, incoming);

      expect(
        incoming.costPeriods.map((p) => p.uid).toList(),
        originalPeriodUids,
      );
      expect(
        incoming.costCharges.map((c) => (c.uid, c.amount, c.date)).toList(),
        originalChargeValues,
      );
    });

    test('LF-UI-10.3: las listas de costes del resultado son inmutables', () {
      final existing = fund(
        symbol: 'EXISTING',
        costPeriods: [period('period-a', day20)],
        costCharges: [charge('charge-a', day20, 2.0)],
      );

      final incoming = fund(
        symbol: 'INCOMING',
        costPeriods: [period('period-b', day21)],
        costCharges: [charge('charge-b', day21, 3.0)],
      );

      final merged = FundDataMerger.merge(existing, incoming);

      expect(merged.costPeriods, hasLength(2));
      expect(merged.costCharges, hasLength(2));

      expect(
        () => merged.costPeriods.add(period('period-c', day22)),
        throwsUnsupportedError,
      );

      expect(
        () => merged.costCharges.add(charge('charge-c', day22, 4.0)),
        throwsUnsupportedError,
      );

      expect(merged.costPeriods, hasLength(2));
      expect(merged.costCharges, hasLength(2));
    });
  });
}
