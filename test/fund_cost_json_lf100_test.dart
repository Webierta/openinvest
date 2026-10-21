import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

class _RestoredCosts {
  final List<FundCostPeriod> periods;
  final List<FundCostCharge> charges;

  const _RestoredCosts({required this.periods, required this.charges});
}

_RestoredCosts _restoreCollection(Map<String, dynamic> json) {
  // Se construyen variables locales y solo se devuelve la colección
  // cuando todos los elementos se han restaurado correctamente.
  final periods = (json['periods'] as List)
      .map(
        (item) =>
            FundCostPeriod.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  final charges = (json['charges'] as List)
      .map(
        (item) =>
            FundCostCharge.fromJson(Map<String, dynamic>.from(item as Map)),
      )
      .toList();

  return _RestoredCosts(periods: periods, charges: charges);
}

void main() {
  group('LF-100: integración de JSON de costes', () {
    test('LF-100.1: restaura una colección con varios periodos y cargos', () {
      final period1 = FundCostPeriod(
        uid: 'lf100-period-1',
        concept: FundCostConcept.performance,
        ratePercent: 8.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime.utc(2025, 1, 1),
        validTo: DateTime.utc(2025, 12, 31),
        description: 'Periodo de éxito 2025',
      );

      final period2 = FundCostPeriod(
        uid: 'lf100-period-2',
        concept: FundCostConcept.performance,
        ratePercent: 7.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime.utc(2026, 1, 1),
        description: 'Periodo de éxito 2026',
      );

      final charge1 = FundCostCharge(
        uid: 'lf100-charge-1',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2025, 6, 30),
        amount: 12.35,
        performancePeriodUid: period1.uid,
        settledThrough: DateTime.utc(2025, 6, 30),
      );

      final charge2 = FundCostCharge(
        uid: 'lf100-charge-2',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2026, 6, 30),
        amount: 15.75,
        performancePeriodUid: period2.uid,
        settledThrough: DateTime.utc(2026, 6, 30),
      );

      final json = jsonDecode(
        jsonEncode({
          'periods': [period1.toJson(), period2.toJson()],
          'charges': [charge1.toJson(), charge2.toJson()],
        }),
      ) as Map<String, dynamic>;

      final restored = _restoreCollection(json);

      expect(restored.periods, hasLength(2));
      expect(restored.charges, hasLength(2));
      expect(restored.periods.map((p) => p.uid), [period1.uid, period2.uid]);
      expect(restored.charges.map((c) => c.uid), [charge1.uid, charge2.uid]);
    });

    test(
      'LF-100.2: cada cargo conserva su relación con el periodo correcto',
      () {
        final json = {
          'periods': [
            FundCostPeriod(
              uid: 'lf100-rel-a',
              concept: FundCostConcept.performance,
              ratePercent: 8,
              basis: FundCostRateBasis.positiveProfit,
              treatment: FundCostTreatment.chargedSeparately,
            ).toJson(),
            FundCostPeriod(
              uid: 'lf100-rel-b',
              concept: FundCostConcept.performance,
              ratePercent: 6,
              basis: FundCostRateBasis.positiveProfit,
              treatment: FundCostTreatment.chargedSeparately,
            ).toJson(),
          ],
          'charges': [
            FundCostCharge(
              uid: 'lf100-rel-charge-a',
              concept: FundCostConcept.performance,
              date: DateTime.utc(2026, 3, 31),
              amount: 10,
              performancePeriodUid: 'lf100-rel-a',
            ).toJson(),
            FundCostCharge(
              uid: 'lf100-rel-charge-b',
              concept: FundCostConcept.performance,
              date: DateTime.utc(2026, 6, 30),
              amount: 20,
              performancePeriodUid: 'lf100-rel-b',
            ).toJson(),
          ],
        };

        final restored = _restoreCollection(json);

        final periodUids = restored.periods.map((p) => p.uid).toSet();
        expect(periodUids, contains('lf100-rel-a'));
        expect(periodUids, contains('lf100-rel-b'));

        final chargeByUid = {
          for (final charge in restored.charges) charge.uid: charge,
        };

        expect(
          chargeByUid['lf100-rel-charge-a']!.performancePeriodUid,
          'lf100-rel-a',
        );
        expect(
          chargeByUid['lf100-rel-charge-b']!.performancePeriodUid,
          'lf100-rel-b',
        );
      },
    );

    test('LF-100.3: conserva valores, fechas y campos opcionales', () {
      final period = FundCostPeriod(
        uid: 'lf100-fields-period',
        concept: FundCostConcept.ter,
        ratePercent: 0.675,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: DateTime.utc(2026, 1, 15, 10, 20, 30, 123, 456),
        description: 'TER anual',
      );

      final charge = FundCostCharge(
        uid: 'lf100-fields-charge',
        concept: FundCostConcept.ter,
        date: DateTime.utc(2026, 10, 21, 12, 30, 45, 678, 901),
        amount: 23.456,
        description: 'Coste acumulado',
      );

      final restored = _restoreCollection({
        'periods': [period.toJson()],
        'charges': [charge.toJson()],
      });

      final restoredPeriod = restored.periods.single;
      final restoredCharge = restored.charges.single;

      expect(restoredPeriod.concept, period.concept);
      expect(restoredPeriod.ratePercent, period.ratePercent);
      expect(restoredPeriod.basis, period.basis);
      expect(restoredPeriod.treatment, period.treatment);
      expect(
        restoredPeriod.validFrom!.microsecondsSinceEpoch,
        period.validFrom!.microsecondsSinceEpoch,
      );
      expect(restoredPeriod.validTo, isNull);
      expect(restoredPeriod.description, period.description);

      expect(restoredCharge.concept, charge.concept);
      expect(restoredCharge.amount, charge.amount);
      expect(
        restoredCharge.date.microsecondsSinceEpoch,
        charge.date.microsecondsSinceEpoch,
      );
      expect(restoredCharge.description, charge.description);
      expect(restoredCharge.performancePeriodUid, isNull);
      expect(restoredCharge.settledThrough, isNull);
    });

    test('LF-100.4: los UID permanecen únicos y estables tras restaurar', () {
      final period = FundCostPeriod(
        uid: 'lf100-unique-period',
        concept: FundCostConcept.performance,
        ratePercent: 8,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
      );

      final charge1 = FundCostCharge(
        uid: 'lf100-unique-charge-1',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2026, 3, 31),
        amount: 10,
        performancePeriodUid: period.uid,
      );

      final charge2 = FundCostCharge(
        uid: 'lf100-unique-charge-2',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2026, 6, 30),
        amount: 20,
        performancePeriodUid: period.uid,
      );

      final json = jsonDecode(
        jsonEncode({
          'periods': [period.toJson()],
          'charges': [charge1.toJson(), charge2.toJson()],
        }),
      ) as Map<String, dynamic>;

      final restored = _restoreCollection(json);
      final allUids = [
        ...restored.periods.map((p) => p.uid),
        ...restored.charges.map((c) => c.uid),
      ];

      expect(allUids.toSet(), hasLength(allUids.length));
      expect(restored.periods.single.uid, period.uid);
      expect(restored.charges[0].uid, charge1.uid);
      expect(restored.charges[1].uid, charge2.uid);
      expect(
        restored.charges.every(
          (charge) => charge.performancePeriodUid == period.uid,
        ),
        isTrue,
      );
    });

    test(
      'LF-100.5: un elemento inválido impide devolver la colección parcial',
      () {
        final validPeriod = FundCostPeriod(
          uid: 'lf100-atomic-period',
          concept: FundCostConcept.performance,
          ratePercent: 8,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
        );

        final validCharge = FundCostCharge(
          uid: 'lf100-atomic-charge',
          concept: FundCostConcept.performance,
          date: DateTime.utc(2026, 10, 21),
          amount: 10,
        );

        final invalidChargeJson = validCharge.toJson()..['amount'] = double.nan;

        final json = {
          'periods': [validPeriod.toJson()],
          'charges': [invalidChargeJson],
        };

        expect(() => _restoreCollection(json), throwsA(isA<ArgumentError>()));
      },
    );
  });
}
