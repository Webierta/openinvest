import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-99: estabilidad tras múltiples ciclos JSON', () {
    Map<String, dynamic> roundTrip(Map<String, dynamic> json) {
      return Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map);
    }

    test('LF-99.1: varios ciclos conservan todos los campos del periodo', () {
      final original = FundCostPeriod(
        id: 42,
        uid: 'lf99-period',
        concept: FundCostConcept.performance,
        ratePercent: 8.125,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime.utc(2024, 2, 29, 12, 34, 56, 789, 123),
        validTo: DateTime.utc(2026, 12, 31, 23, 59, 59, 999, 999),
        description: 'Comisión de éxito',
      );

      var json = original.toJson();

      for (var i = 0; i < 5; i++) {
        json = FundCostPeriod.fromJson(roundTrip(json)).toJson();
      }

      final result = FundCostPeriod.fromJson(json);

      expect(result.uid, original.uid);
      expect(result.concept, original.concept);
      expect(result.ratePercent, original.ratePercent);
      expect(result.basis, original.basis);
      expect(result.treatment, original.treatment);
      expect(result.validFrom, original.validFrom);
      expect(result.validTo, original.validTo);
      expect(result.description, original.description);
    });

    test('LF-99.2: varios ciclos conservan todos los campos del cargo', () {
      final original = FundCostCharge(
        id: 43,
        uid: 'lf99-charge',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2026, 10, 20, 15, 16, 17, 123, 456),
        amount: 19.405,
        description: 'Liquidación trimestral',
        performancePeriodUid: 'lf99-period',
        settledThrough: DateTime.utc(2026, 9, 30, 23, 59, 59, 999, 999),
      );

      var json = original.toJson();

      for (var i = 0; i < 5; i++) {
        json = FundCostCharge.fromJson(roundTrip(json)).toJson();
      }

      final result = FundCostCharge.fromJson(json);

      expect(result.uid, original.uid);
      expect(result.concept, original.concept);
      expect(result.date, original.date);
      expect(result.amount, original.amount);
      expect(result.description, original.description);
      expect(result.performancePeriodUid, original.performancePeriodUid);
      expect(result.settledThrough, original.settledThrough);
    });

    test('LF-99.3: las fechas mantienen precisión de microsegundos', () {
      final period = FundCostPeriod(
        uid: 'lf99-precision',
        concept: FundCostConcept.ter,
        ratePercent: 0.75,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: DateTime.utc(2026, 1, 2, 3, 4, 5, 678, 901),
        validTo: DateTime.utc(2026, 11, 12, 13, 14, 15, 678, 902),
      );

      final charge = FundCostCharge(
        uid: 'lf99-precision-charge',
        concept: FundCostConcept.ter,
        date: DateTime.utc(2026, 7, 8, 9, 10, 11, 222, 333),
        amount: 1.25,
        settledThrough: DateTime.utc(2026, 6, 30, 23, 59, 59, 444, 555),
      );

      final restoredPeriod = FundCostPeriod.fromJson(
        roundTrip(period.toJson()),
      );
      final restoredCharge = FundCostCharge.fromJson(
        roundTrip(charge.toJson()),
      );

      expect(
        restoredPeriod.validFrom!.microsecondsSinceEpoch,
        period.validFrom!.microsecondsSinceEpoch,
      );
      expect(
        restoredPeriod.validTo!.microsecondsSinceEpoch,
        period.validTo!.microsecondsSinceEpoch,
      );
      expect(
        restoredCharge.date.microsecondsSinceEpoch,
        charge.date.microsecondsSinceEpoch,
      );
      expect(
        restoredCharge.settledThrough!.microsecondsSinceEpoch,
        charge.settledThrough!.microsecondsSinceEpoch,
      );
    });

    test('LF-99.4: los campos opcionales null siguen siendo null', () {
      final period = FundCostPeriod(
        uid: 'lf99-null-period',
        concept: FundCostConcept.ter,
        ratePercent: 0.75,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
      );

      final charge = FundCostCharge(
        uid: 'lf99-null-charge',
        concept: FundCostConcept.ter,
        date: DateTime.utc(2026, 10, 20),
        amount: 1.25,
      );

      var periodJson = period.toJson();
      var chargeJson = charge.toJson();

      for (var i = 0; i < 3; i++) {
        periodJson = FundCostPeriod.fromJson(roundTrip(periodJson)).toJson();
        chargeJson = FundCostCharge.fromJson(roundTrip(chargeJson)).toJson();
      }

      final restoredPeriod = FundCostPeriod.fromJson(periodJson);
      final restoredCharge = FundCostCharge.fromJson(chargeJson);

      expect(restoredPeriod.validFrom, isNull);
      expect(restoredPeriod.validTo, isNull);
      expect(restoredPeriod.description, isNull);
      expect(restoredCharge.description, isNull);
      expect(restoredCharge.performancePeriodUid, isNull);
      expect(restoredCharge.settledThrough, isNull);
    });

    test('LF-99.5: UID y relaciones permanecen estables en varios ciclos', () {
      final period = FundCostPeriod(
        uid: 'lf99-related-period',
        concept: FundCostConcept.performance,
        ratePercent: 7.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
      );

      final charge = FundCostCharge(
        uid: 'lf99-related-charge',
        concept: FundCostConcept.performance,
        date: DateTime.utc(2026, 10, 20),
        amount: 15.50,
        performancePeriodUid: period.uid,
      );

      var periodJson = period.toJson();
      var chargeJson = charge.toJson();

      for (var i = 0; i < 5; i++) {
        periodJson = FundCostPeriod.fromJson(roundTrip(periodJson)).toJson();
        chargeJson = FundCostCharge.fromJson(roundTrip(chargeJson)).toJson();
      }

      final restoredPeriod = FundCostPeriod.fromJson(periodJson);
      final restoredCharge = FundCostCharge.fromJson(chargeJson);

      expect(restoredPeriod.uid, period.uid);
      expect(restoredCharge.uid, charge.uid);
      expect(restoredCharge.performancePeriodUid, restoredPeriod.uid);
    });
  });
}
