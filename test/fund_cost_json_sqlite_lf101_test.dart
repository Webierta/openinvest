import 'dart:convert';
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

  const isin = 'IE00LF1010001';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf101_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  Map<String, dynamic> createJsonCollection() {
    final period = FundCostPeriod(
      uid: 'lf101-performance-period',
      concept: FundCostConcept.performance,
      ratePercent: 8.5,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      description: 'Comisión de éxito LF-101',
    );

    final charge = FundCostCharge(
      uid: 'lf101-performance-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 12.50,
      description: 'Liquidación LF-101',
      performancePeriodUid: period.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    return jsonDecode(
      jsonEncode({
        'periods': [period.toJson()],
        'charges': [charge.toJson()],
      }),
    ) as Map<String, dynamic>;
  }

  FundData fundFromJson(Map<String, dynamic> collection) {
    final periods = (collection['periods'] as List)
        .map(
          (item) =>
              FundCostPeriod.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final charges = (collection['charges'] as List)
        .map(
          (item) =>
              FundCostCharge.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return FundData(
      isin: isin,
      symbol: 'LF101',
      name: 'Fondo de prueba LF-101',
      lastValue: 105,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [
        PricePoint(DateTime(2026, 10, 19), 100),
        PricePoint(DateTime(2026, 10, 20), 105),
      ],
      costPeriods: periods,
      costCharges: charges,
    );
  }

  test(
    'LF-101.1: JSON a SQLite y vuelta conserva costes y referencias',
    () async {
      final fund = fundFromJson(createJsonCollection());

      await DatabaseService.saveFund(fund);

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.costPeriods, hasLength(1));
      expect(restored.costCharges, hasLength(1));

      final period = restored.costPeriods.single;
      final charge = restored.costCharges.single;

      expect(period.uid, 'lf101-performance-period');
      expect(period.concept, FundCostConcept.performance);
      expect(period.ratePercent, 8.5);
      expect(period.basis, FundCostRateBasis.positiveProfit);
      expect(period.treatment, FundCostTreatment.chargedSeparately);
      expect(period.validFrom, DateTime(2026, 1, 1));
      expect(period.validTo, DateTime(2026, 12, 31));
      expect(period.description, 'Comisión de éxito LF-101');

      expect(charge.uid, 'lf101-performance-charge');
      expect(charge.concept, FundCostConcept.performance);
      expect(charge.date, DateTime(2026, 10, 20));
      expect(charge.amount, 12.50);
      expect(charge.description, 'Liquidación LF-101');
      expect(charge.performancePeriodUid, period.uid);
      expect(charge.settledThrough, DateTime(2026, 10, 19));
    },
  );

  test(
    'LF-101.2: guardar dos veces la colección restaurada no duplica costes',
    () async {
      final fund = fundFromJson(createJsonCollection());

      await DatabaseService.saveFund(fund);

      final firstRestore = await DatabaseService.getFund(isin);
      expect(firstRestore, isNotNull);

      // Reutilizamos los modelos recuperados de SQLite.
      await DatabaseService.saveFund(firstRestore!);

      final secondRestore = await DatabaseService.getFund(isin);

      expect(secondRestore, isNotNull);
      expect(secondRestore!.costPeriods, hasLength(1));
      expect(secondRestore.costCharges, hasLength(1));
      expect(secondRestore.costPeriods.single.uid, 'lf101-performance-period');
      expect(secondRestore.costCharges.single.uid, 'lf101-performance-charge');
      expect(
        secondRestore.costCharges.single.performancePeriodUid,
        secondRestore.costPeriods.single.uid,
      );
    },
  );

  test(
    'LF-101.3: un UID duplicado no altera el fondo previamente guardado',
    () async {
      final original = fundFromJson(createJsonCollection());

      await DatabaseService.saveFund(original);

      final invalidJson = createJsonCollection();

      final firstPeriod = Map<String, dynamic>.from(
        (invalidJson['periods'] as List).single as Map,
      );

      final duplicatePeriod = Map<String, dynamic>.from(firstPeriod)
        ..['concept'] = FundCostConcept.management.name
        ..['basis'] = FundCostRateBasis.annualBalance.name
        ..['treatment'] = FundCostTreatment.includedInNav.name
        ..['description'] = 'Periodo duplicado';

      invalidJson['periods'] = [firstPeriod, duplicatePeriod];

      final invalidFund = fundFromJson(invalidJson);

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, original.symbol);
      expect(restored.name, original.name);
      expect(restored.lastValue, original.lastValue);

      expect(restored.costPeriods, hasLength(1));
      expect(restored.costPeriods.single.uid, 'lf101-performance-period');

      expect(restored.costCharges, hasLength(1));
      expect(restored.costCharges.single.uid, 'lf101-performance-charge');
      expect(
        restored.costCharges.single.performancePeriodUid,
        'lf101-performance-period',
      );
    },
  );
}
