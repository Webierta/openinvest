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

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'investing_transfer_tr1_',
    );
    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'TR-1.1: si falla la entrada, el traspaso no guarda la salida',
    () async {
      final date = DateTime(2026, 10, 1);

      FundData createFund(String isin) => FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo $isin',
        lastValue: 100,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 100)],
      );

      await DatabaseService.saveFund(createFund('SOURCE'));
      await DatabaseService.saveFund(createFund('DEST'));

      final db = await DatabaseService.database;

      // Simula un fallo al guardar la operación del fondo de destino.
      await db.execute('''
        CREATE TRIGGER fail_destination_transfer
        BEFORE INSERT ON operations
        WHEN NEW.isin = 'DEST'
        BEGIN
          SELECT RAISE(ABORT, 'Fallo simulado al guardar el destino');
        END
      ''');

      final provider = FundProvider();

      await provider.addOperation(
        FundOperation(
          isin: 'SOURCE',
          date: date,
          type: OperationType.outTransfer,
          units: 2,
          price: 100,
          amount: 200,
        ),
        op2: FundOperation(
          isin: 'DEST',
          date: date,
          type: OperationType.inTransfer,
          units: 2,
          price: 100,
          amount: 200,
        ),
      );

      final operations = await db.query('operations');

      expect(
        operations,
        isEmpty,
        reason:
            'No debe persistir ninguna de las dos operaciones '
            'si falla una parte del traspaso.',
      );
    },
  );

  test('TR-1.2: un traspaso correcto guarda la salida y la entrada', () async {
    final date = DateTime(2026, 10, 2);

    FundData createFund(String isin) => FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo $isin',
      lastValue: 100,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 100)],
    );

    await DatabaseService.saveFund(createFund('SOURCE'));
    await DatabaseService.saveFund(createFund('DEST'));

    final db = await DatabaseService.database;
    final provider = FundProvider();

    await provider.addOperation(
      FundOperation(
        isin: 'SOURCE',
        date: date,
        type: OperationType.outTransfer,
        units: 2,
        price: 100,
        amount: 200,
      ),
      op2: FundOperation(
        isin: 'DEST',
        date: date,
        type: OperationType.inTransfer,
        units: 2,
        price: 100,
        amount: 200,
      ),
    );

    final operations = await db.query('operations', orderBy: 'isin ASC');

    expect(operations, hasLength(2));

    expect(operations.map((op) => op['isin']).toList(), ['DEST', 'SOURCE']);

    expect(operations.map((op) => op['type']).toList(), [
      'inTransfer',
      'outTransfer',
    ]);

    for (final operation in operations) {
      expect(operation['units'], 2.0);
      expect(operation['price'], 100.0);
      expect(operation['amount'], 200.0);
    }
  });

  test('TR-2.1: eliminar una mitad del traspaso conserva la otra', () async {
    final date = DateTime(2026, 10, 3);

    FundData createFund(String isin) => FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo $isin',
      lastValue: 100,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 100)],
    );

    await DatabaseService.saveFund(createFund('SOURCE'));
    await DatabaseService.saveFund(createFund('DEST'));

    final provider = FundProvider();

    await provider.addOperation(
      FundOperation(
        isin: 'SOURCE',
        date: date,
        type: OperationType.outTransfer,
        units: 2,
        price: 100,
        amount: 200,
      ),
      op2: FundOperation(
        isin: 'DEST',
        date: date,
        type: OperationType.inTransfer,
        units: 2,
        price: 100,
        amount: 200,
      ),
    );

    final db = await DatabaseService.database;
    final before = await db.query('operations', orderBy: 'isin ASC');

    expect(before, hasLength(2));

    final sourceOperation = before.singleWhere((op) => op['isin'] == 'SOURCE');
    final destinationOperation = before.singleWhere(
      (op) => op['isin'] == 'DEST',
    );

    final sourceId = sourceOperation['id'] as int;
    final destinationId = destinationOperation['id'] as int;

    await provider.deleteOperation(sourceId);

    final after = await db.query('operations');

    expect(after, hasLength(1));
    expect(after.single['id'], destinationId);
    expect(after.single['isin'], 'DEST');
    expect(after.single['type'], 'inTransfer');
    expect(after.single['units'], 2.0);
    expect(after.single['price'], 100.0);
    expect(after.single['amount'], 200.0);
  });
}
