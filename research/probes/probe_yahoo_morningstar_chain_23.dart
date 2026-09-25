import 'dart:convert';
import 'package:http/http.dart' as http;

/// Probe independiente de producción.
///
/// Objetivo:
///   Yahoo Search -> Morningstar ID (0P...) -> Morningstar HoldingIsin
///
/// NO modifica IsinResolver ni ningún provider de producción.
///
/// Ejecutar desde la raíz del proyecto:
///   dart run research/probes/probe_yahoo_morningstar_chain_23.dart
///
/// Nota:
/// - Los casos 1-4 tienen Morningstar ID conocido.
/// - Para los restantes, el probe usa Yahoo para descubrir el ID.
/// - Si Yahoo devuelve varias variantes (.F, .SI, .SW, .L...), se
///   normalizan al ID base antes de consultar Morningstar.
/// - Se consulta cada ID base descubierto una sola vez.

const yahooBase =
    'https://query1.finance.yahoo.com/v1/finance/search?q=';

const morningstarUrl =
    'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

class TestCase {
  final String name;
  final String ticker;
  final String expectedIsin;

  const TestCase({
    required this.name,
    required this.ticker,
    required this.expectedIsin,
  });
}

class YahooMatch {
  final String symbol;
  final String name;
  final String quoteType;
  final String? isin;
  final String? morningstarId;

  YahooMatch({
    required this.symbol,
    required this.name,
    required this.quoteType,
    required this.isin,
    required this.morningstarId,
  });
}

class MorningstarResult {
  final String id;
  final int statusCode;
  final String? holdingIsin;
  final String? error;

  MorningstarResult({
    required this.id,
    required this.statusCode,
    required this.holdingIsin,
    required this.error,
  });
}

