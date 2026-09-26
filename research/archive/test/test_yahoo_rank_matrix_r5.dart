import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R5 - Candidatos falsos / frontera del umbral', () {
    test('R5.1 - nombre bueno + EQUITY: debe quedar descartado', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth Fund',
            'EQUITY',
            'FR0000993172',
          ),
        ],
      );

      // 0.55 - 0.30 + 0.10 = 0.35
      expect(result, isNull);
    });

    test('R5.2 - nombre bueno + ETF: debe quedar descartado', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth Fund',
            'ETF',
            'FR0000993172',
          ),
        ],
      );

      // 0.55 - 0.20 + 0.10 = 0.45
      expect(result, isNull);
    });

    test('R5.3 - nombre malo + MUTUALFUND: frontera problemática', () async {
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
      // Actualmente supera el umbral.
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.4 - nombre muy malo + MUTUALFUND sin ISIN: todavía puede pasar',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Completely Different Fund',
            'MUTUALFUND',
            null,
          ),
        ],
      );

      // Jaccard = 1/5 = 0.20
      // 0.20*0.55 + 0.30 = 0.41
      // Sin ISIN queda por debajo del umbral.
      expect(result, isNull);
    });

    test('R5.5 - ticker exacto + nombre incompatible + MUTUALFUND', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Completely Different Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 1/5 = 0.20
      // + exact ticker 0.20
      // + MUTUALFUND 0.30
      // + ISIN 0.10
      // = 0.71
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.6 - ticker exacto + nombre completamente incompatible',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Completely Unrelated Security',
            'MUTUALFUND',
            null,
          ),
        ],
      );

      // Jaccard = 0
      // + exact ticker 0.20
      // + MUTUALFUND 0.30
      // = 0.50
      // Está exactamente en el umbral.
      expect(result?.isin, isNull);
    });

    test('R5.7 - ticker distinto + nombre idéntico + MUTUALFUND + ISIN',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // 1.00*0.55 + 0.30 + 0.10 = 0.95
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.8 - ticker distinto + nombre casi incompatible + MUTUALFUND',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Bond',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 0/4 = 0
      // + MUTUALFUND 0.30
      // + ISIN 0.10
      // = 0.40
      expect(result, isNull);
    });

    test('R5.9 - Morningstar ID correcto + nombre incompatible',
        () async {
      final result = await _resolve(
        ticker: '0P0000X83M.DE',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        tickerQuotes: [
          _q(
            '0P0000X83M',
            'Completely Different Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 1/9 aproximadamente = 0.111...
      // + MUTUALFUND 0.30
      // + same Morningstar ID 0.10
      // + ISIN 0.10
      // ≈ 0.561
      // Actualmente supera el umbral pese al nombre incompatible.
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.10 - Morningstar ID correcto + nombre incompatible sin ISIN',
        () async {
      final result = await _resolve(
        ticker: '0P0000X83M.DE',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        tickerQuotes: [
          _q(
            '0P0000X83M',
            'Completely Different Fund',
            'MUTUALFUND',
            null,
          ),
        ],
      );

      // Jaccard ≈ 1/9 = 0.111...
      // + MUTUALFUND 0.30
      // + same Morningstar ID 0.10
      // ≈ 0.461
      expect(result, isNull);
    });

    test('R5.11 - ETF con ticker exacto + nombre perfecto + ISIN',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Alpha Growth Fund',
            'ETF',
            'FR0000993172',
          ),
        ],
      );

      // 0.55 + 0.20 - 0.20 + 0.10 = 0.65
      // Actualmente pasa a pesar de ser ETF.
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.12 - EQUITY con ticker exacto + nombre perfecto + ISIN',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Alpha Growth Fund',
            'EQUITY',
            'FR0000993172',
          ),
        ],
      );

      // 0.55 + 0.20 - 0.30 + 0.10 = 0.55
      // Actualmente todavía pasa el umbral.
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.13 - INDEX con ticker exacto + nombre perfecto + ISIN',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Alpha Growth Fund',
            'INDEX',
            'FR0000993172',
          ),
        ],
      );

      // 0.55 + 0.20 - 0.30 + 0.10 = 0.55
      // Actualmente todavía pasa el umbral.
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.14 - MUTUALFUND sin nombre común pero con ticker empieza por ticker',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUNDX.PA',
            'Completely Different Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 1/5 = 0.20
      // + startsWith 0.05
      // + MUTUALFUND 0.30
      // + ISIN 0.10
      // = 0.56
      expect(result?.isin, 'FR0000993172');
    });

    test('R5.15 - candidato sin ninguna señal positiva debe descartarse',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Completely Unrelated Security',
            'EQUITY',
            null,
          ),
        ],
      );

      // 0 - 0.30 = -0.30
      expect(result, isNull);
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
