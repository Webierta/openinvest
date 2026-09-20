import 'package:http/http.dart' as http;

Future<void> main() async {
  final client = http.Client();

  try {
    final tests = <String>[
      'Y9U6.HM',
      '0P00000FB4.F',
      '0P00006DAB.F',
      '0P00000HZF',
    ];

    for (final symbol in tests) {
      print('');
      print('=' * 80);
      print('TEST: $symbol');
      print('=' * 80);

      final uri = Uri.parse(
        'https://markets.businessinsider.com/ajax/'
        'SearchController_Suggest',
      ).replace(queryParameters: {'max_results': '25', 'query': symbol});

      print('URL: $uri');

      try {
        final response = await client.get(
          uri,
          headers: const {'Accept': '*/*', 'User-Agent': 'OpenInvest/1.0'},
        );

        print('HTTP: ${response.statusCode}');
        print('Bytes: ${response.body.length}');

        print('');
        print('RESPUESTA:');
        print(response.body);
      } catch (e) {
        print('ERROR: $e');
      }
    }
  } finally {
    client.close();
  }
}
