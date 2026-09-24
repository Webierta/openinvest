// import 'dart:convert';
//
// import 'package:http/http.dart' as http;
//
// const _url = 'https://www.morningstar.es/es/util/SecuritySearch.ashx';
//
// class ProbeCase {
//   final String label;
//   final String query;
//   final String expectedFragment;
//
//   const ProbeCase({
//     required this.label,
//     required this.query,
//     required this.expectedFragment,
//   });
// }
//
// Future<String> searchMorningstar(String query) async {
//   final request = http.MultipartRequest('POST', Uri.parse(_url));
//
//   request.headers['Accept'] = '*/*';
//   request.headers['User-Agent'] =
//       'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
//       '(KHTML, like Gecko) Chrome/140.0 Safari/537.36';
//
//   request.fields['q'] = query;
//   request.fields['preferedList'] = '';
//   request.fields['source'] = 'nav';
//   request.fields['moduleId'] = '6';
//   request.fields['ifIncludeAds'] = 'false';
//   request.fields['usrtType'] = 'v';
//
//   final streamed = await request.send().timeout(const Duration(seconds: 20));
//   final response = await http.Response.fromStream(streamed);
//
//   print('HTTP ${response.statusCode}');
//   print('Content-Type: ${response.headers['content-type']}');
//   print('Bytes: ${response.bodyBytes.length}');
//
//   if (response.body.isNotEmpty) {
//     print('Respuesta:');
//     print(response.body);
//   }
//
//   if (response.statusCode < 200 || response.statusCode >= 300) {
//     throw Exception('HTTP ${response.statusCode}');
//   }
//
//   return response.body;
// }
//
// Map<String, String>? parseMorningstarResponse(String body) {
//   // Typical response:
//   // Name|{"i":"F0...","pi":"0P...","n":"Name",...}|FUND|||Fondos de Inversión
//
//   final match = RegExp(r'\{.*?\}').firstMatch(body);
//   if (match == null) return null;
//
//   try {
//     final decoded = jsonDecode(match.group(0)!);
//     if (decoded is! Map) return null;
//
//     return {
//       'securityId': '${decoded['i'] ?? ''}',
//       'performanceId': '${decoded['pi'] ?? ''}',
//       'name': '${decoded['n'] ?? ''}',
//     };
//   } catch (_) {
//     return null;
//   }
// }
//
// Future<void> runCase(ProbeCase test) async {
//   print('');
//   print('=' * 80);
//   print(test.label);
//   print('Consulta: ${test.query}');
//   print('=' * 80);
//
//   try {
//     final body = await searchMorningstar(test.query);
//     final parsed = parseMorningstarResponse(body);
//
//     if (parsed == null) {
//       print('PARSE: NO SE PUDO EXTRAER EL OBJETO JSON');
//       return;
//     }
//
//     print('');
//     print('Security ID:    ${parsed['securityId']}');
//     print('Performance ID: ${parsed['performanceId']}');
//     print('Nombre:         ${parsed['name']}');
//
//     if (test.expectedFragment.isNotEmpty) {
//       final ok = body.contains(test.expectedFragment);
//       print('Esperado:       ${test.expectedFragment}');
//       print('COMPROBACIÓN:   ${ok ? 'CORRECTA' : 'NO COINCIDE'}');
//     }
//   } catch (e) {
//     print('ERROR: $e');
//   }
// }
//
// Future<void> main() async {
//   print('=' * 80);
//   print('MORNINGSTAR SecuritySearch.ashx - PROBE');
//   print('=' * 80);
//   print('Endpoint: $_url');
//   print('');
//   print('Este programa NO modifica IsinResolver.');
//   print('Prueba ISIN -> Morningstar ID y Morningstar ID -> resultado.');
//   print('');
//
//   const cases = <ProbeCase>[
//     ProbeCase(
//       label: 'Carmignac Patrimoine A EUR Acc',
//       query: 'FR0010135103',
//       expectedFragment: 'FR0010135103',
//     ),
//     ProbeCase(
//       label: 'PIMCO GIS Income Fund E Class USD Income',
//       query: 'IE00B8K7V925',
//       expectedFragment: 'IE00B8K7V925',
//     ),
//     ProbeCase(
//       label: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
//       query: 'LU0261948904',
//       expectedFragment: 'LU0261948904',
//     ),
//     ProbeCase(
//       label: 'FONMARCH FI Clase A',
//       query: 'ES0138841038',
//       expectedFragment: 'ES0138841038',
//     ),
//     ProbeCase(
//       label: 'Carmignac por Performance ID',
//       query: '0P00000FB4',
//       expectedFragment: '0P00000FB4',
//     ),
//     ProbeCase(
//       label: 'Carmignac por Security ID conocido',
//       query: 'F0GBR04F90',
//       expectedFragment: 'F0GBR04F90',
//     ),
//   ];
//
//   for (final test in cases) {
//     await runCase(test);
//   }
//
//   print('');
//   print('=' * 80);
//   print('FIN DEL PROBE');
//   print('=' * 80);
// }
