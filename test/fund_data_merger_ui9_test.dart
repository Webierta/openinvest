import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-9: integridad de costes', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required List<FundCostPeriod> costPeriods,
      required List<FundCostCharge> costCharges,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: 'TEST',
        name: 'Fondo de prueba',
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

    test('LF-UI-9.1: conserva los periodos de ambas versiones', () {
      final periodA = FundCostPeriod(
        uid: 'period-a',
        concept: FundCostConcept.ter,
        ratePercent: 0.20,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
        //startDate: day20,
      );

      final periodB = FundCostPeriod(
        uid: 'period-b',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.unknown,
        validFrom: day21,
      );

      final merged = FundDataMerger.merge(
        fund(costPeriods: [periodA], costCharges: []),
        fund(costPeriods: [periodB], costCharges: []),
      );

      expect(merged.costPeriods.map((p) => p.uid).toSet(), {
        'period-a',
        'period-b',
      });
      expect(merged.costPeriods, hasLength(2));
    });

    test('LF-UI-9.2: un periodo con el mismo UID no se duplica', () {
      final existingPeriod = FundCostPeriod(
        uid: 'period-shared',
        concept: FundCostConcept.ter,
        ratePercent: 0.20,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );

      final incomingPeriod = FundCostPeriod(
        uid: 'period-shared',
        concept: FundCostConcept.ter,
        ratePercent: 0.25,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );

      final merged = FundDataMerger.merge(
        fund(costPeriods: [existingPeriod], costCharges: []),
        fund(costPeriods: [incomingPeriod], costCharges: []),
      );

      expect(merged.costPeriods, hasLength(1));
      expect(merged.costPeriods.single.uid, 'period-shared');
      expect(merged.costPeriods.single.ratePercent, 0.25);
    });

    test('LF-UI-9.3: conserva y deduplica cargos por UID', () {
      final period = FundCostPeriod(
        uid: 'period-a',
        concept: FundCostConcept.ter,
        ratePercent: 0.20,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );

      final chargeA = FundCostCharge(
        uid: 'charge-a',
        concept: FundCostConcept.ter,
        date: day20,
        amount: 2.0,
      );

      final chargeB = FundCostCharge(
        uid: 'charge-b',
        concept: FundCostConcept.ter,
        date: day21,
        amount: 3.0,
      );

      final duplicateChargeA = FundCostCharge(
        uid: 'charge-a',
        concept: FundCostConcept.ter,
        date: day20,
        amount: 2.5,
      );

      final merged = FundDataMerger.merge(
        fund(costPeriods: [period], costCharges: [chargeA]),
        fund(costPeriods: [period], costCharges: [duplicateChargeA, chargeB]),
      );

      expect(merged.costCharges, hasLength(2));
      final chargesByUid = {
        for (final charge in merged.costCharges) charge.uid: charge,
      };
      expect(chargesByUid.keys, containsAll(['charge-a', 'charge-b']));
      expect(chargesByUid['charge-a']!.amount, 2.5);
      expect(chargesByUid['charge-b']!.performancePeriodUid, isNull);
    });

    test('LF-UI-9.4: los cargos conservan su referencia al periodo', () {
      final periodA = FundCostPeriod(
        uid: 'period-a',
        concept: FundCostConcept.ter,
        ratePercent: 0.20,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );

      final periodB = FundCostPeriod(
        uid: 'period-b',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.unknown,
        validFrom: day21,
      );

      final chargeA = FundCostCharge(
        uid: 'charge-a',
        concept: FundCostConcept.performance,
        date: day20,
        amount: 2.0,
        performancePeriodUid: 'period-a',
      );

      final chargeB = FundCostCharge(
        uid: 'charge-b',
        concept: FundCostConcept.performance,
        date: day22,
        amount: 5.0,
        performancePeriodUid: 'period-b',
      );

      final merged = FundDataMerger.merge(
        fund(costPeriods: [periodA], costCharges: [chargeA]),
        fund(costPeriods: [periodB], costCharges: [chargeB]),
      );

      final periodUids = merged.costPeriods.map((p) => p.uid).toSet();

      expect(merged.costCharges, hasLength(2));
      for (final charge in merged.costCharges) {
        expect(
          periodUids,
          contains(charge.performancePeriodUid),
          reason:
              'El cargo ${charge.uid} debe referenciar un periodo existente',
        );
      }
    });
  });
}
