import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  const tests = <Map<String, String>>[
    {
      'name': 'PIMCO GIS Income Fund E Class USD Income',
      'morningstarId': '0P0000X83M',
      'expectedIsin': 'IE00B8K7V925',
    },
    {
      'name': 'Carmignac Patrimoine A EUR Acc',
      'morningstarId': '0P00000FB4',
      'expectedIsin': 'FR0010135103',
    },
    {
      'name': 'Fidelity Funds - Iberia A-Acc-EUR',
      'morningstarId': '0P00006DAB',
      'expectedIsin': 'LU0261948904',
    },
    {
      'name': 'JPM Europe Strategic Value C Acc EUR',
      'morningstarId': '0P00000Z1Y',
      'expectedIsin': 'LU0129445192',
    },
  ];

  final client = http.Client();

  const baseUrl =
      'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

  print('=' * 100);
  print('PROBE HTML MORNINGSTAR - HoldingIsin / PerformanceId / HoldingId');
  print('=' * 100);

  try {
    for (var i = 0; i < tests.length; i++) {
      final test = tests[i];
      final id = test['morningstarId']!;
      final expected = test['expectedIsin']!;

      print('\n${'-' * 100}');
      print('TEST ${i + 1}: ${test['name']}');
      print('Morningstar ID : $id');
      print('Expected ISIN  : $expected');
      print('-' * 100);

      final uri = Uri.parse(baseUrl).replace(
        queryParameters: {
          'Id': id,
          'LanguageId': 'es-ES',
        },
      );

      final response = await client.get(
        uri,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,'
              'image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

      final body = response.body;
      print('HTTP          : ${response.statusCode}');
      print('URL FINAL     : ${response.request?.url}');
      print('BODY BYTES    : ${body.length}');

      final out = File('morningstar_${id}.html');
      await out.writeAsString(body);
      print('HTML GUARDADO : ${out.path}');

      final lower = body.toLowerCase();

      void reportLiteral(String label, String needle) {
        final pos = lower.indexOf(needle.toLowerCase());
        if (pos < 0) {
          print('$label : NO ENCONTRADO');
          return;
        }

        print('$label : ENCONTRADO en posición $pos');

        final start = pos - 500 < 0 ? 0 : pos - 500;
        final end = pos + needle.length + 1000 > body.length
            ? body.length
            : pos + needle.length + 1000;

        print('--- FRAGMENTO ${label} ---');
        print(body.substring(start, end));
        print('--- FIN FRAGMENTO ---');
      }

      reportLiteral('HoldingIsin', 'HoldingIsin');
      reportLiteral('Expected ISIN', expected);
      reportLiteral('PerformanceId', 'PerformanceId');
      reportLiteral('HoldingId', 'HoldingId');
      reportLiteral('ISIN', 'ISIN');

      print('\n--- VARIABLES JAVASCRIPT Holding* / Performance* ---');

      final patterns = <RegExp>[
        RegExp(
          r'''(?:var\s+)?(?:Holding|Performance)[A-Za-z0-9_]*\s*=\s*[^;\r\n]*;''',
          caseSensitive: false,
        ),
        RegExp(
          r'''["']?(?:Holding|Performance)[A-Za-z0-9_]*["']?\s*:\s*[^,\r\n}]+''',
          caseSensitive: false,
        ),
      ];

      final seen = <String>{};
      for (final pattern in patterns) {
        for (final match in pattern.allMatches(body)) {
          final value = match.group(0)?.trim();
          if (value == null || value.isEmpty) continue;
          if (seen.add(value)) {
            print(value);
          }
        }
      }

      print('\n--- TODAS LAS CADENAS QUE PARECEN ISIN ---');

      final isinRegex = RegExp(r'\b[A-Z]{2}[A-Z0-9]{9}\d\b');
      final isins = <String>{};

      for (final match in isinRegex.allMatches(body)) {
        isins.add(match.group(0)!);
      }

      if (isins.isEmpty) {
        print('No se encontraron cadenas con formato ISIN.');
      } else {
        for (final isin in isins) {
          print(isin + (isin == expected ? '  <-- ESPERADO' : ''));
        }
      }

      print('\n--- CONTEXTO DEL EXPECTED ISIN ---');
      final expectedPos = lower.indexOf(expected.toLowerCase());
      if (expectedPos >= 0) {
        final start = expectedPos - 1500 < 0 ? 0 : expectedPos - 1500;
        final end = expectedPos + expected.length + 2500 > body.length
            ? body.length
            : expectedPos + expected.length + 2500;
        print(body.substring(start, end));
      } else {
        print('El ISIN esperado no aparece literalmente en el HTML.');
      }

      print('\n--- POSIBLES BLOQUES JSON / INITIAL STATE ---');

      for (final key in const [
        'INITIAL_STATE',
        '__INITIAL_STATE__',
        'initialState',
        'HoldingIsin',
        'HoldingId',
        'PerformanceId',
      ]) {
        final pos = lower.indexOf(key.toLowerCase());
        if (pos >= 0) {
          print('$key -> posición $pos');
        }
      }
    }
  } finally {
    client.close();
  }

  print('\n' + '=' * 100);
  print('FIN DEL PROBE');
  print('=' * 100);
}
