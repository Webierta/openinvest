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

  //const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;
  //late FundCostPeriod period;
  //late FundCostCharge charge;
  //late FundData fund;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf71_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );

    /* period = FundCostPeriod(
      uid: 'lf71-period-001',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      validFrom: DateTime(2025, 1, 1),
      validTo: DateTime(2025, 12, 31),
      description: 'Coste de gestión LF-71',
    ); */

    /* charge = FundCostCharge(
      uid: 'lf71-charge-001',
      concept: FundCostConcept.performance,
      date: DateTime(2025, 12, 31),
      amount: 12.75,
      description: 'Cargo de prueba LF-71',
      performancePeriodUid: period.uid,
      settledThrough: DateTime(2026, 10, 4),
    ); */

    /* fund = FundData(
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
    ); */
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-73.1: SQLite mantiene los costes aislados por fondo', () async {
    const secondIsin = 'LU0123456789';

    final firstPeriod = FundCostPeriod(
      uid: 'lf73-period-first',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      //validFrom: DateTime(2025, 1, 1),
      validFrom: DateTime(2025, 1, 1),
      validTo: DateTime(2025, 12, 31),
      description: 'Coste del primer fondo',
    );

    final firstCharge = FundCostCharge(
      uid: 'lf73-charge-first',
      concept: FundCostConcept.performance,
      date: DateTime(2025, 12, 31),
      amount: 12.75,
      performancePeriodUid: firstPeriod.uid,
      description: 'Cargo del primer fondo',
    );

    final secondPeriod = FundCostPeriod(
      uid: 'lf73-period-second',
      concept: FundCostConcept.management,
      ratePercent: 0.30,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      //validFrom: DateTime(2026, 1, 1),
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 10, 4),
      description: 'Coste del segundo fondo',
    );

    final secondCharge = FundCostCharge(
      uid: 'lf73-charge-second',
      concept: FundCostConcept.performance,
      //date: DateTime(2026, 12, 31),
      date: DateTime(2026, 10, 4),
      amount: 4.50,
      performancePeriodUid: secondPeriod.uid,
      description: 'Cargo del segundo fondo',
    );

    FundData createFund({
      required String isin,
      required String symbol,
      required String name,
      required FundCostPeriod period,
      required FundCostCharge charge,
    }) {
      return FundData(
        isin: isin,
        symbol: symbol,
        name: name,
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 4),
        history: [PricePoint(DateTime(2026, 10, 4), 100)],
        costPeriods: [period],
        costCharges: [charge],
      );
    }

    final firstFund = createFund(
      isin: 'IE00B4L5Y983',
      symbol: 'FIRST',
      name: 'Primer fondo',
      period: firstPeriod,
      charge: firstCharge,
    );

    final secondFund = createFund(
      isin: secondIsin,
      symbol: 'SECOND',
      name: 'Segundo fondo',
      period: secondPeriod,
      charge: secondCharge,
    );

    await DatabaseService.saveFund(firstFund);
    await DatabaseService.saveFund(secondFund);

    final savedFirst = await DatabaseService.getFund(firstFund.isin);
    final savedSecond = await DatabaseService.getFund(secondIsin);

    expect(savedFirst, isNotNull);
    expect(savedSecond, isNotNull);

    expect(savedFirst!.costPeriods, hasLength(1));
    expect(savedFirst.costPeriods.single.uid, 'lf73-period-first');
    expect(savedFirst.costPeriods.single.ratePercent, 0.65);
    expect(savedFirst.costCharges, hasLength(1));
    expect(savedFirst.costCharges.single.uid, 'lf73-charge-first');
    expect(savedFirst.costCharges.single.amount, 12.75);
    expect(
      savedFirst.costCharges.single.performancePeriodUid,
      savedFirst.costPeriods.single.uid,
    );

    expect(savedSecond!.costPeriods, hasLength(1));
    expect(savedSecond.costPeriods.single.uid, 'lf73-period-second');
    expect(savedSecond.costPeriods.single.ratePercent, 0.30);
    expect(savedSecond.costCharges, hasLength(1));
    expect(savedSecond.costCharges.single.uid, 'lf73-charge-second');
    expect(savedSecond.costCharges.single.amount, 4.50);
    expect(
      savedSecond.costCharges.single.performancePeriodUid,
      savedSecond.costPeriods.single.uid,
    );

    expect(
      savedFirst.costPeriods.map((p) => p.uid),
      isNot(contains('lf73-period-second')),
    );
    expect(
      savedSecond.costPeriods.map((p) => p.uid),
      isNot(contains('lf73-period-first')),
    );
    expect(
      savedFirst.costCharges.map((c) => c.uid),
      isNot(contains('lf73-charge-second')),
    );
    expect(
      savedSecond.costCharges.map((c) => c.uid),
      isNot(contains('lf73-charge-first')),
    );
  });
}
