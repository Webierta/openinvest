import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';

void main() {
  group('Diagnóstico Yahoo — ES0160483014', () {
    test('muestra exactamente qué devuelve getFundByIsin', () async {
      final result = await FundScraper.getFundByIsin('ES0160483014');

      print('================================================');
      print('DIAGNÓSTICO ES0160483014');
      print('================================================');
      print('data       : ${result.data}');
      print('error      : ${result.error}');
      print('error.type : ${result.error?.type}');
      print('message    : ${result.error?.message}');
      print('cause      : ${result.error?.cause}');
      print('stackTrace : ${result.error?.stackTrace}');
      print('isResolved : ${result.isResolved}');
      print('source     : ${result.source}');
      print('================================================');

      // No hacemos ninguna suposición sobre el resultado.
      expect(result, isNotNull);
    });
  });
}
