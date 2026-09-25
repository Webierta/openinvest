import 'dart:convert';
import 'package:http/http.dart' as http;

class TestCase {
  final String name, ticker;
  final String? expectedIsin;
  const TestCase({required this.name, required this.ticker, this.expectedIsin});
}

class YahooMatch {
  final String symbol, name;
  final String? quoteType, isin;
  const YahooMatch({required this.symbol, required this.name, this.quoteType, this.isin});
}

class MorningstarResult {
  final String? morningstarId, holdingIsin;
  final int? statusCode;
  final String? error;
  const MorningstarResult({this.morningstarId, this.holdingIsin, this.statusCode, this.error});
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
const morningstarBase = 'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

final msIdRx = RegExp(r'(0P[0-9A-Z]+)(?:\.[A-Z]+)?', caseSensitive: false);
final msIsinRx = [
  RegExp(r"""HoldingIsin\s*['"]?\s*[:=]\s*['"]([A-Z]{2}[A-Z0-9]{9}[0-9])['"]""", caseSensitive: false),
  RegExp(r"""HoldingIsin\s*=\s*['"]([A-Z]{2}[A-Z0-9]{9}[0-9])['"]""", caseSensitive: false),
];

bool isIsin(String? value) {
  if (value == null) return false;
  final s = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(s)) return false;
  final digits = <int>[];
  for (final c in s.split('')) {
    if (RegExp(r'[A-Z]').hasMatch(c)) {
      digits.addAll((c.codeUnitAt(0) - 55).toString().split('').map(int.parse));
    } else {
      digits.add(int.parse(c));
    }
  }
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    final p = digits[i] * ((digits.length - i).isEven ? 2 : 1);
    sum += p ~/ 10 + p % 10;
  }
  return sum % 10 == 0;
}

String? msId(String ticker) => msIdRx.firstMatch(ticker.trim())?.group(1)?.toUpperCase();

Future<List<YahooMatch>> yahoo(http.Client client, String query) async {
  final uri = Uri.parse('$yahooBase${Uri.encodeQueryComponent(query)}');
  final r = await client.get(uri, headers: const {'Accept': 'application/json', 'User-Agent': 'Mozilla/5.0'});
  if (r.statusCode != 200) throw Exception('Yahoo HTTP ${r.statusCode}');
  final j = jsonDecode(r.body) as Map<String, dynamic>;
  final q = (j['quotes'] as List?) ?? const [];
  return q.whereType<Map>().map((x) => YahooMatch(
    symbol: '${x['symbol'] ?? ''}',
    name: '${x['longname'] ?? x['shortname'] ?? ''}',
    quoteType: x['quoteType']?.toString(),
    isin: x['isin']?.toString().trim().toUpperCase(),
  )).toList();
}

Future<MorningstarResult> morningstar(http.Client client, String ticker) async {
  final id = msId(ticker);
  if (id == null) return const MorningstarResult(error: 'SIN MORNINGSTAR ID EN EL TICKER');
  try {
    final uri = Uri.parse(morningstarBase).replace(queryParameters: {'Id': id, 'LanguageId': 'es-ES'});
    final r = await client.get(uri, headers: const {
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140.0 Safari/537.36',
    });
    if (r.statusCode != 200) return MorningstarResult(morningstarId: id, statusCode: r.statusCode, error: 'HTTP ${r.statusCode}');
    String? isin;
    for (final rx in msIsinRx) {
      final m = rx.firstMatch(r.body);
      final candidate = m?.group(1)?.toUpperCase();
      if (isIsin(candidate)) { isin = candidate; break; }
    }
    return MorningstarResult(morningstarId: id, holdingIsin: isin, statusCode: r.statusCode,
      error: isin == null ? 'HoldingIsin NO ENCONTRADO' : null);
  } catch (e) {
    return MorningstarResult(morningstarId: id, error: e.toString());
  }
}

Future<void> main() async {
  final client = http.Client();
  var y = 0, m = 0, same = 0, diff = 0, onlyY = 0, onlyM = 0, noId = 0;
  print('=' * 100);
  print('PROBE: YAHOO ISIN vs MORNINGSTAR HoldingIsin');
  print('Casos: ${cases.length}');
  print('=' * 100);

  try {
    for (var i = 0; i < cases.length; i++) {
      final t = cases[i];
      print('\n' + '-' * 100);
      print('CASO ${i + 1}/${cases.length}');
      print('INPUT       ticker : ${t.ticker}');
      print('            nombre : ${t.name}');
      print('            esperado: ${t.expectedIsin ?? '-'}');

      List<YahooMatch> matches = [];
      String? yi;
      try {
        matches = await yahoo(client, t.ticker);
        YahooMatch? selected;
        for (final x in matches) {
          if (x.symbol.toUpperCase() == t.ticker.toUpperCase()) { selected = x; break; }
        }
        if (selected == null) {
          for (final x in matches) {
            if (isIsin(x.isin)) { selected = x; break; }
          }
        }
        yi = selected?.isin;
      } catch (e) {
        print('YAHOO ERROR: $e');
      }

      print('YAHOO');
      if (matches.isEmpty) print('  SIN RESULTADOS');
      for (var n = 0; n < matches.length && n < 5; n++) {
        final x = matches[n];
        print('  [$n] ${x.symbol} | ${x.name} | ${x.quoteType ?? '-'} | ISIN=${x.isin ?? '-'}');
      }
      print('  ISIN seleccionado: ${yi ?? '-'}');
      if (yi != null) y++;

      final mr = await morningstar(client, t.ticker);
      print('MORNINGSTAR');
      print('  ID          : ${mr.morningstarId ?? '-'}');
      print('  HTTP        : ${mr.statusCode ?? '-'}');
      print('  HoldingIsin : ${mr.holdingIsin ?? '-'}');
      if (mr.error != null) print('  estado      : ${mr.error}');
      if (mr.holdingIsin != null) m++;

      final relation = mr.morningstarId == null ? 'SIN MORNINGSTAR ID' :
        yi != null && mr.holdingIsin != null ? (yi == mr.holdingIsin ? 'COINCIDE' : 'DIFIERE') :
        yi != null ? 'SOLO YAHOO' :
        mr.holdingIsin != null ? 'SOLO MORNINGSTAR' : 'NINGUNO';
      print('COMPARACIÓN  : $relation');

      if (relation == 'COINCIDE') same++;
      if (relation == 'DIFIERE') diff++;
      if (relation == 'SOLO YAHOO') onlyY++;
      if (relation == 'SOLO MORNINGSTAR') onlyM++;
      if (relation == 'SIN MORNINGSTAR ID') noId++;

      if (t.expectedIsin != null) {
        print('  Yahoo vs esperado     : ${yi == t.expectedIsin ? 'OK' : 'NO'}');
        print('  Morningstar vs esperado: ${mr.holdingIsin == t.expectedIsin ? 'OK' : 'NO'}');
      }
    }
  } finally {
    client.close();
  }

  print('\n' + '=' * 100);
  print('RESUMEN');
  print('=' * 100);
  print('Casos                     : ${cases.length}');
  print('Yahoo devuelve ISIN       : $y');
  print('Morningstar devuelve ISIN : $m');
  print('Coinciden                 : $same');
  print('Difieren                  : $diff');
  print('Solo Yahoo                : $onlyY');
  print('Solo Morningstar          : $onlyM');
  print('Sin Morningstar ID        : $noId');
  print('=' * 100);
  print('Este probe es independiente de IsinResolver y no modifica producción.');
}
