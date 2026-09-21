import 'dart:convert';
import 'dart:io';

class _ProbeCase {
  final String description;
  final String ticker;
  final String expectedIsin;

  const _ProbeCase({
    required this.description,
    required this.ticker,
    required this.expectedIsin,
  });
}

const _cases = <_ProbeCase>[
  _ProbeCase(
    description: 'PIMCO GIS Income Fund E Class USD Income',
    ticker: '0P0000X83M',
    expectedIsin: 'IE00B8K7V925',
  ),
  _ProbeCase(
    description: 'JPMorgan Korea (acc) - USD',
    ticker: '0P00000ZJQ',
    expectedIsin: 'HK0000055712',
  ),
  _ProbeCase(
    description: 'Premier Miton European Opportunities Fund B Accumulation',
    ticker: '0P00017461',
    expectedIsin: 'GB00BZ2K2M84',
  ),
];

Future<void> main() async {
  print('=' * 80);
  print('YAHOO ISIN PROBE');
  print('=' * 80);
  print('Endpoint: https://query1.finance.yahoo.com/v1/finance/search');
  print('');

  final client = HttpClient();

  try {
    for (final testCase in _cases) {
      await _probe(client, testCase);
    }
  } finally {
    client.close();
  }
}

Future<void> _probe(HttpClient client, _ProbeCase testCase) async {
  print('-' * 80);
  print('TEST: ${testCase.description}');
  print('Ticker:   ${testCase.ticker}');
  print('Esperado: ${testCase.expectedIsin}');
  print('');

  final uri = Uri.https(
    'query1.finance.yahoo.com',
    '/v1/finance/search',
    <String, String>{
      'q': testCase.ticker,
      'quotesCount': '20',
      'newsCount': '0',
      'enableFuzzyQuery': 'false',
    },
  );

  print('GET $uri');

  try {
    final request = await client.getUrl(uri);

    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (compatible; OpenInvest/1.0)',
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    print('HTTP: ${response.statusCode}');

    if (response.statusCode != HttpStatus.ok) {
      print('ERROR: Yahoo respondió HTTP ${response.statusCode}');
      print('Body:');
      print(body);
      print('');
      return;
    }

    final decoded = jsonDecode(body);

    if (decoded is! Map<String, dynamic>) {
      print('ERROR: respuesta JSON inesperada.');
      print(body);
      print('');
      return;
    }

    final quotes = decoded['quotes'];

    if (quotes is! List) {
      print('ERROR: no existe "quotes" como lista.');
      print('JSON:');
      print(const JsonEncoder.withIndent('  ').convert(decoded));
      print('');
      return;
    }

    print('Candidatos encontrados: ${quotes.length}');
    print('');

    String? yahooIsin;
    String? yahooSymbol;
    String? yahooName;

    for (var i = 0; i < quotes.length; i++) {
      final item = quotes[i];

      if (item is! Map) {
        continue;
      }

      final symbol = item['symbol']?.toString();
      final shortName = item['shortname']?.toString();
      final longName = item['longname']?.toString();
      final quoteType = item['quoteType']?.toString();
      final exchange = item['exchange']?.toString();
      final isin = item['isin']?.toString();

      print('Candidato #${i + 1}');
      print('  symbol:    $symbol');
      print('  shortname: $shortName');
      print('  longname:  $longName');
      print('  quoteType: $quoteType');
      print('  exchange:  $exchange');
      print('  isin:      $isin');
      print('');

      if (isin != null && isin.trim().isNotEmpty) {
        yahooIsin = isin.trim().toUpperCase();
        yahooSymbol = symbol;
        yahooName = longName ?? shortName;
      }
    }

    print('RESULTADO YAHOO');
    print('  ISIN:      ${yahooIsin ?? '<no proporcionado>'}');
    print('  Symbol:    ${yahooSymbol ?? '<no encontrado>'}');
    print('  Nombre:    ${yahooName ?? '<no encontrado>'}');
    print('  Esperado:  ${testCase.expectedIsin}');

    if (yahooIsin == testCase.expectedIsin) {
      print('  Estado:    CORRECTO');
    } else if (yahooIsin == null) {
      print('  Estado:    SIN ISIN EN YAHOO');
    } else {
      print('  Estado:    ISIN DISTINTO');
    }

    print('');
  } catch (e, stackTrace) {
    print('EXCEPCIÓN: $e');
    print(stackTrace);
    print('');
  }
}
