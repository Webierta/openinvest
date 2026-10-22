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
      'fund_source_identity_lf62_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-62.1: actualizar las fuentes del fondo A no modifica los datos del fondo B', () async {
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

    final updatedA = FundData(
      isin: isinA,
      symbol: isinA,
      name: 'Fondo A actualizado',
      lastValue: 112.15,
      currency: 'EUR',
      date: date2,
      history: [PricePoint(date1, 100), PricePoint(date2, 112.15)],
      operations: [operationA],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(updatedA);

    final recoveredA = await DatabaseService.getFund(isinA);
    final recoveredB = await DatabaseService.getFund(isinB);

    expect(recoveredA, isNotNull);
    expect(recoveredA!.source, FundSource.cnmv);
    expect(recoveredA.valuationSource, FundSource.financialTimes);
    expect(recoveredA.lastValue, 112.15);
    expect(recoveredA.history, hasLength(2));
    expect(recoveredA.operations, hasLength(1));

    expect(recoveredB, isNotNull);
    expect(recoveredB!.source, FundSource.ecb);
    expect(recoveredB.valuationSource, FundSource.financialTimes);
    expect(recoveredB.lastValue, 120);
    expect(recoveredB.date, date1);
    expect(recoveredB.name, 'Fondo B');
    expect(recoveredB.history, hasLength(1));
    expect(recoveredB.history.single.price, 120);
    expect(recoveredB.operations, hasLength(1));
    expect(recoveredB.operations.single.isin, isinB);
    expect(recoveredB.operations.single.units, 3);
    expect(recoveredB.operations.single.price, 40);
    expect(recoveredB.operations.single.amount, 120);
  });
}
