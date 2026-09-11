import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:investing/services/database_service.dart';
import 'package:investing/services/fund_scraper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'investing_database_test_',
    );
    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('eliminar el último precio actualiza el valor vigente', () async {
    final firstDate = DateTime(2026, 9, 1);
    final latestDate = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: latestDate,
      history: [PricePoint(firstDate, 10), PricePoint(latestDate, 20)],
    );
    await DatabaseService.saveFund(fund);

    await DatabaseService.deletePricePoint('TEST', latestDate);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.lastValue, 10);
    expect(storedFund.date, firstDate);
    expect(storedFund.history.map((point) => point.date), [firstDate]);
  });

  test('eliminar el único precio deja el historial vacío', () async {
    final date = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
    );
    await DatabaseService.saveFund(fund);

    await DatabaseService.deletePricePoint('TEST', date);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.lastValue, 0);
    expect(storedFund.history, isEmpty);
  });

  test(
    'restaurar un precio recupera el historial y el valor vigente',
    () async {
      final firstDate = DateTime(2026, 9, 1);
      final latestDate = DateTime(2026, 9, 2);
      final deletedPoint = PricePoint(latestDate, 20);
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: deletedPoint.price,
        currency: 'EUR',
        date: latestDate,
        history: [PricePoint(firstDate, 10), deletedPoint],
      );
      await DatabaseService.saveFund(fund);
      await DatabaseService.deletePricePoint('TEST', latestDate);

      await DatabaseService.restorePricePoint('TEST', deletedPoint);

      final storedFund = await DatabaseService.getFund('TEST');
      expect(storedFund, isNotNull);
      expect(storedFund!.lastValue, 20);
      expect(storedFund.date, latestDate);
      expect(storedFund.history.map((point) => point.date), [
        firstDate,
        latestDate,
      ]);
    },
  );
}
