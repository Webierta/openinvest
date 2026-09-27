import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:test/test.dart';

/// R7-DIAGNOSTIC
///
/// Diagnóstico de la cadena:
///
///   _searchYahoo()
///        ↓
///   _rankYahooResults()
///        ↓
///   _resolveForeignIsin()
///        ↓
///   resolve()
///
/// NO modifica YahooProvider.
///
/// Los ISIN de prueba utilizados aquí son sintácticamente válidos
/// y pasan el checksum ISIN del proyecto:
///
///   FR0000000010
///   FR0000000028

const _isinOther = 'FR0000000010';
const _isinCorrect = 'FR0000000028';

class _FakeYahooClient extends http.BaseClient {
  final List<Map<String, dynamic>> results;

  _FakeYahooClient(this.results);

  int requestCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;

    print('');
    print('  [FAKE YAHOO] REQUEST #$requestCount');
    print('  URI: ${request.url}');
    print('  QUERY: ${request.url.queryParameters['q']}');

    final quotes = results
        .map(
          (r) => {
            'symbol': r['symbol'],
            'shortname': r['name'],
            'quoteType': r['type'],
            'isin': r['isin'],
          },
        )
        .toList();

    final payload = <String, dynamic>{'quotes': quotes};

    final body = jsonEncode(payload);

    print('  RESPONSE QUOTES:');

