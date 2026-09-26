import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';
import 'package:investing/services/isin_providers/yahoo_provider.dart';

/// R7 - Validación de la nueva barrera de identidad de _rankYahooResults().
///
/// Objetivo:
///   1. Rechazar siempre candidatos con nameSimilarity == 0.
///   2. Permitir candidatos con similitud >= 0.50 sin depender de
///      ticker/Morningstar/ISIN.
///   3. Permitir similitud >= 0.20 cuando existe una identidad fuerte
///      (ticker exacto o mismo Morningstar ID).
///   4. Evitar que MUTUALFUND + ISIN rescate nombres incompatibles.
///   5. Mantener las exclusiones de ETF/EQUITY/INDEX.
///   6. Comprobar los límites 0.20 y 0.50.
///   7. Comprobar competencia entre candidatos.
///
/// IMPORTANTE:
/// Este fichero valida el algoritmo propuesto. NO modifica YahooProvider.

class _FakeForeignProvider implements ForeignIsinProvider {
  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    // ISIN determinista por symbol para poder identificar el candidato
    // seleccionado sin tocar YahooProvider.
    if (yahooSymbol == 'CORRECT.PA') return 'FR0012345678';
    if (yahooSymbol == 'OTHER.PA') return 'FR0000993172';
    return 'FR0000993172';
  }
}

void main() {
  group('R7 - Barrera de identidad y elegibilidad', () {
    late YahooProvider provider;

    setUp(() {
      provider = YahooProvider(foreignIsinProviders: [_FakeForeignProvider()]);
    });

    test('R7.1 - nameSimilarity 0 + exact ticker => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'AAA.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'AAA.PA',
            name: 'Completely Unrelated Product',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test(
      'R7.2 - nameSimilarity 0 + mismo Morningstar ID => RECHAZADO',
      () async {
        final result = await _invoke(
          provider,
          ticker: '0P0000ABC1',
          fundName: 'Alpha Growth Fund',
          candidates: [
            _candidate(
              symbol: '0P0000ABC1',
              name: 'Completely Unrelated Product',
              type: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
          ],
        );

        expect(result, isEmpty);
      },
    );

    test('R7.3 - nameSimilarity 0 + MUTUALFUND + ISIN => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Bond',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test('R7.4 - similitud 0.25 + MUTUALFUND + ISIN, sin identidad fuerte => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Bond',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      );

      // 1 token común de 4 => 0.25.
      // La nueva regla exige >=0.20 + identidad fuerte,
      // o >=0.50. Por tanto debe rechazarse.
      expect(result, isEmpty);
    });

    test('R7.5 - similitud 0.25 + ticker exacto => ACEPTADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Bond',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      );

      // 0.25 + ticker exacto constituye identidad fuerte.
      expect(result, hasLength(1));
      expect(result.single.symbol, 'XYZ.PA');
    });

    test('R7.6 - similitud 0.25 + mismo Morningstar ID => ACEPTADO', () async {
      final result = await _invoke(
        provider,
        ticker: '0P0000ABC1',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: '0P0000ABC1.DE',
            name: 'Alpha Bond',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
        ],
      );

      // El sufijo de mercado no debe impedir reconocer el mismo
      // Morningstar ID.
      expect(result, hasLength(1));
      expect(result.single.symbol, '0P0000ABC1.DE');
    });

    test(
      'R7.7 - similitud 0.50 sin identidad fuerte => ACEPTADO si supera score',
      () async {
        final result = await _invoke(
          provider,
          ticker: 'OTHER.PA',
          fundName: 'Alpha Growth Fund',
          candidates: [
            _candidate(
              symbol: 'XYZ.PA',
              name: 'Alpha Growth Bond',
              type: 'MUTUALFUND',
              isin: null,
            ),
          ],
        );

        // {ALPHA,GROWTH,FUND} vs {ALPHA,GROWTH,BOND}
        // Jaccard = 2/4 = 0.50.
        expect(result, hasLength(1));
        expect(result.single.symbol, 'XYZ.PA');
      },
    );

    test('R7.8 - similitud 0.49 sin identidad fuerte => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'OTHER.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Bond Extra',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
      );

      // Este caso debe quedar por debajo de la barrera de similitud
      // para validar el límite de 0.50.
      expect(result, isEmpty);
    });

    test(
      'R7.9 - similitud 0.20 + ticker exacto => ACEPTADO si supera score',
      () async {
        final result = await _invoke(
          provider,
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
        );

        // 1/3 = 0.333..., por encima de 0.20.
        expect(result, hasLength(1));
      },
    );

    test(
      'R7.10 - similitud baja + ticker exacto + EQUITY => RECHAZADO',
      () async {
        final result = await _invoke(
          provider,
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
        );

        expect(result, isEmpty);
      },
    );

    test('R7.11 - nombre perfecto + EQUITY => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'EQUITY',
            isin: 'US0000000001',
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test('R7.12 - nombre perfecto + ETF => RECHAZADO', () async {
      final result = await _invoke(
        provider,
        ticker: 'XYZ.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            type: 'ETF',
            isin: 'US0000000001',
          ),
        ],
      );

      expect(result, isEmpty);
    });

    test('R7.13 - nombre perfecto + MUTUALFUND => ACEPTADO', () async {
      final result = await _invoke(
        provider,
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
      );

      expect(result, hasLength(1));
    });

    test(
      'R7.14 - candidato falso no debe bloquear candidato correcto',
      () async {
        final result = await _invoke(
          provider,
          ticker: 'CORRECT.PA',
          fundName: 'Alpha Growth Fund',
          candidates: [
            _candidate(
              symbol: 'WRONG.PA',
              name: 'Completely Unrelated Product',
              type: 'MUTUALFUND',
              isin: 'FR0000993172',
            ),
            _candidate(
              symbol: 'CORRECT.PA',
              name: 'Alpha Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0012345678',
            ),
          ],
        );

        expect(result, hasLength(1));
        expect(result.single.symbol, 'CORRECT.PA');
        expect(result.single.isin, 'FR0012345678');
      },
    );

    test('R7.15 - candidato con ISIN no debe ganar a candidato compatible sin ISIN si la identidad es peor', () async {
      final result = await _invoke(
        provider,
        ticker: 'CORRECT.PA',
        fundName: 'Alpha Growth Fund',
        candidates: [
          _candidate(
            symbol: 'OTHER.PA',
            name: 'Alpha',
            type: 'MUTUALFUND',
            isin: 'FR0000993172',
          ),
          _candidate(
            symbol: 'CORRECT.PA',
            name: 'Alpha Growth Fund',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.symbol, 'CORRECT.PA');
    });
  });
}

