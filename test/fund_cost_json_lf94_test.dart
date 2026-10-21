import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-94: serialización JSON de costes', () {
    test('LF-94.1: FundCostPeriod conserva todos sus campos al hacer round-trip JSON', () {
      final period = FundCostPeriod(
        uid: 'lf94-period-1',
        concept: FundCostConcept.performance,
        ratePercent: 8.75,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 15),
        validTo: DateTime(2026, 9, 30),
        description: 'Comisión de éxito',
      );

      final json = period.toJson();
      final restored = FundCostPeriod.fromJson(json);

      expect(restored.uid, period.uid);
      expect(restored.concept, period.concept);
      expect(restored.ratePercent, period.ratePercent);
      expect(restored.basis, period.basis);
      expect(restored.treatment, period.treatment);
      expect(restored.validFrom, period.validFrom);
      expect(restored.validTo, period.validTo);
      expect(restored.description, period.description);
    });

    test('LF-94.2: FundCostPeriod conserva los campos opcionales nulos', () {
      final period = FundCostPeriod(
        uid: 'lf94-period-2',
        concept: FundCostConcept.management,
        ratePercent: 0.65,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
      );

      final restored = FundCostPeriod.fromJson(period.toJson());

      expect(restored.uid, period.uid);
      expect(restored.validFrom, isNull);
      expect(restored.validTo, isNull);
      expect(restored.description, isNull);
    });

    test('LF-94.3: FundCostCharge conserva todos sus campos al hacer round-trip JSON', () {
      final charge = FundCostCharge(
        uid: 'lf94-charge-1',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 27.35,
        description: 'Liquidación trimestral',
        performancePeriodUid: 'lf94-period-1',
        settledThrough: DateTime(2026, 10, 19),
      );

      final json = charge.toJson();
      final restored = FundCostCharge.fromJson(json);

      expect(restored.uid, charge.uid);
      expect(restored.concept, charge.concept);
      expect(restored.date, charge.date);
      expect(restored.amount, charge.amount);
      expect(restored.description, charge.description);
      expect(restored.performancePeriodUid, charge.performancePeriodUid);
      expect(restored.settledThrough, charge.settledThrough);
    });

    test('LF-94.4: FundCostCharge conserva los campos opcionales nulos', () {
      final charge = FundCostCharge(
        uid: 'lf94-charge-2',
        concept: FundCostConcept.management,
        date: DateTime(2026, 10, 20),
        amount: 12.50,
      );

      final restored = FundCostCharge.fromJson(charge.toJson());

      expect(restored.uid, charge.uid);
      expect(restored.description, isNull);
      expect(restored.performancePeriodUid, isNull);
      expect(restored.settledThrough, isNull);
    });

    test('LF-94.5: JSON encode/decode conserva UID y referencia entre periodo y cargo', () {
      final period = FundCostPeriod(
        uid: 'lf94-related-period',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
      );

      final charge = FundCostCharge(
        uid: 'lf94-related-charge',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 19.40,
        performancePeriodUid: period.uid,
        settledThrough: DateTime(2026, 10, 19),
      );

      final periodJson = Map<String, dynamic>.from(period.toJson());
      final chargeJson = Map<String, dynamic>.from(charge.toJson());

      final restoredPeriod = FundCostPeriod.fromJson(periodJson);
      final restoredCharge = FundCostCharge.fromJson(chargeJson);

      expect(restoredPeriod.uid, 'lf94-related-period');
      expect(restoredCharge.uid, 'lf94-related-charge');
      expect(restoredCharge.performancePeriodUid, restoredPeriod.uid);
    });
  });
}
