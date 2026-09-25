import 'dart:convert';

import 'package:http/http.dart' as http;

const String yahooSearchUrl =
    'https://query1.finance.yahoo.com/v1/finance/search';

const String morningstarSnapshotUrl =
    'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

class TestCase {
  final String name;
  final String ticker;
  final String expectedIsin;
  final String? expectedMorningstarId;

  const TestCase({
    required this.name,
    required this.ticker,
    required this.expectedIsin,
    this.expectedMorningstarId,
  });
}

const List<TestCase> tests = [
  TestCase(
    name: 'PIMCO GIS Income Fund E Class USD Income',
    ticker: '0P0000X83M',
    expectedIsin: 'IE00B8K7V925',
    expectedMorningstarId: '0P0000X83M',
  ),
  TestCase(
    name: 'Carmignac Patrimoine A EUR Acc',
    ticker: '0P00000FB4',
    expectedIsin: 'FR0010135103',
    expectedMorningstarId: '0P00000FB4',
  ),
  TestCase(
    name: 'Fidelity Funds - Iberia A-Acc-EUR',
    ticker: '0P00006DAB',
    expectedIsin: 'LU0261948904',
    expectedMorningstarId: '0P00006DAB',
  ),
  TestCase(
    name: 'JPM Europe Strategic Value C Acc EUR',
    ticker: '0P00000Z1Y',
    expectedIsin: 'LU0129445192',
    expectedMorningstarId: '0P00000Z1Y',
  ),
];

class YahooCandidate {
  final String symbol;
  final String name;
  final String exchange;
  final String quoteType;
  final String? isin;

  const YahooCandidate({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.quoteType,
    required this.isin,
  });
}

class MorningstarResult {
  final String? performanceId;
  final String? holdingId;
  final String? holdingName;
  final String? holdingIsin;
  final String? holdingCurrency;

  const MorningstarResult({
    this.performanceId,
    this.holdingId,
    this.holdingName,
    this.holdingIsin,
    this.holdingCurrency,
  });
}

