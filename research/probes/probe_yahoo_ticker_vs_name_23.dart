import 'dart:convert';
import 'package:http/http.dart' as http;

/// Probe independiente de producción:
/// Compara Yahoo Search por TICKER vs Yahoo Search por NOMBRE.
/// Además detecta posibles Morningstar IDs (0P...) en los resultados.
///
/// Ejecutar desde la raíz:
///   dart run research/probes/probe_yahoo_ticker_vs_name_23.dart
///
/// NO modifica producción ni utiliza IsinResolver.

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

class YahooMatch {
  final String symbol;
  final String name;
  final String? quoteType;
  final String? isin;

  const YahooMatch({
    required this.symbol,
    required this.name,
    this.quoteType,
    this.isin,
  });
}

const cases = <TestCase>[
  TestCase(name: 'PIMCO GIS Income Fund E Class USD Income', ticker: '0P0000X83M', expectedIsin: 'IE00B8K7V925'),
  TestCase(name: 'Carmignac Patrimoine A EUR Acc', ticker: '0P00000FB4.F', expectedIsin: 'FR0010135103'),
  TestCase(name: 'Fidelity Funds - Iberia A-Acc-EUR', ticker: '0P00006DAB.F', expectedIsin: 'LU0261948904'),
  TestCase(name: 'JPM Europe Strategic Value C Acc EUR', ticker: '0P00000Z1Y.F', expectedIsin: 'LU0129445192'),
  TestCase(name: 'JPM Europe Strategic Value A Acc EUR', ticker: 'LU0210531983', expectedIsin: 'LU0210531983'),
  TestCase(name: 'JPM Europe Strategic Value A Acc USD Hedged', ticker: 'LU1599125231', expectedIsin: 'LU1599125231'),
  TestCase(name: 'JPM Europe Strategic Value A Acc SGD Hedged', ticker: 'LU3284971820', expectedIsin: 'LU3284971820'),
  TestCase(name: 'JPM Europe Strategic Value A Dist EUR', ticker: 'LU0107398884', expectedIsin: 'LU0107398884'),
  TestCase(name: 'JPM Europe Strategic Value A Dist GBP', ticker: 'LU0119092640', expectedIsin: 'LU0119092640'),
  TestCase(name: 'Fidelity European Growth A Acc EUR', ticker: 'LU0296857971', expectedIsin: 'LU0296857971'),
  TestCase(name: 'Fidelity European Growth A Acc USD Hedged', ticker: 'LU0997586606', expectedIsin: 'LU0997586606'),
  TestCase(name: 'Fidelity European Growth A Dist EUR', ticker: 'LU0048578792', expectedIsin: 'LU0048578792'),
  TestCase(name: 'Fidelity European Growth A Dist SGD', ticker: 'LU0550127509', expectedIsin: 'LU0550127509'),
  TestCase(name: 'Fidelity European Growth C Dist EUR', ticker: 'LU0324710721', expectedIsin: 'LU0324710721'),
  TestCase(name: 'Fidelity European Growth E Acc EUR', ticker: 'LU0115764192', expectedIsin: 'LU0115764192'),
  TestCase(name: 'Fidelity European Growth I Acc EUR', ticker: 'LU1642889510', expectedIsin: 'LU1642889510'),
  TestCase(name: 'Fidelity European Growth SR Acc EUR', ticker: 'LU1235258925', expectedIsin: 'LU1235258925'),
  TestCase(name: 'Fidelity European Growth SR Acc SGD', ticker: 'LU1235259576', expectedIsin: 'LU1235259576'),
  TestCase(name: 'BlackRock Next Generation Technology A10 USD', ticker: 'LU2533724949', expectedIsin: 'LU2533724949'),
  TestCase(name: 'BlackRock Next Generation Technology A2 SEK', ticker: 'LU1861216940', expectedIsin: 'LU1861216940'),
  TestCase(name: 'BlackRock Next Generation Technology A2 EUR', ticker: 'LU2400291972', expectedIsin: 'LU2400291972'),
  TestCase(name: 'BlackRock Next Generation Technology A2 USD', ticker: 'LU1861215975', expectedIsin: 'LU1861215975'),
  TestCase(name: 'Carmignac Patrimoine A CHF Acc Hdg', ticker: 'FR0011269596', expectedIsin: 'FR0011269596'),
];

const yahooBase = 'https://query1.finance.yahoo.com/v1/finance/search?q=';

final morningstarIdRx =
    RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$', caseSensitive: false);

