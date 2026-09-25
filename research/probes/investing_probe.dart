// import 'dart:convert';
// import 'dart:io';
//
// import 'package:http/http.dart' as http;
//
// class FundTest {
//   final String name;
//   final String? morningstarId;
//   final String expectedIsin;
//
//   const FundTest({
//     required this.name,
//     required this.morningstarId,
//     required this.expectedIsin,
//   });
// }
//
// class InvestingResult {
//   String? url;
//   String? title;
//   String? morningstarId;
//   String? isin;
//   String? fundName;
//
//   bool get found => isin != null;
//
//   @override
//   String toString() {
//     return '''
// URL           : ${url ?? '-'}
// Título        : ${title ?? '-'}
// Nombre fondo  : ${fundName ?? '-'}
// Morningstar   : ${morningstarId ?? '-'}
// ISIN          : ${isin ?? '-'}
// ''';
//   }
// }
//
// class InvestingProbe {
//   final http.Client client;
//
//   InvestingProbe({http.Client? client}) : client = client ?? http.Client();
//
//   static const String userAgent =
//       'Mozilla/5.0 (X11; Linux x86_64) '
//       'AppleWebKit/537.36 (KHTML, like Gecko) '
//       'Chrome/140.0 Safari/537.36';
//
//   Future<http.Response?> get(Uri uri, {Map<String, String>? headers}) async {
//     try {
//       print('');
//       print('GET $uri');
//
//       final response = await client.get(
//         uri,
//         headers: {
//           'User-Agent': userAgent,
//           'Accept':
//               'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//           'Accept-Language': 'en-US,en;q=0.9,es;q=0.8',
//           'Referer': 'https://www.investing.com/',
//           ...?headers,
//         },
//       );
//
//       print('HTTP ${response.statusCode}');
//       print('Bytes: ${response.bodyBytes.length}');
//
//       return response;
//     } catch (e) {
//       print('ERROR GET: $e');
//       return null;
//     }
//   }
//
//   Future<http.Response?> postForm(Uri uri, Map<String, String> body) async {
//     try {
//       print('');
//       print('POST $uri');
//       print('BODY: $body');
//
//       final response = await client.post(
//         uri,
//         headers: {
//           'User-Agent': userAgent,
//           'Accept': 'application/json, text/plain, */*',
//           'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
//           'Origin': 'https://www.investing.com',
//           'Referer': 'https://www.investing.com/',
//           'X-Requested-With': 'XMLHttpRequest',
//         },
//         body: body,
//       );
//
//       print('HTTP ${response.statusCode}');
//       print('Bytes: ${response.bodyBytes.length}');
//
//       final preview = response.body.replaceAll(RegExp(r'\s+'), ' ').trim();
//
//       print(
//         'RESPONSE: ${preview.length > 1000 ? preview.substring(0, 1000) : preview}',
//       );
//
//       return response;
//     } catch (e) {
//       print('ERROR POST: $e');
//       return null;
//     }
//   }
//
//   // ---------------------------------------------------------------------------
//   // HTML helpers
//   // ---------------------------------------------------------------------------
//
//   String? extractIsin(String html) {
//     final patterns = <RegExp>[
//       RegExp(
//         r'\bISIN\s*[:</>\s"=]+([A-Z]{2}[A-Z0-9]{9}[0-9])\b',
//         caseSensitive: false,
//       ),
//       RegExp(
//         r'"isin"\s*:\s*"([A-Z]{2}[A-Z0-9]{9}[0-9])"',
//         caseSensitive: false,
//       ),
//       RegExp(
//         r'ISIN.{0,150}?([A-Z]{2}[A-Z0-9]{9}[0-9])',
//         caseSensitive: false,
//         dotAll: true,
//       ),
//     ];
//
//     for (final pattern in patterns) {
//       final match = pattern.firstMatch(html);
//
//       if (match != null) {
//         final isin = match.group(1)?.toUpperCase();
//
//         if (isin != null && isValidIsin(isin)) {
//           return isin;
//         }
//       }
//     }
//
//     return null;
//   }
//
//   String? extractMorningstarId(String html) {
//     final patterns = <RegExp>[
//       RegExp(r'\b(0P[0-9A-Z]{8,})\b', caseSensitive: false),
//       RegExp(r'"morningstarId"\s*:\s*"([^"]+)"', caseSensitive: false),
//       RegExp(r'"morningstar_id"\s*:\s*"([^"]+)"', caseSensitive: false),
//     ];
//
//     for (final pattern in patterns) {
//       final match = pattern.firstMatch(html);
//
//       if (match != null) {
//         return match.group(1);
//       }
//     }
//
//     return null;
//   }
//
//   String? extractTitle(String html) {
//     final match = RegExp(
//       r'<title[^>]*>(.*?)</title>',
//       caseSensitive: false,
//       dotAll: true,
//     ).firstMatch(html);
//
//     if (match == null) {
//       return null;
//     }
//
//     return cleanHtml(match.group(1)!);
//   }
//
//   String? extractFundName(String html) {
//     // Investing suele tener el nombre del fondo en un H1.
//     final h1 = RegExp(
//       r'<h1[^>]*>(.*?)</h1>',
//       caseSensitive: false,
//       dotAll: true,
//     ).firstMatch(html);
//
//     if (h1 != null) {
//       final value = cleanHtml(h1.group(1)!);
//
//       if (value.isNotEmpty) {
//         return removeMorningstarId(value);
//       }
//     }
//
//     // Fallback: buscar texto alrededor de "ISIN".
//     final isinMatch = RegExp(
//       r'.{0,250}ISIN.{0,250}',
//       caseSensitive: false,
//       dotAll: true,
//     ).firstMatch(html);
//
//     if (isinMatch != null) {
//       return cleanHtml(isinMatch.group(0)!);
//     }
//
//     return null;
//   }
//
//   String cleanHtml(String value) {
//     var result = value;
//
//     result = result.replaceAll(
//       RegExp(
//         r'<script\b[^>]*>.*?</script>',
//         caseSensitive: false,
//         dotAll: true,
//       ),
//       ' ',
//     );
//
//     result = result.replaceAll(
//       RegExp(r'<style\b[^>]*>.*?</style>', caseSensitive: false, dotAll: true),
//       ' ',
//     );
//
//     result = result.replaceAll(RegExp(r'<[^>]+>'), ' ');
//
//     result = result
//         .replaceAll('&amp;', '&')
//         .replaceAll('&quot;', '"')
//         .replaceAll('&#39;', "'")
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&lt;', '<')
//         .replaceAll('&gt;', '>');
//
//     result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
//
//     return result;
//   }
//
//   String removeMorningstarId(String value) {
//     return value
//         .replaceAll(RegExp(r'\s*\(0P[0-9A-Z]+\)\s*$', caseSensitive: false), '')
//         .trim();
//   }
//
//   // ---------------------------------------------------------------------------
//   // ISIN validation
//   // ---------------------------------------------------------------------------
//
//   bool isValidIsin(String isin) {
//     if (isin.length != 12) {
//       return false;
//     }
//
//     if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) {
//       return false;
//     }
//
//     final expanded = StringBuffer();
//
//     for (final char in isin.substring(0, 11).split('')) {
//       if (RegExp(r'[A-Z]').hasMatch(char)) {
//         expanded.write((char.codeUnitAt(0) - 'A'.codeUnitAt(0) + 10));
//       } else {
//         expanded.write(char);
//       }
//     }
//
//     final digits = expanded.toString();
//
//     var sum = 0;
//     var positionFromRight = 1;
//
//     for (var i = digits.length - 1; i >= 0; i--) {
//       var value = int.parse(digits[i]);
//
//       if (positionFromRight.isOdd) {
//         value *= 2;
//       }
//
//       sum += (value ~/ 10) + (value % 10);
//
//       positionFromRight++;
//     }
//
//     final checkDigit = (10 - (sum % 10)) % 10;
//
//     return checkDigit == int.parse(isin[11]);
//   }
//
//   // ---------------------------------------------------------------------------
//   // Search endpoint
//   // ---------------------------------------------------------------------------
//
//   Future<List<Map<String, dynamic>>> searchInvesting(String query) async {
//     final encoded = Uri.encodeQueryComponent(query);
//
//     final urls = <Uri>[
//       Uri.parse(
//         'https://www.investing.com/search/service/searchTop?search_text=$encoded',
//       ),
//       Uri.parse(
//         'https://www.investing.com/search/service/searchTop?search_text=$encoded&lang_ID=1',
//       ),
//       Uri.parse(
//         'https://www.investing.com/search/service/searchTop?q=$encoded',
//       ),
//     ];
//
//     for (final uri in urls) {
//       final response = await get(
//         uri,
//         headers: {
//           'Accept': 'application/json, text/plain, */*',
//           'X-Requested-With': 'XMLHttpRequest',
//         },
//       );
//
//       if (response == null) {
//         continue;
//       }
//
//       if (response.statusCode != 200) {
//         continue;
//       }
//
//       try {
//         final decoded = jsonDecode(response.body);
//
//         print('JSON type: ${decoded.runtimeType}');
//
//         final results = extractSearchResults(decoded);
//
//         if (results.isNotEmpty) {
//           print('Resultados encontrados: ${results.length}');
//
//           for (final result in results.take(10)) {
//             print('  $result');
//           }
//
//           return results;
//         }
//       } catch (e) {
//         print('No es JSON válido: $e');
//       }
//     }
//
//     return [];
//   }
//
//   List<Map<String, dynamic>> extractSearchResults(dynamic value) {
//     final results = <Map<String, dynamic>>[];
//
//     void walk(dynamic node) {
//       if (node is Map) {
//         final map = <String, dynamic>{};
//
//         for (final entry in node.entries) {
//           map[entry.key.toString()] = entry.value;
//         }
//
//         final hasUsefulField =
//             map.containsKey('url') ||
//             map.containsKey('link') ||
//             map.containsKey('symbol') ||
//             map.containsKey('title') ||
//             map.containsKey('name');
//
//         if (hasUsefulField) {
//           results.add(map);
//         }
//
//         for (final child in node.values) {
//           walk(child);
//         }
//       } else if (node is List) {
//         for (final child in node) {
//           walk(child);
//         }
//       }
//     }
//
//     walk(value);
//
//     return results;
//   }
//
//   // ---------------------------------------------------------------------------
//   // Search using known Morningstar ID
//   // ---------------------------------------------------------------------------
//
//   Future<InvestingResult> resolveMorningstarId(String morningstarId) async {
//     print('');
//     print('============================================================');
//     print('BUSCAR MORNINGSTAR ID');
//     print('============================================================');
//     print('ID: $morningstarId');
//
//     final result = InvestingResult();
//     result.morningstarId = morningstarId;
//
//     final searchResults = await searchInvesting(morningstarId);
//
//     for (final item in searchResults) {
//       final url = extractUrl(item);
//
//       if (url == null) {
//         continue;
//       }
//
//       if (!url.contains('/funds/')) {
//         continue;
//       }
//
//       final fullUrl = normalizeUrl(url);
//
//       print('');
//       print('Posible fondo encontrado:');
//       print(fullUrl);
//
//       final response = await get(Uri.parse(fullUrl));
//
//       if (response == null || response.statusCode != 200) {
//         continue;
//       }
//
//       final isin = extractIsin(response.body);
//
//       if (isin != null) {
//         result.url = fullUrl;
//         result.title = extractTitle(response.body);
//         result.fundName = extractFundName(response.body);
//         result.isin = isin;
//
//         return result;
//       }
//     }
//
//     return result;
//   }
//
//   String? extractUrl(Map<String, dynamic> item) {
//     final possibleKeys = [
//       'url',
//       'link',
//       'href',
//       'seo_url',
//       'web_url',
//       'target',
//     ];
//
//     for (final key in possibleKeys) {
//       final value = item[key];
//
//       if (value is String && value.isNotEmpty) {
//         return value;
//       }
//     }
//
//     return null;
//   }
//
//   String normalizeUrl(String url) {
//     if (url.startsWith('http://') || url.startsWith('https://')) {
//       return url;
//     }
//
//     if (url.startsWith('//')) {
//       return 'https:$url';
//     }
//
//     if (url.startsWith('/')) {
//       return 'https://www.investing.com$url';
//     }
//
//     return 'https://www.investing.com/$url';
//   }
//
//   // ---------------------------------------------------------------------------
//   // Direct known URL test
//   // ---------------------------------------------------------------------------
//
//   Future<InvestingResult> testDirectUrl(
//     String url, {
//     String? expectedMorningstarId,
//     String? expectedIsin,
//   }) async {
//     print('');
//     print('============================================================');
//     print('TEST DIRECTO');
//     print('============================================================');
//     print(url);
//
//     final result = InvestingResult();
//     result.url = url;
//     result.morningstarId = expectedMorningstarId;
//
//     final response = await get(Uri.parse(url));
//
//     if (response == null) {
//       return result;
//     }
//
//     print('');
//     print('--- EXTRACCIÓN HTML ---');
//
//     result.title = extractTitle(response.body);
//     result.fundName = extractFundName(response.body);
//     result.morningstarId ??= extractMorningstarId(response.body);
//     result.isin = extractIsin(response.body);
//
//     print('Title:       ${result.title}');
//     print('Fund name:   ${result.fundName}');
//     print('Morningstar: ${result.morningstarId}');
//     print('ISIN:        ${result.isin}');
//
//     if (expectedIsin != null) {
//       print('');
//       print('ISIN esperado: $expectedIsin');
//       print('ISIN obtenido: ${result.isin}');
//
//       if (result.isin == expectedIsin) {
//         print('RESULTADO: OK');
//       } else {
//         print('RESULTADO: ERROR');
//       }
//     }
//
//     return result;
//   }
//
//   // ---------------------------------------------------------------------------
//   // Name search
//   // ---------------------------------------------------------------------------
//
//   Future<InvestingResult> resolveByName(
//     String fundName, {
//     String? expectedIsin,
//   }) async {
//     print('');
//     print('============================================================');
//     print('BUSCAR POR NOMBRE');
//     print('============================================================');
//     print('Nombre: $fundName');
//
//     final result = InvestingResult();
//
//     final searchResults = await searchInvesting(fundName);
//
//     for (final item in searchResults) {
//       final url = extractUrl(item);
//
//       if (url == null) {
//         continue;
//       }
//
//       if (!url.contains('/funds/')) {
//         continue;
//       }
//
//       final fullUrl = normalizeUrl(url);
//
//       print('');
//       print('Candidato: $fullUrl');
//
//       final response = await get(Uri.parse(fullUrl));
//
//       if (response == null || response.statusCode != 200) {
//         continue;
//       }
//
//       final isin = extractIsin(response.body);
//
//       if (isin == null) {
//         continue;
//       }
//
//       result.url = fullUrl;
//       result.title = extractTitle(response.body);
//       result.fundName = extractFundName(response.body);
//       result.morningstarId = extractMorningstarId(response.body);
//       result.isin = isin;
//
//       if (expectedIsin == null || isin == expectedIsin) {
//         return result;
//       }
//     }
//
//     return result;
//   }
// }
//
// // ============================================================================
// // MAIN
// // ============================================================================
//
// Future<void> main() async {
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' INVESTING.COM PROBE - ISIN RESOLVER');
//   print(
//     '======================================================================',
//   );
//   print('');
//   print('Objetivo:');
//   print('  ticker/nombre → Investing → Morningstar ID → ISIN');
//   print('');
//
//   final probe = InvestingProbe();
//
//   // --------------------------------------------------------------------------
//   // CASOS REALES
//   // --------------------------------------------------------------------------
//
//   const tests = [
//     FundTest(
//       name: 'PIMCO GIS Income Fund E Class USD Income',
//       morningstarId: '0P0000X83M',
//       expectedIsin: 'IE00B8K7V925',
//     ),
//     FundTest(
//       name: 'Carmignac Patrimoine A EUR Acc',
//       morningstarId: '0P00000FB4',
//       expectedIsin: 'FR0010135103',
//     ),
//     FundTest(
//       name: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
//       morningstarId: '0P00006DAB',
//       expectedIsin: 'LU0261948904',
//     ),
//   ];
//
//   final results = <InvestingResult>[];
//
//   // --------------------------------------------------------------------------
//   // 1. PROBAR URL DIRECTA
//   // --------------------------------------------------------------------------
//
//   print('');
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' 1. PRUEBA DIRECTA DE LAS TRES PÁGINAS');
//   print(
//     '======================================================================',
//   );
//
//   final directUrls = [
//     ('https://www.investing.com/funds/income-fund-e-inc-usd', tests[0]),
//     (
//       'https://www.investing.com/funds/carmignac-patrimoine-a-eur-acc-historical-data',
//       tests[1],
//     ),
//     (
//       'https://www.investing.com/funds/fidelity-funds-iberia-a-acc-eur',
//       tests[2],
//     ),
//   ];
//
//   for (final item in directUrls) {
//     final result = await probe.testDirectUrl(
//       item.$1,
//       expectedMorningstarId: item.$2.morningstarId,
//       expectedIsin: item.$2.expectedIsin,
//     );
//
//     results.add(result);
//   }
//
//   // --------------------------------------------------------------------------
//   // 2. BUSCAR POR MORNINGSTAR ID
//   // --------------------------------------------------------------------------
//
//   print('');
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' 2. BÚSQUEDA POR MORNINGSTAR ID');
//   print(
//     '======================================================================',
//   );
//
//   for (final test in tests) {
//     final id = test.morningstarId;
//
//     if (id == null) {
//       continue;
//     }
//
//     final result = await probe.resolveMorningstarId(id);
//
//     print('');
//     print('Resultado final:');
//     print(result);
//
//     if (result.isin == test.expectedIsin) {
//       print('>>> OK: ISIN correcto');
//     } else {
//       print('>>> NO RESUELTO');
//     }
//
//     results.add(result);
//   }
//
//   // --------------------------------------------------------------------------
//   // 3. BUSCAR POR NOMBRE
//   // --------------------------------------------------------------------------
//
//   print('');
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' 3. BÚSQUEDA POR NOMBRE');
//   print(
//     '======================================================================',
//   );
//
//   for (final test in tests) {
//     final result = await probe.resolveByName(
//       test.name,
//       expectedIsin: test.expectedIsin,
//     );
//
//     print('');
//     print('Resultado final:');
//     print(result);
//
//     if (result.isin == test.expectedIsin) {
//       print('>>> OK: ISIN correcto');
//     } else {
//       print('>>> NO RESUELTO');
//     }
//
//     results.add(result);
//   }
//
//   // --------------------------------------------------------------------------
//   // RESUMEN
//   // --------------------------------------------------------------------------
//
//   print('');
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' RESUMEN FINAL');
//   print(
//     '======================================================================',
//   );
//
//   print('');
//
//   for (final test in tests) {
//     final matching = results.where(
//       (r) => r.morningstarId == test.morningstarId,
//     );
//
//     print('------------------------------------------------------------------');
//     print(test.name);
//     print('Morningstar: ${test.morningstarId}');
//     print('ISIN esperado: ${test.expectedIsin}');
//
//     final found = matching.any((r) => r.isin == test.expectedIsin);
//
//     print('ISIN encontrado: ${found ? test.expectedIsin : "NO"}');
//     print('Resultado: ${found ? "OK" : "NO RESUELTO"}');
//   }
//
//   print('');
//   print(
//     '======================================================================',
//   );
//   print(' FIN DEL PROBE');
//   print(
//     '======================================================================',
//   );
//
//   probe.client.close();
// }
