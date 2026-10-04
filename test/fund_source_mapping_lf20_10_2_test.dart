import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';

//import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-20.10.2 — mapeo IsinSource → FundSource', () {
    test('CNMV/SIL → CNMV', () {
      expect(fundSourceFromIsinSource('CNMV/SIL'), FundSource.cnmv);
    });
    test('CNMV/FI → CNMV', () {
      expect(fundSourceFromIsinSource('CNMV/FI'), FundSource.cnmv);
    });
    test('fondos.json → LOCAL', () {
      expect(fundSourceFromIsinSource('fondos.json'), FundSource.local);
    });
    test('ECB/IFS → ECB', () {
      expect(fundSourceFromIsinSource('ECB/IFS'), FundSource.ecb);
    });
    test('Yahoo y Yahoo/... → YAHOO', () {
      expect(fundSourceFromIsinSource('Yahoo'), FundSource.yahoo);
      expect(fundSourceFromIsinSource('Yahoo/Search'), FundSource.yahoo);
    });
    test('Morningstar y Morningstar/... → MORNINGSTAR', () {
      expect(fundSourceFromIsinSource('Morningstar'), FundSource.morningstar);
      expect(
        fundSourceFromIsinSource('Morningstar/LT'),
        FundSource.morningstar,
      );
    });
    test('fondos_armonizados.json → LOCAL', () {
      expect(
        fundSourceFromIsinSource('fondos_armonizados.json'),
        FundSource.local,
      );
    });
    test('fuente desconocida → ArgumentError', () {
      expect(
        () => fundSourceFromIsinSource('Fuente/Desconocida'),
        throwsArgumentError,
      );
    });
  });
}
