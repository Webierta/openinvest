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

  test('guardar un fondo persiste sus operaciones', () async {
    final date = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
      operations: [
        FundOperation(
          isin: 'TEST',
          date: date,
          type: OperationType.buy,
          units: 3,
          price: 20,
          amount: 60,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.operations, hasLength(1));
    expect(storedFund.operations.single.type, OperationType.buy);
    expect(storedFund.operations.single.amount, 60);
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

  test('restaurar una operación recupera sus datos y su id', () async {
    final date = DateTime(2026, 9, 2);
    await DatabaseService.saveFund(
      FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 20,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 20)],
      ),
    );
    await DatabaseService.saveOperation(
      FundOperation(
        isin: 'TEST',
        date: date,
        type: OperationType.buy,
        units: 3,
        price: 20,
        amount: 60,
      ),
    );

    final savedFund = await DatabaseService.getFund('TEST');
    final operation = savedFund!.operations.single;
    expect(operation.id, isNotNull);

    await DatabaseService.deleteOperation(operation.id!);
    expect((await DatabaseService.getFund('TEST'))!.operations, isEmpty);

    await DatabaseService.restoreOperation(operation);

    final restoredFund = await DatabaseService.getFund('TEST');
    expect(restoredFund!.operations, hasLength(1));
    expect(restoredFund.operations.single.id, operation.id);
    expect(restoredFund.operations.single.amount, 60);
  });

  test(
    'reemplazar un fondo elimina sus datos anteriores atómicamente',
    () async {
      final date = DateTime(2026, 9, 2);
      final original = FundData(
        isin: 'TEST',
        symbol: 'OLD',
        name: 'Old Fund',
        lastValue: 10,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 10)],
      );
      await DatabaseService.saveFund(original);
      await DatabaseService.saveOperation(
        FundOperation(
          isin: 'TEST',
          date: date,
          type: OperationType.buy,
          units: 1,
          price: 10,
          amount: 10,
        ),
      );

      final replacement = FundData(
        isin: 'TEST',
        symbol: 'NEW',
        name: 'New Fund',
        lastValue: 25,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 25)],
        operations: [
          FundOperation(
            id: 999,
            isin: 'TEST',
            date: date,
            type: OperationType.sell,
            units: 2,
            price: 25,
            amount: 50,
          ),
        ],
      );
      await DatabaseService.replaceFund(replacement);

      final storedFund = await DatabaseService.getFund('TEST');
      expect(storedFund!.name, 'New Fund');
      expect(storedFund.lastValue, 25);
      expect(storedFund.operations, hasLength(1));
      expect(storedFund.operations.single.type, OperationType.sell);
      expect(storedFund.operations.single.id, isNot(999));
    },
  );
}
