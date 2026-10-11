import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/models/fund_data.dart';
//import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:investing/services/financialtimes_scraper.dart';
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
      'fund_source_valuation_lf23_',
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

  test(
    'FTFundScraper asigna source y valuationSource a Financial Times',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          return http.Response('''
<h1 class="mod-tearsheet-overview__header__title">Fondo de prueba</h1>
<div>Price (EUR)112.15</div>
<div>as of October 6, 2026</div>
''', 200);
        }

        expect(request.url.path, endsWith('/historical'));

        return http.Response('''
<div class="mod-tearsheet-historical-prices">
  <table>
    <tr>
      <th>Date</th><th>Open</th><th>High</th>
      <th>Low</th><th>Close</th><th>Volume</th>
    </tr>
    <tr>
      <td>Tuesday, October 06, 2026</td>
      <td>112.15</td><td>112.15</td><td>112.15</td>
      <td>112.15</td><td></td>
    </tr>
    <tr>
      <td>Monday, October 05, 2026</td>
      <td>112.10</td><td>112.10</td><td>112.10</td>
      <td>112.10</td><td></td>
    </tr>
  </table>
</div>
''', 200);
      });

      final result = await FTFundScraper(client: client).scrapeByIsin(isin);

      expect(result, isNotNull);
      expect(result!.data, isNotNull);

      final fund = result.data!;

      expect(fund.isin, isin);
      expect(fund.name, 'Fondo de prueba');
      expect(fund.lastValue, 112.15);
      expect(fund.currency, 'EUR');
      expect(fund.date, DateTime(2026, 10, 6));
      expect(
        fund.history.any(
          (point) =>
              point.date == DateTime(2026, 10, 5) && point.price == 112.10,
        ),
        isTrue,
      );

      expect(fund.source, FundSource.financialTimes);
      expect(fund.valuationSource, FundSource.financialTimes);
    },
  );

  test('searchFund conserva source y registra Financial Times como '
      'valuationSource al seleccionar su valoración', () async {
    final previousDate = DateTime(2026, 10, 1);
    final latestDate = DateTime(2026, 10, 2);

    final existing = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo existente',
      lastValue: 100,
      currency: 'EUR',
      date: previousDate,
      history: [PricePoint(previousDate, 100)],
      source: FundSource.financialTimes,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existing);

    final ftFund = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo actualizado por FT',
      lastValue: 105,
      currency: 'EUR',
      date: latestDate,
      history: [PricePoint(latestDate, 105)],
      source: FundSource.financialTimes,
      valuationSource: FundSource.financialTimes,
    );

    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      ftByIsinFetcher: (_) async =>
          ScrapeResult(data: ftFund, source: FundSource.financialTimes),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );

    final result = await provider.searchFund(isin);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.financialTimes);
    expect(saved.valuationSource, FundSource.financialTimes);
    expect(saved.lastValue, 105);
    expect(saved.date, latestDate);
    expect(saved.name, 'Fondo actualizado por FT');
  });
}
