import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-98: integridad de UID y referencias en JSON', () {
    Map<String, dynamic> validPeriodJson() => {
      'uid': 'lf98-period',
      'concept': 'performance',
      'ratePercent': 8.5,
      'basis': 'positiveProfit',
      'treatment': 'chargedSeparately',
      'validFrom': '2026-01-01T00:00:00.000',
      'validTo': '2026-12-31T00:00:00.000',
      'description': 'Comisión de éxito',
    };

    Map<String, dynamic> validChargeJson() => {
      'uid': 'lf98-charge',
      'concept': 'performance',
      'date': '2026-10-20T00:00:00.000',
      'amount': 19.40,
      'description': 'Cargo de comisión',
      'performancePeriodUid': 'lf98-period',
      'settledThrough': '2026-09-30T00:00:00.000',
    };

    test(
      'LF-98.1: UID vacío del periodo se conserva para validación posterior',
      () {
        final json = validPeriodJson()..['uid'] = '';

        final period = FundCostPeriod.fromJson(json);

        expect(period.uid, isEmpty);
      },
    );

    test('LF-98.2: UID compuesto por espacios del cargo se conserva', () {
      final json = validChargeJson()..['uid'] = '   ';

      final charge = FundCostCharge.fromJson(json);

      expect(charge.uid, '   ');
    });

    test('LF-98.3: UID ausente genera un identificador no vacío', () {
      final periodJson = validPeriodJson()..remove('uid');
      final chargeJson = validChargeJson()..remove('uid');

      final period = FundCostPeriod.fromJson(periodJson);
      final charge = FundCostCharge.fromJson(chargeJson);

      expect(period.uid.trim(), isNotEmpty);
      expect(charge.uid.trim(), isNotEmpty);
      expect(period.uid, isNot(charge.uid));
    });

    test('LF-98.4: conserva exactamente la referencia al periodo', () {
      final json = validChargeJson()
        ..['performancePeriodUid'] = '  periodo-especial-98  ';

      final charge = FundCostCharge.fromJson(json);

      expect(charge.performancePeriodUid, '  periodo-especial-98  ');
    });

    test('LF-98.5: JSON round-trip conserva UID y relaciones', () {
      final period = FundCostPeriod(
        uid: 'lf98-period-roundtrip',
        concept: FundCostConcept.performance,
        ratePercent: 8.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
        validTo: DateTime(2026, 12, 31),
      );

      final charge = FundCostCharge(
        uid: 'lf98-charge-roundtrip',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 19.40,
        performancePeriodUid: period.uid,
      );

      final json = jsonDecode(
        jsonEncode({
          'periods': [period.toJson()],
          'charges': [charge.toJson()],
        }),
      ) as Map<String, dynamic>;

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

      expect(periods, hasLength(1));
      expect(charges, hasLength(1));
      expect(periods.single.uid, period.uid);
      expect(charges.single.uid, charge.uid);
      expect(charges.single.performancePeriodUid, periods.single.uid);
    });
  });
}
