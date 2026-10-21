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
  late FundData existingFund;
  late FundData primaryFund;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf65_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );

    existingFund = FundData(
      isin: isin,
      symbol: 'ORIGINAL',
      name: 'Original Fund Name',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [
        PricePoint(DateTime(2026, 10, 1), 100),
        PricePoint(DateTime(2026, 10, 2), 105),
        PricePoint(DateTime(2026, 10, 3), 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      ter: 0.75,
      performanceFee: 10,
      alertMin: 90,
      alertMax: 120,
      morningstarRating: 4,
      morningstarCheckedAt: DateTime(2026, 9, 20),
      morningstarLastAttemptAt: DateTime(2026, 9, 21),
    );

    // La respuesta principal trae una valoración más reciente,
    // pero no informa los metadatos opcionales.
    primaryFund = FundData(
      isin: isin,
      symbol: '',
      name: '',
      lastValue: 112,
      currency: 'EUR',
      date: DateTime(2026, 10, 4),
      history: [
        PricePoint(DateTime(2026, 10, 3), 110),
        PricePoint(DateTime(2026, 10, 4), 112),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  FundProvider createProvider() {
    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: primaryFund),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectMetadataPreserved(FundData fund) {
    expect(fund.lastValue, 112);
    expect(fund.date, DateTime(2026, 10, 4));

    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.cnmv);

    expect(fund.name, 'Original Fund Name');
    expect(fund.symbol, 'ORIGINAL');

    expect(fund.ter, 0.75);
    expect(fund.performanceFee, 10);
    expect(fund.alertMin, 90);
    expect(fund.alertMax, 120);

    expect(fund.morningstarRating, 4);
    expect(fund.morningstarCheckedAt, DateTime(2026, 9, 20));
    expect(fund.morningstarLastAttemptAt, DateTime(2026, 9, 21));

    expect(fund.history.length, 4);
    expect(
      fund.history.map((point) => point.date).toSet().length,
      fund.history.length,
    );
  }

  test(
    'LF-65.1: searchFund conserva metadatos opcionales ausentes en CNMV',
    () async {
      await DatabaseService.saveFund(existingFund);
      final provider = createProvider();

      await provider.searchFund(isin);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expectMetadataPreserved(savedFund!);
    },
  );

  test('LF-65.2: updateAllPortfolio conserva metadatos opcionales ausentes en CNMV', () async {
    await DatabaseService.saveFund(existingFund);
    final provider = createProvider()..portfolio = [existingFund];

    await provider.updateAllPortfolio();

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expectMetadataPreserved(savedFund!);
  });
}
