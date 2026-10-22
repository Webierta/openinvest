import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'fund_source_persistence_lf_ui5_',
    );

    DatabaseService.useDatabasePathForTesting(
      path.join(tempDir.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  FundData fund({
    required String isin,
    FundSource? source,
    FundSource? valuationSource,
    double value = 100.0,
  }) {
    final date = DateTime(2026, 10, 20);

    return FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: value,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  group('LF-UI-5: Persistencia de las fuentes', () {
    test('LF-UI-5.1: conserva identidad CNMV y valoración Yahoo', () async {
      final original = fund(
        isin: 'ES0146722014',
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final recovered = await DatabaseService.getFund(original.isin);

      expect(recovered, isNotNull);
      expect(recovered!.source, FundSource.cnmv);
      expect(recovered.valuationSource, FundSource.yahoo);
    });

    test('LF-UI-5.2: conserva identidad null y valoración Yahoo', () async {
      final original = fund(
        isin: 'ES0146722014',
        source: null,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final recovered = await DatabaseService.getFund(original.isin);

      expect(recovered, isNotNull);
      expect(recovered!.source, isNull);
      expect(recovered.valuationSource, FundSource.yahoo);
    });

    test(
      'LF-UI-5.3: actualizar la valoración conserva la identidad CNMV',
      () async {
        final original = fund(
          isin: 'ES0146722014',
          source: FundSource.cnmv,
          valuationSource: FundSource.yahoo,
          value: 100.0,
        );

        await DatabaseService.saveFund(original);

        final updated = fund(
          isin: original.isin,
          source: FundSource.cnmv,
          valuationSource: FundSource.financialTimes,
          value: 120.0,
        );

        await DatabaseService.saveFund(updated);

        final recovered = await DatabaseService.getFund(original.isin);

        expect(recovered, isNotNull);
        expect(recovered!.source, FundSource.cnmv);
        expect(recovered.valuationSource, FundSource.financialTimes);
        expect(recovered.lastValue, 120.0);
      },
    );

    test('LF-UI-5.4: conserva ambas fuentes null', () async {
      final original = fund(
        isin: 'ES0146722014',
        source: null,
        valuationSource: null,
      );

      await DatabaseService.saveFund(original);

      final recovered = await DatabaseService.getFund(original.isin);

      expect(recovered, isNotNull);
      expect(recovered!.source, isNull);
      expect(recovered.valuationSource, isNull);
    });
  });
}
