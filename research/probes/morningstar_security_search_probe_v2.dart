// import 'dart:convert';
//
// import 'package:http/http.dart' as http;
//
// const _url = 'https://morningstar.es/es/util/SecuritySearch.ashx';
//
// class ProbeCase {
//   final String label;
//   final String query;
//   final String expected;
//
//   const ProbeCase({
//     required this.label,
//     required this.query,
//     required this.expected,
//   });
// }
//
// Future<http.Response> postSearch(String query) async {
//   final request = http.MultipartRequest('POST', Uri.parse(_url));
//
//   request.headers.addAll({
//     'Accept': '*/*',
//     'User-Agent':
//         'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
//         '(KHTML, like Gecko) Chrome/140.0 Safari/537.36',
//     'Origin': 'https://morningstar.es',
//     'Referer': 'https://morningstar.es/',
//   });
//
//   // q is the important parameter documented by the existing implementations.
//   request.fields['q'] = query;
//
//   // Keep the additional parameters used by the public implementation.
//   request.fields['preferedList'] = '';
//   request.fields['source'] = 'nav';
//   request.fields['moduleId'] = '6';
//   request.fields['ifIncludeAds'] = 'false';
//   request.fields['usrtType'] = 'v';
//
//   final streamed = await request.send().timeout(const Duration(seconds: 20));
//
//   // IMPORTANT: do not follow redirects manually here. We want to see the
//   // Location header if Morningstar redirects us.
//   final response = await http.Response.fromStream(streamed);
//   return response;
// }
//
// Map<String, String>? parseResult(String body) {
//   final match = RegExp(r'\{[^{}]*\}').firstMatch(body);
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
//     final response = await postSearch(test.query);
//
//     print('HTTP:        ${response.statusCode}');
//     print('Location:    ${response.headers['location'] ?? '-'}');
//     print('Content-Type:${response.headers['content-type'] ?? '-'}');
//     print('Bytes:       ${response.bodyBytes.length}');
//
//     if (response.body.isEmpty) {
//       print('Respuesta:   <vacía>');
//       return;
//     }
//
//     print('Respuesta:');
//     print(response.body);
//
//     final parsed = parseResult(response.body);
//     if (parsed != null) {
//       print('');
//       print('Security ID:    ${parsed['securityId']}');
//       print('Performance ID: ${parsed['performanceId']}');
//       print('Nombre:         ${parsed['name']}');
//     }
//
//     if (test.expected.isNotEmpty) {
//       final found = response.body.contains(test.expected);
//       print('');
//       print('Esperado:       ${test.expected}');
//       print('COMPROBACIÓN:   ${found ? 'ENCONTRADO' : 'NO ENCONTRADO'}');
//     }
//   } catch (e) {
//     print('ERROR: $e');
//   }
// }
//
// Future<void> main() async {
//   print('=' * 80);
//   print('MORNINGSTAR SecuritySearch.ashx - PROBE v2');
//   print('=' * 80);
//   print('Endpoint: $_url');
//   print('');
//   print('IMPORTANTE: esta versión usa morningstar.es sin www');
//   print('y muestra explícitamente cualquier cabecera Location.');
//   print('');
//
//   const cases = <ProbeCase>[
//     ProbeCase(
//       label: 'Carmignac Patrimoine A EUR Acc',
//       query: 'FR0010135103',
//       expected: 'FR0010135103',
//     ),
//     ProbeCase(
//       label: 'PIMCO GIS Income Fund E Class USD Income',
//       query: 'IE00B8K7V925',
//       expected: 'IE00B8K7V925',
//     ),
//     ProbeCase(
//       label: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
//       query: 'LU0261948904',
//       expected: 'LU0261948904',
//     ),
//     ProbeCase(
//       label: 'FONMARCH FI Clase A',
//       query: 'ES0138841038',
//       expected: 'ES0138841038',
//     ),
//     ProbeCase(
//       label: 'Carmignac por Performance ID',
//       query: '0P00000FB4',
//       expected: '0P00000FB4',
//     ),
//     ProbeCase(
//       label: 'Carmignac por Security ID',
//       query: 'F0GBR04F90',
//       expected: 'F0GBR04F90',
//     ),
//   ];
//
//   for (final test in cases) {
//     await runCase(test);
//   }
//
//   print('');
//   print('=' * 80);
//   print('FIN DEL PROBE v2');
//   print('=' * 80);
// }