final cases = <TestCase>[
  TestCase(
    name: 'PIMCO GIS Income Fund E USD Inc',
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

final _morningstarIdRegex = RegExp(r'0P[0-9A-Z]+', caseSensitive: false);

String? detectMorningstarId(String symbol) {
  final match = _morningstarIdRegex.firstMatch(symbol);
  return match?.group(0)?.toUpperCase();
}

String normalizeMorningstarId(String id) {
  final upper = id.toUpperCase().trim();
  return upper.split('.').first;
}

String cleanHtml(String html) {
  return html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<List<YahooMatch>> searchYahoo(
  http.Client client,
  String query,
) async {
  final uri = Uri.parse(
    '$yahooBase${Uri.encodeQueryComponent(query)}',
  );

  final response = await client.get(
    uri,
    headers: const {
      'User-Agent':
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/140.0 Safari/537.36',
      'Accept': 'application/json,text/plain,*/*',
    },
  );

  if (response.statusCode != 200) {
    return [];
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map) return [];

  final quotes = decoded['quotes'];
  if (quotes is! List) return [];

  final result = <YahooMatch>[];

  for (final item in quotes) {
    if (item is! Map) continue;

    final symbol = item['symbol']?.toString() ?? '';
    if (symbol.isEmpty) continue;

    final name =
        item['longname']?.toString() ??
        item['shortname']?.toString() ??
        '';

    final quoteType = item['quoteType']?.toString() ?? '';

    final rawIsin = item['isin']?.toString();
    final isin =
        rawIsin == null || rawIsin.trim().isEmpty ? null : rawIsin.trim();

    result.add(
      YahooMatch(
        symbol: symbol,
        name: name,
        quoteType: quoteType,
        isin: isin,
        morningstarId: detectMorningstarId(symbol),
      ),
    );
  }

  return result;
}

String? extractHoldingIsin(String body) {
  final patterns = <RegExp>[
    RegExp(
      r"""HoldingIsin\s*=\s*['"]([A-Z]{2}[A-Z0-9]{9}[0-9])['"]""",
      caseSensitive: false,
    ),
    RegExp(
      r"""HoldingIsin['"]?\s*[:=]\s*['"]([A-Z]{2}[A-Z0-9]{9}[0-9])['"]""",
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(body);
    if (match != null) {
      return match.group(1)?.toUpperCase();
    }
  }

  return null;
}

Future<MorningstarResult> queryMorningstar(
  http.Client client,
  String morningstarId,
) async {
  final uri = Uri.parse(morningstarUrl).replace(
    queryParameters: {
      'Id': morningstarId,
      'LanguageId': 'es-ES',
    },
  );

  try {
    final response = await client.get(
      uri,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/140.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      },
    );

    if (response.statusCode != 200) {
      return MorningstarResult(
        id: morningstarId,
        statusCode: response.statusCode,
        holdingIsin: null,
        error: 'HTTP ${response.statusCode}',
      );
    }

    final holdingIsin = extractHoldingIsin(response.body);

    return MorningstarResult(
      id: morningstarId,
      statusCode: response.statusCode,
      holdingIsin: holdingIsin,
      error: holdingIsin == null ? 'HoldingIsin no encontrado' : null,
    );
  } catch (e) {
    return MorningstarResult(
      id: morningstarId,
      statusCode: 0,
      holdingIsin: null,
      error: e.toString(),
    );
  }
}

String statusFor({
  required String? yahooIsin,
  required String? morningstarIsin,
  required String expectedIsin,
}) {
  if (morningstarIsin == expectedIsin) {
    return 'OK';
  }

  if (morningstarIsin == null) {
    return yahooIsin == expectedIsin
        ? 'YAHOO_OK_MS_NO_ISIN'
        : 'MS_NO_ISIN';
  }

  if (morningstarIsin != expectedIsin) {
    return 'ISIN_DIFERENTE';
  }

  return 'NO_DETERMINADO';
}

void main() async {
  final client = http.Client();

  final allDiscoveredIds = <String>{};
  final yahooByCase = <TestCase, List<YahooMatch>>{};

  var yahooQueries = 0;
  var yahooCasesWithResults = 0;
  var yahooCasesWithIsin = 0;
  var yahooCasesWithMsId = 0;

  print('');
  print('=' * 100);
  print('PROBE 3 - CADENA YAHOO -> MORNINGSTAR -> ISIN');
  print('=' * 100);
  print('');
  print('23 casos reales. SIN CAMBIAR PRODUCCIÓN.');
  print('');

  try {
    // -----------------------------------------------------------------------
    // FASE 1: Yahoo
    // -----------------------------------------------------------------------
    print('-' * 100);
    print('FASE 1: YAHOO SEARCH POR TICKER');
    print('-' * 100);

    for (final test in cases) {
      yahooQueries++;

      final matches = await searchYahoo(client, test.ticker);
      yahooByCase[test] = matches;

      if (matches.isNotEmpty) {
        yahooCasesWithResults++;
      }

      final ids = <String>{};

      for (final match in matches) {
        if (match.isin != null) {
          yahooCasesWithIsin++;
          break;
        }
      }

      for (final match in matches) {
        final id = match.morningstarId;
        if (id != null) {
          final normalized = normalizeMorningstarId(id);
          ids.add(normalized);
          allDiscoveredIds.add(normalized);
        }
      }

      if (ids.isNotEmpty) {
        yahooCasesWithMsId++;
      }

      print('');
      print('CASO: ${test.name}');
      print('Ticker: ${test.ticker}');
      print('Esperado: ${test.expectedIsin}');
      print('Yahoo resultados: ${matches.length}');
      print('Morningstar IDs: ${ids.isEmpty ? "-" : ids.join(", ")}');

      for (var i = 0; i < matches.length && i < 10; i++) {
        final m = matches[i];
        print(
          '  ${i + 1}. ${m.symbol} | ${m.name} | '
          '${m.quoteType} | ISIN=${m.isin ?? "-"}',
        );
      }
    }

    // -----------------------------------------------------------------------
    // FASE 2: Morningstar
    // -----------------------------------------------------------------------
    print('');
    print('=' * 100);
    print('FASE 2: MORNINGSTAR HoldingIsin');
    print('=' * 100);
    print('');
    print('IDs base únicos descubiertos por Yahoo: ${allDiscoveredIds.length}');
    print('');

    final morningstarCache = <String, MorningstarResult>{};

    var msOk = 0;
    var msNoIsin = 0;
    var msDifferent = 0;
    var chainOk = 0;
    var chainFailed = 0;
    var chainNoId = 0;

    for (final test in cases) {
      final matches = yahooByCase[test] ?? [];

      final ids = <String>{};
      for (final match in matches) {
        final id = match.morningstarId;
        if (id != null) {
          ids.add(normalizeMorningstarId(id));
        }
      }

      print('');
      print('-' * 100);
      print('CASO: ${test.name}');
      print('Yahoo ticker: ${test.ticker}');
      print('ISIN esperado: ${test.expectedIsin}');
      print('IDs Yahoo: ${ids.isEmpty ? "-" : ids.join(", ")}');

      if (ids.isEmpty) {
        chainNoId++;
        print('RESULTADO CADENA: SIN MORNINGSTAR ID');
        continue;
      }

      var caseOk = false;
      var caseDifferent = false;
      var caseHadMorningstarIsin = false;

      for (final id in ids) {
        final ms = morningstarCache[id] ??= await queryMorningstar(
          client,
          id,
        );

        final status = statusFor(
          yahooIsin: null,
          morningstarIsin: ms.holdingIsin,
          expectedIsin: test.expectedIsin,
        );

        print(
          '  MS $id -> HTTP ${ms.statusCode} | '
          'HoldingIsin=${ms.holdingIsin ?? "-"} | $status',
        );

        if (ms.holdingIsin != null) {
          caseHadMorningstarIsin = true;

          if (ms.holdingIsin == test.expectedIsin) {
            caseOk = true;
          } else {
            caseDifferent = true;
          }
        }
      }

      if (caseOk) {
        chainOk++;
      } else {
        chainFailed++;
      }

      if (caseHadMorningstarIsin) {
        if (caseOk) {
          msOk++;
        } else if (caseDifferent) {
          msDifferent++;
        }
      } else {
        msNoIsin++;
      }

      if (caseOk) {
        print('>>> CADENA: OK');
      } else if (caseDifferent) {
        print('>>> CADENA: ISIN DIFERENTE');
      } else {
        print('>>> CADENA: NO RESUELTO');
      }
    }

    // -----------------------------------------------------------------------
    // FASE 3: resumen
    // -----------------------------------------------------------------------
    print('');
    print('=' * 100);
    print('RESUMEN');
    print('=' * 100);

    print('Casos                              : ${cases.length}');
    print('Consultas Yahoo por ticker         : $yahooQueries');
    print('Casos Yahoo con resultados         : $yahooCasesWithResults');
    print('Casos Yahoo con ISIN               : $yahooCasesWithIsin');
    print('Casos Yahoo con Morningstar ID     : $yahooCasesWithMsId');
    print('IDs Morningstar base únicos        : ${allDiscoveredIds.length}');
    print('');
    print('Casos cadena completos OK          : $chainOk');
    print('Casos cadena no resueltos          : $chainFailed');
    print('Casos sin Morningstar ID            : $chainNoId');
    print('');
    print('Casos Morningstar con ISIN correcto: $msOk');
    print('Casos Morningstar sin HoldingIsin  : $msNoIsin');
    print('Casos Morningstar ISIN diferente   : $msDifferent');

    print('');
    print('IDs Morningstar consultados:');
    final sortedIds = allDiscoveredIds.toList()..sort();
    for (final id in sortedIds) {
      final ms = morningstarCache[id];
      print(
        '  $id -> ${ms?.holdingIsin ?? "-"} '
        '(HTTP ${ms?.statusCode ?? "-"})',
      );
    }

    print('');
    print('=' * 100);
    print('INTERPRETACIÓN');
    print('=' * 100);
    print('');
    print(
      'Este probe NO decide ninguna prioridad ni modifica producción.',
    );
    print(
      'Su objetivo es medir exclusivamente si la cadena '
      'Yahoo -> Morningstar -> HoldingIsin',
    );
    print(
      'recupera el ISIN esperado y si aparecen discrepancias entre clases.',
    );
    print('');
  } finally {
    client.close();
  }
}
