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
      'fund_source_history_precedence_lf55_',
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
      history: [
        // Precio deliberadamente distinto al del proveedor principal.
        PricePoint(oldDate, 101),
        PricePoint(existingLatestDate, 110),
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
      lastValue: 105,
      currency: 'EUR',
      date: staleDate,
      history: [
        // Para esta fecha, el proveedor principal debe prevalecer.
        PricePoint(oldDate, 100),
        PricePoint(staleDate, 105),
      ],
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

  void expectHistoryPrecedence(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    // La valoración de QueFondos debe ser aceptada.
    expect(fund.lastValue, 115);
    expect(fund.date, fallbackDate);
    expect(fund.valuationSource, FundSource.queFondos);

    // El origen del fondo no debe cambiar por recibir una valoración.
    expect(fund.source, FundSource.cnmv);

    // El precio del proveedor principal prevalece para el 1 de octubre.
    expect(
      fund.history
          .where((point) => point.date == oldDate)
          .map((point) => point.price)
          .single,
      100,
    );

    // El punto más reciente del fondo existente se conserva.
    expect(
      fund.history
          .where((point) => point.date == existingLatestDate)
          .map((point) => point.price)
          .single,
      110,
    );

    // Se incorpora el punto de QueFondos.
    expect(
      fund.history
          .where((point) => point.date == fallbackDate)
          .map((point) => point.price)
          .single,
      115,
    );

    // Se conservan los cuatro días, ordenados y sin duplicados.
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
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-55.1: searchFund aplica la precedencia de precios y conserva el historial', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    final result = await provider.searchFund(isin);

    expect(result, isTrue);
    expectHistoryPrecedence(await DatabaseService.getFund(isin));
  });

  test('LF-55.2: updateAllPortfolio aplica la precedencia de precios y conserva el historial', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectHistoryPrecedence(await DatabaseService.getFund(isin));
  });
}
