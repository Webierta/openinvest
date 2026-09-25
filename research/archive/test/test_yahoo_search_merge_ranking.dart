import 'package:test/test.dart';

/// ============================================================================
/// TEST EXPERIMENTAL
/// ============================================================================
///
/// Objetivo:
/// ---------
/// Reproducir de forma aislada el flujo completo de YahooProvider:
///
///   1. búsqueda por ticker
///   2. búsqueda por nombre
///   3. acumulación por symbol
///   4. merge de resultados con el mismo symbol
///   5. ranking actual
///
/// Se comparan dos estrategias:
///
///   OLD    -> comportamiento actual: results[symbol] = incoming
///   MERGED -> nuevo comportamiento: merge(existing, incoming)
///
/// IMPORTANTE:
/// -----------
/// Este archivo NO utiliza YahooProvider de producción.
/// Es deliberadamente independiente para poder experimentar sin modificar
/// lib/services/isin_providers/yahoo_provider.dart
///
/// Ejecutar con:
///
///   dart test research/archive/test/test_yahoo_search_merge_ranking.dart
///
/// ============================================================================

void main() {
  group('YahooProvider - search + merge + ranking', () {
    // -------------------------------------------------------------------------
    // GRUPO A
    // -------------------------------------------------------------------------

    test('A - symbol único: OLD y MERGED producen el mismo resultado', () {
      final tickerResults = <_YahooResult>[
        _YahooResult(
          symbol: 'AAA.PA',
          name: 'Alpha Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000001',
        ),
      ];

      final nameResults = <_YahooResult>[];

      final old = _searchOld(
        tickerResults: tickerResults,
        nameResults: nameResults,
      );

      final merged = _searchMerged(
        tickerResults: tickerResults,
        nameResults: nameResults,
        fundName: 'Alpha Fund',
      );

      final oldRanked = _rank(
        old.values.toList(),
        ticker: 'AAA.PA',
        fundName: 'Alpha Fund',
      );

      final mergedRanked = _rank(
        merged.values.toList(),
        ticker: 'AAA.PA',
        fundName: 'Alpha Fund',
      );

      expect(old.length, 1);
      expect(merged.length, 1);

      expect(oldRanked.map((x) => x.symbol), ['AAA.PA']);
      expect(mergedRanked.map((x) => x.symbol), ['AAA.PA']);

      expect(merged['AAA.PA']!.isin, 'FR0000000001');
    });

    // -------------------------------------------------------------------------
    // GRUPO B
    // -------------------------------------------------------------------------

    test(
      'B - ISIN solamente en búsqueda por nombre: MERGED conserva el ISIN',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'BBB.PA',
            name: 'Beta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ];

        final nameResults = <_YahooResult>[
          _YahooResult(
            symbol: 'BBB.PA',
            name: 'Beta Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000002',
          ),
        ];

        final old = _searchOld(
          tickerResults: tickerResults,
          nameResults: nameResults,
        );

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: nameResults,
          fundName: 'Beta Fund',
        );

        final oldResult = old['BBB.PA']!;
        final mergedResult = merged['BBB.PA']!;

        expect(
          oldResult.isin,
          'FR0000000002',
          reason: 'En este orden concreto OLD conserva el segundo resultado.',
        );

        expect(
          mergedResult.isin,
          'FR0000000002',
          reason: 'MERGED debe conservar el único ISIN disponible.',
        );

        expect(mergedResult.symbol, 'BBB.PA');
      },
    );

    test(
      'B - el resultado posterior sin ISIN NO destruye un ISIN existente',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'BBB2.PA',
            name: 'Beta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000003',
          ),
        ];

        final nameResults = <_YahooResult>[
          _YahooResult(
            symbol: 'BBB2.PA',
            name: 'Beta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ];

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: nameResults,
          fundName: 'Beta Fund',
        );

        expect(merged['BBB2.PA']!.isin, 'FR0000000003');
      },
    );

    // -------------------------------------------------------------------------
    // GRUPO C
    // -------------------------------------------------------------------------

    test(
      'C - ISIN solamente en búsqueda por ticker: MERGED conserva el ISIN',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'CCC.PA',
            name: 'Gamma Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000004',
          ),
        ];

        final nameResults = <_YahooResult>[
          _YahooResult(
            symbol: 'CCC.PA',
            name: 'Gamma Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ];

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: nameResults,
          fundName: 'Gamma Fund',
        );

        expect(merged['CCC.PA']!.isin, 'FR0000000004');
      },
    );

    test(
      'C - resultado de nombre posterior no destruye datos útiles del ticker',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'CCC2.PA',
            name: 'Gamma Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000005',
          ),
        ];

        final nameResults = <_YahooResult>[
          _YahooResult(
            symbol: 'CCC2.PA',
            name: 'Gamma Fund',
            exchange: '',
            type: '',
            isin: null,
          ),
        ];

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: nameResults,
          fundName: 'Gamma Fund',
        );

        final result = merged['CCC2.PA']!;

        expect(result.isin, 'FR0000000005');
        expect(result.exchange, 'PAR');
        expect(result.type, 'MUTUALFUND');
      },
    );

    // -------------------------------------------------------------------------
    // GRUPO D
    // -------------------------------------------------------------------------

    test('D - mismo symbol y mismo ISIN: MERGED conserva el ISIN', () {
      final tickerResults = <_YahooResult>[
        _YahooResult(
          symbol: 'DDD.PA',
          name: 'Delta Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000006',
        ),
      ];

      final nameResults = <_YahooResult>[
        _YahooResult(
          symbol: 'DDD.PA',
          name: 'Delta Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000006',
        ),
      ];

      final merged = _searchMerged(
        tickerResults: tickerResults,
        nameResults: nameResults,
        fundName: 'Delta Fund',
      );

      expect(merged.length, 1);
      expect(merged['DDD.PA']!.isin, 'FR0000000006');
    });

    test(
      'D - mismo symbol, nombres diferentes: se conserva el nombre más similar',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'DDD2.PA',
            name: 'Completely Different Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000007',
          ),
        ];

        final nameResults = <_YahooResult>[
          _YahooResult(
            symbol: 'DDD2.PA',
            name: 'Delta Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000007',
          ),
        ];

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: nameResults,
          fundName: 'Delta Fund',
        );

        expect(merged['DDD2.PA']!.name, 'Delta Fund Class A');

        expect(merged['DDD2.PA']!.isin, 'FR0000000007');
      },
    );

    // -------------------------------------------------------------------------
    // GRUPO E
    // -------------------------------------------------------------------------

    test('E - ISIN conflictivo: MERGED NO elige arbitrariamente un ISIN', () {
      final tickerResults = <_YahooResult>[
        _YahooResult(
          symbol: 'EEE.PA',
          name: 'Epsilon Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000008',
        ),
      ];

      final nameResults = <_YahooResult>[
        _YahooResult(
          symbol: 'EEE.PA',
          name: 'Epsilon Fund Class A',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'LU0000000008',
        ),
      ];

      final merged = _searchMerged(
        tickerResults: tickerResults,
        nameResults: nameResults,
        fundName: 'Epsilon Fund',
      );

      expect(
        merged['EEE.PA']!.isin,
        isNull,
        reason:
            'Ante dos ISIN diferentes para el mismo symbol no debemos '
            'escoger uno arbitrariamente.',
      );
    });

    test('E - ISIN conflictivo: el candidato sigue existiendo para ranking/resolución', () {
      final tickerResults = <_YahooResult>[
        _YahooResult(
          symbol: 'EEE2.PA',
          name: 'Epsilon Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000009',
        ),
      ];

      final nameResults = <_YahooResult>[
        _YahooResult(
          symbol: 'EEE2.PA',
          name: 'Epsilon Fund Class A',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'LU0000000009',
        ),
      ];

      final merged = _searchMerged(
        tickerResults: tickerResults,
        nameResults: nameResults,
        fundName: 'Epsilon Fund',
      );

      final ranked = _rank(
        merged.values.toList(),
        ticker: 'EEE2.PA',
        fundName: 'Epsilon Fund',
      );

      expect(merged.length, 1);
      expect(ranked.length, 1);
      expect(ranked.single.symbol, 'EEE2.PA');
      expect(ranked.single.isin, isNull);
    });

    // -------------------------------------------------------------------------
    // CASO REAL DE LA REVISIÓN
    // -------------------------------------------------------------------------

    test('CASO REAL - MYFUND.PA: merge conserva MUTUALFUND + ISIN', () {
      final tickerResults = <_YahooResult>[
        _YahooResult(
          symbol: 'MYFUND.PA',
          name: 'My Fund ETF',
          exchange: 'PAR',
          type: 'ETF',
          isin: null,
        ),
      ];

      final nameResults = <_YahooResult>[
        _YahooResult(
          symbol: 'MYFUND.PA',
          name: 'My Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0010135103',
        ),
        _YahooResult(
          symbol: 'OTHER.PA',
          name: 'Other Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000993172',
        ),
      ];

      final old = _searchOld(
        tickerResults: tickerResults,
        nameResults: nameResults,
      );

      final merged = _searchMerged(
        tickerResults: tickerResults,
        nameResults: nameResults,
        fundName: 'My Fund',
      );

      final oldRanked = _rank(
        old.values.toList(),
        ticker: 'MYFUND.PA',
        fundName: 'My Fund',
      );

      final mergedRanked = _rank(
        merged.values.toList(),
        ticker: 'MYFUND.PA',
        fundName: 'My Fund',
      );

      // Ambos pipelines deben tener los mismos símbolos candidatos.
      expect(old.keys.toSet(), equals(merged.keys.toSet()));

      // El candidato correcto sigue siendo MYFUND.PA.
      expect(oldRanked.first.symbol, 'MYFUND.PA');
      expect(mergedRanked.first.symbol, 'MYFUND.PA');

      // La diferencia importante:
      // OLD depende de cuál fue el resultado que quedó último.
      // MERGED conserva la información complementaria.
      final mergedMyFund = merged['MYFUND.PA']!;

      expect(mergedMyFund.name, 'My Fund');
      expect(mergedMyFund.type, 'MUTUALFUND');
      expect(mergedMyFund.isin, 'FR0010135103');
    });

    // -------------------------------------------------------------------------
    // DUPLICADOS DENTRO DE UNA MISMA RESPUESTA
    // -------------------------------------------------------------------------

    test(
      'DUPLICADO - dos entradas del mismo symbol dentro de una consulta',
      () {
        final tickerResults = <_YahooResult>[
          _YahooResult(
            symbol: 'DUP.PA',
            name: 'Duplicate Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
          _YahooResult(
            symbol: 'DUP.PA',
            name: 'Duplicate Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
        ];

        final merged = _searchMerged(
          tickerResults: tickerResults,
          nameResults: const [],
          fundName: 'Duplicate Fund',
        );

        expect(merged.length, 1);
        expect(merged['DUP.PA']!.isin, 'FR0000000010');
        expect(merged['DUP.PA']!.name, 'Duplicate Fund');
      },
    );

    // -------------------------------------------------------------------------
    // ORDEN DE LAS CONSULTAS
    // -------------------------------------------------------------------------

    test(
      'ORDEN - ticker->nombre y nombre->ticker producen la misma fusión',
      () {
        final tickerResult = _YahooResult(
          symbol: 'ORDER.PA',
          name: 'Order Fund',
          exchange: 'PAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000011',
        );

        final nameResult = _YahooResult(
          symbol: 'ORDER.PA',
          name: 'Order Fund Class A',
          exchange: '',
          type: '',
          isin: null,
        );

        final forward = _searchMerged(
          tickerResults: [tickerResult],
          nameResults: [nameResult],
          fundName: 'Order Fund',
        );

        final reverse = _searchMerged(
          tickerResults: [nameResult],
          nameResults: [tickerResult],
          fundName: 'Order Fund',
        );

        expect(forward['ORDER.PA']!.symbol, reverse['ORDER.PA']!.symbol);

        expect(forward['ORDER.PA']!.isin, reverse['ORDER.PA']!.isin);

        expect(forward['ORDER.PA']!.exchange, reverse['ORDER.PA']!.exchange);

        expect(forward['ORDER.PA']!.type, reverse['ORDER.PA']!.type);

        expect(forward['ORDER.PA']!.name, reverse['ORDER.PA']!.name);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // RESUMEN
  // ---------------------------------------------------------------------------

  test('RESUMEN - ejecutar OLD y MERGED sobre A/B/C/D/E', () {
    final cases = <_Case>[
      _Case(
        id: 'A',
        ticker: 'AAA.PA',
        fundName: 'Alpha Fund',
        tickerResults: [
          _YahooResult(
            symbol: 'AAA.PA',
            name: 'Alpha Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000001',
          ),
        ],
        nameResults: const [],
      ),
      _Case(
        id: 'B',
        ticker: 'BBB.PA',
        fundName: 'Beta Fund',
        tickerResults: [
          _YahooResult(
            symbol: 'BBB.PA',
            name: 'Beta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
        nameResults: [
          _YahooResult(
            symbol: 'BBB.PA',
            name: 'Beta Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000002',
          ),
        ],
      ),
      _Case(
        id: 'C',
        ticker: 'CCC.PA',
        fundName: 'Gamma Fund',
        tickerResults: [
          _YahooResult(
            symbol: 'CCC.PA',
            name: 'Gamma Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000004',
          ),
        ],
        nameResults: [
          _YahooResult(
            symbol: 'CCC.PA',
            name: 'Gamma Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
        ],
      ),
      _Case(
        id: 'D',
        ticker: 'DDD.PA',
        fundName: 'Delta Fund',
        tickerResults: [
          _YahooResult(
            symbol: 'DDD.PA',
            name: 'Delta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000006',
          ),
        ],
        nameResults: [
          _YahooResult(
            symbol: 'DDD.PA',
            name: 'Delta Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000006',
          ),
        ],
      ),
      _Case(
        id: 'E',
        ticker: 'EEE.PA',
        fundName: 'Epsilon Fund',
        tickerResults: [
          _YahooResult(
            symbol: 'EEE.PA',
            name: 'Epsilon Fund',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000008',
          ),
        ],
        nameResults: [
          _YahooResult(
            symbol: 'EEE.PA',
            name: 'Epsilon Fund Class A',
            exchange: 'PAR',
            type: 'MUTUALFUND',
            isin: 'LU0000000008',
          ),
        ],
      ),
    ];

    for (final testCase in cases) {
      final old = _searchOld(
        tickerResults: testCase.tickerResults,
        nameResults: testCase.nameResults,
      );

      final merged = _searchMerged(
        tickerResults: testCase.tickerResults,
        nameResults: testCase.nameResults,
        fundName: testCase.fundName,
      );

      final oldRanked = _rank(
        old.values.toList(),
        ticker: testCase.ticker,
        fundName: testCase.fundName,
      );

      final mergedRanked = _rank(
        merged.values.toList(),
        ticker: testCase.ticker,
        fundName: testCase.fundName,
      );

      print('');
      print('------------------------------------------------------------');
      print('GRUPO ${testCase.id}');
      print('Ticker : ${testCase.ticker}');
      print('Nombre : ${testCase.fundName}');
      print('------------------------------------------------------------');

      print(
        'OLD    : '
        '${oldRanked.map((x) => '${x.symbol}/${x.type}/${x.isin}').join(', ')}',
      );

      print(
        'MERGED : '
        '${mergedRanked.map((x) => '${x.symbol}/${x.type}/${x.isin}').join(', ')}',
      );

      print('Candidatos OLD    : ${old.length}');
      print('Candidatos MERGED : ${merged.length}');

      // El merge no debe crear ni eliminar símbolos.
      expect(
        old.keys.toSet(),
        equals(merged.keys.toSet()),
        reason: 'El merge no debe modificar el conjunto de candidatos.',
      );

      // Debe existir al menos un candidato.
      expect(mergedRanked, isNotEmpty);

      // Para estos escenarios sintéticos el candidato principal debe seguir
      // siendo el symbol del ticker.
      expect(
        mergedRanked.first.symbol,
        testCase.ticker,
        reason: 'La fusión no debe modificar la decisión de relevancia del ranking.',
      );
    }
  });
}

// ============================================================================
// MODELO AISLADO
// ============================================================================

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String? isin;

  const _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    this.isin,
  });

  @override
  String toString() {
    return '$symbol | $name | $exchange | $type | ${isin ?? '-'}';
  }
}

class _Case {
  final String id;
  final String ticker;
  final String fundName;
  final List<_YahooResult> tickerResults;
  final List<_YahooResult> nameResults;

  const _Case({
    required this.id,
    required this.ticker,
    required this.fundName,
    required this.tickerResults,
    required this.nameResults,
  });
}

// ============================================================================
// IMPLEMENTACIÓN "OLD"
// ============================================================================
//
// Reproduce exactamente la idea de la implementación actual:
//
//   results[symbol] = incoming;
//
// El último resultado recibido para un symbol sustituye al anterior.
// ============================================================================

Map<String, _YahooResult> _searchOld({
  required List<_YahooResult> tickerResults,
  required List<_YahooResult> nameResults,
}) {
  final results = <String, _YahooResult>{};

  for (final result in tickerResults) {
    results[result.symbol] = result;
  }

  for (final result in nameResults) {
    results[result.symbol] = result;
  }

  return results;
}

// ============================================================================
// IMPLEMENTACIÓN "MERGED"
// ============================================================================
//
// Mismo flujo que _searchOld(), pero cuando el symbol ya existe se fusionan
// los dos resultados.
// ============================================================================

Map<String, _YahooResult> _searchMerged({
  required List<_YahooResult> tickerResults,
  required List<_YahooResult> nameResults,
  required String fundName,
}) {
  final results = <String, _YahooResult>{};

  void addResult(_YahooResult incoming) {
    final symbol = incoming.symbol;
    final existing = results[symbol];

    if (existing == null) {
      results[symbol] = incoming;
    } else {
      results[symbol] = _mergeYahooResult(existing, incoming, fundName);
    }
  }

  // Primera consulta: ticker.
  for (final result in tickerResults) {
    addResult(result);
  }

  // Segunda consulta: nombre.
  for (final result in nameResults) {
    addResult(result);
  }

  return results;
}

// ============================================================================
// MERGE
// ============================================================================

_YahooResult _mergeYahooResult(
  _YahooResult existing,
  _YahooResult incoming,
  String fundName,
) {
  final name = _chooseBestName(existing.name, incoming.name, fundName);

  final exchange = existing.exchange.trim().isNotEmpty
      ? existing.exchange
      : incoming.exchange;

  final type = _chooseBestType(existing.type, incoming.type);

  final existingIsin = existing.isin;
  final incomingIsin = incoming.isin;

  String? isin;

  if (existingIsin == null) {
    isin = incomingIsin;
  } else if (incomingIsin == null) {
    isin = existingIsin;
  } else if (existingIsin == incomingIsin) {
    isin = existingIsin;
  } else {
    // ISIN conflictivo:
    // no elegir arbitrariamente uno de los dos.
    isin = null;
  }

  return _YahooResult(
    symbol: existing.symbol,
    name: name,
    exchange: exchange,
    type: type,
    isin: isin,
  );
}

// ============================================================================
// SELECCIÓN DE NOMBRE
// ============================================================================

String _chooseBestName(String existing, String incoming, String fundName) {
  final existingTrimmed = existing.trim();
  final incomingTrimmed = incoming.trim();

  if (existingTrimmed.isEmpty) return incomingTrimmed;
  if (incomingTrimmed.isEmpty) return existingTrimmed;

  final existingSimilarity = _nameSimilarity(fundName, existingTrimmed);

  final incomingSimilarity = _nameSimilarity(fundName, incomingTrimmed);

  if (incomingSimilarity > existingSimilarity) {
    return incomingTrimmed;
  }

  return existingTrimmed;
}

// ============================================================================
// SELECCIÓN DE TYPE
// ============================================================================

String _chooseBestType(String existing, String incoming) {
  final existingTrimmed = existing.trim();
  final incomingTrimmed = incoming.trim();

  if (existingTrimmed.isEmpty) return incomingTrimmed;
  if (incomingTrimmed.isEmpty) return existingTrimmed;

  final existingType = existingTrimmed.toUpperCase();
  final incomingType = incomingTrimmed.toUpperCase();

  if (existingType == incomingType) {
    return existingTrimmed;
  }

  // En caso de conflicto MUTUALFUND tiene prioridad porque es el tipo
  // que el ranking actual favorece.
  if (existingType == 'MUTUALFUND') {
    return existingTrimmed;
  }

  if (incomingType == 'MUTUALFUND') {
    return incomingTrimmed;
  }

  // Para otros conflictos no hacemos una clasificación nueva.
  // Conservamos el valor existente.
  return existingTrimmed;
}

// ============================================================================
// RANKING ACTUAL
// ============================================================================
//
// Esta función reproduce las reglas actuales de _rankYahooResults().
// NO se modifica como consecuencia del merge.
// ============================================================================

List<_YahooResult> _rank(
  List<_YahooResult> results, {
  required String ticker,
  required String fundName,
}) {
  final normalizedTicker = ticker.toUpperCase();

  final scored =
      results
          .map((result) {
            final symbol = result.symbol.toUpperCase();
            final type = result.type.toUpperCase();

            final nameSimilarity = _nameSimilarity(fundName, result.name);

            var score = nameSimilarity * 0.55;

            if (symbol == normalizedTicker) {
              score += 0.20;
            }

            if (symbol.startsWith(normalizedTicker)) {
              score += 0.05;
            }

            if (type == 'MUTUALFUND') {
              score += 0.30;
            } else if (type == 'ETF') {
              score -= 0.20;
            } else if (type == 'EQUITY' || type == 'INDEX') {
              score -= 0.30;
            }

            if (_sameMorningstarId(symbol, normalizedTicker)) {
              score += 0.10;
            }

            if (result.isin != null) {
              score += 0.10;
            }

            return (result: result, score: score);
          })
          .where((item) => item.score >= 0.50)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  return scored.map((item) => item.result).toList();
}

// ============================================================================
// MORNINGSTAR ID
// ============================================================================

bool _sameMorningstarId(String a, String b) {
  String normalize(String value) {
    final match = RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$')
        .firstMatch(value.trim().toUpperCase());

    return match?.group(1) ?? value.trim().toUpperCase();
  }

  return normalize(a) == normalize(b);
}

// ============================================================================
// NAME SIMILARITY
// ============================================================================

double _nameSimilarity(String a, String b) {
  final aa = _normalizeName(a);
  final bb = _normalizeName(b);

  if (aa.isEmpty || bb.isEmpty) {
    return 0.0;
  }

  if (aa == bb) {
    return 1.0;
  }

  final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();

  final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();

  if (ta.isEmpty || tb.isEmpty) {
    return 0.0;
  }

  return ta.intersection(tb).length / ta.union(tb).length;
}

// ============================================================================
// NAME NORMALIZATION
// ============================================================================

String _normalizeName(String value) {
  var result = value.toUpperCase();

  const replacements = <String, String>{
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'Ñ': 'N',
    '&': ' ',
    '-': ' ',
    '_': ' ',
    '/': ' ',
    ',': ' ',
    '.': ' ',
    ':': ' ',
    ';': ' ',
    '(': ' ',
    ')': ' ',
  };

  replacements.forEach((from, to) => result = result.replaceAll(from, to));

  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}
