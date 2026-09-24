// import 'package:http/http.dart' as http;
//
// import '../../models/foreign_isin_provider.dart';
//
// /// Resuelve ISIN de fondos usando el directorio público de FT Markets.
// ///
// /// Estrategia:
// ///  1. Localiza el proveedor en el directorio A-Z.
// ///  2. Descarga su página con pageSize=200.
// ///  3. Extrae nombre de clase e ISIN desde los enlaces de FT.
// ///  4. Compara el nombre solicitado con las clases encontradas.
// class FtIsinProvider implements ForeignIsinProvider {
//   final http.Client client;
//   final int pageSize;
//   final bool debug;
//
//   FtIsinProvider({http.Client? client, this.pageSize = 200, this.debug = true})
//     : client = client ?? http.Client();
//
//   static const String _base = 'https://markets.ft.com/data/funds/uk/directory';
//
//   @override
//   Future<String?> resolve({
//     required String ticker,
//     required String fundName,
//     required String yahooSymbol,
//     required String yahooName,
//   }) async {
//     _log('FT Markets: $fundName');
//
//     final providerName = _guessProviderName(fundName, yahooName);
//     if (providerName == null) {
//       _log('  No se pudo determinar el proveedor.');
//       return null;
//     }
//     _log('  Proveedor candidato: $providerName');
//
//     final provider = await _findProvider(providerName);
//     if (provider == null) {
//       _log('  Proveedor no encontrado en FT.');
//       return null;
//     }
//     _log('  FT provider: ${provider.name} / ${provider.slug}');
//
//     final funds = await _loadProviderFunds(provider);
//     _log('  Clases encontradas: ${funds.length}');
//
//     // Primero buscamos coincidencias exactas directamente sobre todas las
//     // clases obtenidas de FT. No dependemos del score ni del filtro de
//     // candidatos: una igualdad de nombre debe tener prioridad absoluta.
//     final exactFunds = funds
//         .where((fund) => _sameFundName(fundName, fund.name))
//         .toList();
//
//     if (exactFunds.length == 1) {
//       final exact = exactFunds.first;
//       _log('  Coincidencia exacta: ${exact.name} -> ${exact.isin}');
//       return exact.isin;
//     }
//
//     if (exactFunds.length > 1) {
//       final uniqueIsins = exactFunds.map((f) => f.isin).toSet();
//       if (uniqueIsins.length == 1) {
//         _log('  Coincidencia exacta duplicada -> ${exactFunds.first.isin}');
//         return exactFunds.first.isin;
//       }
//       _log(
//         '  Hay varias clases con nombre exactamente igual pero ISIN diferente; no se selecciona ninguna.',
//       );
//       return null;
//     }
//
//     final matches = <_Match>[];
//     for (final fund in funds) {
//       final score = _fundSimilarity(fundName, fund.name);
//       if (score >= 0.68) {
//         matches.add(_Match(fund.name, fund.isin, score));
//       }
//     }
//     matches.sort((a, b) {
//       final score = b.score.compareTo(a.score);
//       if (score != 0) return score;
//       return a.name.length.compareTo(b.name.length);
//     });
//
//     for (final m in matches.take(10)) {
//       _log(
//         '  Candidato: ${m.name} -> ${m.isin} score=${m.score.toStringAsFixed(3)}',
//       );
//     }
//
//     if (matches.isEmpty) return null;
//
//     final best = matches.first;
//
//     if (matches.length > 1 &&
//         best.isin != matches[1].isin &&
//         best.score - matches[1].score < 0.035) {
//       _log('  Coincidencia ambigua; no se selecciona ninguna clase.');
//       return null;
//     }
//
//     return best.isin;
//   }
//
//   Future<_Provider?> _findProvider(String name) async {
//     final letter = _firstLetter(name);
//     final url = '$_base/$letter?page=1&pageSize=$pageSize';
//     _log('  Directorio: $url');
//
//     final html = await _get(url);
//     if (html == null) return null;
//
//     _Provider? best;
//     var bestScore = 0.0;
//     for (final p in _parseProviders(html)) {
//       final score = _providerSimilarity(name, p.name);
//       if (score > bestScore) {
//         bestScore = score;
//         best = p;
//       }
//     }
//     return bestScore >= 0.78 ? best : null;
//   }
//
//   List<_Provider> _parseProviders(String html) {
//     final result = <_Provider>[];
//     final seen = <String>{};
//     final re = RegExp(
//       r'''<a\b[^>]*href=["']([^"']*/directory/[^"']+)["'][^>]*>([\s\S]*?)</a>''',
//       caseSensitive: false,
//     );
//
//     for (final m in re.allMatches(html)) {
//       final href = m.group(1) ?? '';
//       final name = _clean(m.group(2) ?? '');
//       final full = href.startsWith('http')
//           ? href
//           : 'https://markets.ft.com$href';
//       final uri = Uri.tryParse(full);
//       if (uri == null || name.isEmpty) continue;
//       final parts = uri.pathSegments;
//       final i = parts.indexOf('directory');
//       if (i < 0 || i + 2 >= parts.length) continue;
//       final slug = parts[i + 2];
//       if (slug.isEmpty) continue;
//       final key = '${name.toLowerCase()}|$slug';
//       if (seen.add(key)) result.add(_Provider(name, slug));
//     }
//     return result;
//   }
//
//   Future<List<_Fund>> _loadProviderFunds(_Provider provider) async {
//     final result = <String, _Fund>{};
//     for (var page = 1; page <= 50; page++) {
//       final letter = _firstLetter(provider.name);
//       final url =
//           '$_base/$letter/${provider.slug}?page=$page&pageSize=$pageSize';
//       _log('  Página: $url');
//       final html = await _get(url);
//       if (html == null) break;
//       final funds = _parseFunds(html);
//       if (funds.isEmpty) break;
//       for (final fund in funds) result[fund.isin] = fund;
//       if (funds.length < pageSize) break;
//     }
//     return result.values.toList();
//   }
//
//   List<_Fund> _parseFunds(String html) {
//     final result = <_Fund>[];
//     final re = RegExp(
//       r'''<a\b[^>]*href=["']([^"']*/data/funds/tearsheet/summary\?s=([^"'&]+))["'][^>]*>([\s\S]*?)</a>''',
//       caseSensitive: false,
//     );
//
//     for (final m in re.allMatches(html)) {
//       final security = Uri.decodeComponent(m.group(2) ?? '');
//       final isin = security.split(':').first.trim().toUpperCase();
//       if (!_isValidIsin(isin)) continue;
//       // En el HTML de FT el enlace contiene el nombre y, dentro del
//       // mismo <a>, un <span> con "ISIN:DIVISA". Si limpiamos todo el
//       // HTML de una vez terminamos incorporando el ISIN al nombre y una
//       // coincidencia que debería ser exacta se convierte en una similitud
//       // aproximada (por ejemplo 0.880).
//       //
//       // Nos quedamos exclusivamente con el texto del nombre, anterior al
//       // primer <span>.
//       final rawName = m.group(3) ?? '';
//       final nameHtml = rawName
//           .split(RegExp(r'<span\b', caseSensitive: false))
//           .first;
//       final name = _clean(nameHtml);
//       if (name.isNotEmpty) result.add(_Fund(name, isin));
//     }
//     return result;
//   }
//
//   String? _guessProviderName(String fundName, String yahooName) {
//     final sources = [
//       yahooName,
//       fundName,
//     ].map((s) => s.trim()).where((s) => s.isNotEmpty);
//
//     for (final source in sources) {
//       // 1. Formato habitual: "Proveedor - Nombre del fondo".
//       for (final sep in [' - ', ' – ', ' — ', ' | ']) {
//         final i = source.indexOf(sep);
//         if (i > 0) {
//           final candidate = source.substring(0, i).trim();
//           if (_looksLikeProvider(candidate)) return candidate;
//         }
//       }
//
//       // 2. Algunos nombres de Yahoo son "Proveedor Fondo ...".
//       //    Buscamos el prefijo que mejor parezca un proveedor, evitando
//       //    devolver "Premier Miton European Opportunities" como proveedor.
//       final words = source.split(RegExp(r'\s+'));
//       final stopWords = <String>{
//         'fund',
//         'funds',
//         'investment',
//         'investments',
//         'opportunities',
//         'growth',
//         'income',
//         'global',
//         'european',
//         'europe',
//         'international',
//         'strategy',
//         'strategies',
//         'portfolio',
//         'trust',
//         'class',
//       };
//
//       // Probar prefijos de 1..4 palabras. El candidato se validará contra
//       // el directorio FT mediante _providerSimilarity().
//       for (var n = 1; n <= words.length && n <= 4; n++) {
//         final candidate = words.take(n).join(' ').trim();
//         if (!_looksLikeProvider(candidate)) continue;
//         final last = words[n - 1].toLowerCase();
//         if (stopWords.contains(last)) break;
//
//         // Si el siguiente término ya indica claramente que empieza el
//         // nombre del fondo, el prefijo actual es el proveedor más probable.
//         if (n < words.length && stopWords.contains(words[n].toLowerCase())) {
//           return candidate;
//         }
//       }
//
//       // 3. Fallback compatible con la lógica anterior.
//       final lower = source.toLowerCase();
//       for (final marker in [' fund ', ' fund-', ' funds ']) {
//         final i = lower.indexOf(marker);
//         if (i > 0) {
//           final candidate = source.substring(0, i).trim();
//           if (_looksLikeProvider(candidate)) return candidate;
//         }
//       }
//     }
//     return null;
//   }
//
//   bool _looksLikeProvider(String s) {
//     final n = _normalize(s);
//     const generic = {
//       'fund',
//       'funds',
//       'investment',
//       'investments',
//       'capital',
//       'asset',
//       'assets',
//     };
//     return n.length >= 3 && !generic.contains(n);
//   }
//
//   double _providerSimilarity(String a, String b) {
//     final aa = _normalize(a), bb = _normalize(b);
//     if (aa == bb) return 1.0;
//     if (aa.contains(bb) || bb.contains(aa)) return 0.90;
//     final x = aa.split(' ').toSet(), y = bb.split(' ').toSet();
//     if (x.isEmpty || y.isEmpty) return 0;
//     return x.intersection(y).length / x.union(y).length;
//   }
//
//   double _fundSimilarity(String a, String b) {
//     final aa = _normalizeFund(a), bb = _normalizeFund(b);
//     if (aa == bb) return 1.0;
//     if (aa.isEmpty || bb.isEmpty) return 0;
//     final x = aa.split(' ').where((s) => s.length > 1).toSet();
//     final y = bb.split(' ').where((s) => s.length > 1).toSet();
//     if (x.isEmpty || y.isEmpty) return 0;
//     var score = x.intersection(y).length / x.union(y).length;
//     if (aa.contains(bb) || bb.contains(aa)) score = _max(score, 0.88);
//     return score;
//   }
//
//   bool _sameFundName(String a, String b) {
//     // Igualdad exacta semántica: ignora mayúsculas/minúsculas, acentos,
//     // puntuación y espacios repetidos, pero NO elimina palabras como EUR,
//     // GBP, Accumulation, Income, B, F, etc. Así se distinguen correctamente
//     // las distintas clases/share classes.
//     return _normalizeFund(a) == _normalizeFund(b);
//   }
//
//   String _normalizeFund(String value) {
//     var s = _normalize(value);
//     s = s
//         .replaceAll('accum', 'accumulation')
//         .replaceAll('accumulating', 'accumulation');
//     s = s.replaceAll(RegExp(r'\binc\b'), 'income');
//     return s;
//   }
//
//   String _normalize(String value) {
//     var s = value.toLowerCase();
//     const map = {
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
//       '&': ' ',
//       '-': ' ',
//       '_': ' ',
//       '/': ' ',
//       '.': ' ',
//       ',': ' ',
//       ':': ' ',
//       ';': ' ',
//       '(': ' ',
//       ')': ' ',
//       '[': ' ',
//       ']': ' ',
//     };
//     map.forEach((a, b) => s = s.replaceAll(a, b));
//     return s.replaceAll(RegExp(r'\s+'), ' ').trim();
//   }
//
//   String _firstLetter(String s) =>
//       s.trim().isEmpty ? 'a' : s.trim().toLowerCase()[0];
//
//   String _clean(String html) => html
//       .replaceAll(
//         RegExp(r'<script\b[\s\S]*?</script>', caseSensitive: false),
//         ' ',
//       )
//       .replaceAll(
//         RegExp(r'<style\b[\s\S]*?</style>', caseSensitive: false),
//         ' ',
//       )
//       .replaceAll(RegExp(r'<[^>]+>'), ' ')
//       .replaceAll('&nbsp;', ' ')
//       .replaceAll('&amp;', '&')
//       .replaceAll('&quot;', '"')
//       .replaceAll('&#39;', "'")
//       .replaceAll(RegExp(r'\s+'), ' ')
//       .trim();
//
//   Future<String?> _get(String url) async {
//     try {
//       final response = await client.get(
//         Uri.parse(url),
//         headers: const {
//           'Accept':
//               'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
//           'Accept-Language': 'en-GB,en;q=0.9,es;q=0.8',
//           'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/140.0.0.0 Safari/537.36',
//         },
//       );
//       _log('    HTTP ${response.statusCode} (${response.body.length} bytes)');
//       return response.statusCode == 200 ? response.body : null;
//     } catch (e) {
//       _log('    Error HTTP: $e');
//       return null;
//     }
//   }
//
//   bool _isValidIsin(String isin) {
//     if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$').hasMatch(isin)) return false;
//     final digits = <int>[];
//     for (final c in isin.split('')) {
//       if (RegExp(r'[A-Z]').hasMatch(c)) {
//         final n = c.codeUnitAt(0) - 55;
//         digits
//           ..add(n ~/ 10)
//           ..add(n % 10);
//       } else {
//         digits.add(int.parse(c));
//       }
//     }
//     var sum = 0;
//     final parity = digits.length % 2;
//     for (var i = 0; i < digits.length; i++) {
//       var d = digits[i];
//       if (i % 2 == parity) {
//         d *= 2;
//         if (d > 9) d = d ~/ 10 + d % 10;
//       }
//       sum += d;
//     }
//     return sum % 10 == 0;
//   }
//
//   double _max(double a, double b) => a > b ? a : b;
//
//   /// Cierra el cliente HTTP cuando el provider deja de utilizarse.
//   ///
//   /// Es síncrono porque http.Client.close() devuelve void.
//   void dispose() {
//     client.close();
//   }
//
//   void _log(String s) {
//     if (debug) print(s);
//   }
// }
//
// class _Provider {
//   final String name;
//   final String slug;
//   const _Provider(this.name, this.slug);
// }
//
// class _Fund {
//   final String name;
//   final String isin;
//   const _Fund(this.name, this.isin);
// }
//
// class _Match {
//   final String name;
//   final String isin;
//   final double score;
//   const _Match(this.name, this.isin, this.score);
// }
