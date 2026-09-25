// import 'dart:convert';
//
// import 'package:http/http.dart' as http;
// import 'package:investing/models/foreign_isin_provider.dart';
//
// //import '../lib/models/foreign_isin_provider.dart';
//
// /// Proveedor de ISIN basado en fichas públicas de Morningstar.
// ///
// /// Estrategia:
// /// 1. Prueba las fichas modernas de global.morningstar.com.
// /// 2. Prueba las fichas legacy de distintos portales Morningstar.
// /// 3. Si Morningstar moderno devuelve 202 (página dinámica), intenta descubrir
// ///    una ficha pública legacy mediante un buscador web y después descarga esa
// ///    ficha.
// ///
// /// No contiene ISINs hardcodeados: el ISIN siempre se extrae de la respuesta.
// class MorningstarWebIsinProvider implements ForeignIsinProvider {
//   final http.Client _client;
//   final bool debug;
//   final String locale;
//   final bool enableWebSearchFallback;
//
//   MorningstarWebIsinProvider({
//     http.Client? client,
//     this.debug = false,
//     this.locale = 'es',
//     this.enableWebSearchFallback = true,
//   }) : _client = client ?? http.Client();
//
//   static final RegExp _isinPattern = RegExp(
//     r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b',
//     caseSensitive: false,
//   );
//
//   static final RegExp _htmlTagPattern = RegExp(r'<[^>]*>');
//
//   static final RegExp _urlPattern = RegExp(
//     r'https?://[^\s"<>]+',
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
//       _log('No parece un Morningstar Performance ID: $yahooSymbol');
//       return null;
//     }
//
//     final attempted = <String>{};
//
//     // 1) Sitios modernos.
//     final modernUrls = <String>[
//       'https://global.morningstar.com/$locale/inversiones/fondos/$performanceId/cotizacion',
//       'https://global.morningstar.com/$locale/inversiones/fondos/$performanceId/parent',
//       'https://global.morningstar.com/en-ea/investments/funds/$performanceId/parent',
//       'https://global.morningstar.com/en-ea/investments/funds/$performanceId/quote',
//     ];
//
//     for (final url in modernUrls) {
//       attempted.add(url);
//       final result = await _fetch(url);
//       final isin = _extractBestIsin(
//         result?.body,
//         fundName: fundName,
//         yahooName: yahooName,
//       );
//       if (isin != null) return isin;
//     }
//
//     // 2) URLs legacy conocidas. Algunas requieren el identificador interno
//     // F000..., por lo que pueden fallar; se incluyen porque son útiles cuando
//     // el portal regional acepta directamente el Performance ID.
//     final legacyUrls = _legacyUrls(performanceId);
//     for (final url in legacyUrls) {
//       if (!attempted.add(url)) continue;
//       final result = await _fetch(url);
//       final isin = _extractBestIsin(
//         result?.body,
//         fundName: fundName,
//         yahooName: yahooName,
//       );
//       if (isin != null) return isin;
//     }
//
//     // 3) Descubrimiento de una ficha legacy mediante buscador.
//     // Es un fallback: no se usa ningún ISIN del buscador, solo sus URLs.
//     if (enableWebSearchFallback) {
//       final discoveredUrls = await _discoverMorningstarUrls(
//         performanceId,
//         fundName,
//       );
//
//       for (final url in discoveredUrls) {
//         if (!attempted.add(url)) continue;
//         final result = await _fetch(url);
//         final isin = _extractBestIsin(
//           result?.body,
//           fundName: fundName,
//           yahooName: yahooName,
//         );
//         if (isin != null) return isin;
//       }
//     }
//
//     _log(
//       'No se encontró un ISIN en Morningstar. URLs probadas: ${attempted.length}',
//     );
//     return null;
//   }
//
//   List<String> _legacyUrls(String performanceId) {
//     return <String>[
//       'https://www.morningstar.co.uk/uk/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.co.uk/uk/funds/snapshot/snapshot.aspx?id=$performanceId&tab=1',
//       'https://www.morningstar.fr/fr/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.de/de/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.it/it/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.se/se/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.no/no/funds/snapshot/snapshot.aspx?id=$performanceId',
//       'https://www.morningstar.dk/dk/funds/snapshot/snapshot.aspx?id=$performanceId',
//     ];
//   }
//
//   Future<List<String>> _discoverMorningstarUrls(
//     String performanceId,
//     String fundName,
//   ) async {
//     final queries = <String>[
//       '"$performanceId" site:morningstar.com',
//       '"$performanceId" "$fundName" Morningstar',
//     ];
//
//     final urls = <String>[];
//
//     for (final query in queries) {
//       final encoded = Uri.encodeQueryComponent(query);
//       final url = 'https://www.google.com/search?q=$encoded&num=10';
//       _log('Buscando ficha Morningstar: $query');
//
//       final result = await _fetch(url, allowNon200: true);
//       if (result == null) continue;
//
//       // Extraemos enlaces Morningstar del HTML del buscador. No confiamos en
//       // ningún dato textual del buscador para determinar el ISIN.
//       for (final match in _urlPattern.allMatches(result.body)) {
//         var candidate = match.group(0)!;
//         candidate = _decodeUrl(candidate);
//         if (!candidate.toLowerCase().contains('morningstar.')) continue;
//         if (candidate.contains('google.com')) continue;
//         if (candidate.contains('support.google.com')) continue;
//         if (candidate.contains('googleusercontent.com')) continue;
//         urls.add(candidate.replaceAll('&amp;', '&'));
//       }
//
//       // También intentamos enlaces codificados típicos de Google.
//       for (final match in RegExp(
//         r'/url\?q=([^&" ]+)',
//         caseSensitive: false,
//       ).allMatches(result.body)) {
//         final candidate = Uri.decodeComponent(match.group(1)!);
//         if (candidate.toLowerCase().contains('morningstar.')) {
//           urls.add(candidate);
//         }
//       }
//
//       if (urls.isNotEmpty) break;
//     }
//
//     final unique = <String>[];
//     final seen = <String>{};
//     for (final url in urls) {
//       if (seen.add(url)) unique.add(url);
//     }
//
//     _log('Fichas Morningstar descubiertas: ${unique.length}');
//     for (final url in unique.take(10)) {
//       _log('  -> $url');
//     }
//     return unique.take(10).toList();
//   }
//
//   String _decodeUrl(String value) {
//     var v = value;
//     try {
//       v = Uri.decodeComponent(v);
//     } catch (_) {}
//     return v;
//   }
//
//   Future<_FetchResult?> _fetch(String url, {bool allowNon200 = false}) async {
//     _log('URL: $url');
//     try {
//       final response = await _client.get(
//         Uri.parse(url),
//         headers: const {
//           'Accept':
//               'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//           'Accept-Language': 'es-ES,es;q=0.9,en-US;q=0.8,en;q=0.7',
//           'Cache-Control': 'no-cache',
//           'Pragma': 'no-cache',
//           'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
//         },
//       );
//
//       _log('HTTP ${response.statusCode} (${response.bodyBytes.length} bytes)');
//
//       if (debug && response.body.isNotEmpty) {
//         final preview = _cleanHtml(_decodeHtml(response.body));
//         final end = preview.length < 180 ? preview.length : 180;
//         _log('Título/texto inicial: ${preview.substring(0, end)}');
//       }
//
//       if ((!allowNon200 && response.statusCode != 200) ||
//           response.body.isEmpty) {
//         return null;
//       }
//
//       return _FetchResult(response.body, response.statusCode);
//     } catch (e) {
//       _log('ERROR HTTP: $e');
//       return null;
//     }
//   }
//
//   String? _extractPerformanceId(String yahooSymbol, String ticker) {
//     for (final value in [yahooSymbol, ticker]) {
//       final v = value.trim();
//       if (RegExp(r'^0P[0-9A-Z]+$', caseSensitive: false).hasMatch(v)) {
//         return v.toUpperCase();
//       }
//     }
//     return null;
//   }
//
//   String? _extractBestIsin(
//     String? html, {
//     required String fundName,
//     required String yahooName,
//   }) {
//     if (html == null || html.isEmpty) return null;
//
//     final candidates = _extractIsins(html);
//     if (candidates.isEmpty) return null;
//
//     _log('ISIN candidatos: ${candidates.join(', ')}');
//
//     final exact = _findIsinNearName(html, candidates, fundName, yahooName);
//     if (exact != null) {
//       _log('ISIN seleccionado por nombre: $exact');
//       return exact;
//     }
//
//     if (candidates.length == 1) {
//       _log('Único ISIN válido encontrado: ${candidates.first}');
//       return candidates.first;
//     }
//
//     return null;
//   }
//
//   List<String> _extractIsins(String html) {
//     final decoded = _decodeHtml(html).toUpperCase();
//     final found = <String>{};
//
//     for (final match in _isinPattern.allMatches(decoded)) {
//       final isin = match.group(0)!.toUpperCase();
//       if (_isValidIsin(isin)) found.add(isin);
//     }
//
//     return found.toList();
//   }
//
//   String? _findIsinNearName(
//     String html,
//     List<String> candidates,
//     String fundName,
//     String yahooName,
//   ) {
//     if (candidates.isEmpty) return null;
//
//     final text = _cleanHtml(_decodeHtml(html));
//     final normalizedTarget = _normalizeName(
//       yahooName.isNotEmpty ? yahooName : fundName,
//     );
//     if (normalizedTarget.isEmpty) return null;
//
//     final targetTokens = normalizedTarget
//         .split(' ')
//         .where((e) => e.length >= 3)
//         .toSet();
//
//     for (final isin in candidates) {
//       final index = text.toUpperCase().indexOf(isin);
//       if (index < 0) continue;
//
//       final start = index > 1800 ? index - 1800 : 0;
//       final end = (index + isin.length + 1800).clamp(0, text.length);
//       final context = text.substring(start, end);
//       final normalizedContext = _normalizeName(context);
//
//       final hits = targetTokens.where(normalizedContext.contains).length;
//       final ratio = targetTokens.isEmpty ? 0.0 : hits / targetTokens.length;
//
//       _log(
//         'Coincidencia $isin: $hits/${targetTokens.length} (${(ratio * 100).toStringAsFixed(0)}%)',
//       );
//       if (ratio >= 0.65) return isin;
//     }
//
//     return null;
//   }
//
//   String _cleanHtml(String html) {
//     var text = html.replaceAll(_htmlTagPattern, ' ');
//     text = text
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&')
//         .replaceAll('&quot;', '"')
//         .replaceAll('&#39;', "'")
//         .replaceAll('&#x27;', "'");
//     return text.replaceAll(RegExp(r'\s+'), ' ').trim();
//   }
//
//   String _decodeHtml(String value) {
//     try {
//       return const HtmlUnescape().convert(value);
//     } catch (_) {
//       return value;
//     }
//   }
//
//   String _normalizeName(String value) {
//     var s = value.toLowerCase();
//     const replacements = {
//       'á': 'a',
//       'à': 'a',
//       'ä': 'a',
//       'â': 'a',
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
//       'ú': 'u',
//       'ù': 'u',
//       'ü': 'u',
//       'û': 'u',
//       'ñ': 'n',
//     };
//     replacements.forEach((k, v) => s = s.replaceAll(k, v));
//     s = s.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
//     return s.replaceAll(RegExp(r'\s+'), ' ').trim();
//   }
//
//   bool _isValidIsin(String isin) {
//     if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) return false;
//
//     final expanded = StringBuffer();
//     for (final c in isin.substring(0, 11).split('')) {
//       if (RegExp(r'[A-Z]').hasMatch(c)) {
//         expanded.write((c.codeUnitAt(0) - 55).toString());
//       } else {
//         expanded.write(c);
//       }
//     }
//
//     final digits = expanded.toString().split('').map(int.parse).toList();
//     var sum = 0;
//     var doubleDigit = true;
//     for (var i = digits.length - 1; i >= 0; i--) {
//       var n = digits[i];
//       if (doubleDigit) {
//         n *= 2;
//         if (n > 9) n = (n ~/ 10) + (n % 10);
//       }
//       sum += n;
//       doubleDigit = !doubleDigit;
//     }
//     final check = (10 - (sum % 10)) % 10;
//     return check == int.parse(isin.substring(11));
//   }
//
//   void _log(String message) {
//     if (debug) print('MorningstarWeb: $message');
//   }
//
//   void dispose() => _client.close();
// }
//
// class _FetchResult {
//   final String body;
//   final int statusCode;
//   _FetchResult(this.body, this.statusCode);
// }
//
// class HtmlUnescape {
//   const HtmlUnescape();
//
//   String convert(String value) {
//     return value
//         .replaceAll('&nbsp;', ' ')
//         .replaceAll('&amp;', '&')
//         .replaceAll('&quot;', '"')
//         .replaceAll('&apos;', "'")
//         .replaceAll('&#39;', "'")
//         .replaceAll('&#x27;', "'");
//   }
// }
