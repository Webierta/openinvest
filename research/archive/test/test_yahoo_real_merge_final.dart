import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:investing/utils/isin_validator.dart';

/// Prueba final del merge real de YahooProvider.
///
/// IMPORTANTE:
/// - No modifica producción.
/// - No modifica YahooProvider.
/// - Consulta Yahoo realmente por TICKER y por NOMBRE.
/// - Reproduce de forma aislada el merge propuesto.
/// - Comprueba que el merge no inventa candidatos ni ISIN.
/// - Comprueba que no pierde símbolos presentes en Yahoo.
/// - Comprueba que los conflictos de ISIN no se resuelven arbitrariamente.
/// - Compara OLD (last-write-wins) contra MERGED + ranking actual.
///
/// Ejecutar desde la raíz:
///
///   dart test research/archive/test/test_yahoo_real_merge_final.dart -p vm
///
/// Esta prueba depende de que Yahoo Finance esté accesible en el momento
/// de ejecución. Los resultados de Yahoo pueden cambiar con el tiempo.

const _yahooSearchUrl =
    'https://query1.finance.yahoo.com/v1/finance/search?q=';

class TestCase {
  final String name;
  final String ticker;
  final String? expectedIsin;

  const TestCase({
    required this.name,
    required this.ticker,
    this.expectedIsin,
  });
}

const cases = <TestCase>[
  TestCase(
    name: 'PIMCO GIS Income Fund E Class USD Income',
    ticker: '0P0000X83M',
    expectedIsin: 'IE00B8K7V925',
  ),
  TestCase(
    name: 'Carmignac Patrimoine A EUR Acc',
    ticker: '0P00000FB4.F',
    expectedIsin: 'FR0010135103',
  ),
  TestCase(
    name: 'Fidelity Funds - Iberia A-Acc-EUR',
    ticker: '0P00006DAB.F',
    expectedIsin: 'LU0261948904',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value C Acc EUR',
    ticker: '0P00000Z1Y.F',
    expectedIsin: 'LU0129445192',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value A Acc EUR',
    ticker: 'LU0210531983',
    expectedIsin: 'LU0210531983',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value A Acc USD Hedged',
    ticker: 'LU1599125231',
    expectedIsin: 'LU1599125231',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value A Acc SGD Hedged',
    ticker: 'LU3284971820',
    expectedIsin: 'LU3284971820',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value A Dist EUR',
    ticker: 'LU0107398884',
    expectedIsin: 'LU0107398884',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value A Dist GBP',
    ticker: 'LU0119092640',
    expectedIsin: 'LU0119092640',
  ),
  TestCase(
    name: 'Fidelity European Growth A Acc EUR',
    ticker: 'LU0296857971',
    expectedIsin: 'LU0296857971',
  ),
  TestCase(
    name: 'Fidelity European Growth A Acc USD Hedged',
    ticker: 'LU0997586606',
    expectedIsin: 'LU0997586606',
  ),
  TestCase(
    name: 'Fidelity European Growth A Dist EUR',
    ticker: 'LU0048578792',
    expectedIsin: 'LU0048578792',
  ),
  TestCase(
    name: 'Fidelity European Growth A Dist SGD',
    ticker: 'LU0550127509',
    expectedIsin: 'LU0550127509',
  ),
  TestCase(
    name: 'Fidelity European Growth C Dist EUR',
    ticker: 'LU0324710721',
    expectedIsin: 'LU0324710721',
  ),
  TestCase(
    name: 'Fidelity European Growth E Acc EUR',
    ticker: 'LU0115764192',
    expectedIsin: 'LU0115764192',
  ),
  TestCase(
    name: 'Fidelity European Growth I Acc EUR',
    ticker: 'LU1642889510',
    expectedIsin: 'LU1642889510',
  ),
  TestCase(
    name: 'Fidelity European Growth SR Acc EUR',
    ticker: 'LU1235258925',
    expectedIsin: 'LU1235258925',
  ),
  TestCase(
    name: 'Fidelity European Growth SR Acc SGD',
    ticker: 'LU1235259576',
    expectedIsin: 'LU1235259576',
  ),
  TestCase(
    name: 'BlackRock Next Generation Technology A10 USD',
    ticker: 'LU2533724949',
    expectedIsin: 'LU2533724949',
  ),
  TestCase(
    name: 'BlackRock Next Generation Technology A2 SEK',
    ticker: 'LU1861216940',
    expectedIsin: 'LU1861216940',
  ),
  TestCase(
    name: 'BlackRock Next Generation Technology A2 EUR',
    ticker: 'LU2400291972',
    expectedIsin: 'LU2400291972',
  ),
  TestCase(
    name: 'BlackRock Next Generation Technology A2 USD',
    ticker: 'LU1861215975',
    expectedIsin: 'LU1861215975',
  ),
  TestCase(
    name: 'Carmignac Patrimoine A CHF Acc Hdg',
    ticker: 'FR0011269596',
    expectedIsin: 'FR0011269596',
  ),
];

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
    return '$symbol/$type/${isin ?? 'null'}/$name';
  }
}

