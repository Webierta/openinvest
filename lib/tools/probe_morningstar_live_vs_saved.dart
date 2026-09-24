import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

void main() async {
  const cases = <Map<String, String>>[
    {'id': '0P0000X83M', 'expected': 'IE00B8K7V925', 'file': '01_0P0000X83M_raw.html'},
    {'id': '0P00000FB4', 'expected': 'FR0010135103', 'file': '01_0P00000FB4_raw.html'},
    {'id': '0P00006DAB', 'expected': 'LU0261948904', 'file': '03_0P00006DAB_raw.html'},
    {'id': '0P00000Z1Y', 'expected': 'LU0129445192', 'file': '04_0P00000Z1Y_raw.html'},
  ];

  final client = http.Client();

  try {
    print('=' * 90);
    print('DIAGNÓSTICO: ¿DÓNDE DESAPARECE HoldingIsin?');
    print('=' * 90);

    for (final test in cases) {
      final id = test['id']!;
      final expected = test['expected']!;
      final fileName = test['file']!;

      print('\n' + '-' * 90);
      print('Morningstar ID : $id');
      print('Expected ISIN  : $expected');
      print('HTML guardado  : $fileName');

      final savedFile = File(fileName);

      String? savedHtml;
      if (await savedFile.exists()) {
        final savedBytes = await savedFile.readAsBytes();
        savedHtml = utf8.decode(savedBytes, allowMalformed: true);
        _inspect('HTML GUARDADO', savedHtml, expected);
      } else {
        print('HTML GUARDADO   : archivo no encontrado');
      }

      final uri = Uri.https(
        'lt.morningstar.com',
        '/2nhcdckzon/snapshot/snapshot.aspx',
        {'Id': id, 'LanguageId': 'es-ES'},
      );

      print('\nURL             : $uri');

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
          'Referer': 'https://lt.morningstar.com/',
        },
      );

      print('HTTP            : ${response.statusCode}');
      print('Response bytes  : ${response.bodyBytes.length}');

      final liveHtml = utf8.decode(
        response.bodyBytes,
        allowMalformed: true,
      );

      _inspect('HTML LIVE', liveHtml, expected);

      if (savedHtml != null) {
        final savedBytes = await savedFile.readAsBytes();
        final savedIndex = savedHtml.indexOf('HoldingIsin');
        final liveIndex = liveHtml.indexOf('HoldingIsin');

        print('\nCOMPARACIÓN');
        print('Bytes guardado  : ${savedBytes.length}');
        print('Bytes live      : ${response.bodyBytes.length}');
        print('HoldingIsin guardado: $savedIndex');
        print('HoldingIsin live   : $liveIndex');
        print('HTML idéntico     : ${savedHtml == liveHtml ? 'SÍ' : 'NO'}');

        if (savedIndex >= 0 && liveIndex < 0) {
          print('*** HALLAZGO: HoldingIsin existe en el HTML guardado,');
          print('*** pero NO existe en la respuesta HTTP actual. ***');
        } else if (savedIndex >= 0 && liveIndex >= 0) {
          print('*** HoldingIsin está presente en ambos HTML. ***');
        }
      }
    }
  } finally {
    client.close();
  }

  print('\n' + '=' * 90);
  print('FIN DEL DIAGNÓSTICO');
  print('=' * 90);
}

void _inspect(String label, String html, String expected) {
  final index = html.indexOf('HoldingIsin');

  print('\n$label');
  print('Length          : ${html.length}');
  print('indexOf HoldingIsin: $index');

  if (index < 0) {
    print('HoldingIsin     : NO ENCONTRADO');
    return;
  }

  final start = index > 250 ? index - 250 : 0;
  final end = index + 350 < html.length ? index + 350 : html.length;
  print('HoldingIsin     : ENCONTRADO');
  print('Fragmento:');
  print('-----');
  print(html.substring(start, end));
  print('-----');

  final regex = RegExp(
    '''HoldingIsin\\s*[=:]\\s*['"]([A-Z]{2}[A-Z0-9]{9}[0-9])['"]''',
    caseSensitive: false,
  );

  final match = regex.firstMatch(html);

  if (match == null) {
    print('Regex           : NO MATCH');
    return;
  }

  final extracted = match.group(1)!.toUpperCase();
  print('Regex           : MATCH');
  print('ISIN extraído   : $extracted');
  print('Esperado        : ${extracted == expected ? 'OK' : 'ERROR - ISIN distinto'}');
}
