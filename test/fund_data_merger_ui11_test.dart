import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-11: independencia entre objetos de coste', () {
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
        description: 'Cargo $uid',
      );
    }

    test(
      'LF-UI-11.1: conserva los objetos de periodo sin alterar sus datos',
      () {
        final periodA = period('period-a', day20);
        final periodB = period('period-b', day21);

        final existing = fund(
          symbol: 'EXISTING',
          costPeriods: [periodA],
          costCharges: [],
        );
        final incoming = fund(
          symbol: 'INCOMING',
          costPeriods: [periodB],
          costCharges: [],
        );

        final merged = FundDataMerger.merge(existing, incoming);

        final mergedByUid = {
          for (final item in merged.costPeriods) item.uid: item,
        };

        expect(mergedByUid, hasLength(2));
        expect(mergedByUid['period-a'], same(periodA));
        expect(mergedByUid['period-b'], same(periodB));

        expect(periodA.ratePercent, 0.20);
        expect(periodA.validFrom, day20);
        expect(periodB.ratePercent, 0.20);
        expect(periodB.validFrom, day21);
      },
    );

    test('LF-UI-11.2: conserva los objetos de cargo sin alterar sus datos', () {
      final chargeA = charge('charge-a', day20, 2.0);
      final chargeB = charge('charge-b', day21, 3.0);

      final existing = fund(
        symbol: 'EXISTING',
        costPeriods: [],
        costCharges: [chargeA],
      );
      final incoming = fund(
        symbol: 'INCOMING',
        costPeriods: [],
        costCharges: [chargeB],
      );

      final merged = FundDataMerger.merge(existing, incoming);

      final mergedByUid = {
        for (final item in merged.costCharges) item.uid: item,
      };

      expect(mergedByUid, hasLength(2));
      expect(mergedByUid['charge-a'], same(chargeA));
      expect(mergedByUid['charge-b'], same(chargeB));

      expect(chargeA.amount, 2.0);
      expect(chargeA.description, 'Cargo charge-a');
      expect(chargeB.amount, 3.0);
      expect(chargeB.description, 'Cargo charge-b');
    });

    test('LF-UI-11.3: serializar costes no altera los objetos originales', () {
      final periodA = period('period-a', day20);
      final chargeA = charge('charge-a', day20, 2.0);

      final existing = fund(
        symbol: 'EXISTING',
        costPeriods: [periodA],
        costCharges: [chargeA],
      );
      final incoming = fund(
        symbol: 'INCOMING',
        costPeriods: [period('period-b', day21)],
        costCharges: [charge('charge-b', day22, 4.0)],
      );

      final periodBefore = Map<String, dynamic>.from(periodA.toJson());
      final chargeBefore = Map<String, dynamic>.from(chargeA.toJson());

      final merged = FundDataMerger.merge(existing, incoming);

      for (final item in merged.costPeriods) {
        item.toJson();
      }
      for (final item in merged.costCharges) {
        item.toJson();
      }

      expect(periodA.toJson(), periodBefore);
      expect(chargeA.toJson(), chargeBefore);
    });
  });
}
