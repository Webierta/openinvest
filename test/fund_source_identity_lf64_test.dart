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
      'fund_source_identity_lf64_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-64.1: una secuencia de actualizaciones conserva identidad y estado final', () async {
    final date1 = DateTime(2026, 10, 1);
    final date2 = DateTime(2026, 10, 3);
    final date3 = DateTime(2026, 10, 6);

    final initial = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo registrado en CNMV',
      lastValue: 100,
      currency: 'EUR',
      date: date1,
      history: [PricePoint(date1, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(initial);

    final fromFT = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo actualizado por FT',
      lastValue: 105,
      currency: 'EUR',
      date: date2,
      history: [PricePoint(date1, 100), PricePoint(date2, 105)],
      source: null,
      valuationSource: FundSource.financialTimes,
    );

    await DatabaseService.saveFund(fromFT);

    final fromYahoo = FundData(
      isin: isin,
      symbol: isin,
      name: 'Fondo actualizado por Yahoo',
      lastValue: 110,
      currency: 'EUR',
      date: date3,
      history: [
        PricePoint(date1, 100),
        PricePoint(date2, 105),
        PricePoint(date3, 110),
      ],
      source: null,
      valuationSource: FundSource.yahoo,
    );

    await DatabaseService.saveFund(fromYahoo);

    final recovered = await DatabaseService.getFund(isin);

    expect(recovered, isNotNull);
    expect(recovered!.source, isNull);
    expect(recovered.valuationSource, FundSource.yahoo);
    expect(recovered.lastValue, 110);
    expect(recovered.date, date3);
    expect(recovered.name, 'Fondo actualizado por Yahoo');
    expect(recovered.history, hasLength(3));
    expect(
      recovered.history.map((point) => point.date),
      containsAll([date1, date2, date3]),
    );
    expect(
      recovered.history.map((point) => point.price),
      containsAll([100.0, 105.0, 110.0]),
    );
  });
}
