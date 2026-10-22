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
      'fund_source_identity_lf59_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-59.1: SQLite conserva por separado la identidad y la fuente de valoración', () async {
    final date = DateTime(2026, 10, 6);

    final fund = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo de prueba',
      lastValue: 112.15,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 112.15)],
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(fund);

    final recovered = await DatabaseService.getFund(isin);

    expect(recovered, isNotNull);
    expect(recovered!.source, FundSource.cnmv);
    expect(recovered.valuationSource, FundSource.financialTimes);
    expect(recovered.lastValue, 112.15);
    expect(recovered.date, date);
  });

  test('LF-59.2: SQLite conserva una fuente de identidad nula y una valoración informada', () async {
    final date = DateTime(2026, 10, 6);

    final fund = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo sin identidad confirmada',
      lastValue: 112.15,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 112.15)],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(fund);

    final recovered = await DatabaseService.getFund(isin);

    expect(recovered, isNotNull);
    expect(recovered!.source, isNull);
    expect(recovered.valuationSource, FundSource.yahoo);
  });
}
