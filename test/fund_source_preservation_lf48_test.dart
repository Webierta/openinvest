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

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf48_test_',
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

  FundData fund({
    FundSource? source,
    FundSource? valuationSource,
    double value = 100,
    DateTime? date,
  }) {
    final valuationDate = date ?? DateTime(2026, 10, 1);

    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: value,
      currency: 'EUR',
      date: valuationDate,
      history: [PricePoint(valuationDate, value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    final primaryFund = fund(value: 105, date: DateTime(2026, 10, 2));

    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: primaryFund),
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

  void expectUnknownOriginAndKnownValuation(FundData? saved) {
    expect(saved, isNotNull);
    expect(saved!.source, isNull);
    expect(saved.valuationSource, FundSource.queFondos);
    expect(saved.lastValue, 110);
    expect(saved.date, DateTime(2026, 10, 3));
    expect(saved.history, hasLength(3));
  }

  test('LF-48.1: searchFund no infiere source a partir de QueFondos', () async {
    final existing = fund();
    final provider = await createProvider(existing);

    final result = await provider.searchFund(isin);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);
    expectUnknownOriginAndKnownValuation(saved);
  });

  test(
    'LF-48.2: updateAllPortfolio no infiere source a partir de QueFondos',
    () async {
      final existing = fund();
      final provider = await createProvider(existing)
        ..portfolio = [existing];

      await provider.updateAllPortfolio();

      final saved = await DatabaseService.getFund(isin);
      expectUnknownOriginAndKnownValuation(saved);
      expect(provider.lastError, isNull);
    },
  );
}
