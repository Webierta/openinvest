// import 'package:http/http.dart' as http;
//
// Future<void> main() async {
//   const fundName = 'Carmignac Patrimoine A EUR Acc';
//
//   final encodedName = Uri.encodeQueryComponent(fundName);
//
//   final urls = [
//     'https://global.morningstar.com/es/herramientas/buscador?query=$encodedName',
//     'https://global.morningstar.com/es/herramientas/buscador?q=$encodedName',
//   ];
//
//   final headers = {
//     'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//     'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
//     'User-Agent':
//         'Mozilla/5.0 (X11; Linux x86_64) '
//         'AppleWebKit/537.36 (KHTML, like Gecko) '
//         'Chrome/140.0.0.0 Safari/537.36',
//     'Referer': 'https://global.morningstar.com/',
//   };
//
//   for (final url in urls) {
//     print('');
//     print('=' * 100);
//     print('GET $url');
//     print('=' * 100);
//
//     try {
//       final response = await http.get(Uri.parse(url), headers: headers);
//
//       print('STATUS: ${response.statusCode}');
//       print('CONTENT-TYPE: ${response.headers['content-type']}');
//       print('CONTENT-LENGTH: ${response.headers['content-length']}');
//
//       print('');
//       print('HEADERS:');
//       response.headers.forEach((key, value) {
//         print('  $key: $value');
//       });
//
//       print('');
//       print('BODY LENGTH: ${response.body.length}');
//
//       if (response.body.isNotEmpty) {
//         print('');
//         print('BODY (primeros 5000 caracteres):');
//         print(
//           response.body.substring(
//             0,
//             response.body.length > 5000 ? 5000 : response.body.length,
//           ),
//         );
//
//         // Buscar directamente nuestros identificadores conocidos.
//         for (final needle in [
//           '0P00000FB4',
//           'F0GBR04F90',
//           'FR0010135103',
//           'Carmignac Patrimoine',
//         ]) {
//           print(
//             '$needle -> '
//             '${response.body.contains(needle) ? 'ENCONTRADO' : 'no encontrado'}',
//           );
//         }
//       }
//     } catch (e, stack) {
//       print('ERROR: $e');
//       print(stack);
//     }
//   }
// }
