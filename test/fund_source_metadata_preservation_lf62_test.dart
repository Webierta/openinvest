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
      'fund_source_metadata_lf62_',
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
      symbol: 'ORIGINAL',
      name: 'Original Fund Name',
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
      ter: 0.75,
      performanceFee: 10,
      alertMin: 90,
      alertMax: 120,
      morningstarRating: 4,
    );
  }

  FundData createPrimaryFund() {
    return FundData(
      isin: isin,
      symbol: '',
      name: '',
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
        nombre: 'Original Fund Name',
        valorLiquidativo: '115',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectMetadataPreserved(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    // La valoración más reciente procede de QueFondos.
    expect(fund.lastValue, 115);
    expect(fund.date, date4);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);

    // Los metadatos existentes no deben desaparecer por una
    // respuesta principal con nombre y símbolo vacíos.
    expect(fund.name, 'Original Fund Name');
    expect(fund.symbol, 'ORIGINAL');
    expect(fund.currency, 'EUR');

    // Se preservan los metadatos adicionales existentes.
    expect(fund.ter, 0.75);
    expect(fund.performanceFee, 10);
    expect(fund.alertMin, 90);
    expect(fund.alertMax, 120);
    expect(fund.morningstarRating, 4);

    // El historial mantiene los puntos anteriores y la valoración nueva.
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
  }

  test(
    'LF-62.1: searchFund conserva metadatos al actualizar la valoración',
    () async {
      final existing = createExistingFund();
      final provider = await createProvider(existing);

      await provider.searchFund(isin);

      expectMetadataPreserved(await DatabaseService.getFund(isin));
    },
  );

  test('LF-62.2: updateAllPortfolio conserva metadatos al actualizar la valoración', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectMetadataPreserved(await DatabaseService.getFund(isin));
  });
}
