import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';

void main() {
  group('LF-20.10.1 — modelo actual de procedencia', () {
    test(
      'FundSource contiene actualmente las cuatro categorías existentes',
      () {
        expect(
          FundSource.values,
          containsAll(<FundSource>[
            FundSource.cnmv,
            FundSource.local,
            FundSource.morningstar,
            FundSource.yahoo,
          ]),
        );

        expect(FundSource.values, hasLength(4));
      },
    );

    test('FundSearchMatch usa YAHOO como fuente por defecto', () {
      const match = FundSearchMatch(
        isin: 'ES0000000001',
        symbol: 'TEST',
        name: 'Test Fund',
      );

      expect(match.source, FundSource.yahoo);
    });

    test('resultado Yahoo normal se etiqueta como YAHOO', () {
      final matches = FundScraper.parseSearchPayload({
        'quotes': [
          {'symbol': 'TEST', 'isin': 'ES0000000001', 'longname': 'Test Fund'},
        ],
      });

      expect(matches, hasLength(1));
      expect(matches.single.source, FundSource.yahoo);
      expect(matches.single.isin, 'ES0000000001');
    });

    test(
      'resultado Yahoo con símbolo Morningstar 0P se etiqueta como MORNINGSTAR',
      () {
        final matches = FundScraper.parseSearchPayload({
          'quotes': [
            {
              'symbol': '0P00000FB4',
              'isin': 'FR0010135103',
              'longname': 'Morningstar Fund',
            },
          ],
        });

        expect(matches, hasLength(1));
        expect(matches.single.source, FundSource.morningstar);
      },
    );

    test('resultado Yahoo con símbolo terminado en .F se etiqueta como MORNINGSTAR', () {
      final matches = FundScraper.parseSearchPayload({
        'quotes': [
          {
            'symbol': 'TEST.F',
            'isin': 'ES0000000002',
            'longname': 'German Fund',
          },
        ],
      });

      expect(matches, hasLength(1));
      expect(matches.single.source, FundSource.morningstar);
    });

    test('un resultado sin ISIN conserva la fuente de búsqueda', () {
      final matches = FundScraper.parseSearchPayload({
        'quotes': [
          {'symbol': 'TEST', 'longname': 'Test Fund'},
        ],
      });

      expect(matches, hasLength(1));
      expect(matches.single.isin, isNull);
      expect(matches.single.source, FundSource.yahoo);
    });

    test('la búsqueda directa en el catálogo local produce LOCAL', () {
      final matches = FundScraper.searchCatalogMatches({
        'ing direct fondo naranja dinamico fi': 'ES0152743003',
      }, 'ING DIRECT DINAMICO');

      expect(matches, hasLength(1));
      expect(matches.single.source, FundSource.local);
      expect(matches.single.isin, 'ES0152743003');
    });

    test('FundSearchMatch conserva de forma independiente ISIN, símbolo, nombre y fuente', () {
      const match = FundSearchMatch(
        isin: 'ES0000000003',
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.local,
      );

      expect(match.isin, 'ES0000000003');
      expect(match.symbol, 'TEST');
      expect(match.name, 'Test Fund');
      expect(match.source, FundSource.local);
    });
  });
}
