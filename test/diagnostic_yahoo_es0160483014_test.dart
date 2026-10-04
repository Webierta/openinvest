import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';

void main() {
  group('Diagnóstico Yahoo — ES0160483014', () {
    test('muestra exactamente qué devuelve getFundByIsin', () async {
      final result = await FundScraper.getFundByIsin('ES0160483014');

      debugPrint('================================================');
      debugPrint('DIAGNÓSTICO ES0160483014');
      debugPrint('================================================');
      debugPrint('data       : ${result.data}');
      debugPrint('error      : ${result.error}');
      debugPrint('error.type : ${result.error?.type}');
      debugPrint('message    : ${result.error?.message}');
      debugPrint('cause      : ${result.error?.cause}');
      debugPrint('stackTrace : ${result.error?.stackTrace}');
      debugPrint('isResolved : ${result.isResolved}');
      debugPrint('source     : ${result.source}');
      debugPrint('================================================');

      // No hacemos ninguna suposición sobre el resultado.
      expect(result, isNotNull);
    });
  });
}
