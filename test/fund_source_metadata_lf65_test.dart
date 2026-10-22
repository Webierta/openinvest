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
      'fund_source_metadata_lf65_',
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

  test(
    'LF-66.1: una valoración anterior no reemplaza los datos actuales',
    () async {
      final date = DateTime(2026, 10, 6);
      final olderDate = DateTime(2026, 10, 5);

      final existing = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo registrado en CNMV',
        lastValue: 112.15,
        currency: 'EUR',
        date: date,
        history: [PricePoint(olderDate, 111.15), PricePoint(date, 112.15)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(existing);

      final fetchedFund = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo registrado en CNMV',
        lastValue: 111.15,
        currency: 'EUR',
        date: olderDate,
        history: [PricePoint(olderDate, 111.15)],
        source: null,
        valuationSource: FundSource.financialTimes,
      );

      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(),
        ftByIsinFetcher: (_) async => ScrapeResult(data: fetchedFund),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
      );

      final result = await provider.searchFund(isin);

      expect(result, isFalse);

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);
      expect(saved.lastValue, 112.15);
      expect(saved.date, date);
      expect(saved.history, hasLength(2));
      expect(saved.history.map((point) => point.date).toList(), [
        olderDate,
        date,
      ]);
      expect(saved.history.map((point) => point.price).toList(), [
        111.15,
        112.15,
      ]);
    },
  );

  test('LF-66.2: una valoración más reciente actualiza los datos y conserva el origen', () async {
    final oldDate = DateTime(2026, 10, 5);
    final newDate = DateTime(2026, 10, 6);

    final existing = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo registrado en CNMV',
      lastValue: 111.15,
      currency: 'EUR',
      date: oldDate,
      history: [PricePoint(oldDate, 111.15)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(existing);

    final fetchedFund = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo registrado en CNMV',
      lastValue: 112.15,
      currency: 'EUR',
      date: newDate,
      history: [PricePoint(oldDate, 111.15), PricePoint(newDate, 112.15)],
      source: null,
      valuationSource: FundSource.financialTimes,
    );

    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      ftByIsinFetcher: (_) async => ScrapeResult(data: fetchedFund),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );

    final result = await provider.searchFund(isin);

    expect(result, isTrue);

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.source, FundSource.cnmv);
    expect(saved.valuationSource, FundSource.financialTimes);
    expect(saved.lastValue, 112.15);
    expect(saved.date, newDate);
    expect(saved.history, hasLength(2));
    expect(saved.history.map((point) => point.date).toList(), [
      oldDate,
      newDate,
    ]);
    expect(saved.history.map((point) => point.price).toList(), [
      111.15,
      112.15,
    ]);
  });
}
