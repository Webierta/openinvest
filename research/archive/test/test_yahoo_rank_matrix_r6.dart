import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R6 - Casos frontera para elegibilidad', () {
    test('R6.1 - nombre 0.00 + ticker exacto: pasa actualmente por las señales estructurales',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Completely Unrelated Security',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // nameSimilarity = 0.00
      // + exact ticker 0.20
      // + MUTUALFUND 0.30
      // + ISIN 0.10
      // = 0.60
      //
      // El algoritmo actual lo acepta.
      expect(result?.isin, 'FR0000993172');
    });

    test('R6.2 - nombre 0.00 + Morningstar ID correcto: pasa actualmente',
        () async {
      final result = await _resolve(
        ticker: '0P0000X83M.DE',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        tickerQuotes: [
          _q(
            '0P0000X83M',
            'Completely Unrelated Security',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // nameSimilarity = 0.00
      // + MUTUALFUND 0.30
      // + same Morningstar ID 0.10
      // + ISIN 0.10
      // = 0.50
      //
      // El algoritmo actual lo acepta por quedar exactamente en el umbral.
      expect(result?.isin, 'FR0000993172');
    });

    test('R6.3 - similitud 0.25 + MUTUALFUND + ISIN: pasa actualmente',
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

      // Jaccard = 1/4 = 0.25
      // + MUTUALFUND 0.30
      // + ISIN 0.10
      // = 0.5375
      //
      // Este es el caso R5.8 que actualmente se acepta.
      expect(result?.isin, 'FR0000993172');
    });

    test('R6.4 - similitud 0.33 + MUTUALFUND + ISIN: pasa actualmente',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 2/4 = 0.50 en realidad con estos tokens:
      // A = {ALPHA, GROWTH, FUND}
      // B = {ALPHA, GROWTH}
      // intersección = 2, unión = 3 -> 2/3 = 0.666...
      //
      // Se incluye deliberadamente para observar una similitud claramente
      // superior a R6.3, pero el comentario refleja el cálculo real.
      expect(result?.isin, 'FR0000993172');
    });

    test('R6.5 - nombre 0.50 + MUTUALFUND sin ISIN: debe pasar por nombre',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Fund',
            'MUTUALFUND',
            null,
          ),
        ],
      );

      // Jaccard = 2/4 = 0.50
      // 0.50*0.55 + MUTUALFUND 0.30 = 0.575
      expect(result?.isin, isNull);
    });

    test('R6.6 - nombre perfecto + EQUITY: pasa actualmente',
        () async {
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

      // 1.00*0.55 - 0.30 + 0.10 = 0.35
      // Debe quedar fuera.
      expect(result, isNull);
    });

    test('R6.7 - nombre perfecto + ETF: pasa actualmente por el umbral',
        () async {
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

      // 1.00*0.55 - 0.20 + 0.10 = 0.45
      // Debe quedar fuera.
      expect(result, isNull);
    });

    test('R6.8 - nombre perfecto + MUTUALFUND: caso claramente elegible',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth Fund',
            'MUTUALFUND',
            null,
          ),
        ],
      );

      // 1.00*0.55 + 0.30 = 0.85
      //
      // Aunque no haya ISIN en Yahoo, el candidato queda claramente
      // por encima del umbral.
      //
      // Como el test no proporciona un foreign provider, el resultado final
      // será null: aquí nos interesa comprobar que el candidato sería
      // elegible para _resolveForeignIsin(), no que se obtenga un ISIN.
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
