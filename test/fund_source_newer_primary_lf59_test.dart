import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
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
      'fund_source_newer_primary_lf59_',
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

  FundData createNewerPrimaryFund() {
    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 115,
      currency: 'EUR',
      date: date4,
      history: [
        PricePoint(date2, 105),
        PricePoint(date3, 110),
        PricePoint(date4, 115),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
    );
  }

  Future<FundProvider> createProvider(FundData existing) async {
    await DatabaseService.saveFund(existing);

    return FundProvider(
      fundIsinFetcher: (_) async =>
          ScrapeResult(data: createNewerPrimaryFund()),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  void expectNewerPrimaryAccepted(FundData? saved) {
    expect(saved, isNotNull);
    final fund = saved!;

    // La valoración principal más reciente debe aceptarse.
    expect(fund.lastValue, 115);
    expect(fund.date, date4);

    // El origen se conserva y la fuente de valoración se actualiza.
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.cnmv);

    // Se conserva el historial anterior y se incorpora la nueva fecha.
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
      110.0,
      115.0,
    ]);
    expect(
      fund.history.map((point) => point.date).toSet(),
      hasLength(fund.history.length),
    );
  }

  test('LF-59.1: searchFund acepta una valoración principal más reciente cuando los fallbacks no aportan datos', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing);

    await provider.searchFund(isin);

    expectNewerPrimaryAccepted(await DatabaseService.getFund(isin));
  });

  test('LF-59.2: updateAllPortfolio acepta una valoración principal más reciente cuando los fallbacks no aportan datos', () async {
    final existing = createExistingFund();
    final provider = await createProvider(existing)
      ..portfolio = [existing];

    await provider.updateAllPortfolio();

    expectNewerPrimaryAccepted(await DatabaseService.getFund(isin));
  });
}