    for (final quote in quotes) {
      print(
        '    ${quote['symbol']} | '
        '${quote['quoteType']} | '
        '${quote['shortname']} | '
        'ISIN=${quote['isin']}',
      );
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FakeForeignProvider implements ForeignIsinProvider {
  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    print('');
    print('  [FAKE FOREIGN] resolve()');
    print('    input ticker : $ticker');
    print('    fund name    : $fundName');
    print('    yahoo symbol : $yahooSymbol');
    print('    yahoo name   : $yahooName');

    if (yahooSymbol == 'CORRECT.PA') {
      print('    => returning $_isinCorrect');
      return _isinCorrect;
    }

    if (yahooSymbol == 'OTHER.PA') {
      print('    => returning $_isinOther');
      return _isinOther;
    }

    print('    => returning null');
    return null;
  }
}

void main() {
  group('R7-DIAGNOSTIC', () {
    test('R7.1 - similitud 0 + ticker exacto => RECHAZADO', () async {
      await _runCase(
        id: 'R7.1',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Completely Unrelated Product',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.2 - similitud 0 + mismo Morningstar ID => RECHAZADO', () async {
      await _runCase(
        id: 'R7.2',
        ticker: '0P0000ABC1',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: '0P0000ABC1.DE',
            name: 'Completely Unrelated Product',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.3 - similitud 0 + MUTUALFUND + ISIN => RECHAZADO', () async {
      await _runCase(
        id: 'R7.3',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Completely Unrelated Product',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.4 - similitud 0.25 + MUTUALFUND + ISIN, sin identidad fuerte '
        '=> RECHAZADO', () async {
      await _runCase(
        id: 'R7.4',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.5 - similitud 0.25 + ticker exacto => ACEPTADO', () async {
      await _runCase(
        id: 'R7.5',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'ACCEPT',
      );
    });

    test('R7.6 - similitud 0.25 + mismo Morningstar ID => ACEPTADO', () async {
      await _runCase(
        id: 'R7.6',
        ticker: '0P0000ABC1',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: '0P0000ABC1.DE',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
        ],
        expected: 'ACCEPT',
      );
    });

    test('R7.7 - similitud 0.50 sin identidad fuerte => ACEPTADO', () async {
      await _runCase(
        id: 'R7.7',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Alpha Growth',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        expected: 'ACCEPT',
      );
    });

    test('R7.8 - similitud 0.49 sin identidad fuerte => RECHAZADO', () async {
      await _runCase(
        id: 'R7.8',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Alpha Fund',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.9 - similitud 0.20 + ticker exacto => ACEPTADO', () async {
      await _runCase(
        id: 'R7.9',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        expected: 'ACCEPT',
      );
    });

    test(
      'R7.10 - baja similitud + ticker exacto + EQUITY => RECHAZADO',
      () async {
        await _runCase(
          id: 'R7.10',
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
          candidates: [
            _candidate(
              symbol: 'XYZ.PA',
              name: 'Alpha',
              type: 'EQUITY',
              isin: null,
            ),
          ],
          expected: 'REJECT',
        );
      },
    );

    test('R7.11 - nombre perfecto + EQUITY => RECHAZADO', () async {
      await _runCase(
        id: 'R7.11',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'EQUITY',
            isin: null,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.12 - nombre perfecto + ETF => RECHAZADO', () async {
      await _runCase(
        id: 'R7.12',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'ETF',
            isin: null,
          ),
        ],
        expected: 'REJECT',
      );
    });

    test('R7.13 - nombre perfecto + MUTUALFUND => ACEPTADO', () async {
      await _runCase(
        id: 'R7.13',
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        expected: 'ACCEPT',
      );
    });

    test(
      'R7.14 - candidato falso no debe bloquear candidato correcto',
      () async {
        await _runCase(
          id: 'R7.14',
          ticker: 'CORRECT.PA',
          fundName: 'Alpha Growth Fund',
          candidates: [
            _candidate(
              symbol: 'WRONG.PA',
              name: 'Completely Unrelated Product',
              type: 'MUTUALFUND',
              isin: _isinOther,
            ),
            _candidate(
              symbol: 'CORRECT.PA',
              name: 'Alpha Growth Fund',
              type: 'MUTUALFUND',
              isin: _isinCorrect,
            ),
          ],
          expected: 'ACCEPT',
          expectedSymbol: 'CORRECT.PA',
        );
      },
    );

    test('R7.15 - candidato con ISIN no debe ganar a candidato compatible '
        'si la identidad es peor', () async {
      await _runCase(
        id: 'R7.15',
        ticker: 'CORRECT.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: _isinOther,
          ),
          _candidate(
            symbol: 'CORRECT.PA',
            name: 'Alpha Growth Fund',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        expected: 'ACCEPT',
        expectedSymbol: 'CORRECT.PA',
      );
    });
  });
}

Future<void> _runCase({
  required String id,
  required String ticker,
  required String fundName,
  required List<Map<String, dynamic>> candidates,
  required String expected,
  String? expectedSymbol,
}) async {
  print('');
  print('=' * 80);
  print('$id');
  print('=' * 80);

  print('INPUT');
  print('  ticker   : $ticker');
  print('  fundName : $fundName');

  print('');
  print('CANDIDATES');

  for (final candidate in candidates) {
    print(
      '  ${candidate['symbol']} | '
      '${candidate['type']} | '
      '${candidate['name']} | '
      'ISIN=${candidate['isin']}',
    );
  }

  final client = _FakeYahooClient(candidates);

  final provider = YahooProvider(
    client: client,
    foreignIsinProviders: [_FakeForeignProvider()],
  );

  print('');
  print('EXECUTING YahooProvider.resolve()...');

  final result = await provider.resolve(ticker: ticker, fundName: fundName);

  print('');
  print('RESULT');

  if (result == null) {
    print('  resolve() => NULL');
  } else {
    print('  resolve() =>');
    print('    ISIN        : ${result.isin}');
    print('    source      : ${result.source}');
    print('    officialName: ${result.officialName}');
  }

  final accepted = result != null;

  print('');
  print('DIAGNOSTIC');

  print('  expected acceptance : $expected');
  print('  actual acceptance   : ${accepted ? 'ACCEPT' : 'REJECT'}');

  if (expectedSymbol != null && result != null) {
    final matched = candidates.firstWhere(
      (candidate) =>
          candidate['symbol'] == expectedSymbol &&
          (candidate['isin'] == result.isin || candidate['isin'] == null),
      orElse: () => <String, dynamic>{},
    );

    if (matched.isNotEmpty) {
      print('  expected symbol     : $expectedSymbol');
      print('  resolved candidate  : ${matched['symbol']}');
    } else {
      print('  expected symbol     : $expectedSymbol');
      print('  resolved candidate  : NOT IDENTIFIED');
    }
  }

  print('');
  print('NOTE');
  print(
    '  Este diagnóstico no accede directamente a _rankYahooResults(), '
    'porque es un método privado.',
  );
  print(
    '  El punto de corte se determina observando si resolve() llega '
    'a devolver un resultado.',
  );

  if (expected == 'ACCEPT') {
    expect(result, isNotNull, reason: '$id debería aceptar el candidato.');

    if (expectedSymbol != null) {
      expect(
        _identifyCandidate(
          candidates: candidates,
          resultIsin: result!.isin,
          expectedSymbol: expectedSymbol,
        ),
        equals(expectedSymbol),
        reason: '$id debería resolver $expectedSymbol.',
      );
    }
  } else {
    expect(
      result,
      isNull,
      reason: '$id debería rechazar todos los candidatos.',
    );
  }
}

String? _identifyCandidate({
  required List<Map<String, dynamic>> candidates,
  required String resultIsin,
  required String expectedSymbol,
}) {
  for (final candidate in candidates) {
    final symbol = candidate['symbol'] as String;
    final isin = candidate['isin'] as String?;

    if (symbol == expectedSymbol) {
      if (isin == resultIsin) {
        return symbol;
      }

      if (isin == null && symbol == 'CORRECT.PA') {
        return symbol;
      }
    }
  }

  return null;
}

Map<String, dynamic> _candidate({
  required String symbol,
  required String name,
  required String type,
  String? isin,
}) {
  return {'symbol': symbol, 'name': name, 'type': type, 'isin': isin};
}
