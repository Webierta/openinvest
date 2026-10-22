import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/models/fund_data.dart';
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
      'fund_source_identity_lf55_',
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
    'LF-55.1: FT identifica la fuente de valoración, no la de identidad',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/summary')) {
          return http.Response('''
<h1 class="mod-tearsheet-overview__header__title">
  Fondo de prueba
</h1>
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
  </table>
</div>
''', 200);
      });

      final result = await FTFundScraper(client: client).scrapeByIsin(isin);

      expect(result, isNotNull);
      expect(result!.data, isNotNull);
      expect(result.data!.isin, isin);
      expect(result.data!.source, isNull);
      expect(result.data!.valuationSource, FundSource.financialTimes);
    },
  );

  test('LF-55.2: actualizar desde FT conserva la identidad CNMV', () async {
    final previousDate = DateTime(2026, 10, 1);
    final latestDate = DateTime(2026, 10, 6);

    final existing = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo registrado en CNMV',
      lastValue: 100,
      currency: 'EUR',
      date: previousDate,
      history: [PricePoint(previousDate, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existing);

    // FT aporta una valoración, no un nuevo origen de identidad.
    final ftFund = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo actualizado por FT',
      lastValue: 112.15,
      currency: 'EUR',
      date: latestDate,
      history: [PricePoint(latestDate, 112.15)],
      source: null,
      valuationSource: FundSource.financialTimes,
    );

    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      ftByIsinFetcher: (_) async => ScrapeResult(data: ftFund),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );

    final result = await provider.searchFund(isin);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.financialTimes);
    expect(saved.lastValue, 112.15);
    expect(saved.date, latestDate);
    expect(saved.name, 'Fondo actualizado por FT');
  });
}
