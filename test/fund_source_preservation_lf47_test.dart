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

  final oldDate = DateTime(2026, 10, 1);
  final newDate = DateTime(2026, 10, 3);

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf47_',
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
      lastValue: 100,
      currency: 'EUR',
      date: oldDate,
      history: [PricePoint(oldDate, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.queFondos,
    );
  }

  FundData createUpdatedFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 105,
      currency: 'EUR',
      date: newDate,
      history: [PricePoint(oldDate, 100), PricePoint(newDate, 105)],
      // El proveedor no informa la procedencia.
      source: null,
      valuationSource: null,
    );
  }

  FundProvider createProvider() {
    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: createUpdatedFund()),
      ftByIsinFetcher: (_) async => null,
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );
  }

  void expectSourcesAndValuation(FundData? saved) {
    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.queFondos);
    expect(saved.lastValue, 105);
    expect(saved.date, newDate);
    expect(saved.history, hasLength(2));
    expect(saved.history.first.price, 100);
    expect(saved.history.last.price, 105);
  }

  test('LF-47.1: searchFund conserva las fuentes si la nueva valoración no las informa', () async {
    await DatabaseService.saveFund(createExistingFund());

    final provider = createProvider();

    final result = await provider.searchFund(isin);

    expect(result, isTrue);

    expectSourcesAndValuation(await DatabaseService.getFund(isin));
  });

  test('LF-47.2: updateAllPortfolio conserva las fuentes si la nueva valoración no las informa', () async {
    final existing = createExistingFund();
    await DatabaseService.saveFund(existing);

    final provider = createProvider()..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectSourcesAndValuation(await DatabaseService.getFund(isin));
    expect(provider.lastError, isNull);
  });
}
