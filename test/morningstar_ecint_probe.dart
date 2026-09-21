import 'dart:convert';
import 'dart:io';

const cases = <String, String>{
  '0P0000X83M': 'IE00B8K7V925',
  '0P00000ZJQ': 'HK0000055712',
  '0P00017461': 'GB00BZ2K2M84',
};

Future<void> main() async {
  print('=' * 80);
  print('MORNINGSTAR ECINT / SCREENER PROBE');
  print('=' * 80);
  print('');

  final client = HttpClient()
    ..userAgent = 'Mozilla/5.0 (compatible; OpenInvest/1.0)';

  try {
    for (final entry in cases.entries) {
      await probe(client, entry.key, entry.value);
    }
  } finally {
    client.close();
  }
}

Future<void> probe(
  HttpClient client,
  String performanceId,
  String expectedIsin,
) async {
  print('-' * 80);
  print('Performance ID: $performanceId');
  print('Expected ISIN:  $expectedIsin');
  print('');

  final queries = <Uri>[
    Uri.https('www.emea-api.morningstar.com', '/ecint/v1/screener', {
      'page': '1',
      'pageSize': '10',
      'sortOrder': 'name asc',
      'outputType': 'json',
      'version': '1',
      'languageId': 'en-GB',
      'currencyId': 'GBP',
      'universeIds': r'FOGBR$$ALL',
      'securityDataPoints': 'performanceId,name,isin',
      'term': performanceId,
    }),
    Uri.https('www.emea-api.morningstar.com', '/ecint/v1/screener', {
      'page': '1',
      'pageSize': '10',
      'sortOrder': 'name asc',
      'outputType': 'json',
      'version': '1',
      'languageId': 'es-ES',
      'currencyId': 'EUR',
      'universeIds': r'FOGBR$$ALL',
      'securityDataPoints': 'performanceId,name,isin',
      'term': performanceId,
    }),
  ];

  for (final uri in queries) {
    print('GET $uri');

    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.refererHeader,
        'https://global.morningstar.com/',
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      print('HTTP: ${response.statusCode}');
      print('Content-Type: ${response.headers.contentType}');
      print('Body length: ${body.length}');

      if (body.isNotEmpty) {
        try {
          final decoded = jsonDecode(body);
          print(const JsonEncoder.withIndent('  ').convert(decoded));
        } catch (_) {
          print(body.substring(0, body.length.clamp(0, 3000)));
        }
      } else {
        print('Body vacío.');
      }
    } catch (e) {
      print('EXCEPCIÓN: $e');
    }

    print('');
  }
}
