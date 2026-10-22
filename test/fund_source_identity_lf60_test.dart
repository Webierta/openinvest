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
      'fund_source_identity_lf60_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-60.1: guardar de nuevo un fondo actualiza ambas fuentes', () async {
    final firstDate = DateTime(2026, 10, 1);
    final secondDate = DateTime(2026, 10, 6);

    final initial = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo inicial',
      lastValue: 100,
      currency: 'EUR',
      date: firstDate,
      history: [PricePoint(firstDate, 100)],
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
      source: FundSource.ecb,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(updated);

    final recovered = await DatabaseService.getFund(isin);

    expect(recovered, isNotNull);
    expect(recovered!.source, FundSource.ecb);
    expect(recovered.valuationSource, FundSource.financialTimes);
    expect(recovered.lastValue, 112.15);
    expect(recovered.date, secondDate);
    expect(recovered.name, 'Fondo actualizado');
  });

  test(
    'LF-60.2: guardar de nuevo un fondo permite limpiar la fuente de identidad',
    () async {
      final date = DateTime(2026, 10, 6);

      final initial = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo con identidad CNMV',
        lastValue: 100,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 100)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(initial);

      final updated = FundData(
        isin: isin,
        symbol: isin,
        name: 'Fondo sin identidad confirmada',
        lastValue: 105,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 105)],
        source: null,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final recovered = await DatabaseService.getFund(isin);

      expect(recovered, isNotNull);
      expect(recovered!.source, isNull);
      expect(recovered.valuationSource, FundSource.financialTimes);
      expect(recovered.lastValue, 105);
      expect(recovered.name, 'Fondo sin identidad confirmada');
    },
  );
}
