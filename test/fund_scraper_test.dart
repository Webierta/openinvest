import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_search_mode.dart';

import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  test('encuentra el ISIN con términos separados del nombre', () {
    final isin = FundScraper.findCatalogIsin({
      'ing direct fondo naranja dinamico fi': 'ES0152743003',
    }, 'ING DIRECT DINAMICO');

    expect(isin, 'ES0152743003');
  });

  test('devuelve el fondo del catálogo aunque Yahoo no lo encuentre', () {
    final matches = FundScraper.searchCatalogMatches(
      {'ing direct fondo naranja dinamico fi': 'ES0152743003'},
      'ING DIRECT DINAMICO',
      mode: FundSearchMode.name,
    );

    expect(matches, hasLength(1));
    expect(matches.single.isin, 'ES0152743003');
  });

  test('agrupa ISINs de claves que se normalizan al mismo nombre', () {
    final matches = FundScraper.searchCatalogMatches(
      {'Global Equity': 'ES0000000001', 'GLOBAL EQUITY': 'ES0000000002'},
      'global equity',
      mode: FundSearchMode.name,
    );

    expect(matches.map((match) => match.isin).toList(), [
      'ES0000000001',
      'ES0000000002',
    ]);
    expect(matches.map((match) => match.name).toSet(), {'Global Equity'});
  });

  test('parsea resultados de búsqueda con nombre e ISIN', () {
    final matches = FundScraper.parseSearchPayload({
      'quotes': [
        {'symbol': 'FUND1', 'isin': 'ES0000000001', 'longname': 'Fondo Uno'},
        {'symbol': 'FUND2', 'shortname': 'Fondo Dos'},
        {'symbol': 'FUND1', 'longname': 'Duplicado'},
      ],
    });

    expect(matches, hasLength(2));
    expect(matches[0].name, 'Fondo Uno');
    expect(matches[0].isin, 'ES0000000001');
    expect(matches[1].name, 'Fondo Dos');
    expect(matches[1].isin, isNull);
  });

  const basePayload = {
    'chart': {
      'result': [
        {
          'meta': {
            'regularMarketPrice': 12.5,
            'currency': 'EUR',
            'regularMarketTime': 1788307200,
          },
          'timestamp': [1788220800, 1788307200],
          'indicators': {
            'quote': [
              {
                'close': [12.0, 12.5],
              },
            ],
          },
        },
      ],
    },
  };

  ScrapeResult parse(Map<String, dynamic> payload) =>
      FundScraper.parseChartPayload(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        payload: jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
      );

  test('rechaza historiales con longitudes diferentes', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': [1788220800],
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
    expect(result.error?.message, contains('incompleto'));
  });

  test('rechaza timestamps o precios con tipos inválidos', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': ['invalid', 1788307200],
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
    expect(result.error?.message, contains('inválidos'));
  });

  test('acepta un precio actual cuando no hay historial', () {
    final payload = {
      'chart': {
        'result': [
          {
            'meta': {'regularMarketPrice': 12.5, 'currency': 'EUR'},
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.error, isNull);
    expect(result.data?.lastValue, 12.5);
    expect(result.data?.history, isNotEmpty);
  });

  test(
    'usa el último cierre como valor vigente si la fecha del metadato difiere',
    () {
      final payload = {
        'chart': {
          'result': [
            {
              'meta': {
                'regularMarketPrice': 12.5,
                'currency': 'EUR',
                'regularMarketTime': 1788220800,
              },
              'timestamp': [1788307200],
              'indicators': {
                'quote': [
                  {
                    'close': [13.0],
                  },
                ],
              },
            },
          ],
        },
      };

      final result = parse(payload);

      expect(result.data?.lastValue, 13.0);
      expect(result.data?.date, DateTime(2026, 9, 2));
    },
  );

  test('ignora cierres nulos manteniendo el historial válido', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': [1788220800, 1788307200],
            'indicators': {
              'quote': [
                {
                  'close': [null, 12.5],
                },
              ],
            },
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.error, isNull);
    expect(result.data?.history, hasLength(1));
    expect(result.data?.history.single.price, 12.5);
  });

  test('rechaza una respuesta sin estructura chart', () {
    final result = parse({'unexpected': true});

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
  });

  test('la búsqueda por nombre usa los mismos tokens del catálogo', () {
    final catalog = {
      'ING DIRECT FONDO NARANJA DINAMICO FI': 'ES0152743003',
      'ING DIRECT PROFILO DINAMICO ARANCIO': 'ES0000000001',
      'ING DIRECT FONDO RENTA FIJA': 'ES0000000002',
    };

    final matches = FundScraper.searchCatalogMatches(
      catalog,
      'ING DINAMICO',
      mode: FundSearchMode.name,
    );

    expect(matches.map((match) => match.isin).toSet(), {
      'ES0152743003',
      'ES0000000001',
    });
  });

  test('la búsqueda por nombre exige todos los tokens de la consulta', () {
    final matches = FundScraper.searchCatalogMatches(
      {
        'AXONIC STRATEGIC FUND': 'ES0000000001',
        'GLOBAL INCOME FUND': 'ES0000000002',
        'AXONIC ALTERNATIVE': 'ES0000000003',
      },
      'AXONIC INCOME',
      mode: FundSearchMode.name,
    );

    expect(matches, isEmpty);
  });

  test('la búsqueda por ISIN sigue ignorando los nombres del catálogo', () {
    final matches = FundScraper.searchCatalogMatches(
      {
        'ES0160483014': 'ES0160483014',
        'MAPFRE PRIVATE EQUITY I FCR': 'ES0000000001',
        'OTRO FONDO': 'ES0160489999',
      },
      'ES016048',
      mode: FundSearchMode.isin,
    );

    expect(matches.map((match) => match.isin).toList(), [
      'ES0160483014',
      'ES0160489999',
    ]);
  });
}
