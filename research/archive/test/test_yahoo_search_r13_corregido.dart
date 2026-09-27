import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:test/test.dart';

/// R13 — Adquisición y acumulación de _searchYahoo().
///
/// El objetivo es comprobar el comportamiento de YahooProvider.resolve()
/// alrededor de la fase de búsqueda:
///   ticker + fundName
///        -> respuestas Yahoo
///        -> parseo/sanitización
///        -> acumulación por symbol
///        -> merge
///        -> ranking
///
/// No se modifica producción. El HTTP client y los proveedores extranjeros
/// son controlados por el test.
class _YahooResponse {
  final int statusCode;
  final Object? body;

  const _YahooResponse({
    this.statusCode = 200,
    this.body,
  });
}

class _FakeYahooClient extends http.BaseClient {
  final Map<String, _YahooResponse> responses;
  final List<String> queries = [];

  _FakeYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queries.add(query);

    final response = responses[query] ??
        const _YahooResponse(
          statusCode: 200,
          body: {'quotes': <dynamic>[]},
        );

    final body = response.body is String
        ? response.body as String
        : jsonEncode(response.body);

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      response.statusCode,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _RecordingForeignProvider implements ForeignIsinProvider {
  final List<String> yahooSymbols = [];
  final String? value;

  _RecordingForeignProvider({this.value});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    yahooSymbols.add(yahooSymbol);
    return value;
  }
}

class _NullForeignProvider implements ForeignIsinProvider {
  const _NullForeignProvider();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async =>
      null;
}

Map<String, dynamic> _quote({
  required String symbol,
  String? longname,
  String? shortname,
  String? exchange,
  String? quoteType,
  String? isin,
}) {
  return {
    'symbol': symbol,
    if (longname != null) 'longname': longname,
    if (shortname != null) 'shortname': shortname,
    if (exchange != null) 'exchange': exchange,
    if (quoteType != null) 'quoteType': quoteType,
    if (isin != null) 'isin': isin,
  };
}

Future<IsinResult?> _resolve({
  required Map<String, _YahooResponse> responses,
  required String ticker,
  required String fundName,
  ForeignIsinProvider? foreignProvider,
}) async {
  final client = _FakeYahooClient(responses);

  final provider = YahooProvider(
    client: client,
    foreignIsinProviders: [
      foreignProvider ?? const _NullForeignProvider(),
    ],
  );

  return provider.resolve(
    ticker: ticker,
    fundName: fundName,
  );
}

void main() {
  const ticker = 'XYZ.PA';
  const fundName = 'Alpha Growth Fund';
  const validIsin = 'FR0000000010';

  group('R13 — adquisición y acumulación de _searchYahoo()', () {
    test('R13.1 — ejecuta exactamente las consultas ticker y fundName', () async {
      final client = _FakeYahooClient({
        ticker: const _YahooResponse(
          body: {
            'quotes': [
              {
                'symbol': ticker,
                'longname': fundName,
                'exchange': 'XPAR',
                'quoteType': 'MUTUALFUND',
                'isin': validIsin,
              },
            ],
          },
        ),
        fundName: const _YahooResponse(
          body: {
            'quotes': [
              {
                'symbol': ticker,
                'longname': fundName,
                'exchange': 'XPAR',
                'quoteType': 'MUTUALFUND',
                'isin': validIsin,
              },
            ],
          },
        ),
      });

      final provider = YahooProvider(
        client: client,
        foreignIsinProviders: const [_NullForeignProvider()],
      );

      final result = await provider.resolve(
        ticker: ticker,
        fundName: fundName,
      );

      expect(client.queries, [ticker, fundName]);
      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.2 — un symbol exclusivo del ticker se conserva', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.3 — un symbol exclusivo de fundName se conserva', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {'quotes': []},
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.4 — mismo symbol en ambas consultas se fusiona', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': 'Alpha Growth',
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
      expect(result.officialName, fundName);
    });

    test('R13.5 — dos symbols distintos permanecen independientes', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
                {
                  'symbol': 'OTHER.PA',
                  'longname': 'Alpha Growth Fund',
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'FR0000000028',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.6 — duplicado dentro de una misma respuesta no genera un candidato separado',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': 'Alpha Growth',
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
      expect(result.officialName, fundName);
    });

    test('R13.7 — duplicados en ambas respuestas se fusionan acumulativamente',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': 'Alpha Growth',
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                },
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
      expect(result.officialName, fundName);
    });

    test('R13.8 — un ISIN aportado sólo por la segunda consulta se conserva',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.9 — un nombre mejor aportado sólo por la segunda consulta se conserva',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': 'Alpha Growth',
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.officialName, fundName);
    });

    test('R13.10 — un exchange aportado sólo por la segunda consulta no impide resolver',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': '',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.11 — HTTP 500 en ticker no impide procesar fundName', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            statusCode: 500,
            body: {'error': 'server error'},
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.12 — HTTP 500 en fundName no impide usar ticker', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            statusCode: 500,
            body: {'error': 'server error'},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.13 — JSON inválido en ticker no impide procesar fundName', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: '{not-valid-json',
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.14 — JSON inválido en fundName no impide usar ticker', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: '{not-valid-json',
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.15 — quotes ausente se ignora sin romper la segunda consulta',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: <String, dynamic>{},
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.16 — quotes con tipo incorrecto se ignora sin romper la segunda consulta',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {'quotes': 'not-a-list'},
          ),
          fundName: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.17 — elemento no mapa no impide procesar los demás quotes', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                'corrupt',
                123,
                null,
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.18 — quote sin symbol se ignora y no bloquea un quote válido posterior',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.19 — symbol vacío se ignora y no bloquea un quote válido posterior',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': '',
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.20 — campos ausentes del quote son tolerados', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      // No debe producir una excepción. El quote es válido como estructura,
      // aunque no tenga suficiente información para resolver el fondo.
      expect(result, isNull);
    });

    test('R13.21 — ISIN válido en Yahoo se normaliza antes de acumularlo',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'mutualfund',
                  'isin': '  fr0000000010  ',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, validIsin);
    });

    test('R13.22 — ISIN válido de una quote no-MUTUALFUND se descarta',
        () async {
      final foreign = _RecordingForeignProvider();

      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'ETF',
                  'isin': validIsin,
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
        foreignProvider: foreign,
      );

      expect(result, isNull);
      expect(foreign.yahooSymbols, isEmpty);
    });

    test('R13.23 — ISIN inválido se descarta aunque el quote sea MUTUALFUND',
        () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {
              'symbol': ticker,
              'quotes': [
                {
                  'symbol': ticker,
                  'longname': fundName,
                  'exchange': 'XPAR',
                  'quoteType': 'MUTUALFUND',
                  'isin': 'INVALID',
                },
              ],
            },
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNull);
    });

    test('R13.24 — una respuesta completamente vacía no rompe resolve()', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            body: {'quotes': []},
          ),
          fundName: const _YahooResponse(
            body: {'quotes': []},
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNull);
    });

    test('R13.25 — fallo de ambas consultas devuelve null limpiamente', () async {
      final result = await _resolve(
        responses: {
          ticker: const _YahooResponse(
            statusCode: 500,
            body: {'error': 'ticker failed'},
          ),
          fundName: const _YahooResponse(
            body: '{invalid-json',
          ),
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNull);
    });
  });
}