final anyMorningstarIdRx =
    RegExp(r'0P[0-9A-Z]+(?:\.[A-Z]+)?', caseSensitive: false);

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
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Yahoo HTTP ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final quotes = (json['quotes'] as List?) ?? const [];

  return quotes.whereType<Map>().map((q) {
    return YahooMatch(
      symbol: '${q['symbol'] ?? ''}',
      name: '${q['longname'] ?? q['shortname'] ?? ''}',
      quoteType: q['quoteType']?.toString(),
      isin: q['isin']?.toString().trim().toUpperCase(),
    );
  }).toList();
}

String? extractMorningstarIdFromSymbol(String symbol) {
  final match = morningstarIdRx.firstMatch(symbol.trim());
  return match?.group(1)?.toUpperCase();
}

String? extractMorningstarIdFromAnyText(String text) {
  final match = anyMorningstarIdRx.firstMatch(text);
  if (match == null) return null;
  return match.group(0)?.toUpperCase();
}

List<String> uniqueMorningstarIds(List<YahooMatch> matches) {
  final ids = <String>{};

  for (final m in matches) {
    final fromSymbol = extractMorningstarIdFromSymbol(m.symbol);
    if (fromSymbol != null) ids.add(fromSymbol);

    final fromAll = extractMorningstarIdFromAnyText(
      '${m.symbol} ${m.name}',
    );
    if (fromAll != null) ids.add(fromAll);
  }

  return ids.toList();
}

