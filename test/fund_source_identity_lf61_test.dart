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

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_identity_lf61_',
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
    'LF-61.1: actualizar fuentes y valoración conserva historial y operaciones',
    () async {
      final firstDate = DateTime(2026, 10, 1);
      final secondDate = DateTime(2026, 10, 6);

      final operation = FundOperation(
        isin: isin,
        type: OperationType.buy,
        date: firstDate,
        units: 2,
        price: 50,
        amount: 100,
      );

      final initial = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo inicial',
        lastValue: 100,
        currency: 'EUR',
        date: firstDate,
        history: [PricePoint(firstDate, 100)],
        operations: [operation],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(initial);

      final updated = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo actualizado',
        lastValue: 112.15,
        currency: 'EUR',
        date: secondDate,
        history: [PricePoint(firstDate, 100), PricePoint(secondDate, 112.15)],
        operations: [operation],
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final recovered = await DatabaseService.getFund(isin);

      expect(recovered, isNotNull);
      expect(recovered!.source, FundSource.ecb);
      expect(recovered.valuationSource, FundSource.financialTimes);
      expect(recovered.lastValue, 112.15);

      expect(recovered.history, hasLength(2));
      expect(
        recovered.history.map((point) => point.date),
        containsAll([firstDate, secondDate]),
      );
      expect(
        recovered.history.map((point) => point.price),
        containsAll([100.0, 112.15]),
      );

      expect(recovered.operations, hasLength(1));
      expect(recovered.operations.single.isin, isin);
      expect(recovered.operations.single.units, 2);
      expect(recovered.operations.single.price, 50);
      expect(recovered.operations.single.amount, 100);
    },
  );
}
