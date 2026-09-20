import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();

  try {
    final uri = Uri.https(
      'global.morningstar.com',
      '/api/v1/es/tools/screener/_data',
      {
        'query': '((name ~= "Carmignac Patrimoine A EUR Acc"))',
        'fields': 'isin,name,securityID',
        'page': '1',
        'sort': 'name:asc',
      },
    );

    print('');
    print('=' * 80);
    print('PETICIÓN MORNINGSTAR');
    print('=' * 80);
    print(uri);

    final response = await client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) '
            'AppleWebKit/537.36 '
            '(KHTML, like Gecko) '
            'Chrome/140.0 Safari/537.36',
      },
    );

    print('');
    print('STATUS: ${response.statusCode}');
    print('CONTENT-TYPE: ${response.headers['content-type']}');
    print('CONTENT-LENGTH: ${response.body.length}');

    print('');
    print('HEADERS:');
    response.headers.forEach((key, value) {
      print('  $key: $value');
    });

    print('');
    print('BODY:');
    print(response.body);
    print('');
    print('=' * 80);
  } finally {
    client.close();
  }
}