class _RawResults {
  final List<_YahooResult> tickerResults;
  final List<_YahooResult> nameResults;

  const _RawResults({
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
}

Future<List<_YahooResult>> _searchYahoo(
  http.Client client,
  String query,
) async {
  final uri = Uri.parse(_yahooSearchUrl).replace(
    queryParameters: {
      'q': query,
      'quotesCount': '20',
      'newsCount': '0',
      'enableFuzzyQuery': 'false',
    },
  );

  final response = await client
      .get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'OpenInvest/1.0',
        },
      )
      .timeout(const Duration(seconds: 20));

  if (response.statusCode != 200) {
    throw Exception('Yahoo HTTP ${response.statusCode}');
  }

  final json = jsonDecode(response.body);
  if (json is! Map<String, dynamic>) {
    throw Exception('Yahoo devolvió JSON no válido');
  }

  final quotes = json['quotes'];
  if (quotes is! List) return const [];

  return quotes
      .whereType<Map>()
      .map((item) {
        final symbol = item['symbol']?.toString().trim() ?? '';
        final rawIsin = item['isin']?.toString().trim().toUpperCase();

        return _YahooResult(
          symbol: symbol,
          name:
              item['longname']?.toString() ??
              item['shortname']?.toString() ??
              '',
          exchange: item['exchange']?.toString() ?? '',
          type: item['quoteType']?.toString() ?? '',
          isin: rawIsin != null && IsinValidator.isValid(rawIsin)
              ? rawIsin
              : null,
        );
      })
      .where((x) => x.symbol.isNotEmpty)
      .toList();
}

_YahooResult _mergeYahooResult(
  _YahooResult existing,
  _YahooResult incoming,
  String fundName,
) {
  final name = _chooseBestName(
    existing.name,
    incoming.name,
    fundName,
  );

  final exchange = existing.exchange.trim().isNotEmpty
      ? existing.exchange
      : incoming.exchange;

  final type = _chooseBestType(
    existing.type,
    incoming.type,
  );

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

String _chooseBestName(
  String existing,
  String incoming,
  String fundName,
) {
  if (existing.trim().isEmpty) return incoming;
  if (incoming.trim().isEmpty) return existing;

  final existingScore = _nameSimilarity(fundName, existing);
  final incomingScore = _nameSimilarity(fundName, incoming);

  return incomingScore > existingScore ? incoming : existing;
}

String _chooseBestType(
  String existing,
  String incoming,
) {
  final e = existing.trim().toUpperCase();
  final i = incoming.trim().toUpperCase();

  if (e.isEmpty) return incoming;
  if (i.isEmpty) return existing;
  if (e == i) return existing;

  if (e == 'MUTUALFUND') return existing;
  if (i == 'MUTUALFUND') return incoming;

  return existing;
}

List<_YahooResult> _searchOld(_RawResults raw) {
  final results = <String, _YahooResult>{};

  for (final result in <_YahooResult>[
    ...raw.tickerResults,
    ...raw.nameResults,
  ]) {
    results[result.symbol] = result;
  }

  return results.values.toList();
}

List<_YahooResult> _searchMerged(
  _RawResults raw,
  String fundName,
) {
  final results = <String, _YahooResult>{};

  for (final result in <_YahooResult>[
    ...raw.tickerResults,
    ...raw.nameResults,
  ]) {
    final existing = results[result.symbol];

    if (existing == null) {
      results[result.symbol] = result;
    } else {
      results[result.symbol] = _mergeYahooResult(
        existing,
        result,
        fundName,
      );
    }
  }

  return results.values.toList();
}

_Comparison _compare(
  _RawResults raw,
  String ticker,
  String fundName,
) {
  final old = _searchOld(raw);
  final merged = _searchMerged(raw, fundName);

  final oldRanked = _rank(old, ticker, fundName);
  final mergedRanked = _rank(merged, ticker, fundName);

  return _Comparison(
    oldRanked: oldRanked,
    mergedRanked: mergedRanked,
    oldBySymbol: {
      for (final x in old) x.symbol: x,
    },
    mergedBySymbol: {
      for (final x in merged) x.symbol: x,
    },
  );
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
            final nameSimilarity = _nameSimilarity(
              fundName,
              result.name,
            );

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

            if (_sameMorningstarId(symbol, normalizedTicker)) {
              score += 0.10;
            }

            if (result.isin != null) score += 0.10;

            return (
              result: result,
              score: score,
            );
          })
          .where((item) => item.score >= 0.50)
          .toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  return scored.map((item) => item.result).toList();
}

