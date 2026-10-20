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
      'fund_source_recovery_lf46_',
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
    FundSource? valuationSource = FundSource.queFondos,
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

  FundProvider createRecoveringProvider() {
    var attempts = 0;

    return FundProvider(
      fundIsinFetcher: (_) async {
        attempts++;

        if (attempts == 1) {
          throw Exception('Fallo simulado del proveedor principal');
        }

        final date = DateTime(2026, 10, 3);
        final fund = createFund(
          source: FundSource.yahoo,
          valuationSource: FundSource.yahoo,
          value: 105,
          date: date,
        );

        return ScrapeResult(data: fund, source: FundSource.yahoo);
      },
      ftByIsinFetcher: (_) async => null,
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );
  }

  void expectRecoveredFund(FundData? saved) {
    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.yahoo);
    expect(saved.lastValue, 105);
    expect(saved.date, DateTime(2026, 10, 3));
    expect(saved.history, hasLength(2));
    expect(
      saved.history.map((point) => point.date),
      containsAll([DateTime(2026, 10, 1), DateTime(2026, 10, 3)]),
    );
  }

  test('LF-46.1: searchFund se recupera después de un fallo', () async {
    await DatabaseService.saveFund(createFund());

    final provider = createRecoveringProvider();

    final firstResult = await provider.searchFund(isin);

    expect(firstResult, isFalse);

    final afterFailure = await DatabaseService.getFund(isin);
    expect(afterFailure, isNotNull);
    expect(afterFailure!.source, FundSource.cnmv);
    expect(afterFailure.valuationSource, FundSource.queFondos);
    expect(afterFailure.lastValue, 100);
    expect(afterFailure.date, DateTime(2026, 10, 1));

    final secondResult = await provider.searchFund(isin);

    expect(secondResult, isTrue);

    expectRecoveredFund(await DatabaseService.getFund(isin));
  });

  test('LF-46.2: updateAllPortfolio se recupera después de un fallo', () async {
    final existing = createFund();
    await DatabaseService.saveFund(existing);

    final provider = createRecoveringProvider()..portfolio = [existing];

    await provider.updateAllPortfolio();

    final afterFailure = await DatabaseService.getFund(isin);
    expect(afterFailure, isNotNull);
    expect(afterFailure!.source, FundSource.cnmv);
    expect(afterFailure.valuationSource, FundSource.queFondos);
    expect(afterFailure.lastValue, 100);
    expect(afterFailure.date, DateTime(2026, 10, 1));

    await provider.updateAllPortfolio();

    expectRecoveredFund(await DatabaseService.getFund(isin));
    expect(provider.lastError, isNull);
  });
}
