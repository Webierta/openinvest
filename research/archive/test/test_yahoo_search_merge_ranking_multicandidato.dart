import 'package:test/test.dart';

/// Test aislado para comparar el ranking actual (OLD) con el ranking
/// después de fusionar resultados de las búsquedas ticker + nombre (MERGED).
///
/// NO importa YahooProvider y NO modifica producción.
/// Reproduce únicamente:
///   - deduplicación OLD por symbol (last write wins)
///   - deduplicación MERGED por symbol + merge
///   - ranking actual de YahooProvider
void main() {
  group('YahooProvider - OLD vs MERGED - multicandidato', () {
    test(
      'R1 - varios candidatos: el candidato principal permanece primero',
      () {
        final scenario = _Scenario(
          ticker: 'FUND.PA',
          fundName: 'Alpha Growth Fund',
          tickerResults: [
            _r(
              'FUND.PA',
              'Alpha Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000001',
            ),
            _r('ALPHA.PA', 'Alpha Growth ETF', type: 'ETF'),
            _r(
              'OTHER.PA',
              'Other Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000002',
            ),
          ],
          nameResults: [
            _r('FUND.PA', 'Alpha Growth Fund'),
            _r('ALPHA.PA', 'Alpha Growth ETF', type: 'ETF'),
            _r(
              'OTHER.PA',
              'Other Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000002',
            ),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R1', scenario, result);
        expect(result.oldSymbols, equals(result.mergedSymbols));
        expect(result.oldSymbols.first, equals('FUND.PA'));
        expect(result.mergedSymbols.first, equals('FUND.PA'));
      },
    );

    test(
      'R2 - merge cambia ETF a MUTUALFUND y puede recuperar un candidato',
      () {
        final scenario = _Scenario(
          ticker: 'FUND.PA',
          fundName: 'Alpha Growth Fund',
          tickerResults: [
            _r('FUND.PA', 'Alpha Growth Fund', type: 'ETF'),
            _r(
              'ALPHA.PA',
              'Alpha Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
            _r(
              'BETA.PA',
              'Beta Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000011',
            ),
          ],
          nameResults: [
            _r(
              'FUND.PA',
              'Alpha Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000012',
            ),
            _r('ALPHA.PA', 'Alpha Growth Fund', type: 'ETF'),
            _r(
              'BETA.PA',
              'Beta Growth Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000011',
            ),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R2', scenario, result);

        // OLD conserva el comportamiento actual: ALPHA.PA queda fuera
        // porque el último resultado recibido para ese symbol es ETF.
        expect(result.oldSymbols, containsAll(<String>['FUND.PA', 'BETA.PA']));
        expect(result.oldSymbols, isNot(contains('ALPHA.PA')));

        // MERGED puede recuperar ALPHA.PA porque combina ambos resultados
        // y conserva MUTUALFUND como type preferente.
        expect(
          result.mergedSymbols,
          containsAll(<String>['FUND.PA', 'ALPHA.PA', 'BETA.PA']),
        );

        // El candidato exacto por ticker sigue siendo el ganador.
        expect(result.oldSymbols.first, equals('FUND.PA'));
        expect(result.mergedSymbols.first, equals('FUND.PA'));

        // Comprobamos explícitamente la información fusionada.
        expect(result.mergedBySymbol['ALPHA.PA']!.type, equals('MUTUALFUND'));
        expect(result.mergedBySymbol['ALPHA.PA']!.isin, equals('FR0000000010'));

        // FUND.PA también queda como MUTUALFUND, pero sus dos ISIN son
        // diferentes, por lo que el merge no debe elegir uno arbitrariamente.
        expect(result.mergedBySymbol['FUND.PA']!.type, equals('MUTUALFUND'));
        //expect(result.mergedBySymbol['FUND.PA']!.isin, isNull);
        expect(
          result.mergedBySymbol['FUND.PA']!.isin,
          equals('FR0000000012'),
          reason: 'FUND.PA solo aporta un ISIN válido; el otro resultado tiene ISIN null.',
        );
      },
    );

    test(
      'R3 - merge mejora el nombre de un candidato sin eliminar los demás',
      () {
        final scenario = _Scenario(
          ticker: 'GAMMA.PA',
          fundName: 'Gamma Sustainable Bond Fund',
          tickerResults: [
            _r('GAMMA.PA', 'Gamma Sustainability', type: 'MUTUALFUND'),
            _r('DELTA.PA', 'Gamma Sustainable Bond Fund', type: 'ETF'),
            _r('OMEGA.PA', 'Omega Bond Fund', type: 'MUTUALFUND'),
          ],
          nameResults: [
            _r('GAMMA.PA', 'Gamma Sustainable Bond Fund', type: 'MUTUALFUND'),
            _r('DELTA.PA', 'Gamma Sustainable Bond Fund', type: 'ETF'),
            _r('OMEGA.PA', 'Omega Bond Fund', type: 'MUTUALFUND'),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R3', scenario, result);
        expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
        expect(
          result.mergedBySymbol['GAMMA.PA']!.name,
          equals('Gamma Sustainable Bond Fund'),
        );
        expect(result.mergedSymbols.first, equals('GAMMA.PA'));
      },
    );

    test('R4 - ISIN recuperado por merge no hace desaparecer candidatos', () {
      final scenario = _Scenario(
        ticker: 'DELTA.PA',
        fundName: 'Delta Income Fund',
        tickerResults: [
          _r('DELTA.PA', 'Delta Income Fund', type: 'MUTUALFUND'),
          _r(
            'OMEGA.PA',
            'Delta Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000021',
          ),
          _r(
            'BETA.PA',
            'Beta Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000022',
          ),
        ],
        nameResults: [
          _r(
            'DELTA.PA',
            'Delta Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000020',
          ),
          _r(
            'OMEGA.PA',
            'Delta Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000021',
          ),
          _r(
            'BETA.PA',
            'Beta Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000022',
          ),
        ],
      );

      final result = _compare(scenario);

      _printComparison('R4', scenario, result);
      expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
      expect(result.mergedBySymbol['DELTA.PA']!.isin, isNotNull);
      expect(result.mergedSymbols.first, equals('DELTA.PA'));
    });

    test('R5 - candidato por nombre no debe superar automáticamente al ticker exacto', () {
      final scenario = _Scenario(
        ticker: 'EXACT.PA',
        fundName: 'Exact Balanced Fund',
        tickerResults: [
          _r('EXACT.PA', 'Completely Different Fund', type: 'MUTUALFUND'),
          _r(
            'SIMILAR.PA',
            'Exact Balanced Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000031',
          ),
          _r('ETF.PA', 'Exact Balanced Fund ETF', type: 'ETF'),
        ],
        nameResults: [
          _r(
            'EXACT.PA',
            'Exact Balanced Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000030',
          ),
          _r(
            'SIMILAR.PA',
            'Exact Balanced Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000031',
          ),
          _r('ETF.PA', 'Exact Balanced Fund ETF', type: 'ETF'),
        ],
      );

      final result = _compare(scenario);

      _printComparison('R5', scenario, result);
      expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
      expect(result.mergedSymbols.first, equals('EXACT.PA'));
    });

    test('R6 - dos candidatos muy cercanos: merge mejora solo uno', () {
      final scenario = _Scenario(
        ticker: 'CLOSE.PA',
        fundName: 'Global Flexible Income Fund',
        tickerResults: [
          _r('CLOSE.PA', 'Global Flexible Income', type: 'MUTUALFUND'),
          _r(
            'NEAR.PA',
            'Global Flexible Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000041',
          ),
          _r('THIRD.PA', 'Global Income Fund', type: 'MUTUALFUND'),
        ],
        nameResults: [
          _r(
            'CLOSE.PA',
            'Global Flexible Income Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000040',
          ),
          _r(
            'NEAR.PA',
            'Global Flexible Income',
            type: 'MUTUALFUND',
            isin: 'FR0000000041',
          ),
          _r('THIRD.PA', 'Global Income Fund', type: 'MUTUALFUND'),
        ],
      );

      final result = _compare(scenario);

      _printComparison('R6', scenario, result);
      expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
      expect(result.mergedSymbols.first, equals('CLOSE.PA'));
      expect(result.mergedBySymbol['CLOSE.PA']!.isin, isNotNull);
    });

    test(
      'R7 - conflicto de ISIN: el candidato sigue participando en ranking',
      () {
        final scenario = _Scenario(
          ticker: 'CONFLICT.PA',
          fundName: 'Conflict Global Fund',
          tickerResults: [
            _r(
              'CONFLICT.PA',
              'Conflict Global Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000050',
            ),
            _r(
              'OTHER.PA',
              'Conflict Global Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000051',
            ),
            _r('ETF.PA', 'Conflict Global Fund ETF', type: 'ETF'),
          ],
          nameResults: [
            _r(
              'CONFLICT.PA',
              'Conflict Global Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000052',
            ),
            _r(
              'OTHER.PA',
              'Conflict Global Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000051',
            ),
            _r('ETF.PA', 'Conflict Global Fund ETF', type: 'ETF'),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R7', scenario, result);
        expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
        expect(result.mergedBySymbol['CONFLICT.PA']!.isin, isNull);
        expect(result.mergedSymbols.first, equals('CONFLICT.PA'));
      },
    );

    test(
      'R8 - caso equivalente a MYFUND: merge consolida MUTUALFUND + ISIN',
      () {
        final scenario = _Scenario(
          ticker: 'MYFUND.PA',
          fundName: 'My Fund',
          tickerResults: [
            _r('MYFUND.PA', 'My Fund ETF', type: 'ETF'),
            _r(
              'OTHER.PA',
              'Other Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000061',
            ),
          ],
          nameResults: [
            _r(
              'MYFUND.PA',
              'My Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000060',
            ),
            _r(
              'OTHER.PA',
              'Other Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000061',
            ),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R8', scenario, result);
        expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
        expect(result.mergedBySymbol['MYFUND.PA']!.type, equals('MUTUALFUND'));
        expect(
          result.mergedBySymbol['MYFUND.PA']!.isin,
          equals('FR0000000060'),
        );
        expect(result.mergedSymbols.first, equals('MYFUND.PA'));
      },
    );

    test(
      'R9 - tres candidatos: exact ticker, nombre y MUTUALFUND compiten',
      () {
        final scenario = _Scenario(
          ticker: 'TRIPLE.PA',
          fundName: 'Triple Strategy Fund',
          tickerResults: [
            _r('TRIPLE.PA', 'Triple Strategy', type: 'ETF'),
            _r('NAME.PA', 'Triple Strategy Fund', type: 'ETF'),
            _r(
              'MF.PA',
              'Triple Strategy',
              type: 'MUTUALFUND',
              isin: 'FR0000000071',
            ),
          ],
          nameResults: [
            _r(
              'TRIPLE.PA',
              'Triple Strategy Fund',
              type: 'MUTUALFUND',
              isin: 'FR0000000070',
            ),
            _r('NAME.PA', 'Triple Strategy Fund', type: 'ETF'),
            _r(
              'MF.PA',
              'Triple Strategy',
              type: 'MUTUALFUND',
              isin: 'FR0000000071',
            ),
          ],
        );

        final result = _compare(scenario);

        _printComparison('R9', scenario, result);
        expect(result.oldSymbols.toSet(), equals(result.mergedSymbols.toSet()));
        expect(result.mergedSymbols.first, equals('TRIPLE.PA'));
        expect(result.mergedBySymbol['TRIPLE.PA']!.type, equals('MUTUALFUND'));
      },
    );

    test('R10 - invertir el orden de las dos búsquedas no cambia MERGED', () {
      final base = _Scenario(
        ticker: 'ORDER.PA',
        fundName: 'Order Balanced Fund',
        tickerResults: [
          _r('ORDER.PA', 'Order Balanced', type: 'ETF'),
          _r(
            'SECOND.PA',
            'Order Balanced Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000081',
          ),
          _r('THIRD.PA', 'Third Fund', type: 'MUTUALFUND'),
        ],
        nameResults: [
          _r(
            'ORDER.PA',
            'Order Balanced Fund',
            type: 'MUTUALFUND',
            isin: 'FR0000000080',
          ),
          _r(
            'SECOND.PA',
            'Order Balanced',
            type: 'MUTUALFUND',
            isin: 'FR0000000081',
          ),
          _r('THIRD.PA', 'Third Fund', type: 'MUTUALFUND'),
        ],
      );

      final normal = _compare(base);
      final reversed = _compare(
        _Scenario(
          ticker: base.ticker,
          fundName: base.fundName,
          tickerResults: base.nameResults,
          nameResults: base.tickerResults,
        ),
      );

      _printComparison('R10 NORMAL', base, normal);
      _printComparison('R10 INVERTIDO', base, reversed);

      expect(normal.mergedSymbols, equals(reversed.mergedSymbols));
      expect(
        normal.mergedBySymbol['ORDER.PA']!.name,
        equals(reversed.mergedBySymbol['ORDER.PA']!.name),
      );
      expect(
        normal.mergedBySymbol['ORDER.PA']!.type,
        equals(reversed.mergedBySymbol['ORDER.PA']!.type),
      );
      expect(
        normal.mergedBySymbol['ORDER.PA']!.isin,
        equals(reversed.mergedBySymbol['ORDER.PA']!.isin),
      );
    });
  });
}

class _Scenario {
  final String ticker;
  final String fundName;
  final List<_YahooResult> tickerResults;
  final List<_YahooResult> nameResults;

  const _Scenario({
    required this.ticker,
    required this.fundName,
    required this.tickerResults,
    required this.nameResults,
  });
}

class _Comparison {
  final List<_YahooResult> oldRanked;
  final List<_YahooResult> mergedRanked;
  final Map<String, _YahooResult> oldBySymbol;
  final Map<String, _YahooResult> mergedBySymbol;

  const _Comparison({
    required this.oldRanked,
    required this.mergedRanked,
    required this.oldBySymbol,
    required this.mergedBySymbol,
  });

  List<String> get oldSymbols => oldRanked.map((x) => x.symbol).toList();
  List<String> get mergedSymbols => mergedRanked.map((x) => x.symbol).toList();
}

_Comparison _compare(_Scenario scenario) {
  final old = _searchOld(scenario);
  final merged = _searchMerged(scenario);

  return _Comparison(
    oldRanked: _rank(old.values.toList(), scenario.ticker, scenario.fundName),
    mergedRanked: _rank(
      merged.values.toList(),
      scenario.ticker,
      scenario.fundName,
    ),
    oldBySymbol: old,
    mergedBySymbol: merged,
  );
}

Map<String, _YahooResult> _searchOld(_Scenario scenario) {
  final results = <String, _YahooResult>{};

  for (final response in [scenario.tickerResults, scenario.nameResults]) {
    for (final incoming in response) {
      results[incoming.symbol] = incoming;
    }
  }

  return results;
}

Map<String, _YahooResult> _searchMerged(_Scenario scenario) {
  final results = <String, _YahooResult>{};

  for (final response in [scenario.tickerResults, scenario.nameResults]) {
    for (final incoming in response) {
      final existing = results[incoming.symbol];

      if (existing == null) {
        results[incoming.symbol] = incoming;
      } else {
        results[incoming.symbol] = _mergeYahooResult(
          existing,
          incoming,
          scenario.fundName,
        );
      }
    }
  }

  return results;
}

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

String _chooseBestName(String a, String b, String fundName) {
  final aa = a.trim();
  final bb = b.trim();

  if (aa.isEmpty) return bb;
  if (bb.isEmpty) return aa;
  if (aa == bb) return aa;

  final scoreA = _nameSimilarity(fundName, aa);
  final scoreB = _nameSimilarity(fundName, bb);

  return scoreB > scoreA ? bb : aa;
}

String _chooseBestType(String a, String b) {
  final aa = a.trim();
  final bb = b.trim();

  if (aa.isEmpty) return bb;
  if (bb.isEmpty) return aa;
  if (aa.toUpperCase() == bb.toUpperCase()) return aa;

  if (aa.toUpperCase() == 'MUTUALFUND') return aa;
  if (bb.toUpperCase() == 'MUTUALFUND') return bb;

  return aa;
}

List<_YahooResult> _rank(
  List<_YahooResult> results,
  String ticker,
  String fundName,
) {
  final normalizedTicker = ticker.toUpperCase();

  final scored =
      results
          .map((result) {
            final symbol = result.symbol.toUpperCase();
            final type = result.type.toUpperCase();
            final nameSimilarity = _nameSimilarity(fundName, result.name);
            var score = nameSimilarity * 0.55;

            if (symbol == normalizedTicker) score += 0.20;
            if (symbol.startsWith(normalizedTicker)) score += 0.05;

            if (type == 'MUTUALFUND') {
              score += 0.30;
            } else if (type == 'ETF') {
              score -= 0.20;
            } else if (type == 'EQUITY' || type == 'INDEX') {
              score -= 0.30;
            }

            if (_sameMorningstarId(symbol, normalizedTicker)) score += 0.10;
            if (result.isin != null) score += 0.10;

            return (result: result, score: score);
          })
          .where((item) => item.score >= 0.50)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  return scored.map((item) => item.result).toList();
}

bool _sameMorningstarId(String a, String b) {
  String normalize(String value) {
    final match = RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$')
        .firstMatch(value.trim().toUpperCase());
    return match?.group(1) ?? value.trim().toUpperCase();
  }

  return normalize(a) == normalize(b);
}

double _nameSimilarity(String a, String b) {
  final aa = _normalizeName(a);
  final bb = _normalizeName(b);
  if (aa.isEmpty || bb.isEmpty) return 0.0;
  if (aa == bb) return 1.0;

  final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();
  final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();
  if (ta.isEmpty || tb.isEmpty) return 0.0;

  return ta.intersection(tb).length / ta.union(tb).length;
}

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

_YahooResult _r(
  String symbol,
  String name, {
  String type = '',
  String? isin,
  String exchange = 'PA',
}) {
  return _YahooResult(
    symbol: symbol,
    name: name,
    exchange: exchange,
    type: type,
    isin: isin,
  );
}

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
}

void _printComparison(String label, _Scenario scenario, _Comparison result) {
  print('');
  print('------------------------------------------------------------');
  print(label);
  print('Ticker : ${scenario.ticker}');
  print('Nombre : ${scenario.fundName}');
  print('------------------------------------------------------------');

  print('OLD:');
  for (var i = 0; i < result.oldRanked.length; i++) {
    final r = result.oldRanked[i];
    print('  ${i + 1}. ${_format(r)}');
  }

  print('MERGED:');
  for (var i = 0; i < result.mergedRanked.length; i++) {
    final r = result.mergedRanked[i];
    print('  ${i + 1}. ${_format(r)}');
  }

  print('');
  print(
    'OLD ganador    : ${result.oldRanked.isEmpty ? '-' : result.oldRanked.first.symbol}',
  );
  print(
    'MERGED ganador : ${result.mergedRanked.isEmpty ? '-' : result.mergedRanked.first.symbol}',
  );
  print('Candidatos OLD    : ${result.oldRanked.length}');
  print('Candidatos MERGED : ${result.mergedRanked.length}');
}

String _format(_YahooResult r) {
  return '${r.symbol}/${r.type}/${r.isin ?? 'null'}/${r.name}';
}
