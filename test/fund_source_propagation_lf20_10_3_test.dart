import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-20.10.3 — propagación de procedencia de resolución', () {
    test('YAHOO + ECB/IFS → ECB', () {
      const match = FundSearchMatch(
        isin: null,
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.yahoo,
      );

      const resolution = IsinResult(
        isin: 'ES0000000001',
        source: 'ECB/IFS',
        officialName: 'Test Fund',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.isin, 'ES0000000001');
      expect(effective.symbol, 'TEST');
      expect(effective.name, 'Test Fund');
      expect(effective.source, FundSource.ecb);
    });

    test('YAHOO + fondos.json → LOCAL', () {
      const match = FundSearchMatch(
        isin: null,
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.yahoo,
      );

      const resolution = IsinResult(
        isin: 'ES0000000002',
        source: 'fondos.json',
        officialName: 'Test Fund',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.isin, 'ES0000000002');
      expect(effective.source, FundSource.local);
    });

    test('YAHOO + Morningstar → MORNINGSTAR', () {
      const match = FundSearchMatch(
        isin: null,
        symbol: '0P000TEST',
        name: 'Test Fund',
        source: FundSource.yahoo,
      );

      const resolution = IsinResult(
        isin: 'IE0000000003',
        source: 'Morningstar/LT',
        officialName: 'Test Fund',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.isin, 'IE0000000003');
      expect(effective.source, FundSource.morningstar);
    });

    test('LOCAL + ECB/IFS → ECB', () {
      const match = FundSearchMatch(
        isin: 'ES0000000004',
        symbol: '',
        name: 'Test Fund',
        source: FundSource.local,
      );

      const resolution = IsinResult(
        isin: 'ES0000000004',
        source: 'ECB/IFS',
        officialName: 'Test Fund',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.isin, 'ES0000000004');
      expect(effective.source, FundSource.ecb);
    });

    test('CNMV + fondos.json → LOCAL', () {
      const match = FundSearchMatch(
        isin: 'ES0000000005',
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.cnmv,
      );

      const resolution = IsinResult(
        isin: 'ES0000000005',
        source: 'fondos.json',
        officialName: 'Test Fund',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.isin, 'ES0000000005');
      expect(effective.source, FundSource.local);
    });

    test('la resolución conserva símbolo y nombre originales', () {
      const match = FundSearchMatch(
        isin: null,
        symbol: 'ABC.F',
        name: 'Original Fund Name',
        source: FundSource.yahoo,
      );

      const resolution = IsinResult(
        isin: 'LU0000000006',
        source: 'ECB/IFS',
        officialName: 'Official Fund Name',
      );

      final effective = withResolvedSource(match, resolution);

      expect(effective.symbol, 'ABC.F');
      expect(effective.name, 'Original Fund Name');
      expect(effective.isin, 'LU0000000006');
      expect(effective.source, FundSource.ecb);
    });
  });
}
