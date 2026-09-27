import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';

/// R11 - integración real de YahooProvider.
///
/// Ejecutar desde la raíz:
///   dart test research/archive/test/test_yahoo_integrated_r11.dart -p vm
///
/// Las pruebas deterministas usan YahooProvider real y un HTTP client falso.
/// No reproducen _searchYahoo(), _mergeYahooResult() ni _rankYahooResults():
/// ejecutan directamente YahooProvider.resolve().
///
/// El bloque R11 LIVE consulta Yahoo Finance realmente y es diagnóstico.

class _Quote {
  final String symbol;
  final String longname;
  final String? shortname;
  final String exchange;
  final String quoteType;
  final String? isin;

  const _Quote({
    required this.symbol,
    this.longname = '',
    this.shortname,
    this.exchange = 'XPAR',
    required this.quoteType,
    this.isin,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'longname': longname,
        if (shortname != null) 'shortname': shortname,
        'exchange': exchange,
        'quoteType': quoteType,
        if (isin != null) 'isin': isin,
      };
}

class _FakeYahooClient extends http.BaseClient {
  final Map<String, List<_Quote>> responses;
  final Map<String, int> queryCount = {};

  _FakeYahooClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final query = request.url.queryParameters['q'] ?? '';
    queryCount[query] = (queryCount[query] ?? 0) + 1;

    final body = jsonEncode({
      'quotes': (responses[query] ?? const <_Quote>[])
          .map((q) => q.toJson())
          .toList(),
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FakeForeignProvider implements ForeignIsinProvider {
  final Map<String, String> bySymbol;
  final List<Map<String, String>> calls = [];

  _FakeForeignProvider({this.bySymbol = const {}});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    calls.add({
      'ticker': ticker,
      'fundName': fundName,
      'yahooSymbol': yahooSymbol,
      'yahooName': yahooName,
    });
    return bySymbol[yahooSymbol];
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

YahooProvider _provider({
  required _FakeYahooClient client,
  List<ForeignIsinProvider>? foreign,
}) {
  return YahooProvider(
    client: client,
    foreignIsinProviders:
        foreign ?? const [_NullForeignProvider()],
  );
}

void _expectIsin(dynamic result, String expected, String label) {
  expect(result, isNotNull, reason: '$label: resultado null');
  expect(result.isin, expected, reason: '$label: ISIN inesperado');
}

void main() {
  group('R11 - integración determinista', () {
    test('R11.1 - ejecuta ticker y nombre', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(client.queryCount['XYZ.PA'], 1);
      expect(client.queryCount['Alpha Growth Fund'], 1);
      expect(result, isNull);
      print('[R11.1] ticker=1, nombre=1 -> OK');
    });

    test('R11.2 - mismo symbol fusiona y conserva ISIN de segunda consulta',
        () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.2');
      expect(result, isNotNull);
      expect(result!.source, 'Yahoo');
      print('[R11.2] merge por symbol + ISIN -> OK');
    });

    test('R11.3 - conserva candidato solo del ticker', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.3');
      print('[R11.3] ticker-only -> OK');
    });

    test('R11.4 - conserva candidato solo del nombre', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.4');
      print('[R11.4] name-only -> OK');
    });

    test('R11.5 - conflicto de ISIN para mismo symbol -> null', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
        ],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      print('[R11.5] ISIN conflict -> null -> OK');
    });

    test('R11.6 - MUTUALFUND supera ETF/EQUITY/INDEX', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'ETF',
            isin: 'FR0000000028',
          ),
          const _Quote(
            symbol: 'XYZ.PA2',
            longname: 'Alpha Growth Fund',
            quoteType: 'EQUITY',
            isin: 'FR0000000028',
          ),
          const _Quote(
            symbol: 'XYZ.PA3',
            longname: 'Alpha Growth Fund',
            quoteType: 'INDEX',
            isin: 'FR0000000028',
          ),
          const _Quote(
            symbol: 'XYZ.PA4',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.6');
      print('[R11.6] tipo -> OK');
    });

