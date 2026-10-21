import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';

  final oldDate = DateTime(2026, 10, 1);
  final primaryDate = DateTime(2026, 10, 2);
  final fallbackDate = DateTime(2026, 10, 3);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf52_',
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
      lastValue: 100,
      currency: 'EUR',
      date: oldDate,
      history: [PricePoint(oldDate, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  FundData createPrimaryFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 105,
      currency: 'EUR',
      date: primaryDate,
      history: [PricePoint(oldDate, 100), PricePoint(primaryDate, 105)],
      source: FundSource.yahoo,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: createPrimaryFund()),
      queFondosFetcher: (_) async => const ScraperResult(
        nombre: 'Test Fund',
        valorLiquidativo: '110',
        fecha: '03/10/2026',
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectPreservedOriginAndLatestValuation(FundData? saved) {
    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.queFondos);
    expect(saved.lastValue, 110);
    expect(saved.date, fallbackDate);
    expect(saved.history, hasLength(3));
    expect(saved.history[0].date, oldDate);
    expect(saved.history[0].price, 100);
    expect(saved.history[1].date, primaryDate);
    expect(saved.history[1].price, 105);
    expect(saved.history[2].date, fallbackDate);
    expect(saved.history[2].price, 110);
  }

  test('LF-52.1: searchFund preserva el origen existente ante un conflicto de fuentes', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    final result = await provider.searchFund(isin);

    expect(result, isTrue);
    expectPreservedOriginAndLatestValuation(
      await DatabaseService.getFund(isin),
    );
  });

  test('LF-52.2: updateAllPortfolio preserva el origen existente ante un conflicto de fuentes', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectPreservedOriginAndLatestValuation(
      await DatabaseService.getFund(isin),
    );
    expect(provider.lastError, isNull);
  });
}
