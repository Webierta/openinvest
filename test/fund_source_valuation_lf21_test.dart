import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:investing/services/fund_scraper.dart';
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
      'fund_source_valuation_lf21_test_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundData fund({
    FundSource? source,
    FundSource? valuationSource,
    double value = 100,
    DateTime? date,
    String name = 'Test Fund',
  }) {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: name,
      lastValue: value,
      currency: 'EUR',
      date: date ?? DateTime(2026, 10, 1),
      history: [PricePoint(date ?? DateTime(2026, 10, 1), value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  test(
    'searchFund conserva source cuando la valoración viene de otra fuente',
    () async {
      final existing = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
        value: 100,
        date: DateTime(2026, 10, 1),
      );

      await DatabaseService.saveFund(existing);

      final fetched = fund(
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
        value: 105,
        date: DateTime(2026, 10, 2),
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async =>
            ScrapeResult(data: fetched, source: FundSource.yahoo),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.searchFund(isin);

      expect(result, isTrue);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.financialTimes);
    },
  );

  test(
    'searchFund conserva valuationSource del resultado recuperado',
    () async {
      final existing = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
        value: 100,
        date: DateTime(2026, 10, 1),
      );

      await DatabaseService.saveFund(existing);

      final fetched = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.yahoo,
        value: 105,
        date: DateTime(2026, 10, 2),
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async =>
            ScrapeResult(data: fetched, source: FundSource.financialTimes),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.searchFund(isin);

      expect(result, isTrue);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.financialTimes);
    },
  );

  test(
    'searchFund no sustituye source existente si el resultado no lo aporta',
    () async {
      final existing = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
        value: 100,
        date: DateTime(2026, 10, 1),
      );

      await DatabaseService.saveFund(existing);

      final fetched = fund(
        source: null,
        valuationSource: FundSource.yahoo,
        value: 105,
        date: DateTime(2026, 10, 2),
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async =>
            ScrapeResult(data: fetched, source: FundSource.yahoo),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.searchFund(isin);

      expect(result, isTrue);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.financialTimes);
    },
  );

  test(
    'updateAllPortfolio conserva source al actualizar la valoración',
    () async {
      final existing = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
        value: 100,
        date: DateTime(2026, 10, 1),
      );

      await DatabaseService.saveFund(existing);

      final fetched = fund(
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
        value: 105,
        date: DateTime(2026, 10, 2),
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async =>
            ScrapeResult(data: fetched, source: FundSource.yahoo),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      )..portfolio = [existing];

      await provider.updateAllPortfolio();

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.financialTimes);
    },
  );

  test('updateAllPortfolio conserva valuationSource del resultado', () async {
    final existing = fund(
      source: FundSource.financialTimes,
      valuationSource: FundSource.financialTimes,
      value: 100,
      date: DateTime(2026, 10, 1),
    );

    await DatabaseService.saveFund(existing);

    final fetched = fund(
      source: FundSource.financialTimes,
      valuationSource: FundSource.yahoo,
      value: 105,
      date: DateTime(2026, 10, 2),
    );

    final provider = FundProvider(
      fundIsinFetcher: (_) async =>
          ScrapeResult(data: fetched, source: FundSource.financialTimes),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    )..portfolio = [existing];

    await provider.updateAllPortfolio();

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.source, FundSource.financialTimes);
    expect(saved.valuationSource, FundSource.financialTimes);
  });

  test(
    'updateAllPortfolio conserva la valoración previa aunque llegue Yahoo',
    () async {
      final existing = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
        value: 100,
        date: DateTime(2026, 10, 1),
      );

      await DatabaseService.saveFund(existing);

      final fetched = fund(
        source: FundSource.financialTimes,
        valuationSource: FundSource.yahoo,
        value: 105,
        date: DateTime(2026, 10, 2),
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async =>
            ScrapeResult(data: fetched, source: FundSource.financialTimes),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      )..portfolio = [existing];

      await provider.updateAllPortfolio();

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.financialTimes);
      expect(saved.lastValue, 100);
      expect(saved.date, DateTime(2026, 10, 1));
    },
  );

  test('parseChartPayload usa el ISIN proporcionado por Yahoo en meta', () {
    final result = FundScraper.parseChartPayload(
      isin: 'TEST',
      symbol: 'TEST',
      name: 'Test Fund',
      payload: {
        'chart': {
          'result': [
            {
              'meta': {
                'isin': isin,
                'regularMarketPrice': 105.0,
                'currency': 'EUR',
              },
            },
          ],
        },
      },
    );

    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.isin, isin);
  });

  test(
    'parseChartPayload conserva el ISIN solicitado cuando Yahoo no lo incluye',
    () {
      final result = FundScraper.parseChartPayload(
        isin: isin,
        symbol: 'TEST',
        name: 'Test Fund',
        payload: {
          'chart': {
            'result': [
              {
                'meta': {'regularMarketPrice': 105.0, 'currency': 'EUR'},
              },
            ],
          },
        },
      );

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.isin, isin);
    },
  );
}
