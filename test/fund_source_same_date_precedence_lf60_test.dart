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

  final date1 = DateTime(2026, 10, 1);
  final date2 = DateTime(2026, 10, 2);
  final date3 = DateTime(2026, 10, 3);
  final date4 = DateTime(2026, 10, 4);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_same_date_precedence_lf60_',
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
        PricePoint(date2, 107),
        PricePoint(date3, 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  FundData createPrimaryFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 112,
      currency: 'EUR',
      date: date3,
      history: [PricePoint(date2, 105), PricePoint(date3, 112)],
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
        valorLiquidativo: '115',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectMergedHistory(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    expect(fund.lastValue, 115);
    expect(fund.date, date4);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);

    // La respuesta principal prevalece en las fechas compartidas.
    // El punto del 1 de octubre solo existente en la base de datos
    // se conserva, y QueFondos aporta la nueva fecha.
    expect(fund.history, hasLength(4));
    expect(fund.history.map((point) => point.date).toList(), [
      date1,
      date2,
      date3,
      date4,
    ]);
    expect(fund.history.map((point) => point.price).toList(), [
      100.0,
      105.0,
      112.0,
      115.0,
    ]);
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-60.1: searchFund aplica la precedencia de precios en fechas compartidas', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    await provider.searchFund(isin);

    expectMergedHistory(await DatabaseService.getFund(isin));
  });

  test('LF-60.2: updateAllPortfolio aplica la precedencia de precios en fechas compartidas', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectMergedHistory(await DatabaseService.getFund(isin));
  });
}
