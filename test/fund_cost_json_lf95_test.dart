import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-95: validación de JSON de costes', () {
    Map<String, dynamic> validPeriodJson() => {
      'uid': 'lf95-period',
      'concept': 'performance',
      'ratePercent': 8.5,
      'basis': 'positiveProfit',
      'treatment': 'chargedSeparately',
      'validFrom': '2026-01-01T00:00:00.000',
      'validTo': null,
      'description': null,
    };

    Map<String, dynamic> validChargeJson() => {
      'uid': 'lf95-charge',
      'concept': 'performance',
      'date': '2026-10-20T00:00:00.000',
      'amount': 19.40,
      'description': null,
      'performancePeriodUid': 'lf95-period',
      'settledThrough': null,
    };

    test('LF-95.1: rechaza un periodo sin ratePercent', () {
      final json = validPeriodJson()..remove('ratePercent');

      expect(() => FundCostPeriod.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('LF-95.2: rechaza un periodo con ratePercent de tipo incorrecto', () {
      final json = validPeriodJson()..['ratePercent'] = '8.5';

      expect(() => FundCostPeriod.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('LF-95.3: rechaza un cargo sin date', () {
      final json = validChargeJson()..remove('date');

      expect(() => FundCostCharge.fromJson(json), throwsA(anything));
    });

    test('LF-95.4: rechaza un cargo con amount de tipo incorrecto', () {
      final json = validChargeJson()..['amount'] = '19.40';

      expect(() => FundCostCharge.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('LF-95.5a: concept desconocido usa other', () {
      final json = validPeriodJson()..['concept'] = 'futureConcept';

      final period = FundCostPeriod.fromJson(json);

      expect(period.concept, FundCostConcept.other);
    });

    test('LF-95.5b: basis desconocido usa annualBalance', () {
      final json = validPeriodJson()..['basis'] = 'futureBasis';

      final period = FundCostPeriod.fromJson(json);

      expect(period.basis, FundCostRateBasis.annualBalance);
    });

    test('LF-95.5c: treatment desconocido usa unknown', () {
      final json = validPeriodJson()..['treatment'] = 'futureTreatment';

      final period = FundCostPeriod.fromJson(json);

      expect(period.treatment, FundCostTreatment.unknown);
    });
  });
}
