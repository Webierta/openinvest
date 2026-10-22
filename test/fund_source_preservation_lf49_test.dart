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
      'fund_source_preservation_lf49_',
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
    required FundSource? source,
    required FundSource? valuationSource,
    required double value,
    required DateTime date,
    required List<PricePoint> history,
  }) {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: value,
      currency: 'EUR',
      date: date,
      history: history,
      source: source,
      valuationSource: valuationSource,
    );
  }

  test('LF-49.1: updateAllPortfolio conserva el origen CNMV si el proveedor devuelve ECB', () async {
    final oldDate = DateTime(2026, 10, 1);
    final newDate = DateTime(2026, 10, 3);

    final existing = createFund(
      source: FundSource.cnmv,
      valuationSource: FundSource.queFondos,
      value: 100,
      date: oldDate,
      history: [PricePoint(oldDate, 100)],
    );

    final incoming = createFund(
      source: FundSource.ecb,
      valuationSource: FundSource.yahoo,
      value: 105,
      date: newDate,
      history: [PricePoint(oldDate, 100), PricePoint(newDate, 105)],
    );

    await DatabaseService.saveFund(existing);

    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: incoming),
      ftByIsinFetcher: (_) async => null,
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    )..portfolio = [existing];

    await provider.updateAllPortfolio();

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.lastValue, 105);
    expect(saved.date, newDate);
    expect(saved.history, hasLength(2));
    expect(saved.history.first.price, 100);
    expect(saved.history.last.price, 105);
    expect(provider.lastError, isNull);
  });
}
