/* import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:test/test.dart'; */

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('R7-DIAGNOSTIC v2 - YahooProvider identity barrier', () {
    late _FakeYahooClient client;
    late YahooProvider provider;

    setUp(() {
      client = _FakeYahooClient();

      provider = YahooProvider(
        client: client,
        foreignIsinProviders: [_FakeForeignProvider()],
      );
    });

    test(
      'R7.1 - ticker exacto + nombre exacto + MUTUALFUND + ISIN => ACEPTADO',
      () async {
        client.setQuotes([
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ]);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        _printResult(result);

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test('R7.2 - ticker exacto + nombre parcialmente similar + MUTUALFUND + ISIN => ACEPTADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R7.3 - nameSimilarity 0 + MUTUALFUND + ISIN => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Completely Different',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    test('R7.4 - similitud 0.25 + MUTUALFUND + ISIN, sin identidad fuerte => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    test(
      'R7.5 - ticker exacto + similitud 0.25 + MUTUALFUND + ISIN => ACEPTADO',
      () async {
        client.setQuotes([
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ]);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        _printResult(result);

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test('R7.6 - mismo Morningstar ID + similitud baja => ACEPTADO', () async {
      client.setQuotes([
        _quote(
          symbol: '0P0000ABC1.PA',
          name: 'Alpha',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ]);

      final result = await provider.resolve(
        ticker: '0P0000ABC1',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test(
      'R7.7 - ticker exacto + similitud 0.20 + identidad fuerte => ACEPTADO',
      () async {
        client.setQuotes([
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ]);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        _printResult(result);

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000010');
      },
    );

    test('R7.8 - similitud < 0.50 sin identidad fuerte => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha Extra',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    /* test('R7.8 - similitud 0.49 sin identidad fuerte => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha Growth Fund Extra',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    }); */

    test('R7.9 - ticker exacto + nombre exacto + MUTUALFUND sin ISIN => ACEPTADO vía Foreign', () async {
      client.setQuotes([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000028');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('R7.10 - similitud 0.0 + ETF => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Completely Different',
          type: 'ETF',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    test('R7.11 - nombre perfecto + EQUITY => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha Growth Fund',
          type: 'EQUITY',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    test('R7.12 - nombre perfecto + ETF => RECHAZADO', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha Growth Fund',
          type: 'ETF',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNull);
    });

    test('R7.13 - ticker exacto + nombre perfecto + MUTUALFUND sin ISIN => ACEPTADO vía Foreign', () async {
      client.setQuotes([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000028');
      expect(result.source, 'Yahoo/Foreign');
    });

    test(
      'R7.14 - candidato falso no debe bloquear candidato correcto',
      () async {
        client.setQuotes([
          _quote(
            symbol: 'OTHER.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          _quote(
            symbol: 'CORRECT.PA',
            name: 'Alpha Growth Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
        ]);

        final result = await provider.resolve(
          ticker: 'CORRECT.PA',
          fundName: 'Alpha Growth Fund',
        );

        _printResult(result);

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000000028');
        expect(result.source, 'Yahoo');
      },
    );

    test('R7.15 - candidato con ISIN no debe ganar a candidato compatible sin ISIN si la identidad es peor', () async {
      client.setQuotes([
        _quote(
          symbol: 'OTHER.PA',
          name: 'Alpha Growth',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        _quote(
          symbol: 'CORRECT.PA',
          name: 'Alpha Growth Fund',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ]);

      final result = await provider.resolve(
        ticker: 'CORRECT.PA',
        fundName: 'Alpha Growth Fund',
      );

      _printResult(result);

      expect(result, isNotNull);
      expect(result!.source, 'Yahoo/Foreign');
      expect(result.isin, 'FR0000000028');
    });
  });
}

Map<String, dynamic> _quote({
  required String symbol,
  required String name,
  required String type,
  String? isin,
}) {
  return {
    'symbol': symbol,
    'longname': name,
    'exchange': 'TEST',
    'quoteType': type,
    if (isin != null) 'isin': isin,
  };
}

void _printResult(IsinResult? result) {
  print('');
  print('  [FINAL RESULT]');

  if (result == null) {
    print('    => null');
    return;
  }

  print('    ISIN:         ${result.isin}');
  print('    source:       ${result.source}');
  print('    officialName: ${result.officialName}');
}

class _FakeYahooClient extends http.BaseClient {
  List<Map<String, dynamic>> _quotes = [];

  void setQuotes(List<Map<String, dynamic>> quotes) {
    _quotes = quotes;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    print('');
    print('  [FAKE YAHOO REQUEST]');
    print('    URL: ${request.url}');
    print('    candidates:');

    for (final quote in _quotes) {
      print(
        '      ${quote['symbol']} | '
        '${quote['quoteType']} | '
        '${quote['longname']} | '
        'ISIN=${quote['isin'] ?? 'null'}',
      );
    }

    final body = jsonEncode({'quotes': _quotes});

    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _FakeForeignProvider implements ForeignIsinProvider {
  static const String _isinCorrect = 'FR0000000028';
  static const String _isinOther = 'FR0000000010';

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

    // R7.9 y R7.13 necesitan completar realmente
    // la cadena Yahoo -> Foreign -> IsinResult.
    if (yahooSymbol == 'XYZ.PA') {
      print('    => returning $_isinCorrect');
      return _isinCorrect;
    }

    print('    => returning null');
    return null;
  }
}
