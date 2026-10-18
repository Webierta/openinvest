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
      'fund_source_preservation_lf44_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<void> saveTestFund() async {
    final date = DateTime(2026, 10, 1);

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Test Fund',
        lastValue: 100,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 100)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      ),
    );
  }

  test('LF-44.1: updateMorningstarAttempt conserva ambas fuentes', () async {
    await saveTestFund();

    final attemptedAt = DateTime(2026, 10, 10, 11);

    await DatabaseService.updateMorningstarAttempt(isin, attemptedAt);

    final stored = await DatabaseService.getFund(isin);

    expect(stored, isNotNull);
    expect(stored!.source, FundSource.cnmv);
    expect(stored.valuationSource, FundSource.yahoo);
    expect(stored.morningstarLastAttemptAt, attemptedAt);
  });

  test('LF-44.2: updateMorningstarRating conserva ambas fuentes', () async {
    await saveTestFund();

    final checkedAt = DateTime(2026, 10, 10, 12);

    await DatabaseService.updateMorningstarRating(
      isin,
      rating: 4,
      checkedAt: checkedAt,
    );

    final stored = await DatabaseService.getFund(isin);

    expect(stored, isNotNull);
    expect(stored!.source, FundSource.cnmv);
    expect(stored.valuationSource, FundSource.yahoo);
    expect(stored.morningstarRating, 4);
    expect(stored.morningstarCheckedAt, checkedAt);
  });

  test('LF-44.3: clearAllData conserva ambas fuentes', () async {
    await saveTestFund();

    await DatabaseService.clearAllData(isin);

    final stored = await DatabaseService.getFund(isin);

    expect(stored, isNotNull);
    expect(stored!.source, FundSource.cnmv);
    expect(stored.valuationSource, FundSource.yahoo);
    expect(stored.lastValue, 0);
    expect(stored.history, isEmpty);
  });
}
