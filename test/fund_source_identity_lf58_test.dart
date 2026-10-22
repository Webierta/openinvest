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
      'fund_source_identity_lf58_',
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
    'LF-58.1: una nueva fuente de valoración sustituye a la anterior',
    () async {
      final previousDate = DateTime(2026, 10, 1);
      final latestDate = DateTime(2026, 10, 6);

      final existing = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo registrado en CNMV',
        lastValue: 100,
        currency: 'EUR',
        date: previousDate,
        history: [PricePoint(previousDate, 100)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(existing);

      final fetchedFund = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo actualizado por FT',
        lastValue: 112.15,
        currency: 'EUR',
        date: latestDate,
        history: [
          PricePoint(previousDate, 100),
          PricePoint(latestDate, 112.15),
        ],
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
      expect(saved.date, latestDate);
      expect(saved.name, 'Fondo actualizado por FT');
    },
  );
}
