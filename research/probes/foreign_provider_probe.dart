//
// import 'package:flutter_test/flutter_test.dart';
// import 'package:http/http.dart' as http;
//
// void main() {
//   TestWidgetsFlutterBinding.ensureInitialized();
//
//   group('Foreign ISIN provider probe', () {
//     test('probar fuentes públicas extranjeras', () async {
//       final client = http.Client();
//
//       try {
//         await _probe(
//           client,
//           name: 'Carmignac Patrimoine A EUR Acc',
//           expectedIsin: 'FR0010135103',
//           urls: [
//             'https://www.carmignac.com/es-es/nuestros-fondos/carmignac-patrimoine-FR0010135103-a-eur-acc',
//             'https://www.carmignac.com/en/our-funds/carmignac-patrimoine-FR0010135103-a-eur-acc',
//           ],
//         );
//
//         await _probe(
//           client,
//           name: 'PIMCO GIS Income Fund E Class USD Income',
//           expectedIsin: 'IE00B8K7V925',
//           urls: [
//             'https://global.morningstar.com/es/inversiones/fondos/0P0000X83M/cotizacion',
//           ],
//         );
//
//         await _probe(
//           client,
//           name: 'Fidelity Iberia A-ACC-Euro',
//           expectedIsin: 'LU0261948904',
//           urls: [
//             'https://www.fidelityinternational.com/FDS/KIID/FF/en-gb/FF-Iberia%20Fund%20A-ACC-Euro_CH_en-gb_LU0261948904.pdf',
//           ],
//         );
//       } finally {
//         client.close();
//       }
//     });
//   });
// }
//
// Future<void> _probe(
//   http.Client client, {
//   required String name,
//   required String expectedIsin,
//   required List<String> urls,
// }) async {
//   print('');
//   print('=' * 78);
//   print('FONDO: $name');
//   print('ISIN esperado: $expectedIsin');
//   print('=' * 78);
//
//   for (final url in urls) {
//     print('');
//     print('GET $url');
//
//     try {
//       final response = await client
//           .get(
//             Uri.parse(url),
//             headers: const {
//               'User-Agent':
//                   'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
//                   '(KHTML, like Gecko) Chrome/140.0 Safari/537.36',
//               'Accept':
//                   'text/html,application/xhtml+xml,application/xml;q=0.9,'
//                   'application/pdf;q=0.8,*/*;q=0.7',
//               'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
//             },
//           )
//           .timeout(const Duration(seconds: 25));
//
//       print('HTTP: ${response.statusCode}');
//       print('Content-Type: ${response.headers['content-type'] ?? '-'}');
//       print('Bytes: ${response.bodyBytes.length}');
//
//       final body = response.body;
//
//       final matches = _findIsins(body);
//
//       if (matches.isEmpty) {
//         print('ISIN encontrados: ninguno');
//       } else {
//         print('ISIN encontrados:');
//         for (final isin in matches) {
//           print('  $isin${isin == expectedIsin ? '  <-- ESPERADO' : ''}');
//         }
//       }
//
//       final normalized = body.toUpperCase();
//
//       print(
//         'Contiene nombre parcial: '
//         '${_containsName(normalized, name) ? 'SI' : 'NO'}',
//       );
//
//       print(
//         'Contiene ISIN esperado: '
//         '${normalized.contains(expectedIsin) ? 'SI' : 'NO'}',
//       );
//
//       if (response.statusCode == 200 && normalized.contains(expectedIsin)) {
//         print('RESULTADO: FUENTE VÁLIDA PARA ESTE FONDO');
//       } else {
//         print('RESULTADO: NO VALIDADA');
//       }
//
//       print('');
//       print('Primeros 500 caracteres:');
//       print(_preview(body, 500));
//     } catch (e) {
//       print('EXCEPCIÓN: $e');
//     }
//   }
// }
//
// Set<String> _findIsins(String text) {
//   final regex = RegExp(r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b', caseSensitive: false);
//
//   return regex
//       .allMatches(text)
//       .map((m) => m.group(0)!.toUpperCase())
//       .where(_isValidIsin)
//       .toSet();
// }
//
// bool _isValidIsin(String isin) {
//   if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) {
//     return false;
//   }
//
//   final expanded = isin.split('').map((c) {
//     final code = c.codeUnitAt(0);
//     if (code >= 65 && code <= 90) {
//       return (code - 55).toString();
//     }
//     return c;
//   }).join();
//
//   var sum = 0;
//   final digits = expanded.split('').map(int.parse).toList();
//
//   for (var i = 0; i < digits.length; i++) {
//     var value = digits[digits.length - 1 - i];
//
//     if (i.isOdd) {
//       value *= 2;
//     }
//
//     sum += value ~/ 10;
//     sum += value % 10;
//   }
//
//   return sum % 10 == 0;
// }
//
// bool _containsName(String body, String name) {
//   final normalizedName = name
//       .toUpperCase()
//       .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
//       .trim();
//
//   final tokens = normalizedName
//       .split(RegExp(r'\s+'))
//       .where((t) => t.length >= 4)
//       .take(4);
//
//   var found = 0;
//
//   for (final token in tokens) {
//     if (body.contains(token)) {
//       found++;
//     }
//   }
//
//   return found >= 2;
// }
//
// String _preview(String value, int maxLength) {
//   final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
//   if (compact.length <= maxLength) {
//     return compact;
//   }
//   return '${compact.substring(0, maxLength)}...';
// }
