import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00LF1040001';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf104_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundCostPeriod period({
    required String uid,
    required DateTime from,
    required DateTime to,
    double rate = 8.5,
  }) {
    return FundCostPeriod(
      uid: uid,
      concept: FundCostConcept.performance,
      ratePercent: rate,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: from,
      validTo: to,
      description: uid,
    );
  }

  FundCostCharge charge({
    required String uid,
    required DateTime date,
    required String periodUid,
    double amount = 12.50,
  }) {
    return FundCostCharge(
      uid: uid,
      concept: FundCostConcept.performance,
      date: date,
      amount: amount,
      description: uid,
      performancePeriodUid: periodUid,
      settledThrough: date.subtract(const Duration(days: 1)),
    );
  }

  FundData fund({
    required String symbol,
    required String name,
    required double lastValue,
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) {
    return FundData(
      isin: isin,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [
        PricePoint(DateTime(2026, 10, 19), 100),
        PricePoint(DateTime(2026, 10, 20), lastValue),
      ],
      costPeriods: periods,
      costCharges: charges,
    );
  }

  FundData originalFund() {
    final originalPeriod = period(
      uid: 'lf104-original-period',
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 12, 31),
    );

    final originalCharge = charge(
      uid: 'lf104-original-charge',
      date: DateTime(2026, 10, 20),
      periodUid: originalPeriod.uid,
    );

    return fund(
      symbol: 'ORIGINAL',
      name: 'Fondo original LF-104',
      lastValue: 100,
      periods: [originalPeriod],
      charges: [originalCharge],
    );
  }

  Future<void> expectOriginalFundUnchanged() async {
    final restored = await DatabaseService.getFund(isin);

    expect(restored, isNotNull);
    expect(restored!.symbol, 'ORIGINAL');
    expect(restored.name, 'Fondo original LF-104');
    expect(restored.lastValue, 100);

    expect(restored.costPeriods, hasLength(1));
    expect(restored.costPeriods.single.uid, 'lf104-original-period');

    expect(restored.costCharges, hasLength(1));
    expect(restored.costCharges.single.uid, 'lf104-original-charge');
    expect(
      restored.costCharges.single.performancePeriodUid,
      'lf104-original-period',
    );
    expect(restored.costCharges.single.amount, 12.50);
  }

  test(
    'LF-104.1: un periodo inválido no modifica el fondo ni sus costes',
    () async {
      await DatabaseService.saveFund(originalFund());

      final invalidPeriod = period(
        uid: 'lf104-invalid-period',
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 7, 1),
      );

      final invalidFund = fund(
        symbol: 'MODIFIED',
        name: 'Fondo modificado inválido',
        lastValue: 200,
        periods: [invalidPeriod],
        charges: [],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      await expectOriginalFundUnchanged();
    },
  );

  test(
    'LF-104.2: un cargo inválido no persiste parcialmente los costes',
    () async {
      await DatabaseService.saveFund(originalFund());

      final validPeriod = period(
        uid: 'lf104-new-period',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final invalidCharge = charge(
        uid: 'lf104-invalid-charge',
        date: DateTime(2026, 10, 20),
        periodUid: 'lf104-period-inexistent',
      );

      final invalidFund = fund(
        symbol: 'MODIFIED',
        name: 'Fondo modificado con cargo inválido',
        lastValue: 200,
        periods: [validPeriod],
        charges: [invalidCharge],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      await expectOriginalFundUnchanged();
    },
  );

  test(
    'LF-104.3: tras un rechazo se puede guardar una colección válida',
    () async {
      await DatabaseService.saveFund(originalFund());

      final invalidFund = fund(
        symbol: 'INVALID',
        name: 'Fondo inválido',
        lastValue: 200,
        periods: [
          period(
            uid: 'lf104-invalid-period',
            from: DateTime(2026, 8, 1),
            to: DateTime(2026, 7, 1),
          ),
        ],
        charges: [],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final validPeriod = period(
        uid: 'lf104-valid-period',
        from: DateTime(2026, 1, 1),
        to: DateTime(2026, 12, 31),
      );

      final validCharge = charge(
        uid: 'lf104-valid-charge',
        date: DateTime(2026, 10, 20),
        periodUid: validPeriod.uid,
        amount: 17.25,
      );

      await DatabaseService.saveFund(
        fund(
          symbol: 'VALID',
          name: 'Fondo válido LF-104',
          lastValue: 110,
          periods: [validPeriod],
          charges: [validCharge],
        ),
      );

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, 'VALID');
      expect(restored.name, 'Fondo válido LF-104');
      expect(restored.lastValue, 110);

      expect(restored.costPeriods, hasLength(1));
      expect(restored.costPeriods.single.uid, 'lf104-valid-period');

      expect(restored.costCharges, hasLength(1));
      expect(restored.costCharges.single.uid, 'lf104-valid-charge');
      expect(
        restored.costCharges.single.performancePeriodUid,
        'lf104-valid-period',
      );
      expect(restored.costCharges.single.amount, 17.25);
    },
  );
}