bool _sameMorningstarId(String a, String b) {
  String normalize(String value) {
    final match = RegExp(
      r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
    ).firstMatch(value.trim().toUpperCase());

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

  replacements.forEach(
    (from, to) => result = result.replaceAll(from, to),
  );

  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void _printResults(
  String label,
  List<_YahooResult> results,
) {
  print('$label:');

  if (results.isEmpty) {
    print('  SIN RESULTADOS');
    return;
  }

  for (var i = 0; i < results.length && i < 10; i++) {
    print('  ${i + 1}. ${results[i]}');
  }
}

void _printComparison(
  int index,
  TestCase testCase,
  _RawResults raw,
  _Comparison result,
) {
  print('\n${'-' * 100}');
  print('CASO REAL $index/${cases.length}');
  print('${'-' * 100}');
  print('Ticker : ${testCase.ticker}');
  print('Nombre : ${testCase.name}');
  print('Esperado ISIN : ${testCase.expectedIsin ?? '-'}');

  print('');
  _printResults('YAHOO TICKER', raw.tickerResults);
  print('');
  _printResults('YAHOO NOMBRE', raw.nameResults);
  print('');
  _printResults('OLD RANKED', result.oldRanked);
  print('');
  _printResults('MERGED RANKED', result.mergedRanked);

  final oldWinner =
      result.oldRanked.isEmpty ? '-' : result.oldRanked.first.symbol;
  final mergedWinner =
      result.mergedRanked.isEmpty ? '-' : result.mergedRanked.first.symbol;

  print('');
  print('Ganador OLD    : $oldWinner');
  print('Ganador MERGED : $mergedWinner');
  print('Candidatos OLD    : ${result.oldRanked.length}');
  print('Candidatos MERGED : ${result.mergedRanked.length}');
}

void main() {
  test(
    'YahooProvider - prueba final real de ticker + nombre + merge',
    () async {
      final client = http.Client();

      var queriesOk = 0;
      var queriesFailed = 0;
      var casesWithResults = 0;
      var casesWithTickerResults = 0;
      var casesWithNameResults = 0;
      var casesWithIsin = 0;
      var casesWithMorningstar = 0;
      var mergedRecoveredInformation = 0;
      var oldOrderDependent = 0;
      var oldLostValidIsin = 0;
      var mergedIsinConflicts = 0;
      var mergedCandidatesRecovered = 0;

      try {
        for (var index = 0; index < cases.length; index++) {
          final testCase = cases[index];

          List<_YahooResult> tickerResults = const [];
          List<_YahooResult> nameResults = const [];

          try {
            tickerResults = await _searchYahoo(
              client,
              testCase.ticker,
            );
            queriesOk++;
          } catch (e) {
            queriesFailed++;
            print(
              '\nERROR Yahoo ticker [${testCase.ticker}]: $e',
            );
          }

          try {
            nameResults = await _searchYahoo(
              client,
              testCase.name,
            );
            queriesOk++;
          } catch (e) {
            queriesFailed++;
            print(
              '\nERROR Yahoo nombre [${testCase.name}]: $e',
            );
          }

          final raw = _RawResults(
            tickerResults: tickerResults,
            nameResults: nameResults,
          );

          if (tickerResults.isNotEmpty) casesWithTickerResults++;
          if (nameResults.isNotEmpty) casesWithNameResults++;

          if (tickerResults.isNotEmpty || nameResults.isNotEmpty) {
            casesWithResults++;
          }

          final comparison = _compare(
            raw,
            testCase.ticker,
            testCase.name,
          );

          _printComparison(
            index + 1,
            testCase,
            raw,
            comparison,
          );

          // -----------------------------------------------------------------
          // INVARIANT 1:
          // MERGED nunca puede inventar un symbol.
          // -----------------------------------------------------------------
          final rawSymbols = <String>{
            ...tickerResults.map((x) => x.symbol),
            ...nameResults.map((x) => x.symbol),
          };

          for (final symbol in comparison.mergedBySymbol.keys) {
            expect(
              rawSymbols.contains(symbol),
              isTrue,
              reason:
                  'MERGED ha inventado el symbol $symbol '
                  'en ${testCase.ticker}',
            );
          }

          // -----------------------------------------------------------------
          // INVARIANT 2:
          // MERGED no puede perder un symbol antes del ranking.
          //
          // Nota: después del ranking sí puede quedar fuera por score < 0.50.
          // Aquí comprobamos el mapa consolidado, no la lista rankeada.
          // -----------------------------------------------------------------
          expect(
            comparison.mergedBySymbol.keys.toSet(),
            equals(rawSymbols),
            reason:
                'El merge debe conservar todos los symbols recibidos '
                'por Yahoo en ${testCase.ticker}',
          );

          // -----------------------------------------------------------------
          // INVARIANT 3:
          // Ningún ISIN MERGED puede aparecer de la nada.
          //
          // Si hay un solo ISIN válido entre las dos apariciones del symbol,
          // debe conservarse.
          // Si hay dos ISIN distintos, debe quedar null.
          // -----------------------------------------------------------------
          final rawBySymbol = <String, List<_YahooResult>>{};

          for (final item in <_YahooResult>[
            ...tickerResults,
            ...nameResults,
          ]) {
            rawBySymbol.putIfAbsent(item.symbol, () => []).add(item);
          }

          for (final entry in rawBySymbol.entries) {
            final isins = entry.value
                .map((x) => x.isin)
                .whereType<String>()
                .toSet();

            final merged = comparison.mergedBySymbol[entry.key]!;

            if (isins.length > 1) {
              expect(
                merged.isin,
                isNull,
                reason:
                    'Conflicto de ISIN para ${entry.key}: '
                    '${isins.join(', ')}',
              );
              mergedIsinConflicts++;
            } else if (isins.length == 1) {
              expect(
                merged.isin,
                equals(isins.single),
                reason:
                    'MERGED ha perdido el único ISIN válido de '
                    '${entry.key}',
              );
            } else {
              expect(
                merged.isin,
                isNull,
                reason:
                    'No debe inventarse un ISIN para ${entry.key}',
              );
            }
          }

          // -----------------------------------------------------------------
          // INVARIANT 4:
          // El nombre MERGED debe proceder de una de las dos apariciones.
          // -----------------------------------------------------------------
          for (final entry in rawBySymbol.entries) {
            final mergedName = comparison.mergedBySymbol[entry.key]!.name;

            expect(
              entry.value.map((x) => x.name).contains(mergedName),
              isTrue,
              reason:
                  'El nombre fusionado de ${entry.key} no procede '
                  'de Yahoo',
            );
          }

          // -----------------------------------------------------------------
          // INVARIANT 5:
          // El type MERGED debe proceder de Yahoo y, si existe MUTUALFUND,
          // debe conservarlo.
          // -----------------------------------------------------------------
          for (final entry in rawBySymbol.entries) {
            final rawTypes = entry.value
                .map((x) => x.type.trim())
                .where((x) => x.isNotEmpty)
                .toList();

            final mergedType =
                comparison.mergedBySymbol[entry.key]!.type.trim();

            if (rawTypes.isNotEmpty) {
              expect(
                rawTypes.contains(mergedType),
                isTrue,
                reason:
                    'El type fusionado de ${entry.key} no procede '
                    'de Yahoo',
              );

              if (rawTypes
                  .map((x) => x.toUpperCase())
                  .contains('MUTUALFUND')) {
                expect(
                  mergedType.toUpperCase(),
                  equals('MUTUALFUND'),
                  reason:
                      'Si Yahoo aporta MUTUALFUND, el merge debe '
                      'preferirlo para ${entry.key}',
                );
              }
            }
          }

          // -----------------------------------------------------------------
          // INVARIANT 6:
          // El ranking MERGED no debe producir symbols que no existían.
          // -----------------------------------------------------------------
          for (final item in comparison.mergedRanked) {
            expect(
              rawSymbols.contains(item.symbol),
              isTrue,
              reason:
                  'Ranking MERGED ha producido un candidato inexistente: '
                  '${item.symbol}',
            );
          }

          // -----------------------------------------------------------------
          // DIAGNÓSTICO: casos donde MERGED recupera un ISIN que OLD perdió.
          // -----------------------------------------------------------------
          for (final symbol in rawSymbols) {
            final old = comparison.oldBySymbol[symbol]!;
            final merged = comparison.mergedBySymbol[symbol]!;

            if (old.isin == null && merged.isin != null) {
              mergedRecoveredInformation++;
              oldLostValidIsin++;
            }
          }

          // -----------------------------------------------------------------
          // DIAGNÓSTICO: candidatos recuperados por MERGED tras el ranking.
          // Es válido y esperado si el merge mejora type/name/ISIN.
          // -----------------------------------------------------------------
          final oldRankedSymbols =
              comparison.oldRanked.map((x) => x.symbol).toSet();
          final mergedRankedSymbols =
              comparison.mergedRanked.map((x) => x.symbol).toSet();

          if (mergedRankedSymbols.length > oldRankedSymbols.length) {
            mergedCandidatesRecovered++;
          }

          // -----------------------------------------------------------------
          // DIAGNÓSTICO: ISIN esperado.
          //
          // No exigimos que Yahoo lo devuelva siempre, porque el objetivo
          // de esta prueba es el merge, no validar cobertura de Yahoo.
          // Solo registramos si aparece.
          // -----------------------------------------------------------------
          if (testCase.expectedIsin != null) {
            final expected = testCase.expectedIsin!.toUpperCase();

            final appearsInRaw = <_YahooResult>[
              ...tickerResults,
              ...nameResults,
            ].any((x) => x.isin == expected);

            if (appearsInRaw) {
              casesWithIsin++;
            }
          }

          // Morningstar IDs: diagnóstico, no criterio de fallo.
          final hasMorningstar = <_YahooResult>[
            ...tickerResults,
            ...nameResults,
          ].any(
            (x) => RegExp(
              r'^0P[0-9A-Z]+(?:\.[A-Z]+)?$',
              caseSensitive: false,
            ).hasMatch(x.symbol.trim()),
          );

          if (hasMorningstar) casesWithMorningstar++;

          // ---------------------------------------------------------------
          // Prueba de orden:
          // procesamos primero nombre y luego ticker.
          // El resultado MERGED debe ser equivalente.
          // ---------------------------------------------------------------
          final reversedRaw = _RawResults(
            tickerResults: nameResults,
            nameResults: tickerResults,
          );

          final reversedMerged = _searchMerged(
            reversedRaw,
            testCase.name,
          );

          final normalMap = comparison.mergedBySymbol;

          final reversedMap = <String, _YahooResult>{
            for (final x in reversedMerged) x.symbol: x,
          };

          expect(
            reversedMap.keys.toSet(),
            equals(normalMap.keys.toSet()),
            reason:
                'El MERGED depende del orden de las dos búsquedas '
                'en ${testCase.ticker}',
          );

          for (final symbol in normalMap.keys) {
            final a = normalMap[symbol]!;
            final b = reversedMap[symbol]!;

            expect(
              b.name,
              equals(a.name),
              reason:
                  'El nombre MERGED depende del orden para $symbol',
            );
            expect(
              b.type,
              equals(a.type),
              reason:
                  'El type MERGED depende del orden para $symbol',
            );
            expect(
              b.exchange,
              equals(a.exchange),
              reason:
                  'El exchange MERGED depende del orden para $symbol',
            );
            expect(
              b.isin,
              equals(a.isin),
              reason:
                  'El ISIN MERGED depende del orden para $symbol',
            );
          }

          await Future<void>.delayed(
            const Duration(milliseconds: 150),
          );
        }

        print('\n${'=' * 100}');
        print('RESUMEN FINAL - PRUEBA REAL YAHOO + MERGE');
        print('=' * 100);
        print('Casos                              : ${cases.length}');
        print('Consultas Yahoo OK                 : $queriesOk');
        print('Consultas Yahoo con error          : $queriesFailed');
        print('Casos con algún resultado           : $casesWithResults');
        print('Casos con resultados por ticker     : $casesWithTickerResults');
        print('Casos con resultados por nombre     : $casesWithNameResults');
        print('Casos donde apareció ISIN esperado  : $casesWithIsin');
        print('Casos con Morningstar ID             : $casesWithMorningstar');
        print('ISIN recuperados por MERGED vs OLD  : $mergedRecoveredInformation');
        print('ISIN válidos perdidos por OLD       : $oldLostValidIsin');
        print('Conflictos ISIN resueltos a null    : $mergedIsinConflicts');
        print('Candidatos recuperados por MERGED   : $mergedCandidatesRecovered');
        print('');
        print('Las invariantes estructurales del merge han pasado.');
        print('No se ha modificado YahooProvider.');
        print('=' * 100);

        // Si Yahoo está completamente caído, no tiene sentido considerar
        // la prueba real como válida.
        expect(
          queriesOk,
          greaterThan(0),
          reason:
              'Yahoo no respondió correctamente a ninguna consulta.',
        );
      } finally {
        client.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
