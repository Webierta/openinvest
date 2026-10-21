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
  final staleDate = DateTime(2026, 10, 2);
  final existingLatestDate = DateTime(2026, 10, 3);
  final fallbackDate = DateTime(2026, 10, 4);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf54_',
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
      date: existingLatestDate,
      history: [PricePoint(oldDate, 100), PricePoint(existingLatestDate, 110)],
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
        valorLiquidativo: '115',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectLatestValuationAccepted(FundData? saved) {
    expect(saved, isNotNull);

    final fund = saved!;

    // El origen del fondo se conserva aunque QueFondos aporte
    // la valoración más reciente.
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);

    // La valoración más reciente debe proceder de QueFondos.
    expect(fund.lastValue, 115);
    expect(fund.date, fallbackDate);

    // Se conservan los puntos históricos existentes y el punto
    // recibido del proveedor principal, aunque este sea más antiguo.
    expect(fund.history, hasLength(4));

    expect(fund.history.map((point) => point.date).toList(), [
      oldDate,
      staleDate,
      existingLatestDate,
      fallbackDate,
    ]);

    expect(fund.history.map((point) => point.price).toList(), [
      100.0,
      105.0,
      110.0,
      115.0,
    ]);

    // No debe haber fechas duplicadas en el historial.
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-54.1: searchFund acepta la valoración reciente de QueFondos frente a una valoración principal antigua', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    final result = await provider.searchFund(isin);

    expect(result, isTrue);
    expectLatestValuationAccepted(await DatabaseService.getFund(isin));
  });

  test('LF-54.2: updateAllPortfolio acepta la valoración reciente de QueFondos frente a una valoración principal antigua', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectLatestValuationAccepted(await DatabaseService.getFund(isin));
  });
}
