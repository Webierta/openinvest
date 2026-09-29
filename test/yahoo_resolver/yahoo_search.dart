import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

import 'yahoo_test_support.dart';

void runYahooSearchTests() {
  group('Yahoo search', () {
    test('T1 - _searchYahoo ejecuta ticker y nombre', () async {
      final client = FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': const [],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T1] ticker=1, nombre=1 -> OK');
    });

    test('T8 - PIMCO ejecuta ticker y nombre y resuelve ISIN', () async {
      final client = FakeYahooClient({
        '0P0000X83M': [
          const Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund E Class USD Income',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund E Class USD Income': [
          const Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund E Class USD Income',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final foreign = FakeForeignProvider(
        bySymbol: {
          '0P0000X83M': 'IE00B8K7V925',
          '0P0000X83M.F': 'IE00B8K7V925',
        },
      );

      final provider = createYahooProvider(client: client, foreign: [foreign]);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expectIsin(result, 'IE00B8K7V925', 'T8');

      expect(result?.source, 'Yahoo/Foreign');

      expect(client.queryCount['0P0000X83M'], 1);
      expect(client.queryCount['PIMCO GIS Income Fund E Class USD Income'], 1);

      expect(client.queryCount.length, 2);

      expect(foreign.calls, isNotEmpty);

      debugPrint('[T8] PIMCO ticker + nombre + Morningstar -> OK');
    });

    test('T9 - ticker sin resultados y nombre con resultado', () async {
      final client = FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T9');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T9] ticker vacío + nombre válido -> OK');
    });

    test('T10 - ticker con resultado y nombre sin resultados', () async {
      final client = FakeYahooClient({
        'XYZ.PA': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T10');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T10] ticker válido + nombre vacío -> OK');
    });

    test('T11 - ticker y nombre devuelven mismo fondo y se fusionan', () async {
      final client = FakeYahooClient({
        'XYZ.PA': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T11');

      expect(result?.source, 'Yahoo');

      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T11] mismo symbol + datos complementarios -> fusión OK');
    });

    test('T12 - error en ticker no impide consultar el nombre', () async {
      final client = FailFirstYahooClient(
        failingQuery: 'XYZ.PA',
        responses: {
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
      );

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T12');

      expect(result?.source, 'Yahoo');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      expect(client.queryCount.length, 2);

      debugPrint('[T12] error ticker + continuación con nombre -> OK');
    });

    test('T13 - quote con symbol vacío se ignora', () async {
      final client = FakeYahooClient({
        'Alpha Growth Fund': [
          const Quote(
            symbol: '',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'XYZ.PA': const [],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T13');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T13] symbol vacío ignorado -> OK');
    });

    test('T14 - elementos de quotes que no son Map se ignoran', () async {
      final client = RawYahooClient({
        'XYZ.PA': {
          'quotes': [
            'basura',
            123,
            null,
            {
              'symbol': 'XYZ.PA',
              'longname': 'Alpha Growth Fund',
              'quoteType': 'MUTUALFUND',
              'isin': 'FR0000000010',
            },
          ],
        },
        'Alpha Growth Fund': {'quotes': []},
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T14');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T14] elementos no Map ignorados -> OK');
    });

    test(
      'T15 - ISIN válido con quoteType ETF no se acepta como ISIN Yahoo',
      () async {
        final client = FakeYahooClient({
          'XYZ.PA': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'ETF',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': const [],
        });

        final provider = createYahooProvider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expect(result, isNull);

        expect(client.queryCount['XYZ.PA'], 1);
        expect(client.queryCount['Alpha Growth Fund'], 1);

        debugPrint('[T15] ISIN de ETF ignorado -> OK');
      },
    );

    test('T16 - ISIN inválido se descarta', () async {
      final client = FakeYahooClient({
        'XYZ.PA': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'NO-ES-UN-ISIN',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T16] ISIN inválido descartado -> OK');
    });

    test('T17 - si falta longname se utiliza shortname', () async {
      final client = RawYahooClient({
        'XYZ.PA': {'quotes': []},
        'Alpha Growth Fund': {
          'quotes': [
            {
              'symbol': 'XYZ.PA',
              'shortname': 'Alpha Growth Fund',
              'quoteType': 'MUTUALFUND',
              'isin': 'FR0000000010',
            },
          ],
        },
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expectIsin(result, 'FR0000000010', 'T17');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Alpha Growth Fund');

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T17] fallback longname -> shortname -> OK');
    });

    test('T18 - quoteType ausente impide aceptar el ISIN', () async {
      final client = FakeYahooClient({
        'XYZ.PA': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: '',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint('[T18] quoteType ausente/vacío -> ISIN ignorado -> OK');
    });

    test(
      'T20 - error HTTP en ticker no impide resolver mediante nombre',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'XYZ.PA') {
            return http.Response('', 500);
          }

          if (query == 'Alpha Growth Fund') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'XYZ.PA',
                    'longname': 'Alpha Growth Fund',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'FR0000000010',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expectIsin(result, 'FR0000000010', 'T20');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Alpha Growth Fund');

        debugPrint('[T20] HTTP 500 en ticker + continuación con nombre -> OK');
      },
    );

    // ===========================================================================
    // S1-S10 — SELECCIÓN DEL SÍMBOLO REPRESENTATIVO DESPUÉS DE LA FUSIÓN
    // ===========================================================================

    test('S1 - Morningstar: si incoming es el ticker exacto, reemplaza la variante', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M');
    });

    test(
      'S2 - Morningstar: si existing ya es el ticker exacto, se conserva',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': '0P0000X83M.F',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, '0P0000X83M');
      },
    );

    test('S3 - Morningstar: ticker exacto después de dos variantes', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M');
    });

    test('S4 - Morningstar: la comparación del ticker ignora mayúsculas/minúsculas', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'TEST',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'TEST');
    });

    test('S5 - Morningstar: si ninguna variante coincide exactamente, se conserva existing', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M.SG');
    });

    test('S6 - Morningstar: entre variantes no exactas no se introduce una preferencia de mercado', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': '0P0000X83M.SG',
                  'longname': 'Test Fund',
                  'exchange': 'SGX',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: '0P0000X83M', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, '0P0000X83M.F');
    });

    test('S7 - Mercado: ticker exacto TEST.PA gana frente a TEST.MC', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST.PA') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'TEST.MC',
                  'longname': 'Test Fund',
                  'exchange': 'MCE',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'TEST.PA',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'TEST.PA');
    });

    test(
      'S8 - Mercado: TEST.PA gana aunque TEST.MC aparezca primero',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST.PA') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'TEST.MC',
                    'longname': 'Test Fund',
                    'exchange': 'MCE',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': 'TEST.PA',
                    'longname': 'Test Fund',
                    'exchange': 'PAR',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, 'TEST.PA');
      },
    );

    test(
      'S9 - Sin coincidencia exacta: se conserva el primer símbolo recibido',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'ABC',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                  {
                    'symbol': 'XYZ',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [trackingProvider],
        );

        await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, isNotEmpty);
        expect(seenSymbols.first, 'ABC');
      },
    );

    test('S10 - Sin coincidencia exacta: el orden determina el representante de forma estable', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'XYZ',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'ABC',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [trackingProvider],
      );

      await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, isNotEmpty);
      expect(seenSymbols.first, 'XYZ');
    });

    test('S11. Incoming coincide con ticker ignorando mayúsculas', () async {
      final client = FakeYahooClient({
        'TEST.PA': [
          const Quote(
            symbol: 'test.pa',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST.PA',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST.PA']);

      debugPrint(
        '[S11] incoming coincide con ticker ignorando mayúsculas -> OK',
      );
    });

    test('S12. Existing coincide con ticker ignorando mayúsculas', () async {
      final client = FakeYahooClient({
        'TEST.PA': [
          const Quote(
            symbol: 'TEST.PA',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'test.pa',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST.PA']);

      debugPrint(
        '[S12] existing coincide con ticker ignorando mayúsculas -> OK',
      );
    });
  });
}
