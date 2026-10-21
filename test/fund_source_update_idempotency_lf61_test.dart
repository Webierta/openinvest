import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

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
      'fund_source_update_idempotency_lf61_',
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

  List<(DateTime, double)> historySnapshot(FundData fund) {
    return fund.history.map((point) => (point.date, point.price)).toList();
  }

  void expectStableState(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    expect(fund.lastValue, 115);
    expect(fund.date, date4);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);

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

  test(
    'LF-61.1: searchFund es idempotente al repetir la misma actualización',
    () async {
      final existing = createExistingFund();
      final provider = await createProvider(existing);

      await provider.searchFund(isin);
      final first = await DatabaseService.getFund(isin);
      expectStableState(first);

      final firstHistory = historySnapshot(first!);

      await provider.searchFund(isin);
      final second = await DatabaseService.getFund(isin);
      expectStableState(second);

      expect(historySnapshot(second!), firstHistory);
    },
  );

  test('LF-61.2: updateAllPortfolio es idempotente al repetir la misma actualización', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();
    final first = await DatabaseService.getFund(isin);
    expectStableState(first);

    final firstHistory = historySnapshot(first!);

    await provider.updateAllPortfolio();
    final second = await DatabaseService.getFund(isin);
    expectStableState(second);

    expect(historySnapshot(second!), firstHistory);
  });
}
