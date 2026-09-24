// //import 'dart:convert';
//
// import 'package:http/http.dart' as http;
// import 'package:investing/models/foreign_isin_provider.dart';
//
// //import '../lib/models/foreign_isin_provider.dart';
//
// /// Resuelve ISIN de fondos extranjeros a partir de páginas públicas de Investing.com.
// ///
// /// Estrategia:
// /// 1. Intenta URLs previsibles construidas desde el nombre del fondo.
// /// 2. Si no encuentra el ISIN, busca públicamente el Performance ID en Google
// ///    restringiendo los resultados a investing.com/funds.
// /// 3. Descarga la ficha pública encontrada y extrae/valida el ISIN.
// ///
// /// No utiliza endpoints internos de Investing.com ni intenta saltarse controles
// /// anti-bot. El buscador se usa únicamente para descubrir una URL pública.
// class InvestingIsinProvider implements ForeignIsinProvider {
//   final http.Client _client;
//   final bool debug;
//   final bool enableWebSearchFallback;
//
//   InvestingIsinProvider({
//     http.Client? client,
//     this.debug = false,
//     this.enableWebSearchFallback = true,
//   }) : _client = client ?? http.Client();
//
//   static final RegExp _isinPattern = RegExp(
//     r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b',
//     caseSensitive: false,
//   );
//
//   static final RegExp _investingUrlPattern = RegExp(
//     r"https?://(?:[a-z]{2}\.)?investing\.com/funds/[A-Za-z0-9._%~:/?#\[\]@!$&\'()*+,;=-]+",
//     caseSensitive: false,
//   );
//
//   @override
//   Future<String?> resolve({
//     required String ticker,
//     required String fundName,
//     required String yahooSymbol,
//     required String yahooName,
//   }) async {
//     final performanceId = _extractPerformanceId(yahooSymbol, ticker);
//     if (performanceId == null) {
//       _log('No parece un Performance ID de Morningstar: $yahooSymbol');
//       return null;
//     }
//
//     final attempted = <String>{};
//
//     // Primero intentamos URLs construidas a partir del nombre.
//     final names = <String>{fundName.trim(), yahooName.trim()}
//       ..removeWhere((e) => e.isEmpty);
//
//     for (final name in names) {
//       final slug = _slugify(name);
//       if (slug.isEmpty) continue;
//
//       final urls = <String>[
//         'https://www.investing.com/funds/$slug',
//         'https://www.investing.com/funds/$slug-company-profile',
//         'https://www.investing.com/funds/$slug-historical-data',
//       ];
//
//       for (final url in urls) {
//         if (!attempted.add(url)) continue;
//         final result = await _fetchAndExtract(
//           url,
//           performanceId: performanceId,
//           fundName: name,
//         );
//         if (result != null) return result;
//       }
//     }
//
//     // Fallback: descubrir la ficha pública mediante Google.
//     if (enableWebSearchFallback) {
//       final discoveredUrls = await _discoverInvestingUrls(
//         performanceId: performanceId,
//         fundName: fundName,
//       );
//
//       _log('URLs Investing descubiertas: ${discoveredUrls.length}');
//       for (final url in discoveredUrls) {
//         if (!attempted.add(url)) continue;
//         final result = await _fetchAndExtract(
//           url,
//           performanceId: performanceId,
//           fundName: fundName,
//         );
//         if (result != null) return result;
//       }
//     }
//
//     _log(
//       'No se encontró ISIN en Investing.com. URLs probadas: ${attempted.length}',
//     );
//     return null;
//   }
//
//   Future<String?> _fetchAndExtract(
//     String url, {
//     required String performanceId,
//     required String fundName,
//   }) async {
//     try {
//       _log('URL: $url');
//       final response = await _client.get(
//         Uri.parse(url),
//         headers: const {
//           'Accept':
//               'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//           'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
//           'User-Agent':
//               'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
//               '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
//         },
//       );
//
//       _log('HTTP ${response.statusCode} (${response.bodyBytes.length} bytes)');
//       if (response.statusCode != 200) return null;
//
//       final body = response.body;
//       if (!_containsPerformanceId(body, performanceId)) {
//         _log('La página no contiene el Performance ID $performanceId');
//         return null;
//       }
//
//       final candidates = _extractValidIsins(body);
//       _log('ISIN candidatos: ${candidates.join(', ')}');
//
//       if (candidates.length == 1) {
//         return candidates.single;
//       }
//
//       // Si hay varios ISIN, intentamos localizar el que aparece cerca de
//       // la etiqueta "ISIN" y del Performance ID/nombre del fondo.
//       final contextual = _extractContextualIsin(body, performanceId, fundName);
//       if (contextual != null) return contextual;
//
//       return null;
//     } catch (e) {
//       _log('Error: $e');
//       return null;
//     }
//   }
//
//   Future<List<String>> _discoverInvestingUrls({
//     required String performanceId,
//     required String fundName,
//   }) async {
//     final queries = <String>[
//       '"$performanceId" site:investing.com/funds',
//       '"$performanceId" "$fundName" Investing.com',
//     ];
//
//     final urls = <String>{};
//
//     for (final query in queries) {
//       final googleUrl = Uri.https('www.google.com', '/search', {
//         'q': query,
//         'num': '10',
//       });
//
//       try {
//         _log('Buscando Investing: "$query"');
//         final response = await _client.get(
//           googleUrl,
//           headers: const {
//             'Accept': 'text/html,application/xhtml+xml',
//             'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
//             'User-Agent':
//                 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
//                 '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
//           },
//         );
//
//         _log(
//           'Google HTTP ${response.statusCode} (${response.bodyBytes.length} bytes)',
//         );
//         if (response.statusCode != 200) continue;
//
//         final decoded = _decodeHtml(response.body);
//         for (final match in _investingUrlPattern.allMatches(decoded)) {
//           var url = match.group(0)!;
//           url = _cleanUrl(url);
//           if (url.contains('/funds/')) urls.add(url);
//         }
//
//         // Google también codifica enlaces como /url?q=... .
//         final hrefPattern = RegExp(
//           r"(?:https?://)?(?:[a-z]{2}\.)?investing\.com/funds/[A-Za-z0-9._%~:/?#\[\]@!$&\'()*+,;=-]+",
//           caseSensitive: false,
//         );
//         for (final match in hrefPattern.allMatches(decoded)) {
//           var url = match.group(0)!;
//           if (!url.startsWith('http')) url = 'https://$url';
//           url = _cleanUrl(url);
//           if (url.contains('/funds/')) urls.add(url);
//         }
//       } catch (e) {
//         _log('Error buscando en Google: $e');
//       }
//     }
//
//     return urls.toList();
//   }
//
//   List<String> _extractValidIsins(String html) {
//     final result = <String>{};
//     for (final match in _isinPattern.allMatches(html)) {
//       final isin = match.group(0)!.toUpperCase();
//       if (_isValidIsin(isin)) result.add(isin);
//     }
//     return result.toList();
//   }
//
//   String? _extractContextualIsin(
//     String html,
//     String performanceId,
//     String fundName,
//   ) {
//     final text = _decodeHtml(html).replaceAll(RegExp(r'\s+'), ' ');
//     final positions = <int>[];
//
//     for (final needle in ['ISIN:', 'ISIN', performanceId]) {
//       var start = 0;
//       while (true) {
//         final index = text.toUpperCase().indexOf(needle.toUpperCase(), start);
//         if (index < 0) break;
//         positions.add(index);
//         start = index + needle.length;
//       }
//     }
//
//     for (final position in positions) {
//       final start = position > 500 ? position - 500 : 0;
//       final end = (position + 1000 < text.length)
//           ? position + 1000
//           : text.length;
//       final fragment = text.substring(start, end);
//       for (final match in _isinPattern.allMatches(fragment)) {
//         final isin = match.group(0)!.toUpperCase();
//         if (_isValidIsin(isin)) return isin;
//       }
//     }
//
//     return null;
//   }
//
//   bool _containsPerformanceId(String html, String performanceId) {
//     return html.toUpperCase().contains(performanceId.toUpperCase());
//   }
//
//   String? _extractPerformanceId(String yahooSymbol, String ticker) {
//     for (final value in [yahooSymbol, ticker]) {
//       final normalized = value.trim().toUpperCase();
//       final match = RegExp(r'\b0P[0-9A-Z]+\b').firstMatch(normalized);
//       if (match != null) return match.group(0);
//     }
//     return null;
//   }
//
//   String _slugify(String value) {
//     var text = _decodeHtml(value).toLowerCase().trim();
//     text = text.replaceAll(RegExp(r'&'), ' and ');
//     const replacements = {
//       'á': 'a',
//       'à': 'a',
//       'ä': 'a',
//       'â': 'a',
//       'ã': 'a',
//       'é': 'e',
//       'è': 'e',
//       'ë': 'e',
//       'ê': 'e',
//       'í': 'i',
//       'ì': 'i',
//       'ï': 'i',
//       'î': 'i',
//       'ó': 'o',
//       'ò': 'o',
//       'ö': 'o',
//       'ô': 'o',
//       'õ': 'o',
//       'ú': 'u',
//       'ù': 'u',
//       'ü': 'u',
//       'û': 'u',
//       'ñ': 'n',
//       'ç': 'c',
//     };
//     replacements.forEach((from, to) => text = text.replaceAll(from, to));
//     text = text.replaceAll(RegExp(r"['’]"), '');
//     text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
//     return text.replaceAll(RegExp(r'^-+|-+$'), '');
//   }
//
//   String _cleanUrl(String url) {
//     var value = Uri.decodeFull(url).replaceAll('&amp;', '&');
//     final end = value.indexOf(RegExp(r'[\"<> ]'));
//     if (end >= 0) value = value.substring(0, end);
//     return value.replaceAll(RegExp(r'[),.;]+$'), '');
//   }
//
//   String _decodeHtml(String value) {
//     var text = value;
//     text = text.replaceAll('&amp;', '&');
//     text = text.replaceAll('&quot;', '"');
//     text = text.replaceAll('&#39;', "'");
//     text = text.replaceAll('&apos;', "'");
//     text = text.replaceAll('&lt;', '<');
//     text = text.replaceAll('&gt;', '>');
//
//     text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
//       final code = int.tryParse(m.group(1)!);
//       return code == null ? m.group(0)! : String.fromCharCode(code);
//     });
//     text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
//       final code = int.tryParse(m.group(1)!, radix: 16);
//       return code == null ? m.group(0)! : String.fromCharCode(code);
//     });
//     return text;
//   }
//
//   bool _isValidIsin(String isin) {
//     if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) return false;
//
//     final expanded = StringBuffer();
//     for (final char in isin.substring(0, 11).split('')) {
//       final code = char.codeUnitAt(0);
//       if (code >= 65 && code <= 90) {
//         expanded.write(code - 55);
//       } else {
//         expanded.write(char);
//       }
//     }
//     expanded.write(isin[11]);
//
//     final digits = expanded.toString();
//     var sum = 0;
//     var doubleDigit = true;
//     for (var i = digits.length - 1; i >= 0; i--) {
//       var digit = int.parse(digits[i]);
//       if (doubleDigit) {
//         digit *= 2;
//         if (digit > 9) digit -= 9;
//       }
//       sum += digit;
//       doubleDigit = !doubleDigit;
//     }
//     return sum % 10 == 0;
//   }
//
//   void _log(String message) {
//     if (debug) print('Investing: $message');
//   }
//
//   void dispose() => _client.close();
// }
