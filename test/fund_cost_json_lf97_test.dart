import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-97: integridad semántica de costes JSON', () {
    Map<String, dynamic> validPeriodJson() => {
      'uid': 'lf97-period',
      'concept': 'performance',
      'ratePercent': 8.5,
      'basis': 'positiveProfit',
      'treatment': 'chargedSeparately',
      'validFrom': '2026-01-01T00:00:00.000',
      'validTo': '2026-12-31T00:00:00.000',
      'description': 'Comisión de éxito',
    };

    Map<String, dynamic> validChargeJson() => {
      'uid': 'lf97-charge',
      'concept': 'performance',
      'date': '2026-10-20T00:00:00.000',
      'amount': 19.40,
      'description': 'Cargo de comisión',
      'performancePeriodUid': 'lf97-period',
      'settledThrough': '2026-09-30T00:00:00.000',
    };

    test(
      'LF-97.1: rechaza un periodo cuya fecha final precede a la inicial',
      () {
        final json = validPeriodJson()
          ..['validFrom'] = '2026-12-31T00:00:00.000'
          ..['validTo'] = '2026-01-01T00:00:00.000';

        expect(() => FundCostPeriod.fromJson(json), throwsA(anything));
      },
    );

    test('LF-97.2: rechaza una tasa NaN', () {
      final json = validPeriodJson()..['ratePercent'] = double.nan;

      expect(() => FundCostPeriod.fromJson(json), throwsA(anything));
    });

    test('LF-97.3: rechaza una tasa positiva infinita', () {
      final json = validPeriodJson()..['ratePercent'] = double.infinity;

      expect(() => FundCostPeriod.fromJson(json), throwsA(anything));
    });

    test('LF-97.4: rechaza una tasa negativa infinita', () {
      final json = validPeriodJson()..['ratePercent'] = double.negativeInfinity;

      expect(() => FundCostPeriod.fromJson(json), throwsA(anything));
    });

    test('LF-97.5: rechaza un importe NaN', () {
      final json = validChargeJson()..['amount'] = double.nan;

      expect(() => FundCostCharge.fromJson(json), throwsA(anything));
    });

    test('LF-97.6: rechaza un importe infinito', () {
      final json = validChargeJson()..['amount'] = double.infinity;

      expect(() => FundCostCharge.fromJson(json), throwsA(anything));
    });

    test('LF-97.7: acepta un periodo con fechas válidas y tasa finita', () {
      final period = FundCostPeriod.fromJson(validPeriodJson());

      expect(period.validFrom, DateTime(2026, 1, 1));
      expect(period.validTo, DateTime(2026, 12, 31));
      expect(period.ratePercent.isFinite, isTrue);
    });

    test('LF-97.8: acepta un cargo con importe finito', () {
      final charge = FundCostCharge.fromJson(validChargeJson());

      expect(charge.amount, 19.40);
      expect(charge.amount.isFinite, isTrue);
    });
  });
}
