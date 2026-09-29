import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:http/http.dart' as http;

import 'yahoo_test_support.dart';

void runYahooMergeTests() {
  group('Yahoo merge', () {
    test('M1. Mismo symbol + mismo ISIN en ambas búsquedas', () async {
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
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'M2. Mismo symbol: búsqueda ticker con ISIN + nombre sin ISIN',
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
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND"'
              '}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M3. Mismo symbol: búsqueda ticker sin ISIN + nombre con ISIN',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND"'
              '}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
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

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test(
      'M4. Mismo symbol con dos ISIN diferentes: debe producir conflicto',
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
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"}'
              ']}',
              200,
            );
          }

          return http.Response('{"quotes": []}', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test(
      'M5. Mismo symbol con nombres diferentes: conserva el más similar',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Completely Different Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
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
        expect(result.officialName, 'Test Fund');
      },
    );

    test(
      'M6. Mismo symbol: MUTUALFUND prevalece sobre otro quoteType',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
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
      },
    );

    test(
      'M7. Mismo symbol: exchange vacío se completa con la segunda respuesta',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
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
      },
    );

    test(
      'M8. Mismo symbol repetido con el mismo ISIN: no crea conflicto',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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
      },
    );

    test(
      'M9. Symbol con distinta capitalización se fusiona y detecta conflicto',
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

        expect(result, isNull);
      },
    );
    test(
      'M10. Tres resultados con el mismo symbol se fusionan acumulativamente',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "", '
              '"quoteType": "ETF"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
              '"quoteType": "MUTUALFUND"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"exchange": "PAR", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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
      },
    );

    test('M11. Tres resultados con el mismo symbol y el mismo ISIN', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.queryParameters['q'];

        if (query == 'TEST') {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"},'
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"},'
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        }

        if (query == 'Test Fund') {
          return http.Response('{"quotes": []}', 200);
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

    test(
      'M12. Tres resultados con el mismo symbol y tres ISIN diferentes',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0261948904"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "LU0129445192"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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

        expect(result, isNull);
      },
    );

    test(
      'M13. Nombre vacío seguido de nombre válido conserva el nombre válido',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "", '
              '"shortname": "", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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
        expect(result.officialName, 'Test Fund');
      },
    );

    test(
      'M14. MUTUALFUND no se degrada al fusionar posteriormente un ETF',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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
      },
    );

    test(
      'M15. ETF + EQUITY + MUTUALFUND: MUTUALFUND prevalece al final',
      () async {
        final mockClient = MockClient((request) async {
          final query = request.url.queryParameters['q'];

          if (query == 'TEST') {
            return http.Response(
              '{"quotes": ['
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "ETF"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "EQUITY"},'
              '{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}'
              ']}',
              200,
            );
          }

          if (query == 'Test Fund') {
            return http.Response('{"quotes": []}', 200);
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
      },
    );

    test(
      'M19. Mismo symbol: MUTUALFUND + MUTUALFUND con el mismo ISIN',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
        });

        final provider = createYahooProvider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expectIsin(result, 'FR0000993172', 'M19');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Test Fund');

        debugPrint('[M19] MUTUALFUND + MUTUALFUND + mismo ISIN -> OK');
      },
    );

    test(
      'M20. Mismo symbol: ETF aporta ISIN y MUTUALFUND no aporta ISIN',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'ETF',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final provider = createYahooProvider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);

        debugPrint('[M20] ISIN solo del ETF ignorado -> OK');
      },
    );

    test(
      'M21. Mismo symbol: MUTUALFUND aporta ISIN y ETF no aporta ISIN',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'ETF',
              isin: null,
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
        });

        final provider = createYahooProvider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expectIsin(result, 'FR0000993172', 'M21');
        expect(result?.source, 'Yahoo');
        expect(result?.officialName, 'Test Fund');

        debugPrint('[M21] ISIN solo del MUTUALFUND + ETF -> OK');
      },
    );

    test('M22. Mismo symbol: ETF y MUTUALFUND aportan el mismo ISIN', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: 'FR0000993172',
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expectIsin(result, 'FR0000993172', 'M22');
      expect(result?.source, 'Yahoo');
      expect(result?.officialName, 'Test Fund');

      debugPrint('[M22] ETF + MUTUALFUND + mismo ISIN -> OK');
    });

    test(
      'M23. Mismo symbol: dos MUTUALFUND con ISIN diferentes generan conflicto',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B4L5Y983',
            ),
          ],
        });

        final provider = createYahooProvider(client: client);

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);

        debugPrint('[M23] dos ISIN válidos distintos -> conflicto -> null');
      },
    );

    test('M24. Mismo symbol: ISIN de ETF se ignora aunque MUTUALFUND aporte otro ISIN', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: 'LU0123456789',
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expectIsin(result, 'FR0000993172', 'M24');
      expect(result?.source, 'Yahoo');

      debugPrint('[M24] ISIN ETF ignorado + ISIN MF aceptado -> OK');
    });

    test(
      'M25. Conflicto de ISIN Yahoo permite continuar con proveedor extranjero',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B4L5Y983',
            ),
          ],
        });

        final seenSymbols = <String>[];

        final foreignProvider = TrackingForeignProvider(
          seenSymbols: seenSymbols,
        );

        final provider = createYahooProvider(
          client: client,
          foreign: [foreignProvider],
        );

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
        expect(seenSymbols, contains('TEST'));

        debugPrint(
          '[M25] conflicto Yahoo -> proveedor extranjero consultado -> OK',
        );
      },
    );

    test('M26. Mismo symbol: varias apariciones del mismo ISIN no generan conflicto', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      });

      final provider = createYahooProvider(client: client);

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expectIsin(result, 'FR0000993172', 'M26');
      expect(result?.source, 'Yahoo');

      debugPrint('[M26] ISIN repetido -> una sola evidencia -> OK');
    });

    test(
      'M27. Mismo mergeKey: symbol exacto del ticker tiene prioridad',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'test',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
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

        await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, contains('TEST'));

        debugPrint('[M27] symbol exacto del ticker -> TEST -> OK');
      },
    );

    test('M28a. Mismo Morningstar ID sin sufijo se fusiona', () async {
      final client = FakeYahooClient({
        '0P0000X83M': [
          const Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
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

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols, ['0P0000X83M']);

      debugPrint(
        '[M28a] mismo Morningstar ID sin sufijo -> 1 resultado fusionado -> OK',
      );
    });

    test('M28b. Mismo Morningstar ID con .F se fusiona', () async {
      final client = FakeYahooClient({
        '0P0000X83M': [
          const Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund',
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

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols, ['0P0000X83M']);

      debugPrint('[M28b] 0P0000X83M + 0P0000X83M.F -> fusionado -> OK');
    });

    test(
      'M28c. Mismo Morningstar ID con sufijos diferentes se fusiona',
      () async {
        final client = FakeYahooClient({
          '0P0000X83M': [
            const Quote(
              symbol: '0P0000X83M.F',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'PIMCO GIS Income Fund': [
            const Quote(
              symbol: '0P0000X83M.DE',
              longname: 'PIMCO GIS Income Fund',
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

        await provider.resolve(
          ticker: '0P0000X83M',
          fundName: 'PIMCO GIS Income Fund',
        );

        expect(seenSymbols.length, 1);
        expect(seenSymbols.single, '0P0000X83M.F');

        debugPrint('[M28c] 0P0000X83M.F + 0P0000X83M.DE -> fusionado -> OK');
      },
    );

    test('M28d. Morningstar IDs diferentes no se fusionan', () async {
      final client = FakeYahooClient({
        '0P0000X83M': [
          const Quote(
            symbol: '0P0000X83M',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'PIMCO GIS Income Fund': [
          const Quote(
            symbol: '0P0000X83N',
            longname: 'PIMCO GIS Income Fund',
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

      await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['0P0000X83M', '0P0000X83N']));

      debugPrint('[M28d] Morningstar IDs diferentes -> 2 resultados -> OK');
    });

    test('M28e. Ticker normal con mercados diferentes no se fusiona', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST.MC',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST.DE',
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

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['TEST.MC', 'TEST.DE']));

      debugPrint('[M28e] TEST.MC + TEST.DE -> no fusion -> OK');
    });

    test('M28f. Ticker normal y ticker base no se fusionan', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST.MC',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
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

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols.length, 2);
      expect(seenSymbols, containsAll(<String>['TEST.MC', 'TEST']));

      debugPrint('[M28f] TEST.MC + TEST -> no fusion -> OK');
    });

    test(
      'M28g. Mismo ticker con diferente capitalización se fusiona',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'test',
              longname: 'Test Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Test Fund': [
            const Quote(
              symbol: 'TEST',
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

        await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

        expect(seenSymbols, ['TEST']);

        debugPrint('[M28g] test + TEST -> mismo mergeKey -> fusionado -> OK');
      },
    );

    test(
      'M29. Mismo symbol: conserva el nombre más similar al fundName',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'Alpha Income Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenNames = <String>[];

        final provider = createYahooProvider(
          client: client,
          foreign: [
            TrackingForeignProvider(
              seenSymbols: <String>[],
              seenNames: seenNames,
            ),
          ],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

        expect(seenNames, contains('Alpha Growth Fund'));
        expect(seenNames, isNot(contains('Alpha Income Fund')));

        debugPrint(
          '[M29] nombre más similar al fundName -> Alpha Growth Fund -> OK',
        );
      },
    );

    test('M30. Mismo symbol: empate de similitud conserva existing', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'Growth Alpha Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final seenNames = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [
          TrackingForeignProvider(
            seenSymbols: <String>[],
            seenNames: seenNames,
          ),
        ],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

      expect(seenNames, contains('Alpha Growth Fund'));
      expect(seenNames, isNot(contains('Growth Alpha Fund')));

      debugPrint('[M30] empate de similitud -> conserva existing -> OK');
    });

    test('M31. Mismo mergeKey: MUTUALFUND + ETF conserva MUTUALFUND', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: null,
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST']);

      debugPrint('[M31] MUTUALFUND + ETF -> conserva MUTUALFUND -> OK');
    });

    test('M32. Mismo mergeKey: ETF + MUTUALFUND conserva MUTUALFUND', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'Test Fund',
            quoteType: 'ETF',
            isin: null,
          ),
        ],
        'Test Fund': [
          const Quote(
            symbol: 'TEST',
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

      await provider.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(seenSymbols, ['TEST']);

      debugPrint('[M32] ETF + MUTUALFUND -> conserva MUTUALFUND -> OK');
    });

    test(
      'M33. Mismo mergeKey: nombres contradictorios conserva el más similar',
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
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: null,
            ),
          ],
        });

        final seenSymbols = <String>[];
        final seenNames = <String>[];

        final provider = createYahooProvider(
          client: client,
          foreign: [
            TrackingForeignProvider(
              seenSymbols: seenSymbols,
              seenNames: seenNames,
            ),
          ],
        );

        await provider.resolve(ticker: 'TEST', fundName: 'Alpha Growth Fund');

        expect(seenSymbols, ['TEST']);
        expect(seenNames, ['Alpha Growth Fund']);

        debugPrint(
          '[M33] nombres contradictorios -> conserva el más similar al fundName -> OK',
        );
      },
    );

    test('M34. Mismo mergeKey: ISIN real idéntico repetido no genera conflicto', () async {
      final client = FakeYahooClient({
        'TEST': [
          const Quote(
            symbol: 'TEST',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: 'IE00B8K7V925',
          ),
        ],
        'PIMCO GIS Income Fund': [
          const Quote(
            symbol: 'TEST',
            longname: 'PIMCO GIS Income Fund',
            quoteType: 'MUTUALFUND',
            isin: 'IE00B8K7V925',
          ),
        ],
      });

      final seenSymbols = <String>[];

      final provider = createYahooProvider(
        client: client,
        foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
      );

      final result = await provider.resolve(
        ticker: 'TEST',
        fundName: 'PIMCO GIS Income Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'IE00B8K7V925');
      expect(seenSymbols, isEmpty);

      debugPrint(
        '[M34] ISIN real repetido -> una única evidencia -> Yahoo acepta -> OK',
      );
    });

    test(
      'M35. Mismo mergeKey: dos ISIN reales diferentes mantienen el conflicto',
      () async {
        final client = FakeYahooClient({
          'TEST': [
            const Quote(
              symbol: 'TEST',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: 'IE00B8K7V925',
            ),
          ],
          'PIMCO GIS Income Fund': [
            const Quote(
              symbol: 'TEST',
              longname: 'PIMCO GIS Income Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0010135103',
            ),
          ],
        });

        final seenSymbols = <String>[];

        final provider = createYahooProvider(
          client: client,
          foreign: [TrackingForeignProvider(seenSymbols: seenSymbols)],
        );

        final result = await provider.resolve(
          ticker: 'TEST',
          fundName: 'PIMCO GIS Income Fund',
        );

        expect(result, isNull);
        expect(seenSymbols, ['TEST']);

        debugPrint(
          '[M35] dos ISIN reales diferentes -> conflicto -> proveedor extranjero -> OK',
        );
      },
    );

    test(
      'F1 - al fusionar el mismo mergeKey se conserva el symbol del ticker',
      () async {
        final client = FakeYahooClient({
          '0P0000X83M.F': [
            const Quote(
              symbol: '0P0000X83M',
              longname: 'PIMCO GIS Income Fund E Class USD Income',
              quoteType: 'MUTUALFUND',
            ),
          ],
          'PIMCO GIS Income Fund E Class USD Income': [
            const Quote(
              symbol: '0P0000X83M.F',
              longname: 'PIMCO GIS Income Fund E Class USD Income',
              quoteType: 'MUTUALFUND',
            ),
          ],
        });

        final tracking = TrackingForeignProvider(seenSymbols: []);

        final provider = createYahooProvider(
          client: client,
          foreign: [tracking],
        );

        final result = await provider.resolve(
          ticker: '0P0000X83M.F',
          fundName: 'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(result, isNull);

        expect(tracking.seenSymbols, ['0P0000X83M.F']);

        debugPrint('[F1] symbol representativo del ticker -> OK');
      },
    );

    test('F2 - al fusionar el mismo mergeKey se conserva el nombre más similar al fundName', () async {
      final seenSymbols = <String>[];
      final seenNames = <String>[];

      final client = FakeYahooClient({
        'XYZ.PA': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Completely Different Fund',
            quoteType: 'MUTUALFUND',
          ),
        ],
        'Alpha Growth Fund': [
          const Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
          ),
        ],
      });

      final provider = createYahooProvider(
        client: client,
        foreign: [
          TrackingForeignProvider(
            seenSymbols: seenSymbols,
            seenNames: seenNames,
          ),
        ],
      );

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);

      expect(seenSymbols, ['XYZ.PA']);
      expect(seenNames, ['Alpha Growth Fund']);

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);

      debugPrint(
        '[F2] nombre más similar seleccionado -> '
        '${seenNames.first} -> OK',
      );
    });
  });
}
