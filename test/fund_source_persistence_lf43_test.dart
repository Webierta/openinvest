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

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_persistence_lf43_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundData fund({
    required String isin,
    FundSource? source,
    FundSource? valuationSource,
    double value = 100,
  }) {
    final date = DateTime(2026, 10, 1);

    return FundData(
      isin: isin,
      symbol: isin,
      name: 'Test Fund $isin',
      lastValue: value,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  test(
    'LF-43.1: saveFund y getFund conservan ambas fuentes independientes',
    () async {
      final original = fund(
        isin: 'LF43SAVE',
        source: FundSource.cnmv,
        valuationSource: FundSource.queFondos,
      );

      await DatabaseService.saveFund(original);

      final stored = await DatabaseService.getFund(original.isin);

      expect(stored, isNotNull);
      expect(stored!.source, FundSource.cnmv);
      expect(stored.valuationSource, FundSource.queFondos);
    },
  );

  test('LF-43.2: replaceFund actualiza y conserva ambas fuentes', () async {
    const isin = 'LF43REPLACE';

    await DatabaseService.saveFund(
      fund(
        isin: isin,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      ),
    );

    await DatabaseService.replaceFund(
      fund(
        isin: isin,
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
        value: 120,
      ),
    );

    final stored = await DatabaseService.getFund(isin);

    expect(stored, isNotNull);
    expect(stored!.source, FundSource.ecb);
    expect(stored.valuationSource, FundSource.financialTimes);
    expect(stored.lastValue, 120);
  });

  test('LF-43.3: getPortfolio conserva las fuentes de cada fondo', () async {
    await DatabaseService.saveFund(
      fund(
        isin: 'LF43PORT1',
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      ),
    );

    await DatabaseService.saveFund(
      fund(
        isin: 'LF43PORT2',
        source: FundSource.ecb,
        valuationSource: FundSource.queFondos,
      ),
    );

    final portfolio = await DatabaseService.getPortfolio();
    final first = portfolio.singleWhere((item) => item.isin == 'LF43PORT1');
    final second = portfolio.singleWhere((item) => item.isin == 'LF43PORT2');

    expect(first.source, FundSource.cnmv);
    expect(first.valuationSource, FundSource.yahoo);
    expect(second.source, FundSource.ecb);
    expect(second.valuationSource, FundSource.queFondos);
  });

  test('LF-43.4: getFund y getPortfolio conservan las fuentes nulas', () async {
    const isin = 'LF43NULL';

    await DatabaseService.saveFund(fund(isin: isin));

    final stored = await DatabaseService.getFund(isin);
    final portfolio = await DatabaseService.getPortfolio();
    final fromPortfolio = portfolio.singleWhere((item) => item.isin == isin);

    expect(stored, isNotNull);
    expect(stored!.source, isNull);
    expect(stored.valuationSource, isNull);
    expect(fromPortfolio.source, isNull);
    expect(fromPortfolio.valuationSource, isNull);
  });
}
