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

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf45_',
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

  FundData createFund({
    FundSource? source = FundSource.cnmv,
    FundSource? valuationSource = FundSource.yahoo,
    double value = 100,
    DateTime? date,
  }) {
    final effectiveDate = date ?? DateTime(2026, 10, 1);

    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: value,
      currency: 'EUR',
      date: effectiveDate,
      history: [PricePoint(effectiveDate, value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  FundProvider createFailingProvider() {
    return FundProvider(
      fundIsinFetcher: (_) async {
        throw Exception('Fallo simulado del proveedor principal');
      },
      ftByIsinFetcher: (_) async => null,
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );
  }

  test('LF-45.1: searchFund conserva el fondo y sus fuentes si falla la actualización', () async {
    await DatabaseService.saveFund(createFund());

    final provider = createFailingProvider();

    final result = await provider.searchFund(isin);

    expect(result, isFalse);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.lastValue, 100);
    expect(saved.date, DateTime(2026, 10, 1));
    expect(saved.history, hasLength(1));
    expect(saved.history.single.price, 100);
  });

  test('LF-45.2: updateAllPortfolio conserva el fondo si fallan todos los proveedores', () async {
    final existing = createFund();

    await DatabaseService.saveFund(existing);

    final provider = createFailingProvider()..portfolio = [existing];

    await provider.updateAllPortfolio();

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.lastValue, 100);
    expect(saved.date, DateTime(2026, 10, 1));
    expect(saved.history, hasLength(1));
    expect(saved.history.single.price, 100);
    expect(provider.lastError, isNotNull);
  });
}
