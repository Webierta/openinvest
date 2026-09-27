import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:test/test.dart';

/// R12 — Fusión profunda de resultados Yahoo con el mismo symbol.
///
/// Este test no modifica producción. Ejecuta YahooProvider.resolve() real,
/// utilizando únicamente un HTTP client falso y proveedores extranjeros
/// controlados.
class _Quote {
  final String symbol;
  final String? longname;
  final String? shortname;
  final String? exchange;
  final String? quoteType;
  final String? isin;

  const _Quote({
    required this.symbol,
    this.longname,
    this.shortname,
    this.exchange,
    this.quoteType,
    this.isin,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    if (longname != null) 'longname': longname,
    if (shortname != null) 'shortname': shortname,
    if (exchange != null) 'exchange': exchange,
    if (quoteType != null) 'quoteType': quoteType,
    if (isin != null) 'isin': isin,
  };
}

class _FakeYahooClient extends http.BaseClient {
  final Map<String, List<_Quote>> responses;
  final List<String> queries = [];

  _FakeYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queries.add(query);

    final quotes = responses[query] ?? const <_Quote>[];

    final body = jsonEncode({'quotes': quotes.map((q) => q.toJson()).toList()});

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
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
  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async => null;
}

Future<IsinResult?> _resolve({
  required Map<String, List<_Quote>> responses,
  required String ticker,
  required String fundName,
  ForeignIsinProvider? foreignProvider,
}) async {
  final client = _FakeYahooClient(responses);

  final provider = YahooProvider(
    client: client,
    foreignIsinProviders: [foreignProvider ?? _NullForeignProvider()],
  );

  return provider.resolve(ticker: ticker, fundName: fundName);
}

void main() {
  const fundName = 'Alpha Growth Fund';
  const ticker = 'XYZ.PA';

  group('R12 — fusión profunda por symbol', () {
    test(
      'R12.1 — mismo symbol en ticker y nombre produce un único resultado',
      () async {
        final client = _FakeYahooClient({
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        });

        final provider = YahooProvider(
          client: client,
          //foreignIsinProviders: const [_NullForeignProvider()],
          foreignIsinProviders: [_NullForeignProvider()],
        );

        final result = await provider.resolve(
          ticker: ticker,
          fundName: fundName,
        );

        expect(client.queries, [ticker, fundName]);
        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
        expect(result.officialName, 'Alpha Growth Fund');
        expect(result.source, 'Yahoo');
      },
    );

    test('R12.2 — el resultado es equivalente aunque nombre/ticker cambien de orden', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
      expect(result.officialName, 'Alpha Growth Fund');
    });

    test('R12.3 — tres apariciones del mismo symbol conservan un único ISIN consistente', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
      expect(result.officialName, 'Alpha Growth Fund');
    });

    test(
      'R12.4 — un resultado vacío no sustituye un exchange existente',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: '',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test(
      'R12.5 — un exchange posterior completa uno inicialmente vacío',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: '',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test(
      'R12.6 — MUTUALFUND posterior prevalece frente a type menos específico',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'EQUITY',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
        expect(result.source, 'Yahoo');
      },
    );

    test('R12.7 — conflicto de ISIN no se resuelve arbitrariamente', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000028',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      // Al perder el ISIN Yahoo por conflicto, el resultado no puede salir
      // directamente de Yahoo. El proveedor extranjero nulo tampoco resuelve.
      expect(result, isNull);
    });

    test('R12.8 — conflicto de ISIN sigue siendo conflicto aunque el nombre posterior sea mejor', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000028',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNull);
    });

    test('R12.9 — un symbol distinto no se fusiona aunque tenga el mismo nombre', () async {
      final client = _FakeYahooClient({
        ticker: [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            exchange: 'XPAR',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        fundName: [
          const _Quote(
            symbol: 'ABC.PA',
            longname: 'Alpha Growth Fund',
            exchange: 'XPAR',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
        ],
      });

      final provider = YahooProvider(
        client: client,
        //foreignIsinProviders: const [_NullForeignProvider()],
        foreignIsinProviders: [_NullForeignProvider()],
      );

      final result = await provider.resolve(ticker: ticker, fundName: fundName);

      // El candidato exacto por ticker sigue siendo el resultado seleccionado.
      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R12.10 — información válida del primer resultado no se pierde al enriquecerlo', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: '',
              quoteType: '',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
      expect(result.officialName, 'Alpha Growth Fund');
    });

    test(
      'R12.11 — nombre con mayor similitud sustituye al menos similar',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.officialName, 'Alpha Growth Fund');
      },
    );

    test('R12.12 — nombre vacío no destruye un nombre existente', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: '',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.officialName, 'Alpha Growth Fund');
    });

    test('R12.13 — type vacío se completa con MUTUALFUND', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: '',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test(
      'R12.14 — type no vacío no se sustituye por otro type no MUTUALFUND',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'EQUITY',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test('R12.15 — la fusión es determinista al repetir exactamente la misma entrada', () async {
      Future<IsinResult?> run() => _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      final a = await run();
      final b = await run();

      expect(a?.isin, b?.isin);
      expect(a?.officialName, b?.officialName);
      expect(a?.source, b?.source);
    });

    test('R12.16 — varios symbols distintos siguen siendo candidatos independientes', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
            const _Quote(
              symbol: 'ABC.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000028',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R12.17 — un ISIN válido recibido posteriormente completa un resultado sin ISIN', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R12.18 — un ISIN válido inicial se conserva si el posterior no tiene ISIN', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test(
      'R12.19 — conflicto de exchange no altera la identidad ni el ISIN',
      () async {
        final result = await _resolve(
          responses: {
            ticker: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'XPAR',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
            fundName: [
              const _Quote(
                symbol: 'XYZ.PA',
                longname: 'Alpha Growth Fund',
                exchange: 'BATE',
                quoteType: 'MUTUALFUND',
                isin: 'FR0000000010',
              ),
            ],
          },
          ticker: ticker,
          fundName: fundName,
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test('R12.20 — conflicto de type donde uno es MUTUALFUND mantiene el ISIN Yahoo', () async {
      final result = await _resolve(
        responses: {
          ticker: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          fundName: [
            const _Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              exchange: 'XPAR',
              quoteType: 'ETF',
              isin: 'FR0000000010',
            ),
          ],
        },
        ticker: ticker,
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
      expect(result.source, 'Yahoo');
    });
  });
}
