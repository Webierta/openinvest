import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:investing/services/isin_resolver.dart';

import 'yahoo_test_support.dart';

void runYahooRankingTests() {
  group('Yahoo ranking', () {
    test(
      'R1. Identidad fuerte: ticker exacto permite similitud de nombre >= 0.20',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Alpha Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Completely Different': const <Quote>[],
        });

        final seenSymbols = <String>[];

        final provider = createYahooProvider(
          client: client,
          foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Fund');

        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[R1] ticker exacto + identidad fuerte + similitud suficiente -> OK',
        );
      },
    );

    test(
      'R2. Identidad fuerte: similitud de nombre cero descarta el candidato',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Completely Different',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Unrelated Fund': const <Quote>[],
        });
        final seenSymbols = <String>[];
        final provider = createYahooProvider(
          client: client,
          foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
        );
        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Unrelated Fund',
        );
        expect(result, isNull);
        expect(seenSymbols, isEmpty);
        debugPrint(
          '[R2] ticker exacto pero nombre sin similitud -> descartado -> OK',
        );
      },
    );

    test('R3. Sin identidad fuerte: similitud inferior a 0.50 descarta el candidato', () async {
      final client = FakeYahooClient({
        'OTHER': [
          const Quote(
            symbol: 'OTHER',
            longname: 'Alpha Beta Gamma',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      expect(seenSymbols, isEmpty);

      debugPrint(
        '[R3] sin identidad fuerte + similitud < 0.50 -> descartado -> OK',
      );
    });

    test('R4. Sin identidad fuerte: similitud >= 0.50 permite competir', () async {
      final client = FakeYahooClient({
        'TEST': const <Quote>[],
        'Alpha Growth Fund': [
          const Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });
      final seenSymbols = <String>[];
      final seenNames = <String>[];
      final provider = YahooProvider(
        client: client,
        foreignIsinProviders: [
          TrackingForeignProvider(
            seenSymbols: seenSymbols,
            seenNames: seenNames,
          ),
        ],
      );
      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund',
      );
      expect(result, isNull);
      expect(seenSymbols, ['OTHER']);
      expect(seenNames, ['Alpha Growth']);
      debugPrint(
        '[R4] candidato sin identidad fuerte pero con similitud >= 0.50 -> OK',
      );
    });

    test('R5. Ticker exacto supera a candidato no exacto con nombre ligeramente mejor', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund International',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'TEST');

      debugPrint('[R5] ticker exacto obtiene prioridad en el ranking -> OK');
    });

    /* test('R6. Un nombre perfecto puede superar a un ticker exacto con similitud menor', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Alpha Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const <Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = provider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'OTHER');

      debugPrint(
        '[R6] nombre perfecto puede superar ticker exacto con similitud baja -> OK',
      );
    }); */

    /* test('R7. ISIN aporta peso adicional al ranking', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
          const Quote(
            symbol: 'OTHER',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
        'Alpha Growth Fund': const <Quote>[],
      });

      final seenSymbols = <String>[];

      final provider = provider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenSymbols.first, 'OTHER');

      debugPrint('[R7] ISIN válido añade peso al ranking -> OK');
    }); */

    test('R8 - identidad fuerte con similitud de nombre por debajo del mínimo se rechaza', () async {
      final seenSymbols = <String>[];

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {'symbol': 'TEST', 'longname': 'Alpha', 'quoteType': 'OTHER'},
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund Class A',
      );

      expect(result, isNull);
      expect(seenSymbols, isEmpty);

      debugPrint('[R8] identidad fuerte + similitud insuficiente -> OK');
    });

    test('R9 - identidad fuerte con similitud exactamente 0.20 supera la barrera de identidad', () async {
      final seenSymbols = <String>[];
      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {'symbol': 'TEST', 'longname': 'Alpha', 'quoteType': 'OTHER'},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'quotes': []}), 200);
      });
      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);
      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );
      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth Fund Class A',
      );
      // Alpha / {Alpha, Growth, Fund, Class, A} = 1/5 = 0.20.
      // La identidad fuerte permite superar la barrera de identidad,
      // pero el score final sigue siendo inferior a 0.50:
      // 0.20 * 0.55 + 0.20 + 0.05 = 0.36
      // Por tanto, el candidato no llega al proveedor extranjero.
      expect(result, isNull);
      expect(seenSymbols, isEmpty);
      debugPrint(
        '[R9] identidad fuerte + similitud = 0.20 -> '
        'supera barrera, pero no score final -> OK',
      );
    });

    test(
      'R10 - sin identidad fuerte y similitud inferior a 0.50 se rechaza',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'OTHER',
                    'longname': 'Alpha Something Else',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Alpha Growth Fund',
        );

        expect(result, isNull);
        expect(seenSymbols, isEmpty);

        debugPrint('[R10] sin identidad fuerte + similitud < 0.50 -> OK');
      },
    );

    test('R11 - sin identidad fuerte y similitud exactamente 0.50 permite competir', () async {
      final seenSymbols = <String>[];
      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'TEST') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'OTHER',
                  'longname': 'Alpha',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'quotes': []}), 200);
      });
      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);
      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );
      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Alpha Growth',
      );
      // Alpha / {Alpha, Growth} = 1/2 = 0.50.
      // No existe identidad fuerte, pero 0.50 supera la barrera.
      // Score: // 0.50 * 0.55 + 0.30 (MUTUALFUND) = 0.575
      // Por tanto, el candidato supera también el score final.
      expect(result, isNull);
      expect(seenSymbols, ['OTHER']);
      debugPrint(
        '[R11] sin identidad fuerte + similitud = 0.50 -> '
        'score = 0.575 -> candidato admitido -> OK',
      );
    });

    test(
      'R12 - identidad fuerte con score inferior a 0.50 se rechaza',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'TEST',
                    'longname': 'Alpha Beta',
                    'quoteType': 'OTHER',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Alpha Beta Gamma Delta Epsilon',
        );

        // Tokens del nombre del fondo:
        // {ALPHA, BETA, GAMMA, DELTA, EPSILON}
        //
        // Tokens del resultado:
        // {ALPHA, BETA}
        //
        // Similitud Jaccard = 2 / 5 = 0.40.
        //
        // Existe identidad fuerte porque symbol == ticker.
        //
        // Score:
        // 0.40 * 0.55 + 0.20 + 0.05 = 0.47
        //
        // No alcanza el umbral final de 0.50.

        expect(result, isNull);
        expect(seenSymbols, isEmpty);

        debugPrint(
          '[R12] identidad fuerte + similitud = 0.40 -> '
          'score = 0.47 -> rechazado -> OK',
        );
      },
    );

    test(
      'R13 - identidad fuerte con score superior a 0.50 se admite',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {'symbol': 'TEST', 'longname': 'Alpha', 'quoteType': 'OTHER'},
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Alpha Growth',
        );

        // Tokens del nombre del fondo:
        // {ALPHA, GROWTH}
        //
        // Tokens del resultado:
        // {ALPHA}
        //
        // Similitud Jaccard = 1 / 2 = 0.50.
        //
        // Existe identidad fuerte porque symbol == ticker.
        //
        // Score:
        // 0.50 * 0.55 + 0.20 + 0.05 = 0.525
        //
        // Supera el umbral final de 0.50.

        expect(result, isNull);
        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[R13] identidad fuerte + similitud = 0.50 -> '
          'score = 0.525 -> admitido -> OK',
        );
      },
    );

    test(
      'R14 - MUTUALFUND sin identidad fuerte con similitud = 0.50 se admite',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'OTHER',
                    'longname': 'Alpha',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Alpha Growth',
        );

        // Similitud Jaccard = 1 / 2 = 0.50.
        //
        // No existe identidad fuerte:
        // symbol != ticker
        // y no hay coincidencia de Morningstar ID.
        //
        // Al ser MUTUALFUND:
        //
        // 0.50 * 0.55 + 0.30 = 0.575
        //
        // Supera el umbral final de 0.50.

        expect(result, isNull);
        expect(seenSymbols, ['OTHER']);

        debugPrint(
          '[R14] sin identidad fuerte + MUTUALFUND + similitud = 0.50 -> '
          'score = 0.575 -> admitido -> OK',
        );
      },
    );

    test(
      'R15 - mismo Morningstar ID con sufijos distintos se reconoce',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == '0P0000X83M.F') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.SG',
                    'longname': 'Alpha Growth Fund',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'Alpha Growth Fund',
        );

        // Ticker:
        //   0P0000X83M.F
        //
        // Yahoo:
        //   0P0000X83M.SG
        //
        // Ambos representan el mismo Morningstar ID:
        //   0P0000X83M
        //
        // nameSimilarity = 1.00
        //
        // Score:
        //   1.00 * 0.55 = 0.55
        //   + 0.30 MUTUALFUND
        //   + 0.10 sameMorningstar
        //   = 0.95
        //
        // Debe llegar al proveedor extranjero.

        expect(result, isNull);
        expect(seenSymbols, ['0P0000X83M.SG']);

        debugPrint(
          '[R15] mismo Morningstar ID con sufijos distintos -> '
          'sameMorningstar = true -> OK',
        );
      },
    );

    test(
      'R16 - sameMorningstar permite competir con similitud exactamente 0.20',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == '0P0000X83M.F') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': '0P0000X83M.SG',
                    'longname': 'Alpha',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'Alpha Growth Fund Class A',
        );

        // Tokens del fondo:
        //   {ALPHA, GROWTH, FUND, CLASS, A}
        //
        // Tokens de Yahoo:
        //   {ALPHA}
        //
        // Similitud Jaccard:
        //   1 / 5 = 0.20
        //
        // No hay coincidencia textual exacta de ticker,
        // pero sí sameMorningstar.
        //
        // Score:
        //   0.20 * 0.55 = 0.11
        //   + 0.30 MUTUALFUND
        //   + 0.10 sameMorningstar
        //   = 0.51
        //
        // Supera el umbral final de 0.50.

        expect(result, isNull);
        expect(seenSymbols, ['0P0000X83M.SG']);

        debugPrint(
          '[R16] sameMorningstar + similitud = 0.20 -> '
          'score = 0.51 -> admitido -> OK',
        );
      },
    );

    test('R17 - Morningstar IDs diferentes no reciben bonificación sameMorningstar', () async {
      final seenSymbols = <String>[];

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M.F') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000ABC12.SG',
                  'longname': 'Alpha Growth Fund',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M.F',
        fundName: 'Alpha Growth Fund',
      );

      // Ambos símbolos tienen formato Morningstar,
      // pero representan IDs diferentes:
      //
      // ticker: 0P0000X83M
      // Yahoo : 0P0000ABC12
      //
      // Por tanto:
      //   sameMorningstar = false
      //
      // nameSimilarity = 1.00
      //
      // Score:
      //   1.00 * 0.55 = 0.55
      //   + 0.30 MUTUALFUND
      //   = 0.85
      //
      // Se admite por nombre + MUTUALFUND, pero sin
      // la bonificación de sameMorningstar.

      expect(result, isNull);
      expect(seenSymbols, ['0P0000ABC12.SG']);

      debugPrint(
        '[R17] Morningstar IDs diferentes -> '
        'sameMorningstar = false -> sin +0.10 -> OK',
      );
    });

    test(
      'R18 - ticker vacío no debe otorgar bonificación startsWith',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'ABC',
                  'longname':
                      'Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota',
                  'quoteType': 'OTHER',
                },
              ],
            }),
            200,
          );
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: '',
          fundName: 'Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa',
        );

        // Similitud Jaccard:
        //
        // Yahoo:
        //   {ALPHA, BETA, GAMMA, DELTA, EPSILON,
        //    ZETA, ETA, THETA, IOTA}
        //
        // Fondo:
        //   {ALPHA, BETA, GAMMA, DELTA, EPSILON,
        //    ZETA, ETA, THETA, IOTA, KAPPA}
        //
        // Intersección = 9
        // Unión = 10
        // similarity = 0.90
        //
        // Sin startsWith:
        //   0.90 * 0.55 = 0.495
        //   -> rechazado
        //
        // Con la implementación actual:
        //   normalizedTicker = ''
        //   'ABC'.startsWith('') == true
        //
        // Por tanto:
        //   0.495 + 0.05 = 0.545
        //   -> admitido
        //
        // El proveedor extranjero debe recibir el candidato.

        expect(result, isNull);
        expect(seenSymbols, ['ABC']);

        debugPrint(
          '[R18] ticker vacío -> startsWith("") aporta +0.05 -> '
          'score = 0.545 -> candidato admitido -> OK',
        );
      },
    );

    test(
      'R19 - ticker en minúsculas se compara de forma insensible a mayúsculas',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'ABC.PA',
                  'longname': 'Alpha Growth Fund',
                  'quoteType': 'OTHER',
                },
              ],
            }),
            200,
          );
        });

        final tracking = TrackingForeignProvider(seenSymbols: <String>[]);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'abc.pa',
          fundName: 'Alpha Growth Fund',
        );

        // El ranking normaliza el ticker:
        //   normalizedTicker = ABC.PA
        //
        // y compara:
        //   symbol == normalizedTicker
        //
        // por tanto:
        //   ABC.PA == ABC.PA -> exactTicker = true
        //
        // El candidato debe superar el ranking aunque la entrada
        // original del ticker estuviera en minúsculas.

        expect(result, isNull);

        debugPrint(
          '[R19] ticker en minúsculas -> comparación normalizada -> OK',
        );
      },
    );

    test(
      'R20 - ticker Morningstar exacto activa exactTicker y sameMorningstar',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Alpha Growth Fund',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        });

        final tracking = TrackingForeignProvider(seenSymbols: <String>[]);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'Alpha Growth Fund',
        );

        // normalizedTicker:
        //   0P0000X83M.F
        //
        // Yahoo symbol:
        //   0P0000X83M.F
        //
        // Por tanto:
        //   exactTicker    = true
        //   sameMorningstar = true
        //
        // nameSimilarity = 1.00
        //
        // Score:
        //   1.00 * 0.55 = 0.55
        //   + 0.20 exactTicker
        //   + 0.05 startsWith
        //   + 0.30 MUTUALFUND
        //   + 0.10 sameMorningstar
        //   = 1.20
        //
        // El candidato debe ser admitido.

        expect(result, isNull);

        debugPrint(
          '[R20] ticker Morningstar exacto -> '
          'exactTicker + sameMorningstar -> score = 1.20 -> OK',
        );
      },
    );

    test(
      'R21 - exactTicker acumula también la bonificación startsWith',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'TEST') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'TEST',
                    'longname': 'Alpha Beta',
                    'quoteType': 'OTHER',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Alpha Beta Gamma Delta',
        );

        // similarity = 2 / 4 = 0.50
        //
        // Sin startsWith:
        //   0.50 * 0.55 + 0.20 = 0.475
        //   -> rechazado
        //
        // Con startsWith:
        //   0.475 + 0.05 = 0.525
        //   -> admitido
        //
        // Por tanto, el resultado demuestra que exactTicker
        // acumula también el bonus startsWith.

        expect(result, isNull);
        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[R21] exactTicker + startsWith -> '
          '0.475 + 0.05 = 0.525 -> admitido -> OK',
        );
      },
    );

    test('R22 - exactTicker y sameMorningstar se acumulan', () async {
      final seenSymbols = <String>[];

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == '0P0000X83M.F') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': '0P0000X83M.F',
                  'longname': 'Alpha Beta',
                  'quoteType': 'OTHER',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );

      final result = await resolver.resolve(
        ticker: '0P0000X83M.F',
        fundName: 'Alpha Beta Gamma Delta',
      );

      // similarity = 2 / 4 = 0.50
      //
      // exactTicker       = +0.20
      // startsWith        = +0.05
      // sameMorningstar   = +0.10
      //
      // Score:
      //   0.50 * 0.55 = 0.275
      //   0.275 + 0.20 + 0.05 + 0.10
      //   = 0.625
      //
      // Sin sameMorningstar sería 0.525.
      //
      // El test demuestra que ambas señales se acumulan.

      expect(result, isNull);
      expect(seenSymbols, ['0P0000X83M.F']);

      debugPrint(
        '[R22] exactTicker + sameMorningstar + startsWith '
        '-> score = 0.625 -> OK',
      );
    });

    test(
      'R23 - un ISIN único aporta +0.10 y decide entre candidatos equivalentes',
      () async {
        final seenSymbols = <String>[];

        final client = MockClient((request) async {
          if (request.url.queryParameters['q'] == 'Target Fund') {
            return http.Response(
              jsonEncode({
                'quotes': [
                  {
                    'symbol': 'AAA',
                    'longname': 'Target Fund',
                    'quoteType': 'MUTUALFUND',
                    'isin': 'FR0000993172',
                  },
                  {
                    'symbol': 'BBB',
                    'longname': 'Target Fund',
                    'quoteType': 'MUTUALFUND',
                  },
                ],
              }),
              200,
            );
          }

          return http.Response(jsonEncode({'quotes': []}), 200);
        });

        final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [tracking],
        );

        final result = await resolver.resolve(
          ticker: 'ZZZ',
          fundName: 'Target Fund',
        );

        // Ambos candidatos:
        //   similarity = 1.00
        //   MUTUALFUND = +0.30
        //
        // AAA además:
        //   ISIN único = +0.10
        //
        // AAA:
        //   0.55 + 0.30 + 0.10 = 0.95
        //
        // BBB:
        //   0.55 + 0.30 = 0.85
        //
        // AAA debe quedar primero.
        //
        // Como AAA tiene un ISIN Yahoo válido, resolve() debe
        // devolverlo directamente sin consultar ForeignProvider.

        expect(result, isNotNull);
        expect(result?.isin, 'FR0000993172');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Target Fund');

        // El proveedor extranjero no debe llegar a ejecutarse.
        expect(seenSymbols, isEmpty);

        debugPrint(
          '[R23] ISIN único -> +0.10 -> '
          'AAA = 0.95 frente a BBB = 0.85 -> '
          'AAA primero -> ISIN Yahoo devuelto -> OK',
        );
      },
    );

    test('R24 - MUTUALFUND supera a OTHER con el mismo nombre', () async {
      final seenSymbols = <String>[];

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] == 'Target Fund') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'AAA',
                  'longname': 'Target Fund',
                  'quoteType': 'OTHER',
                },
                {
                  'symbol': 'BBB',
                  'longname': 'Target Fund',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );

      final result = await resolver.resolve(
        ticker: 'ZZZ',
        fundName: 'Target Fund',
      );

      // Ambos:
      //   similarity = 1.00
      //
      // AAA OTHER:
      //   0.55
      //
      // BBB MUTUALFUND:
      //   0.55 + 0.30 = 0.85
      //
      // BBB debe quedar primero.

      expect(result, isNull);
      expect(seenSymbols, ['BBB', 'AAA']);

      debugPrint('[R24] MUTUALFUND = 0.85 frente a OTHER = 0.55 -> OK');
    });

    test('R25 - dos candidatos próximos se ordenan por score', () async {
      final seenSymbols = <String>[];

      final client = MockClient((request) async {
        if (request.url.queryParameters['q'] ==
            'Alpha Beta Gamma Delta Epsilon') {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'AAA',
                  'longname': 'Alpha Beta Gamma X',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': 'BBB',
                  'longname': 'Alpha Beta Gamma',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            }),
            200,
          );
        }

        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final tracking = TrackingForeignProvider(seenSymbols: seenSymbols);

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [tracking],
      );

      final result = await resolver.resolve(
        ticker: 'ZZZ',
        fundName: 'Alpha Beta Gamma Delta Epsilon',
      );

      // AAA:
      //   intersección = 3
      //   unión = 6
      //   similarity = 0.50
      //
      //   0.50 * 0.55 + 0.30 = 0.575
      //
      // BBB:
      //   intersección = 3
      //   unión = 5
      //   similarity = 0.60
      //
      //   0.60 * 0.55 + 0.30 = 0.63
      //
      // Ambos superan el umbral de 0.50.
      // BBB debe quedar primero.

      expect(result, isNull);
      expect(seenSymbols, ['BBB', 'AAA']);

      debugPrint(
        '[R25] scores próximos: BBB = 0.630, AAA = 0.575 '
        '-> ranking correcto -> OK',
      );
    });
  });
}