String normalize(String s) {
  return s
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

double nameSimilarity(String a, String b) {
  final aa = normalize(a);
  final bb = normalize(b);

  if (aa == bb) return 1.0;
  if (aa.contains(bb) || bb.contains(aa)) return 0.9;

  final aWords = aa.split(' ').where((x) => x.length > 2).toSet();
  final bWords = bb.split(' ').where((x) => x.length > 2).toSet();

  if (aWords.isEmpty || bWords.isEmpty) return 0.0;

  final intersection = aWords.intersection(bWords).length;
  final union = aWords.union(bWords).length;

  return union == 0 ? 0.0 : intersection / union;
}

YahooMatch? bestNameMatch(
  List<YahooMatch> matches,
  String fundName,
) {
  if (matches.isEmpty) return null;

  YahooMatch? best;
  var bestScore = -1.0;

  for (final m in matches) {
    var score = nameSimilarity(fundName, m.name);

    if (m.quoteType == 'MUTUALFUND') {
      score += 0.10;
    }

    if (score > bestScore) {
      bestScore = score;
      best = m;
    }
  }

  return best;
}

void printMatches(
  String label,
  List<YahooMatch> matches,
  String fundName,
) {
  print(label);

  if (matches.isEmpty) {
    print('  SIN RESULTADOS');
    return;
  }

  for (var i = 0; i < matches.length && i < 10; i++) {
    final m = matches[i];
    final ms = extractMorningstarIdFromAnyText(
      '${m.symbol} ${m.name}',
    );

    print('  [$i] ${m.symbol}');
    print('      name     : ${m.name}');
    print('      quoteType: ${m.quoteType ?? '-'}');
    print('      isin     : ${m.isin ?? '-'}');
    print('      MS ID    : ${ms ?? '-'}');
    print(
      '      similitud: ${nameSimilarity(fundName, m.name).toStringAsFixed(3)}',
    );
  }
}

Future<void> main() async {
  final client = http.Client();

  var tickerQueries = 0;
  var nameQueries = 0;
  var tickerFound = 0;
  var nameFound = 0;
  var tickerHasIsin = 0;
  var nameHasIsin = 0;
  var tickerHasMsId = 0;
  var nameHasMsId = 0;
  var newMsIdsFromName = 0;
  var sameTopSymbol = 0;
  var differentTopSymbol = 0;

  final discoveredMsIds = <String>{};

  print('=' * 100);
  print('PROBE: YAHOO POR TICKER vs YAHOO POR NOMBRE');
  print('Casos: ${cases.length}');
  print('=' * 100);

  try {
    for (var i = 0; i < cases.length; i++) {
      final t = cases[i];

      print('\n' + '-' * 100);
      print('CASO ${i + 1}/${cases.length}');
      print('-' * 100);
      print('INPUT');
      print('  ticker   : ${t.ticker}');
      print('  nombre   : ${t.name}');
      print('  esperado : ${t.expectedIsin ?? '-'}');

      List<YahooMatch> tickerResults = const [];
      List<YahooMatch> nameResults = const [];

      try {
        tickerResults = await searchYahoo(client, t.ticker);
        tickerQueries++;
      } catch (e) {
        print('  ERROR Yahoo ticker: $e');
      }

      try {
        nameResults = await searchYahoo(client, t.name);
        nameQueries++;
      } catch (e) {
        print('  ERROR Yahoo nombre: $e');
      }

      if (tickerResults.isNotEmpty) tickerFound++;
      if (nameResults.isNotEmpty) nameFound++;

      final tickerIsin = tickerResults
          .map((x) => x.isin)
          .whereType<String>()
          .firstWhere(
            (x) => x.isNotEmpty,
            orElse: () => '',
          );

      final nameIsin = nameResults
          .map((x) => x.isin)
          .whereType<String>()
          .firstWhere(
            (x) => x.isNotEmpty,
            orElse: () => '',
          );

      if (tickerIsin.isNotEmpty) tickerHasIsin++;
      if (nameIsin.isNotEmpty) nameHasIsin++;

      final tickerMsIds = uniqueMorningstarIds(tickerResults);
      final nameMsIds = uniqueMorningstarIds(nameResults);

      if (tickerMsIds.isNotEmpty) tickerHasMsId++;
      if (nameMsIds.isNotEmpty) nameHasMsId++;

      discoveredMsIds.addAll(tickerMsIds);
      discoveredMsIds.addAll(nameMsIds);

      final newFromName = nameMsIds
          .where((id) => !tickerMsIds.contains(id))
          .toList();

      if (newFromName.isNotEmpty) newMsIdsFromName++;

      final tickerTop = tickerResults.isEmpty ? null : tickerResults.first.symbol;
      final nameTop = nameResults.isEmpty ? null : nameResults.first.symbol;

      if (tickerTop != null && nameTop != null) {
        if (tickerTop.toUpperCase() == nameTop.toUpperCase()) {
          sameTopSymbol++;
        } else {
          differentTopSymbol++;
        }
      }

      print('');
      printMatches('YAHOO POR TICKER', tickerResults, t.name);

      print('');
      printMatches('YAHOO POR NOMBRE', nameResults, t.name);

      print('');
      print('COMPARACIÓN');
      print('  ISIN por ticker : ${tickerIsin.isEmpty ? '-' : tickerIsin}');
      print('  ISIN por nombre : ${nameIsin.isEmpty ? '-' : nameIsin}');
      print('  MS ID ticker    : ${tickerMsIds.isEmpty ? '-' : tickerMsIds.join(', ')}');
      print('  MS ID nombre    : ${nameMsIds.isEmpty ? '-' : nameMsIds.join(', ')}');

      if (newFromName.isNotEmpty) {
        print(
          '  NUEVO MS ID POR NOMBRE: ${newFromName.join(', ')}',
        );
      }

      if (t.expectedIsin != null) {
        print(
          '  ticker ISIN = esperado: '
          '${tickerIsin == t.expectedIsin ? 'SI' : 'NO'}',
        );
        print(
          '  nombre ISIN = esperado: '
          '${nameIsin == t.expectedIsin ? 'SI' : 'NO'}',
        );
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 150),
      );
    }
  } finally {
    client.close();
  }

  print('\n' + '=' * 100);
  print('RESUMEN');
  print('=' * 100);
  print('Casos                         : ${cases.length}');
  print('Consultas Yahoo por ticker    : $tickerQueries');
  print('Consultas Yahoo por nombre    : $nameQueries');
  print('Ticker con resultados         : $tickerFound');
  print('Nombre con resultados         : $nameFound');
  print('Ticker devuelve ISIN          : $tickerHasIsin');
  print('Nombre devuelve ISIN          : $nameHasIsin');
  print('Ticker descubre Morningstar ID: $tickerHasMsId');
  print('Nombre descubre Morningstar ID: $nameHasMsId');
  print('Nombre descubre MS ID adicional: $newMsIdsFromName');
  print('Mismo primer symbol           : $sameTopSymbol');
  print('Primer symbol diferente       : $differentTopSymbol');
  print('');
  print('Morningstar IDs descubiertos:');
  if (discoveredMsIds.isEmpty) {
    print('  Ninguno');
  } else {
    for (final id in discoveredMsIds.toList()..sort()) {
      print('  $id');
    }
  }

  print('');
  print('Este probe es independiente de IsinResolver.');
  print('No modifica ningún archivo de producción.');
  print('=' * 100);
}
