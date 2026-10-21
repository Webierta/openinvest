import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:investing/utils/app_error.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';

  final oldDate = DateTime(2026, 10, 1);
  final latestDate = DateTime(2026, 10, 3);
  final staleDate = DateTime(2026, 10, 2);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf53_',
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
      date: latestDate,
      history: [PricePoint(oldDate, 100), PricePoint(latestDate, 110)],
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
      date: staleDate,
      history: [PricePoint(oldDate, 100), PricePoint(staleDate, 105)],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: createPrimaryFund()),
      queFondosFetcher: (_) async => const ScraperResult(
        nombre: 'Test Fund',
        valorLiquidativo: '105',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectLatestValuationPreserved(FundData? saved) {
    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.lastValue, 110);
    expect(saved.date, latestDate);

    // La valoración más reciente debe seguir presente y no duplicarse.
    expect(saved.history, hasLength(2));
    expect(saved.history[0].date, oldDate);
    expect(saved.history[0].price, 100);
    expect(saved.history[1].date, latestDate);
    expect(saved.history[1].price, 110);
  }

  test(
    'LF-53.1: searchFund rechaza una valoración de QueFondos más antigua',
    () async {
      final existing = createExistingFund();
      final provider = await createProvider(existing);

      final result = await provider.searchFund(isin);

      expect(result, isTrue);
      expectLatestValuationPreserved(await DatabaseService.getFund(isin));
    },
  );

  test('LF-53.2: updateAllPortfolio rechaza una valoración de QueFondos más antigua', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectLatestValuationPreserved(await DatabaseService.getFund(isin));
    //expect(provider.lastError, isNull);

    expect(provider.lastError, isNotNull);
    expect(provider.lastError!.type, AppErrorType.info);
    expect(
      provider.lastError!.message,
      'Los datos ya están actualizados y no se han producido cambios.',
    );
  });
}