    test('R11.7 - ETF con ISIN válido es rechazado', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'ETF',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final foreign = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'FR0000000010'},
      );

      final result = await _provider(
        client: client,
        foreign: [foreign],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      expect(foreign.calls, isEmpty);
      print('[R11.7] ETF -> rechazado -> OK');
    });

    test('R11.8 - EQUITY e INDEX no llegan al foreign provider', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'EQUITY',
            isin: null,
          ),
          const _Quote(
            symbol: 'XYZ.PA2',
            longname: 'Alpha Growth Fund',
            quoteType: 'INDEX',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final foreign = _FakeForeignProvider(
        bySymbol: {
          'XYZ.PA': 'FR0000000010',
          'XYZ.PA2': 'FR0000000028',
        },
      );

      final result = await _provider(
        client: client,
        foreign: [foreign],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      expect(foreign.calls, isEmpty);
      print('[R11.8] EQUITY/INDEX -> rechazados -> OK');
    });

    test('R11.9 - identidad fuerte permite similitud > 0.20', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Extra',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.9');
      print('[R11.9] identidad fuerte -> OK');
    });

    test('R11.10 - sin identidad fuerte exige similitud >= 0.50',
        () async {
      final client = _FakeYahooClient({
        'XYZ.PA': const [],
        'Alpha Growth Fund': [
          const _Quote(
            symbol: 'OTHER.PA',
            longname: 'Alpha Extra',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      print('[R11.10] identidad débil + similitud 0.25 -> OK');
    });

    test('R11.11 - mismo Morningstar base ID es identidad fuerte', () async {
      final client = _FakeYahooClient({
        '0P0000X83M': [
          const _Quote(
            symbol: '0P0000X83M.F',
            longname: 'PIMCO GIS Income Fund E Class USD Income',
            quoteType: 'MUTUALFUND',
            isin: 'IE00B8K7V925',
          ),
        ],
        'PIMCO GIS Income Fund E Class USD Income': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      _expectIsin(result, 'IE00B8K7V925', 'R11.11');
      print('[R11.11] Morningstar base ID -> OK');
    });

    test('R11.12 - foreign provider recibe candidato rankeado', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final foreign = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'FR0000000010'},
      );

      final result = await _provider(
        client: client,
        foreign: [foreign],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.12');
      expect(result, isNotNull);
      expect(result!.source, 'Yahoo/Foreign');
      expect(foreign.calls, hasLength(1));
      expect(foreign.calls.single['yahooSymbol'], 'XYZ.PA');
      expect(foreign.calls.single['yahooName'], 'Alpha Growth Fund');
      print('[R11.12] Yahoo -> rank -> foreign -> ISIN -> OK');
    });

    test('R11.13 - foreign providers se prueban en orden', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final first = _FakeForeignProvider();
      final second = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'FR0000000010'},
      );
      final third = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'FR0000000028'},
      );

      final result = await _provider(
        client: client,
        foreign: [first, second, third],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.13');
      expect(first.calls, hasLength(1));
      expect(second.calls, hasLength(1));
      expect(third.calls, isEmpty);
      print('[R11.13] orden de providers -> OK');
    });

    test('R11.14 - foreign provider con ISIN inválido no resuelve', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: null,
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final foreign = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'NOT-AN-ISIN'},
      );

      final result = await _provider(
        client: client,
        foreign: [foreign],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      expect(result, isNull);
      print('[R11.14] ISIN foreign inválido -> OK');
    });

    test('R11.15 - ISIN Yahoo válido evita foreign provider', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });
      final foreign = _FakeForeignProvider(
        bySymbol: {'XYZ.PA': 'FR0000000028'},
      );

      final result = await _provider(
        client: client,
        foreign: [foreign],
      ).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.15');
      expect(result, isNotNull);
      expect(result!.source, 'Yahoo');
      expect(foreign.calls, isEmpty);
      print('[R11.15] Yahoo ISIN tiene prioridad -> OK');
    });

    test('R11.16 - longname vacío NO cae a shortname', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: '',
            shortname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      // Comportamiento documentado en R10.18.
      expect(result, isNull);
      print('[R11.16] longname vacío -> comportamiento actual -> OK');
    });

    test('R11.17 - ranking elige el candidato exacto', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'WRONG.PA',
            longname: 'Alpha Other Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.17');
      print('[R11.17] candidato exacto -> OK');
    });

    test('R11.18 - candidato irrelevante no bloquea candidato válido',
        () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'BAD.PA',
            longname: 'Completely Unrelated Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.18');
      print('[R11.18] irrelevante descartado; válido conservado -> OK');
    });

    test('R11.19 - ISIN Yahoo se normaliza', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'MUTUALFUND',
            isin: ' fr0000000010 ',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.19');
      print('[R11.19] normalización ISIN -> OK');
    });

    test('R11.20 - quoteType lowercase MUTUALFUND es válido', () async {
      final client = _FakeYahooClient({
        'XYZ.PA': [
          const _Quote(
            symbol: 'XYZ.PA',
            longname: 'Alpha Growth Fund',
            quoteType: 'mutualfund',
            isin: 'FR0000000010',
          ),
        ],
        'Alpha Growth Fund': const [],
      });

      final result = await _provider(client: client).resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _expectIsin(result, 'FR0000000010', 'R11.20');
      print('[R11.20] quoteType lowercase -> OK');
    });
  });

  group('R11 LIVE - Yahoo real', () {
    const cases = <({
      String name,
      String ticker,
      String expectedIsin,
    })>[
      (
        name: 'PIMCO GIS Income Fund E Class USD Income',
        ticker: '0P0000X83M',
        expectedIsin: 'IE00B8K7V925',
      ),
      (
        name: 'Carmignac Patrimoine A EUR Acc',
        ticker: '0P00000FB4.F',
        expectedIsin: 'FR0010135103',
      ),
      (
        name: 'Fidelity Funds - Iberia A-Acc-EUR',
        ticker: '0P00006DAB.F',
        expectedIsin: 'LU0261948904',
      ),
      (
        name: 'JPM Europe Strategic Value C Acc EUR',
        ticker: '0P00000Z1Y.F',
        expectedIsin: 'LU0129445192',
      ),
      (
        name: 'Fidelity European Growth A Acc EUR',
        ticker: 'LU0296857971',
        expectedIsin: 'LU0296857971',
      ),
      (
        name: 'BlackRock Next Generation Technology A2 EUR',
        ticker: 'LU2400291972',
        expectedIsin: 'LU2400291972',
      ),
    ];

    for (final c in cases) {
      test(
        'R11 LIVE - ${c.ticker}',
        () async {
          final client = http.Client();
          final foreign = _FakeForeignProvider(
            bySymbol: {c.ticker: c.expectedIsin},
          );

          final provider = YahooProvider(
            client: client,
            foreignIsinProviders: [foreign],
          );

          try {
            final result = await provider.resolve(
              ticker: c.ticker,
              fundName: c.name,
            );

            print('');
            print('-' * 80);
            print('[R11 LIVE] ${c.ticker}');
            print('  Nombre : ${c.name}');
            print('  ISIN esperado : ${c.expectedIsin}');
            print('  Resultado : ${result?.isin ?? 'null'}');
            print('  Fuente : ${result?.source ?? 'null'}');
            print('  Nombre Yahoo : ${result?.officialName ?? 'null'}');
            print('  Foreign calls : ${foreign.calls.length}');
            if (foreign.calls.isNotEmpty) {
              print('  Yahoo symbol : '
                  '${foreign.calls.first['yahooSymbol']}');
              print('  Yahoo name : '
                  '${foreign.calls.first['yahooName']}');
            }
            print('-' * 80);

            // LIVE es observacional. No fuerza éxito porque Yahoo cambia.
            expect(result, anyOf(isNull, isNotNull));
          } finally {
            client.close();
          }
        },
        timeout: const Timeout(Duration(seconds: 30)),
      );
    }
  });
}
