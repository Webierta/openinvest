import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_resolver.dart';

import 'package:http/http.dart' as http;

Future<void> testMorningstarSecuritySearch() async {
  final client = http.Client();

  final url = Uri.parse('https://morningstar.es/es/util/SecuritySearch.ashx');

  final queries = ['0P00006DAB', '0P00000FB4', '0P00000HZF'];

  try {
    for (final query in queries) {
      print('');
      print('============================================================');
      print('SecuritySearch: $query');
      print('============================================================');

      final request = http.MultipartRequest('POST', url)
        ..fields['q'] = query
        ..headers['User-Agent'] =
            'Mozilla/5.0 (X11; Linux x86_64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/140.0.0.0 Safari/537.36';

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      print('STATUS: ${response.statusCode}');
      print('HEADERS:');

      response.headers.forEach((key, value) {
        print('  $key: $value');
      });

      print('');
      print('BODY LENGTH: ${response.body.length}');
      print('BODY:');
      print(response.body);
    }
  } finally {
    client.close();
  }
}

Future<void> testMorningstarHttp() async {
  final client = http.Client();

  final url = Uri.parse(
    'https://global.morningstar.com/es/inversiones/fondos/'
    '0P00006DAB/cotizacion',
  );

  try {
    final response = await client.get(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (X11; Linux x86_64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/140.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,'
            'image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'Referer': 'https://www.google.com/',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
        'Upgrade-Insecure-Requests': '1',
      },
    );

    print('STATUS: ${response.statusCode}');
    print('HEADERS:');

    response.headers.forEach((key, value) {
      print('  $key: $value');
    });

    print('');
    print('BODY LENGTH: ${response.body.length}');
    print('BODY START:');

    print(
      response.body.substring(
        0,
        response.body.length > 2000 ? 2000 : response.body.length,
      ),
    );
  } finally {
    client.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test instala un HttpOverrides que bloquea la red.
  // El resolver necesita acceder a CNMV/Yahoo/Morningstar.
  HttpOverrides.global = null;

  test('IsinResolver - integración completa', () async {
    final resolver = IsinResolver();

    final tests = [
      (
        name: 'Elcano High Yield Opportunities SIL, S.A.',
        ticker: 'SL020.MC',
        expected: 'ES0128581008',
      ),
      (
        name: 'Rosalita Capital SIL, S.A.',
        ticker: 'SL021.MC',
        expected: 'ES0134934001',
      ),
      (
        name: 'Freecap Investment SIL, S.A.',
        ticker: 'SL024.MC',
        expected: 'ES0139363008',
      ),
      (
        name: 'Carmignac Patrimoine A EUR Acc',
        ticker: 'Y9U6.HM',
        expected: 'FR0010135103',
      ),
      (
        name: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
        ticker: '0P00006DAB',
        expected: 'LU0261948904',
      ),
      (
        name: 'Vontobel Fund - US Dollar Money B USD',
        ticker: '0P00000HZF',
        expected: 'LU0120690226',
      ),
    ];

    var correct = 0;

    try {
      for (final testCase in tests) {
        print('\n${'-' * 70}');
        print('TEST: ${testCase.name}');
        print('Ticker:   ${testCase.ticker}');
        print('Esperado: ${testCase.expected}');

        final result = await resolver.resolve(
          ticker: testCase.ticker,
          fundName: testCase.name,
        );

        print('Obtenido: ${result?.isin ?? 'null'}');
        print('Fuente:   ${result?.source ?? '-'}');

        if (result?.isin == testCase.expected) {
          print('RESULTADO: ✅ CORRECTO');
          correct++;
        } else {
          print('RESULTADO: ❌ INCORRECTO');

          fail(
            'ISIN incorrecto para ${testCase.ticker}: '
            'esperado ${testCase.expected}, '
            'obtenido ${result?.isin ?? 'null'}',
          );
        }
      }
    } finally {
      resolver.dispose();
    }

    print('\n${'=' * 70}');
    print('RESULTADO FINAL: $correct / ${tests.length}');
    print('${'=' * 70}');
  });
}
