import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

import 'yahoo_test_support.dart';

void runYahooSelectionTests() {
  group('Yahoo selection', () {
    // ===========================================================================
    // O1-O6 — SYMBOL REPRESENTATIVO DESPUÉS DE LA FUSIÓN
    // ===========================================================================

    test(
      'O1 - Morningstar: el ticker exacto aparece después de una variante .F',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

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
      },
    );

    test('O2 - Morningstar: el ticker exacto aparece primero y sigue siendo representativo', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
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
    });

    test(
      'O3 - Morningstar: con tres variantes se conserva el ticker exacto',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == '0P0000X83M') {
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
      },
    );

    test('O4 - Morningstar: sin ticker exacto se conserva una variante de forma determinista', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == '0P0000X83M') {
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

    test('O5 - symbol genérico: se conserva la variante que coincide exactamente con el ticker', () async {
      final seenSymbols = <String>[];

      final trackingProvider = TrackingForeignProvider(
        seenSymbols: seenSymbols,
      );

      final client = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
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

    test(
      'O6 - mercado: TEST.PA y TEST.MC siguen siendo resultados independientes',
      () async {
        final seenSymbols = <String>[];

        final trackingProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final client = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST.PA') {
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
  });
}
