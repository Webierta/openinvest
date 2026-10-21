import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  group('LF-96: robustez de fechas y campos opcionales JSON', () {
    Map<String, dynamic> validPeriodJson() => {
      'uid': 'lf96-period',
      'concept': 'performance',
      'ratePercent': 8.5,
      'basis': 'positiveProfit',
      'treatment': 'chargedSeparately',
      'validFrom': '2026-01-01T00:00:00.000',
      'validTo': '2026-12-31T00:00:00.000',
      'description': 'Comisión de éxito',
    };

    Map<String, dynamic> validChargeJson() => {
      'uid': 'lf96-charge',
      'concept': 'performance',
      'date': '2026-10-20T00:00:00.000',
      'amount': 19.40,
      'description': 'Cargo de comisión',
      'performancePeriodUid': 'lf96-period',
      'settledThrough': '2026-09-30T00:00:00.000',
    };

    test('LF-96.1: fecha validFrom inválida se convierte en null', () {
      final json = validPeriodJson()..['validFrom'] = 'fecha-invalida';

      final period = FundCostPeriod.fromJson(json);

      expect(period.validFrom, isNull);
    });

    test('LF-96.2: fecha validTo inválida se convierte en null', () {
      final json = validPeriodJson()..['validTo'] = 'fecha-invalida';

      final period = FundCostPeriod.fromJson(json);

      expect(period.validTo, isNull);
    });

    test('LF-96.3: settledThrough inválida se convierte en null', () {
      final json = validChargeJson()..['settledThrough'] = 'fecha-invalida';

      final charge = FundCostCharge.fromJson(json);

      expect(charge.settledThrough, isNull);
    });

    test('LF-96.4: description de periodo con tipo incorrecto se rechaza', () {
      final json = validPeriodJson()..['description'] = 123;

      expect(() => FundCostPeriod.fromJson(json), throwsA(isA<TypeError>()));
    });

    test(
      'LF-96.5: performancePeriodUid de cargo con tipo incorrecto se rechaza',
      () {
        final json = validChargeJson()..['performancePeriodUid'] = 123;

        expect(() => FundCostCharge.fromJson(json), throwsA(isA<TypeError>()));
      },
    );

    test('LF-96.6: description de cargo con tipo incorrecto se rechaza', () {
      final json = validChargeJson()..['description'] = 123;

      expect(() => FundCostCharge.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('LF-96.7: los campos opcionales ausentes siguen siendo válidos', () {
      final periodJson = validPeriodJson()
        ..remove('validFrom')
        ..remove('validTo')
        ..remove('description');

      final chargeJson = validChargeJson()
        ..remove('description')
        ..remove('performancePeriodUid')
        ..remove('settledThrough');

      final period = FundCostPeriod.fromJson(periodJson);
      final charge = FundCostCharge.fromJson(chargeJson);

      expect(period.validFrom, isNull);
      expect(period.validTo, isNull);
      expect(period.description, isNull);
      expect(charge.description, isNull);
      expect(charge.performancePeriodUid, isNull);
      expect(charge.settledThrough, isNull);
    });
  });
}