Future<void> main() async {
  final client = http.Client();

  try {
    print('');
    print('=' * 100);
    print('PROBE INDEPENDIENTE: YAHOO vs MORNINGSTAR');
    print('=' * 100);
    print('');
    print('Este programa NO utiliza IsinResolver.');
    print('No modifica ningún archivo del proyecto.');
    print('');

    var total = 0;
    var yahooFound = 0;
    var yahooIsinFound = 0;
    var morningstarFound = 0;
    var correct = 0;

    for (final test in tests) {
      total++;

      print('');
      print('=' * 100);
      print('TEST $total/${tests.length}');
      print('=' * 100);
      print('Nombre esperado : ${test.name}');
      print('Ticker / ID     : ${test.ticker}');
      print('ISIN esperado   : ${test.expectedIsin}');
      print(
        'Morningstar ID  : '
        '${test.expectedMorningstarId ?? '(no disponible)'}',
      );
      print('');

      // ---------------------------------------------------------------------
      // 1. YAHOO
      // ---------------------------------------------------------------------

      print('-' * 100);
      print('1. YAHOO SEARCH');
      print('-' * 100);

      final yahooResults = await searchYahoo(client, test.ticker);

      print('Yahoo candidatos encontrados: ${yahooResults.length}');
      print('');

      if (yahooResults.isNotEmpty) {
        yahooFound++;
      }

      String? selectedMorningstarId;
      String? selectedYahooIsin;

      if (yahooResults.isEmpty) {
        print('  Yahoo no devolvió candidatos.');
      } else {
        for (var i = 0; i < yahooResults.length; i++) {
          final candidate = yahooResults[i];

          print('  CANDIDATO #${i + 1}');
          print('    symbol    : ${candidate.symbol}');
          print('    name      : ${candidate.name}');
          print('    exchange  : ${candidate.exchange}');
          print('    quoteType : ${candidate.quoteType}');
          print('    isin      : ${candidate.isin ?? "(null)"}');

          final morningstarId = extractMorningstarId(candidate.symbol);

          print(
            '    MS ID      : '
            '${morningstarId ?? '(no es Morningstar 0P...)'}',
          );

          if (morningstarId != null && selectedMorningstarId == null) {
            selectedMorningstarId = morningstarId;
          }

          if (candidate.isin != null && selectedYahooIsin == null) {
            selectedYahooIsin = candidate.isin;
          }

          print('');
        }
      }

      if (selectedYahooIsin != null) {
        yahooIsinFound++;
      }

      // ---------------------------------------------------------------------
      // 2. MORNINGSTAR
      // ---------------------------------------------------------------------

      print('-' * 100);
      print('2. MORNINGSTAR');
      print('-' * 100);

      final morningstarId = selectedMorningstarId ?? test.expectedMorningstarId;

      if (morningstarId == null) {
        print('No hay Morningstar ID disponible.');
        print('');
      } else {
        print('Morningstar ID utilizado: $morningstarId');

        final ms = await queryMorningstar(client, morningstarId);

        if (ms == null) {
          print('Morningstar: sin resultado.');
        } else {
          morningstarFound++;

          print('');
          print('  PerformanceId : ${ms.performanceId ?? '(null)'}');
          print('  HoldingId     : ${ms.holdingId ?? '(null)'}');
          print('  HoldingName   : ${ms.holdingName ?? '(null)'}');
          print('  HoldingIsin   : ${ms.holdingIsin ?? '(null)'}');
          print('  Currency      : ${ms.holdingCurrency ?? '(null)'}');
        }
      }

      // ---------------------------------------------------------------------
      // 3. COMPARACIÓN
      // ---------------------------------------------------------------------

      print('');
      print('-' * 100);
      print('3. COMPARACIÓN');
      print('-' * 100);

      String? morningstarIsin;

      if (morningstarId != null) {
        final ms = await queryMorningstar(client, morningstarId);

        morningstarIsin = ms?.holdingIsin;
      }

      print('ISIN esperado      : ${test.expectedIsin}');
      print('ISIN Yahoo         : ${selectedYahooIsin ?? '(null)'}');
      print('ISIN Morningstar   : ${morningstarIsin ?? '(null)'}');
      print('');

      final yahooMatches =
          selectedYahooIsin?.toUpperCase() == test.expectedIsin.toUpperCase();

      final morningstarMatches =
          morningstarIsin?.toUpperCase() == test.expectedIsin.toUpperCase();

      final yahooMorningstarAgree =
          selectedYahooIsin != null &&
          morningstarIsin != null &&
          selectedYahooIsin.toUpperCase() == morningstarIsin.toUpperCase();

      print(
        'Yahoo == esperado       : '
        '${yahooMatches ? 'SI' : 'NO'}',
      );

      print(
        'Morningstar == esperado : '
        '${morningstarMatches ? 'SI' : 'NO'}',
      );

      print(
        'Yahoo == Morningstar    : '
        '${yahooMorningstarAgree ? 'SI' : 'NO'}',
      );

      if (yahooMatches && morningstarMatches) {
        correct++;
        print('');
        print('RESULTADO: 🟢 CONFIRMADO POR AMBAS FUENTES');
      } else if (morningstarMatches && !yahooMatches) {
        print('');
        print('RESULTADO: 🟡 MORNINGSTAR CORRECTO / YAHOO NO CONFIRMA');
      } else if (yahooMatches && !morningstarMatches) {
        print('');
        print('RESULTADO: 🟠 YAHOO CORRECTO / MORNINGSTAR NO CONFIRMA');
      } else {
        print('');
        print('RESULTADO: 🔴 NO RESUELTO DE FORMA CONCLUYENTE');
      }

      print('');
    }

    // -----------------------------------------------------------------------
    // RESUMEN
    // -----------------------------------------------------------------------

    print('');
    print('=' * 100);
    print('RESUMEN');
    print('=' * 100);

    print('Casos                         : $total');
    print('Yahoo encontró candidatos     : $yahooFound');
    print('Yahoo proporcionó algún ISIN  : $yahooIsinFound');
    print('Morningstar respondió         : $morningstarFound');
    print('Yahoo + Morningstar correctos : $correct');

    print('');
    print('=' * 100);
    print('FIN DEL PROBE');
    print('=' * 100);
  } finally {
    client.close();
  }
}

// ============================================================================
// YAHOO
// ============================================================================

