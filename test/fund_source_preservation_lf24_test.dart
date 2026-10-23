import 'dart:io';

import 'package:flutter/material.dart';
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
      'fund_source_preservation_lf24_',
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
    'searchFundByRange conserva source y valuationSource del fondo existente',
    () async {
      final previousDate = DateTime(2026, 10, 1);
      final historyDate = DateTime(2026, 9, 15);
      final rangeStart = DateTime(2026, 9, 1);
      final rangeEnd = DateTime(2026, 10, 1);
      final range = DateTimeRange(start: rangeStart, end: rangeEnd);

      final existingFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo existente',
        lastValue: 100,
        currency: 'EUR',
        date: previousDate,
        history: [PricePoint(previousDate, 100)],
        source: FundSource.financialTimes,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(existingFund);

      final fetchedFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo descargado',
        lastValue: 98,
        currency: 'EUR',
        date: historyDate,
        history: [PricePoint(historyDate, 98)],
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
      );

      String? receivedIsin;
      DateTimeRange? receivedRange;

      final provider = FundProvider(
        fundRangeFetcher: (requestedIsin, requestedRange) async {
          receivedIsin = requestedIsin;
          receivedRange = requestedRange;
          return ScrapeResult(data: fetchedFund);
        },
      );

      final result = await provider.searchFundByRange(
        isin.toLowerCase(),
        range,
      );

      expect(result, isTrue);
      expect(receivedIsin, isin);
      expect(receivedRange, range);

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.source, FundSource.financialTimes);
      expect(saved.valuationSource, FundSource.yahoo);

      // La consulta de rango sustituye el historial, no la valoración vigente.
      expect(saved.lastValue, 100);

      expect(saved.date, previousDate);
      expect(
        saved.history,
        contains(
          isA<PricePoint>()
              .having((point) => point.date, 'date', historyDate)
              .having((point) => point.price, 'price', 98),
        ),
      );
    },
  );
}
