import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('E1 - Elegibilidad por similitud de nombre', () {
    test('E1.1 - nombre perfecto + MUTUALFUND: elegible', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('OTHER.PA', 'Alpha Growth Fund', 'MUTUALFUND', null),
        ],
      );

      // Candidato claramente compatible.
      // Sin foreign provider no se obtiene ISIN; null es esperado.
      expect(result, isNull);
    });

    test('E1.2 - nombre razonablemente relacionado + MUTUALFUND: elegible',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q('OTHER.PA', 'Alpha Fund', 'MUTUALFUND', null),
        ],
      );

      // Jaccard = 2/4 = 0.50
      // score = 0.50*0.55 + 0.30 = 0.575
      // Debe superar el umbral de ranking.
      expect(result, isNull);
    });

    test('E1.3 - nombre demasiado diferente + MUTUALFUND + ISIN: no elegible',
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

      // Jaccard = 1/4 = 0.25.
      // Aunque score = 0.5375, la propuesta E1 exige
      // una relación nominal mínima más fuerte para la elegibilidad.
      expect(result, isNull);
    });

    test('E1.4 - nombre completamente incompatible: no elegible', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Completely Unrelated Security',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // nameSimilarity = 0.
      // El ISIN y MUTUALFUND no deben rescatar un nombre incompatible.
      expect(result, isNull);
    });
  });

  group('E2 - Elegibilidad con ticker exacto', () {
    test('E2.1 - ticker exacto + relación nominal mínima: elegible',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'FUND.PA',
            'Alpha Bond',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // Jaccard = 1/4 = 0.25.
      // exactTicker + MUTUALFUND + ISIN produce score suficiente.
      // La relación nominal mínima permite continuar.
      expect(result?.isin, 'FR0000993172');
    });

    test('E2.2 - ticker exacto + nombre completamente incompatible: no elegible',
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

      // exactTicker no debe compensar nameSimilarity = 0.
      expect(result, isNull);
    });

    test('E2.3 - ticker distinto + nombre idéntico: elegible', () async {
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

      // La identidad puede establecerse por nombre aunque el ticker no sea exacto.
      expect(result?.isin, 'FR0000993172');
    });
  });

  group('E3 - Elegibilidad con Morningstar ID', () {
    test('E3.1 - Morningstar ID correcto + relación nominal mínima: elegible',
        () async {
      final result = await _resolve(
        ticker: '0P0000X83M.DE',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        tickerQuotes: [
          _q(
            '0P0000X83M',
            'PIMCO GIS Income Fund E Class USD',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      expect(result?.isin, 'FR0000993172');
    });

    test('E3.2 - Morningstar ID correcto + nombre completamente incompatible: no elegible',
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

      // sameMorningstarId no debe sustituir la comprobación nominal mínima.
      expect(result, isNull);
    });
  });

  group('E4 - MUTUALFUND + ISIN no es suficiente', () {
    test('E4.1 - MUTUALFUND + ISIN + nombre insuficiente: no elegible',
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

      expect(result, isNull);
    });

    test('E4.2 - MUTUALFUND + ISIN + nombre suficientemente relacionado: elegible',
        () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Fund',
            'MUTUALFUND',
            'FR0000993172',
          ),
        ],
      );

      // La similitud nominal permite utilizar el ISIN como señal adicional.
      expect(result?.isin, 'FR0000993172');
    });

    test('E4.3 - MUTUALFUND sin ISIN + nombre bueno: sigue siendo candidato',
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

      // Debe llegar a resolución extranjera aunque Yahoo no aporte ISIN.
      // Sin foreign provider el resultado final es null.
      expect(result, isNull);
    });
  });

  group('E5 - Tipos Yahoo no compatibles', () {
    test('E5.1 - nombre perfecto + EQUITY: no elegible', () async {
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

      expect(result, isNull);
    });

    test('E5.2 - nombre perfecto + INDEX: no elegible', () async {
      final result = await _resolve(
        ticker: 'FUND.PA',
        fundName: 'Alpha Growth Fund',
        tickerQuotes: [
          _q(
            'OTHER.PA',
            'Alpha Growth Fund',
            'INDEX',
            'FR0000993172',
          ),
        ],
      );

      expect(result, isNull);
    });

    test('E5.3 - nombre perfecto + ETF: no elegible', () async {
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

      expect(result, isNull);
    });

    test('E5.4 - MUTUALFUND + nombre perfecto: elegible', () async {
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
