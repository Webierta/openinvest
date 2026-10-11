import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf22_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  FundData createFund() {
    final date = DateTime(2026, 10, 1);

    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 100,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  test('setAlerts conserva source y valuationSource', () async {
    await DatabaseService.saveFund(createFund());

    final provider = FundProvider();
    await provider.setAlerts(isin, 90, 110);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.alertMin, 90);
    expect(saved.alertMax, 110);
  });

  test('setFundCosts conserva source y valuationSource', () async {
    await DatabaseService.saveFund(createFund());

    final provider = FundProvider();
    await provider.setFundCosts(
      isin,
      periods: [
        FundCostPeriod(
          concept: FundCostConcept.ter,
          ratePercent: 0.5,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
      ],
      charges: [
        FundCostCharge(
          concept: FundCostConcept.management,
          date: DateTime(2026, 10, 2),
          amount: 1.25,
        ),
      ],
    );

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.costPeriods, hasLength(1));
    expect(saved.costCharges, hasLength(1));
  });
}