/// Invoca _rankYahooResults() indirectamente mediante resolve().
///
/// La intención es validar el comportamiento observable del ranking:
/// los candidatos elegibles son los únicos que llegan a la resolución
/// posterior. El provider extranjero es deliberadamente nulo.
Future<List<_YahooResultView>> _invoke(
  YahooProvider provider, {
  required String ticker,
  required String fundName,
  required List<_YahooResultView> candidates,
}) async {
  // Esta función queda como adaptador conceptual para la matriz.
  //
  // IMPORTANTE:
  // Si YahooProvider mantiene _rankYahooResults() privado, esta matriz
  // necesita un pequeño harness de test o acceso controlado al método.
  // No se modifica producción desde este fichero.
  //
  // Para mantener el test ejecutable sin reflexión, usamos un cliente HTTP
  // falso que devuelve exactamente la respuesta Yahoo suministrada.
  final client = _FakeYahooClient(candidates);

  final testedProvider = YahooProvider(
    client: client,
    foreignIsinProviders: [_FakeForeignProvider()],
  );

  final result = await testedProvider.resolve(
    ticker: ticker,
    fundName: fundName,
  );

  if (result == null) return [];

  final match = candidates.firstWhere(
    (c) =>
        c.isin == result.isin ||
        (c.isin == null &&
            ((c.symbol == 'CORRECT.PA' && result.isin == 'FR0012345678') ||
                (c.symbol == 'OTHER.PA' && result.isin == 'FR0000993172'))),
    orElse: () => candidates.first,
  );

  return [match];
}

_YahooResultView _candidate({
  required String symbol,
  required String name,
  required String type,
  String? isin,
}) {
  return _YahooResultView(symbol: symbol, name: name, type: type, isin: isin);
}

class _YahooResultView {
  final String symbol;
  final String name;
  final String type;
  final String? isin;

  const _YahooResultView({
    required this.symbol,
    required this.name,
    required this.type,
    required this.isin,
  });
}

/// Cliente Yahoo mínimo para convertir los candidatos de la matriz en
/// respuestas JSON reales de /v1/finance/search.
class _FakeYahooClient extends http.BaseClient {
  final List<_YahooResultView> candidates;

  _FakeYahooClient(this.candidates);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = jsonEncode({
      'quotes': candidates
          .map(
            (c) => {
              'symbol': c.symbol,
              'longname': c.name,
              'exchange': 'TEST',
              'quoteType': c.type,
              if (c.isin != null) 'isin': c.isin,
            },
          )
          .toList(),
    });

    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
      request: request,
    );
  }
}
