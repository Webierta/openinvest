import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void runYahooIdentityTests() {
  group('Yahoo identity', () {
    test('N1. Symbol con distinta capitalización: TEST y test', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "test", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('N2. Symbol con espacios: TEST y " TEST "', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": " TEST ", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('N3. Morningstar ID base y con sufijo .F', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    test('N4. Morningstar ID con sufijo .F y base: orden inverso', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M.F') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M.F',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    test(
      'N5. Símbolos de mercados diferentes no se fusionan: TEST.PA y TEST.MC',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.MC", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('N6. Symbol con distinta capitalización y mismo mercado: TEST.PA y TEST.pa', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST.PA') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST.PA", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST.pa", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'N7. Morningstar base y .F con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        // Si ambos symbols se normalizan al mismo identificador,
        // los dos ISIN entran en el mismo _YahooResult y hay conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N8. TEST y test con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "test", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        // Si TEST y test se consideran el mismo symbol,
        // los ISIN entran en conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N9. TEST.PA y TEST.pa con ISIN diferentes: detecta si se fusionan',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.pa", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        // Si sólo cambia la capitalización, una normalización
        // case-insensitive debería detectar el conflicto.
        expect(result, isNull);
      },
    );

    test(
      'N10. TEST.PA y TEST.MC con ISIN diferentes: no deben fusionarse',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.PA", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST.MC", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        // PA y MC representan mercados diferentes y no deben
        // considerarse el mismo symbol durante la fusión.
        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'N11. Morningstar ID base y .F con el mismo ISIN deben fusionarse',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'IE00B8K7V925');
        expect(result.source, 'Yahoo');
      },
    );

    test('N12. Morningstar ID base y .F con ISIN diferentes deben generar conflicto', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M.F", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "LU0261948904"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNull);
    });

    test(
      'N13. Morningstar ID .F y .SG deben considerarse la misma identidad',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M.F') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.F", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "IE00B8K7V925"}'
              ']}',
              200,
            );
          }

          if (query == 'PIMCO GIS Income Fund E Class USD Income') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "0P0000X83M.SG", '
              '"longname": "PIMCO GIS Income Fund E Class USD Income", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNull);
      },
    );

    test('N14. Morningstar IDs diferentes no deben fusionarse', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P0000X83M", '
            '"longname": "PIMCO GIS Income Fund E Class USD Income", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "IE00B8K7V925"}'
            ']}',
            200,
          );
        }

        if (query == 'PIMCO GIS Income Fund E Class USD Income') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "0P00000FB4", '
            '"longname": "Carmignac Court Terme", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0010135103"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(result.source, 'Yahoo');
    });

    // ===========================================================================
    // N15-N20 — NORMALIZACIÓN DE SYMBOL
    // ===========================================================================

    test('N15 - Morningstar ID con espacios y mayúsculas se fusiona', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': ' 0p0000x83m ',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P0000X83M.F',
                'longname': 'Test Fund',
                'exchange': 'FRA',
                'quoteType': 'MUTUALFUND',
                'isin': 'FR0010135103',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('N16 - dos suffixes Morningstar diferentes con ISIN distintos producen conflicto', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P0000X83M.SG',
                'longname': 'Test Fund',
                'exchange': 'SGX',
                'quoteType': 'MUTUALFUND',
                'isin': 'FR0010135103',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'N17 - symbol genérico con mayúsculas/minúsculas y espacios se fusiona',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': ' TEST ',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'IE00B8K7V925',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'N18 - suffix de mercado se normaliza solo por mayúsculas/minúsculas',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': ' TEST.PA ',
                    'longname': 'Test Fund',
                    'exchange': 'PAR',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'FR0010135103',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'test.pa',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'IE00B8K7V925',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.PA',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test('N19 - diferentes mercados no se fusionan', () async {
      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST.PA') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'TEST.PA',
                  'longname': 'Test Fund',
                  'exchange': 'PAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': 'TEST.MC',
                'longname': 'Test Fund',
                'exchange': 'MCE',
                'quoteType': 'MUTUALFUND',
                'isin': 'IE00B8K7V925',
              },
            ],
          }),
          200,
        );
      });

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
    });

    test(
      'N20 - Morningstar ID con sufijo no alfabético no se fusiona',
      () async {
        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.123',
                    'longname': 'Test Fund',
                    'exchange': 'FRA',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'IE00B8K7V925',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M',
                  'longname': 'Test Fund',
                  'exchange': 'FRA',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0010135103',
                },
              ],
            }),
            200,
          );
        });

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: const [],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0010135103');
      },
    );
  });
}
