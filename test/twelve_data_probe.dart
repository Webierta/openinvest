import 'dart:convert';
import 'dart:io';

const testSymbols = <Map<String, String>>[
  {
    'symbol': '0P0000X83M',
    'expectedIsin': 'IE00B8K7V925',
    'expectedName': 'PIMCO GIS Income Fund E Class USD Income',
  },
  {
    'symbol': '0P00000ZJQ',
    'expectedIsin': 'HK0000055712',
    'expectedName': 'JPMorgan Korea (acc) - USD',
  },
  {
    'symbol': '0P00017461',
    'expectedIsin': 'GB00BZ2K2M84',
    'expectedName': 'Premier Miton European Opportunities Fund B Accumulation',
  },
];

Future<void> main() async {
  final apiKey = Platform.environment['TWELVE_DATA_API_KEY'];

  if (apiKey == null || apiKey.trim().isEmpty) {
    stderr.writeln(
      'ERROR: falta la variable de entorno TWELVE_DATA_API_KEY.\n'
      'Ejemplo:\n'
      '  export TWELVE_DATA_API_KEY="TU_SECRET_KEY"\n'
      '  dart run test/twelve_data_probe.dart',
    );
    exitCode = 2;
    return;
  }

  stdout.writeln('=' * 80);
  stdout.writeln('TWELVE DATA / FUNDS PROBE');
  stdout.writeln('=' * 80);

  final client = HttpClient();

  try {
    for (final test in testSymbols) {
      final symbol = test['symbol']!;
      final expectedIsin = test['expectedIsin']!;
      final expectedName = test['expectedName']!;

      stdout.writeln('\n' + '-' * 80);
      stdout.writeln('Symbol:         $symbol');
      stdout.writeln('Expected name:  $expectedName');
      stdout.writeln('Expected ISIN:  $expectedIsin');

      await _probe(client, '/funds', {
        'symbol': symbol,
        'show_plan': 'true',
      }, apiKey);

      await _probe(client, '/search', {
        'symbol': symbol,
        'outputsize': '10',
      }, apiKey);
    }
  } finally {
    client.close();
  }
}

Future<void> _probe(
  HttpClient client,
  String endpoint,
  Map<String, String> params,
  String apiKey,
) async {
  final query = <String, String>{...params, 'apikey': apiKey};

  final uri = Uri.https('api.twelvedata.com', endpoint, query);

  stdout.writeln(
    '\nGET ${uri.replace(queryParameters: {...query, 'apikey': '***'})}',
  );

  try {
    final request = await client.getUrl(uri);
    request.headers.set('Accept', 'application/json');

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    stdout.writeln('HTTP: ${response.statusCode}');
    stdout.writeln('Content-Type: ${response.headers.contentType}');
    stdout.writeln('Body length: ${body.length}');

    try {
      final decoded = jsonDecode(body);
      const encoder = JsonEncoder.withIndent('  ');
      stdout.writeln(encoder.convert(decoded));
    } catch (_) {
      stdout.writeln(body);
    }
  } catch (e, st) {
    stdout.writeln('ERROR: $e');
    stdout.writeln(st);
  }
}
