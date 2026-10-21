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

  final date1 = DateTime(2026, 10, 1);
  final date2 = DateTime(2026, 10, 2);
  final date3 = DateTime(2026, 10, 3);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_stale_primary_lf58_',
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

  FundData createExistingFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: date3,
      history: [
        PricePoint(date1, 100),
        PricePoint(date2, 105),
        PricePoint(date3, 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  FundData createStalePrimaryFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 103,
      currency: 'EUR',
      date: date2,
      history: [PricePoint(date1, 100), PricePoint(date2, 103)],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    return FundProvider(
      fundIsinFetcher: (_) async =>
          ScrapeResult(data: createStalePrimaryFund()),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectExistingFundPreserved(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    // La valoración almacenada es más reciente y debe prevalecer.
    expect(fund.lastValue, 110);
    expect(fund.date, date3);

    // Las fuentes existentes deben conservarse.
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);

    // El historial debe permanecer exactamente igual.
    expect(fund.history, hasLength(3));
    expect(fund.history.map((point) => point.date).toList(), [
      date1,
      date2,
      date3,
    ]);
    expect(fund.history.map((point) => point.price).toList(), [
      100.0,
      105.0,
      110.0,
    ]);
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-58.1: searchFund no retrocede ante una valoración principal más antigua', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    await provider.searchFund(isin);

    expectExistingFundPreserved(await DatabaseService.getFund(isin));
  });

  test('LF-58.2: updateAllPortfolio no retrocede ante una valoración principal más antigua', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectExistingFundPreserved(await DatabaseService.getFund(isin));
  });
}
