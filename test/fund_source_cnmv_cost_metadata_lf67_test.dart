import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
  late FundData existingFund;
  late FundData primaryFund;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf67_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );

    existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [
        PricePoint(DateTime(2026, 10, 2), 105),
        PricePoint(DateTime(2026, 10, 3), 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      ter: 0.75,
      performanceFee: 10,
      costPeriods: const [],
      costCharges: const [],
    );

    primaryFund = FundData(
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
      valuationSource: FundSource.cnmv,
      ter: 0.50,
      // CNMV no informa performanceFee.
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  FundProvider createProvider() {
    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: primaryFund),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectCostsPreserved(FundData fund) {
    expect(fund.lastValue, 112);
    expect(fund.date, DateTime(2026, 10, 4));

    expect(fund.ter, 0.50);
    expect(fund.performanceFee, 10);

    // Las listas estructuradas existentes deben conservarse.
    expect(fund.costPeriods, isEmpty);
    expect(fund.costCharges, isEmpty);
  }

  test(
    'LF-67.1: searchFund actualiza TER sin perder los costes estructurados',
    () async {
      await DatabaseService.saveFund(existingFund);
      final provider = createProvider();

      await provider.searchFund(isin);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expectCostsPreserved(savedFund!);
    },
  );

  test('LF-67.2: updateAllPortfolio actualiza TER sin perder los costes estructurados', () async {
    await DatabaseService.saveFund(existingFund);
    final provider = createProvider()..portfolio = [existingFund];

    await provider.updateAllPortfolio();

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expectCostsPreserved(savedFund!);
  });
}
