import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isinA = 'IE00B4L5Y983';
  const isinB = 'IE00B3XXRP09';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_identity_lf63_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-63.1: actualizar las fuentes del fondo B no modifica los datos del fondo A', () async {
    final date1 = DateTime(2026, 10, 1);
    final date2 = DateTime(2026, 10, 6);

    final operationA = FundOperation(
      isin: isinA,
      type: OperationType.buy,
      date: date1,
      units: 2,
      price: 50,
      amount: 100,
    );

    final operationB = FundOperation(
      isin: isinB,
      type: OperationType.buy,
      date: date1,
      units: 3,
      price: 40,
      amount: 120,
    );

    final fundA = FundData(
      isin: isinA,
      symbol: isinA,
      name: 'Fondo A',
      lastValue: 100,
      currency: 'EUR',
      date: date1,
      history: [PricePoint(date1, 100)],
      operations: [operationA],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    final fundB = FundData(
      isin: isinB,
      symbol: isinB,
      name: 'Fondo B',
      lastValue: 120,
      currency: 'EUR',
      date: date1,
      history: [PricePoint(date1, 120)],
      operations: [operationB],
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(fundA);
    await DatabaseService.saveFund(fundB);

    final updatedB = FundData(
      isin: isinB,
      symbol: isinB,
      name: 'Fondo B actualizado',
      lastValue: 125.50,
      currency: 'EUR',
      date: date2,
      history: [PricePoint(date1, 120), PricePoint(date2, 125.50)],
      operations: [operationB],
      source: FundSource.ecb,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(updatedB);

    final recoveredA = await DatabaseService.getFund(isinA);
    final recoveredB = await DatabaseService.getFund(isinB);

    expect(recoveredB, isNotNull);
    expect(recoveredB!.source, FundSource.ecb);
    expect(recoveredB.valuationSource, FundSource.yahoo);
    expect(recoveredB.lastValue, 125.50);
    expect(recoveredB.history, hasLength(2));
    expect(recoveredB.operations, hasLength(1));

    expect(recoveredA, isNotNull);
    expect(recoveredA!.source, FundSource.cnmv);
    expect(recoveredA.valuationSource, FundSource.yahoo);
    expect(recoveredA.lastValue, 100);
    expect(recoveredA.date, date1);
    expect(recoveredA.name, 'Fondo A');
    expect(recoveredA.history, hasLength(1));
    expect(recoveredA.history.single.price, 100);
    expect(recoveredA.operations, hasLength(1));
    expect(recoveredA.operations.single.isin, isinA);
    expect(recoveredA.operations.single.units, 2);
    expect(recoveredA.operations.single.price, 50);
    expect(recoveredA.operations.single.amount, 100);
  });
}
