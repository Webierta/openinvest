import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R1 - Ticker / Morningstar ID', () {
    test('R1.1 - ticker exacto gana por poco frente a nombre perfecto', () async {
      final result = await _resolve(
        ticker: 'ABC.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('ABC.PA', 'Alpha Growth', 'MUTUALFUND', 'FR0000993172'),
          _q('XYZ.PA', 'Alpha Growth Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      // ABC = 0.75*0.55 + 0.20 + 0.30 + 0.10 = 1.0125
      // XYZ = 1.00*0.55 + 0.30 + 0.10 = 0.95
      expect(result?.isin, 'FR0000993172');
    });

    test('R1.2 - mismo Morningstar ID recibe +0.10', () async {
      final result = await _resolve(
        ticker: '0P0000X83M.DE',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        tickerQuotes: [
          _q(
            '0P0000X83M',
            'PIMCO GIS Income Fund E Class USD Income',
            'MUTUALFUND',
            'FR0000993172',
          ),
          _q(
            'OTHER.DE',
            'PIMCO GIS Income Fund E Class USD Income',
            'MUTUALFUND',
            'FR0010135103',
          ),
        ],
      );

      expect(result?.isin, 'FR0000993172');
    });

    test('R1.3 - startsWith del ticker aporta +0.05', () async {
      final result = await _resolve(
        ticker: 'ABC.PA',
        fundName: 'Alpha Fund',
        tickerQuotes: [
          _q('ABCX.PA', 'Alpha Fund', 'MUTUALFUND', 'FR0000993172'),
          _q('XYZ.PA', 'Alpha Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      expect(result?.isin, 'FR0000993172');
    });
  });

  group('R2 - Tipo Yahoo', () {
    test('R2.1 - MUTUALFUND supera ETF con nombre equivalente', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('ETF.PA', 'Alpha Growth Fund', 'ETF', 'FR0000993172'),
          _q('FUND.PA', 'Alpha Growth Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      expect(result?.isin, 'FR0010135103');
    });

    test('R2.2 - MUTUALFUND supera EQUITY con nombre equivalente', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('EQTY.PA', 'Alpha Growth Fund', 'EQUITY', 'FR0000993172'),
          _q('FUND.PA', 'Alpha Growth Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      expect(result?.isin, 'FR0010135103');
    });

    test('R2.3 - EQUITY sin ticker exacto queda por debajo de 0.50', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('EQTY.PA', 'Alpha Growth Fund', 'EQUITY', 'FR0000993172'),
        ],
      );

      // 0.55 - 0.30 + 0.10 = 0.35
      expect(result, isNull);
    });

    test('R2.4 - ETF sin ticker exacto queda por debajo de 0.50', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('ETF.PA', 'Alpha Growth Fund', 'ETF', 'FR0000993172'),
        ],
      );

      // 0.55 - 0.20 + 0.10 = 0.45
      expect(result, isNull);
    });
  });

  group('R3 - Similitud de nombre', () {
    test('R3.1 - nombre exacto gana a coincidencia parcial', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'JPMorgan Global Bond Fund',
        tickerQuotes: [
          _q(
            'A.PA',
            'JPMorgan Global Bond Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
          _q(
            'B.PA',
            'JPMorgan Global Equity Fund',
            'MUTUALFUND',
            'FR0010135103',
          ),
        ],
      );

      expect(result?.isin, 'FR0000993172');
    });

    test('R3.2 - una clase diferente comparte casi todos los tokens', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'JPMorgan Global Bond Fund A EUR Acc',
        tickerQuotes: [
          _q(
            'A.PA',
            'JPMorgan Global Bond Fund B EUR Acc',
            'MUTUALFUND',
            'FR0000993172',
          ),
          _q(
            'B.PA',
            'JPMorgan Global Bond Fund A EUR Acc',
            'MUTUALFUND',
            'FR0010135103',
          ),
        ],
      );

      expect(result?.isin, 'FR0010135103');
    });

    test('R3.3 - EUR y USD se distinguen por el token de moneda', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Global Bond Fund EUR Acc',
        tickerQuotes: [
          _q(
            'USD.PA',
            'Global Bond Fund USD Acc',
            'MUTUALFUND',
            'FR0000993172',
          ),
          _q(
            'EUR.PA',
            'Global Bond Fund EUR Acc',
            'MUTUALFUND',
            'FR0010135103',
          ),
        ],
      );

      expect(result?.isin, 'FR0010135103');
    });

    test('R3.4 - candidato distinto pero con una palabra común puede superar 0.50', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Completely Different Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 1/5 = 0.20
      // 0.20*0.55 + 0.30 + 0.10 = 0.51
      expect(result?.isin, 'FR0000993172');
    });
  });

  group('R4 - ISIN', () {
    test('R4.1 - el ISIN aporta +0.10 en igualdad de señales', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('A.PA', 'Alpha Growth Fund', 'MUTUALFUND', null),
          _q('B.PA', 'Alpha Growth Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      expect(result?.isin, 'FR0010135103');
    });

    test('R4.2 - ticker exacto + ISIN supera nombre perfecto sin ticker', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('FUND.PA', 'Alpha Growth', 'MUTUALFUND', 'FR0000993172'),
          _q('OTHER.PA', 'Alpha Growth Fund', 'MUTUALFUND', 'FR0010135103'),
        ],
      );

      // FUND = 0.75*0.55 + 0.20 + 0.30 + 0.10 = 1.0125
      // OTHER = 1.00*0.55 + 0.30 + 0.10 = 0.95
      expect(result?.isin, 'FR0000993172');
    });
  });
}

Map<String, dynamic> _q(
  String symbol,
  String name,
  String type,
  String? isin,
) {
  return {
    'symbol': symbol,
    'longname': name,
    'quoteType': type,
    if (isin != null) 'isin': isin,
  };
}

Future<IsinResult?> _resolve({
  required String ticker,
  required String fundName,
  required List<Map<String, dynamic>> tickerQuotes,
}) async {
  final client = MockClient((request) async {
    final q = request.url.queryParameters['q'] ?? '';
    final quotes = q == ticker ? tickerQuotes : const <Map<String, dynamic>>[];

    return http.Response(
      jsonEncode({'quotes': quotes}),
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  final resolver = IsinResolver(
    client: client,
    foreignIsinProviders: const [],
  );

  return resolver.resolve(ticker: ticker, fundName: fundName);
}
