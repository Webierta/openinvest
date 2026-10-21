import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
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

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf57_',
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
        PricePoint(date2, 105),
        PricePoint(date3, 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  FundData createUnusablePrimaryFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 0,
      currency: 'EUR',
      date: date3,
      history: const [],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    return FundProvider(
      fundIsinFetcher: (_) async =>
          ScrapeResult(data: createUnusablePrimaryFund()),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectExistingFundPreserved(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    // Se conserva la última valoración aceptada.
    expect(fund.lastValue, 110);
    expect(fund.date, date3);

    // Ninguna fuente incompleta sustituye las fuentes existentes.
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);

    // Se conserva el historial sin cambios ni puntos duplicados.
    expect(fund.history, hasLength(3));
    expect(fund.history.map((point) => point.date).toList(), [
      date1,
      date2,
      date3,
    ]);
    expect(fund.history.map((point) => point.price).toList(), [
      100.0,
      105.0,
      110.0,
    ]);
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-57.1: searchFund conserva el fondo cuando ningún proveedor ofrece una valoración válida', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    await provider.searchFund(isin);

    // La búsqueda puede devolver false si no encuentra datos nuevos.
    // Lo importante aquí es verificar que el fondo sigue intacto.
    expectExistingFundPreserved(await DatabaseService.getFund(isin));
  });

  test('LF-57.2: updateAllPortfolio conserva el fondo cuando ningún proveedor ofrece una valoración válida', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectExistingFundPreserved(await DatabaseService.getFund(isin));
  });
}
