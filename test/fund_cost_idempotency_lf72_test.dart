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

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;
  late FundCostPeriod period;
  late FundCostCharge charge;
  late FundData fund;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf71_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );

    period = FundCostPeriod(
      uid: 'lf71-period-001',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      validFrom: DateTime(2025, 1, 1),
      validTo: DateTime(2025, 12, 31),
      description: 'Coste de gestión LF-71',
    );

    charge = FundCostCharge(
      uid: 'lf71-charge-001',
      concept: FundCostConcept.performance,
      date: DateTime(2025, 12, 31),
      amount: 12.75,
      description: 'Cargo de prueba LF-71',
      performancePeriodUid: period.uid,
      settledThrough: DateTime(2025, 12, 31),
    );

    fund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 112,
      currency: 'EUR',
      date: DateTime(2026, 10, 4),
      history: [
        PricePoint(DateTime(2026, 10, 3), 110),
        PricePoint(DateTime(2026, 10, 4), 112),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      ter: 0.50,
      performanceFee: 10,
      costPeriods: [period],
      costCharges: [charge],
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'LF-72.1: guardar dos veces no duplica los periodos de costes',
    () async {
      await DatabaseService.saveFund(fund);

      final firstLoad = await DatabaseService.getFund(isin);
      expect(firstLoad, isNotNull);
      expect(firstLoad!.costPeriods, hasLength(1));

      await DatabaseService.saveFund(firstLoad);

      final secondLoad = await DatabaseService.getFund(isin);
      expect(secondLoad, isNotNull);
      expect(secondLoad!.costPeriods, hasLength(1));

      final savedPeriod = secondLoad.costPeriods.single;
      expect(savedPeriod.uid, 'lf71-period-001');
      expect(savedPeriod.ratePercent, 0.65);
      expect(savedPeriod.description, 'Coste de gestión LF-71');
    },
  );

  test(
    'LF-72.2: guardar dos veces no duplica cargos ni rompe sus relaciones',
    () async {
      await DatabaseService.saveFund(fund);

      final firstLoad = await DatabaseService.getFund(isin);
      expect(firstLoad, isNotNull);
      expect(firstLoad!.costCharges, hasLength(1));

      await DatabaseService.saveFund(firstLoad);

      final secondLoad = await DatabaseService.getFund(isin);
      expect(secondLoad, isNotNull);
      expect(secondLoad!.costCharges, hasLength(1));
      expect(secondLoad.costPeriods, hasLength(1));

      final savedCharge = secondLoad.costCharges.single;
      expect(savedCharge.uid, 'lf71-charge-001');
      expect(savedCharge.amount, 12.75);
      expect(savedCharge.performancePeriodUid, 'lf71-period-001');
      expect(savedCharge.settledThrough, DateTime(2025, 12, 31));

      expect(
        secondLoad.costPeriods.single.uid,
        savedCharge.performancePeriodUid,
      );
    },
  );
}