Future<List<YahooCandidate>> searchYahoo(
  http.Client client,
  String query,
) async {
  final uri = Uri.parse(yahooSearchUrl).replace(
    queryParameters: {
      'q': query,
      'quotesCount': '20',
      'newsCount': '0',
      'enableFuzzyQuery': 'false',
    },
  );

  print('GET Yahoo: $uri');

  try {
    final response = await client
        .get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'OpenInvest-Probe/1.0',
          },
        )
        .timeout(const Duration(seconds: 15));

    print('HTTP Yahoo: ${response.statusCode}');
    print('Yahoo body: ${response.body.length} bytes');
    print('');

    if (response.statusCode != 200) {
      return [];
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      print('Yahoo: JSON inesperado.');
      return [];
    }

    final quotes = decoded['quotes'];

    if (quotes is! List) {
      print('Yahoo: campo quotes inexistente o no es una lista.');
      return [];
    }

    final results = <YahooCandidate>[];

    for (final item in quotes) {
      if (item is! Map) continue;

      final symbol = item['symbol']?.toString();

      if (symbol == null || symbol.isEmpty) {
        continue;
      }

      final rawIsin = item['isin']?.toString().trim().toUpperCase();

      results.add(
        YahooCandidate(
          symbol: symbol,
          name:
              item['longname']?.toString() ??
              item['shortname']?.toString() ??
              '',
          exchange: item['exchange']?.toString() ?? '',
          quoteType: item['quoteType']?.toString() ?? '',
          isin: rawIsin == null || rawIsin.isEmpty ? null : rawIsin,
        ),
      );
    }

    return results;
  } catch (e) {
    print('ERROR Yahoo: $e');
    return [];
  }
}

// ============================================================================
// MORNINGSTAR
// ============================================================================

Future<MorningstarResult?> queryMorningstar(
  http.Client client,
  String morningstarId,
) async {
  final uri = Uri.parse(morningstarSnapshotUrl)
      .replace(queryParameters: {'Id': morningstarId, 'LanguageId': 'es-ES'});

  print('');
  print('GET Morningstar: $uri');

  try {
    final response = await client
        .get(
          uri,
          headers: const {
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
            'User-Agent':
                'Mozilla/5.0 (X11; Linux x86_64) '
                'AppleWebKit/537.36 (KHTML, like Gecko) '
                'Chrome/140.0.0.0 Safari/537.36',
          },
        )
        .timeout(const Duration(seconds: 15));

    print('HTTP Morningstar: ${response.statusCode}');
    print('Morningstar body: ${response.body.length} bytes');

    if (response.statusCode != 200) {
      return null;
    }

    final html = response.body;

    final performanceId = extractJsValue(html, 'PerformanceId');

    final holdingId = extractJsValue(html, 'HoldingId');

    final holdingName = extractJsValue(html, 'HoldingName');

    final holdingIsin = extractJsValue(html, 'HoldingIsin');

    final holdingCurrency = extractJsValue(html, 'HoldingCurrency');

    return MorningstarResult(
      performanceId: performanceId,
      holdingId: holdingId,
      holdingName: holdingName,
      holdingIsin: holdingIsin,
      holdingCurrency: holdingCurrency,
    );
  } catch (e) {
    print('ERROR Morningstar: $e');
    return null;
  }
}

// ============================================================================
// EXTRACCIÓN MORNINGSTAR ID
// ============================================================================

String? extractMorningstarId(String symbol) {
  final match = RegExp(
    r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
    caseSensitive: false,
  ).firstMatch(symbol.trim().toUpperCase());

  return match?.group(1);
}

// ============================================================================
// EXTRACCIÓN VARIABLES JAVASCRIPT
// ============================================================================

String? extractJsValue(String html, String variableName) {
  final patterns = [
    RegExp(
      '\\b${RegExp.escape(variableName)}\\s*=\\s*[\'"]([^\'"]*)[\'"]',
      caseSensitive: false,
    ),
    RegExp(
      '\\b${RegExp.escape(variableName)}\\s*:\\s*[\'"]([^\'"]*)[\'"]',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(html);

    if (match != null) {
      final value = match.group(1)?.trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
  }

  return null;
}
