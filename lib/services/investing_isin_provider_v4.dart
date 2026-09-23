import 'package:http/http.dart' as http;

import '../models/foreign_isin_provider.dart';

/// Proveedor de ISIN basado en resultados públicos de Investing.com.
///
/// V4: Investing.com devuelve 403 a peticiones HTTP directas desde Dart.
/// Por eso el proveedor no intenta saltarse esa protección. Utiliza primero
/// fichas públicas conocidas y, cuando Investing bloquea la petición, intenta
/// obtener la relación Performance ID -> ISIN desde el resultado indexado de
/// un buscador público.
///
/// Orden:
///   1. URL directa construida desde el nombre (si responde 200).
///   2. Google en modo HTML simple, extrayendo URL y/o ISIN del resultado.
///   3. Bing como segundo buscador.
///
/// Nunca devuelve un ISIN sin validarlo mediante checksum ISIN.
class InvestingIsinProvider implements ForeignIsinProvider {
  final http.Client _client;
  final bool debug;
  final bool enableSearchFallback;

  InvestingIsinProvider({
    http.Client? client,
    this.debug = false,
    this.enableSearchFallback = true,
  }) : _client = client ?? http.Client();

  static final RegExp _isinPattern = RegExp(
    r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b',
    caseSensitive: false,
  );

  static final RegExp _performancePattern = RegExp(
    r'\b0P[0-9A-Z]+\b',
    caseSensitive: false,
  );

  static final RegExp _hrefPattern = RegExp(
    r'''href\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _plainInvestingUrlPattern = RegExp(
    r'https?://(?:[a-z]{2}\.)?investing\.com/funds/[^\s"<>\\]+',
    caseSensitive: false,
  );

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    final performanceId = _extractPerformanceId(yahooSymbol, ticker);
    if (performanceId == null) {
      _log('No es un Performance ID Morningstar: $yahooSymbol');
      return null;
    }

    final attempted = <String>{};

    // 1) Intento directo. Se mantiene como optimización para cuando Investing
    // sea accesible desde el entorno donde se ejecute la aplicación.
    for (final name in <String>{fundName.trim(), yahooName.trim()}) {
      final slug = _slugify(name);
      if (slug.isEmpty) continue;

      for (final suffix in ['', '-company-profile', '-historical-data']) {
        final url = 'https://www.investing.com/funds/$slug$suffix';
        if (!attempted.add(url)) continue;

        final result = await _fetchPageAndExtract(
          url,
          performanceId: performanceId,
          fundName: fundName,
        );
        if (result != null) return result;
      }
    }

    if (!enableSearchFallback) return null;

    // 2) Buscar en índices públicos. Importante: si Investing devuelve 403,
    // podemos aprovechar el contenido del resultado del buscador sin intentar
    // evadir la protección del sitio original.
    final searchResult = await _searchIndexedSources(
      performanceId: performanceId,
      fundName: fundName,
    );

    _log('URLs Investing descubiertas: ${searchResult.urls.length}');
    for (final url in searchResult.urls) {
      _log('  -> $url');
    }

    if (searchResult.isin != null) {
      _log('ISIN obtenido del índice del buscador: ${searchResult.isin}');
      return searchResult.isin;
    }

    // 3) Si encontramos una URL pero el buscador no mostró el ISIN, intentamos
    // la página una última vez. Esto permite que funcione en redes donde
    // Investing sí sea accesible.
    for (final url in searchResult.urls) {
      if (!attempted.add(url)) continue;
      final result = await _fetchPageAndExtract(
        url,
        performanceId: performanceId,
        fundName: fundName,
      );
      if (result != null) return result;
    }

    _log(
      'No se encontró ISIN en Investing.com. URLs probadas: ${attempted.length}',
    );
    return null;
  }

  Future<String?> _fetchPageAndExtract(
    String url, {
    required String performanceId,
    required String fundName,
  }) async {
    try {
      _log('URL: $url');
      final response = await _client.get(
        Uri.parse(url),
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
        },
      );

      _log('HTTP ${response.statusCode} (${response.bodyBytes.length} bytes)');
      if (response.statusCode != 200) return null;

      final body = response.body;
      if (!_containsPerformanceId(body, performanceId)) return null;

      final candidates = _extractValidIsins(body);
      _log('ISIN candidatos: ${candidates.join(', ')}');
      if (candidates.length == 1) return candidates.single;

      return _extractContextualIsin(body, performanceId, fundName);
    } catch (e) {
      _log('Error: $e');
      return null;
    }
  }

  Future<_SearchResult> _searchIndexedSources({
    required String performanceId,
    required String fundName,
  }) async {
    final urls = <String>{};
    final isins = <String>{};

    // V4: no dependemos de una sola consulta. Los índices pueden mostrar el
    // Performance ID, el nombre y el ISIN en fragmentos diferentes según la
    // consulta. Probamos varias formulaciones muy específicas y acumulamos
    // evidencia antes de aceptar un ISIN.
    final slug = _slugify(fundName);
    final queries = <String>[
      '"$performanceId" "ISIN" site:investing.com/funds',
      '"$performanceId" "$fundName" site:investing.com/funds',
      '"$performanceId" "ISIN" "$fundName"',
      'site:investing.com/funds "$performanceId" ISIN',
      '"$fundName" "ISIN" Investing.com',
      'site:investing.com/funds "$slug" ISIN',
    ];

    // 1) Google: puede estar temporalmente limitado (429), por lo que nunca
    // dependemos exclusivamente de él.
    for (final query in queries) {
      final html = await _getSearchPage(
        engine: 'Google',
        uri: Uri.https('www.google.com', '/search', {
          'q': query,
          'num': '10',
          'gbv': '1',
          'filter': '0',
        }),
      );
      if (html == null) continue;
      final result = _parseSearchHtml(
        html,
        performanceId: performanceId,
        engine: 'Google',
      );
      urls.addAll(result.urls);
      isins.addAll(result.isins);
      final accepted = _selectIndexedIsin(isins, performanceId, fundName);
      if (accepted != null) {
        return _SearchResult(urls: urls, isin: accepted);
      }
    }

    // 2) DuckDuckGo. Hacemos varias consultas porque el snippet cambia según
    // los términos solicitados. También consultamos una variante basada en el
    // nombre para los casos donde el índice no muestra el ISIN junto al ID.
    for (final query in queries) {
      final html = await _getSearchPage(
        engine: 'DuckDuckGo',
        uri: Uri.https('html.duckduckgo.com', '/html/', {'q': query}),
      );
      if (html == null) continue;
      final result = _parseSearchHtml(
        html,
        performanceId: performanceId,
        engine: 'DuckDuckGo',
      );
      urls.addAll(result.urls);
      isins.addAll(result.isins);

      // Si la URL contiene directamente el ISIN (como gb00bz2k2m84), es una
      // evidencia muy fuerte y no necesitamos acceder a Investing.com.
      for (final url in result.urls) {
        final slugIsin = _extractIsinFromInvestingUrl(url);
        if (slugIsin != null) isins.add(slugIsin);
      }

      final accepted = _selectIndexedIsin(isins, performanceId, fundName);
      if (accepted != null) {
        return _SearchResult(urls: urls, isin: accepted);
      }
    }

    // 3) Bing. Usamos consultas más largas para intentar que el snippet
    // contenga explícitamente "ISIN: ...".
    final bingQueries = <String>[
      '"$performanceId" "ISIN" "$fundName" Investing.com',
      '"$performanceId" "$fundName" "ISIN"',
      'site:investing.com/funds "$performanceId" "$fundName"',
    ];
    for (final query in bingQueries) {
      final html = await _getSearchPage(
        engine: 'Bing',
        uri: Uri.https('www.bing.com', '/search', {
          'q': query,
          'count': '10',
          'first': '1',
        }),
      );
      if (html == null) continue;
      final result = _parseSearchHtml(
        html,
        performanceId: performanceId,
        engine: 'Bing',
      );
      urls.addAll(result.urls);
      isins.addAll(result.isins);
      for (final url in result.urls) {
        final slugIsin = _extractIsinFromInvestingUrl(url);
        if (slugIsin != null) isins.add(slugIsin);
      }
      final accepted = _selectIndexedIsin(isins, performanceId, fundName);
      if (accepted != null) {
        return _SearchResult(urls: urls, isin: accepted);
      }
    }

    return _SearchResult(
      urls: urls,
      isin: _selectIndexedIsin(isins, performanceId, fundName),
    );
  }

  Future<String?> _getSearchPage({
    required String engine,
    required Uri uri,
  }) async {
    try {
      _log('Buscando en $engine: ${uri.queryParameters['q']}');
      final response = await _client.get(
        uri,
        headers: const {
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36',
        },
      );
      _log(
        '$engine HTTP ${response.statusCode} (${response.bodyBytes.length} bytes)',
      );
      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      _log('Error $engine: $e');
      return null;
    }
  }

  _ParsedSearch _parseSearchHtml(
    String rawHtml, {
    required String performanceId,
    required String engine,
  }) {
    var html = _decodeHtml(rawHtml);
    html = html
        .replaceAll(r'\u003A', ':')
        .replaceAll(r'\u002F', '/')
        .replaceAll(r'\u003F', '?')
        .replaceAll(r'\u003D', '=')
        .replaceAll(r'\u0026', '&')
        .replaceAll('%3A', ':')
        .replaceAll('%2F', '/')
        .replaceAll('%3F', '?')
        .replaceAll('%3D', '=')
        .replaceAll('%26', '&');
    final urls = <String>{};
    final isins = <String>{};

    // Extraemos hrefs reales. Esto cubre tanto enlaces directos como enlaces
    // de redirección de buscadores.
    for (final match in _hrefPattern.allMatches(html)) {
      final href = _normalizeSearchHref(match.group(1)!);
      if (_isInvestingFundUrl(href)) urls.add(href);
    }

    // Algunos buscadores incluyen las URLs directamente en scripts/JSON.
    for (final match in _plainInvestingUrlPattern.allMatches(html)) {
      final url = _cleanUrl(match.group(0)!);
      if (_isInvestingFundUrl(url)) urls.add(url);
    }

    // Analizamos bloques de texto cercanos al Performance ID. Así evitamos
    // coger un ISIN perteneciente a otro resultado de la misma búsqueda.
    final text = _stripTags(html).replaceAll(RegExp(r'\s+'), ' ');
    final upper = text.toUpperCase();
    var offset = 0;

    while (true) {
      final index = upper.indexOf(performanceId.toUpperCase(), offset);
      if (index < 0) break;

      final start = index > 1800 ? index - 1800 : 0;
      final end = index + 3000 < text.length ? index + 3000 : text.length;
      final fragment = text.substring(start, end);

      // Prioridad máxima: candidatos que estén cerca de la palabra ISIN.
      // Esto evita aceptar identificadores aleatorios de 12 caracteres que
      // aparezcan en otros campos del resultado (por ejemplo tracking IDs).
      final upperFragment = fragment.toUpperCase();
      var cursor = 0;
      while (true) {
        final isinLabel = upperFragment.indexOf('ISIN', cursor);
        if (isinLabel < 0) break;
        final localStart = isinLabel > 300 ? isinLabel - 300 : 0;
        final localEnd = isinLabel + 500 < fragment.length
            ? isinLabel + 500
            : fragment.length;
        final local = fragment.substring(localStart, localEnd);
        for (final match in _isinPattern.allMatches(local)) {
          final isin = match.group(0)!.toUpperCase();
          if (_isValidIsin(isin)) isins.add(isin);
        }
        cursor = isinLabel + 4;
      }

      // Fallback: sólo si no apareció una etiqueta ISIN, permitimos buscar
      // en el fragmento cercano al Performance ID. El checksum sigue siendo
      // obligatorio.
      if (isins.isEmpty) {
        for (final match in _isinPattern.allMatches(fragment)) {
          final isin = match.group(0)!.toUpperCase();
          if (_isValidIsin(isin)) isins.add(isin);
        }
      }

      offset = index + performanceId.length;
    }

    // Algunos buscadores esconden el fragmento útil en atributos/JSON y no
    // queda visible después de quitar etiquetas. Si la búsqueda era exacta
    // para un único Performance ID, un único ISIN válido en toda la respuesta
    // es una evidencia suficientemente fuerte.
    if (isins.isEmpty &&
        html.toUpperCase().contains(performanceId.toUpperCase())) {
      final upperHtml = html.toUpperCase();
      var cursor = 0;
      while (true) {
        final label = upperHtml.indexOf('ISIN', cursor);
        if (label < 0) break;
        final start = label > 500 ? label - 500 : 0;
        final end = label + 800 < html.length ? label + 800 : html.length;
        final local = html.substring(start, end);
        for (final match in _isinPattern.allMatches(local)) {
          final isin = match.group(0)!.toUpperCase();
          if (_isValidIsin(isin)) isins.add(isin);
        }
        cursor = label + 4;
      }
    }

    _log('$engine: URLs=${urls.length}, ISIN candidatos=${isins.join(', ')}');
    return _ParsedSearch(urls: urls, isins: isins);
  }

  String _normalizeSearchHref(String value) {
    var href = _decodeHtml(value.trim());
    href = href.replaceAll(r'\\u003d', '=').replaceAll(r'\\u0026', '&');

    if (href.startsWith('/url?')) {
      final parsed = Uri.tryParse('https://www.google.com$href');
      final target =
          parsed?.queryParameters['q'] ?? parsed?.queryParameters['url'];
      if (target != null && target.isNotEmpty) href = target;
    }

    if (href.startsWith('//')) href = 'https:$href';
    if (href.startsWith('/')) return '';

    try {
      href = Uri.decodeComponent(href);
    } catch (_) {}

    return _cleanUrl(href);
  }

  String _cleanUrl(String value) {
    var url = value.trim();
    url = url.replaceAll('&amp;', '&');
    url = url.replaceAll(RegExp(r'["<>]+$'), '');

    // DuckDuckGo añade a veces &rut=... al final de la URL visible. No forma
    // parte de Investing.com. Eliminamos cualquier query porque no la
    // necesitamos para identificar la página indexada.
    final rut = url.indexOf('&rut=');
    if (rut >= 0) url = url.substring(0, rut);
    final question = url.indexOf('?');
    if (question >= 0) url = url.substring(0, question);

    // También limpiamos un posible slash final para facilitar deduplicación.
    if (url.endsWith('/') && url.length > 'https://x.com/'.length) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  bool _isInvestingFundUrl(String url) {
    final lower = url.toLowerCase();
    return lower.startsWith('http') && lower.contains('investing.com/funds/');
  }

  String? _extractIsinFromInvestingUrl(String url) {
    final match = RegExp(
      r'/funds/([a-z0-9]{12})(?:-|/|$)',
      caseSensitive: false,
    ).firstMatch(url);
    if (match == null) return null;
    final candidate = match.group(1)!.toUpperCase();
    return _isValidIsin(candidate) ? candidate : null;
  }

  String? _selectIndexedIsin(
    Set<String> candidates,
    String performanceId,
    String fundName,
  ) {
    final valid = candidates
        .where(_isValidIsin)
        .map((e) => e.toUpperCase())
        .toSet();
    if (valid.isEmpty) return null;
    if (valid.length == 1) return valid.single;

    // Si hay varios candidatos, no elegimos arbitrariamente. Priorizamos los
    // que aparecen literalmente en una evidencia que también contiene el
    // Performance ID y el nombre del fondo. Esta función recibe sólo el
    // conjunto acumulado, por lo que el desempate conservador es devolver null
    // y dejar que una consulta más específica reduzca el conjunto.
    _log(
      'V4: varios ISIN válidos, no se elige arbitrariamente: ${valid.join(', ')}',
    );
    return null;
  }

  List<String> _extractValidIsins(String html) {
    final result = <String>{};
    for (final match in _isinPattern.allMatches(html)) {
      final isin = match.group(0)!.toUpperCase();
      if (_isValidIsin(isin)) result.add(isin);
    }
    return result.toList();
  }

  String? _extractContextualIsin(
    String html,
    String performanceId,
    String fundName,
  ) {
    final text = _stripTags(_decodeHtml(html)).replaceAll(RegExp(r'\s+'), ' ');
    final needles = ['ISIN', performanceId, fundName];

    for (final needle in needles) {
      final index = text.toUpperCase().indexOf(needle.toUpperCase());
      if (index < 0) continue;

      final start = index > 1000 ? index - 1000 : 0;
      final end = index + 2000 < text.length ? index + 2000 : text.length;
      final fragment = text.substring(start, end);
      for (final match in _isinPattern.allMatches(fragment)) {
        final isin = match.group(0)!.toUpperCase();
        if (_isValidIsin(isin)) return isin;
      }
    }

    return null;
  }

  bool _containsPerformanceId(String html, String performanceId) =>
      html.toUpperCase().contains(performanceId.toUpperCase());

  String? _extractPerformanceId(String yahooSymbol, String ticker) {
    for (final value in [yahooSymbol, ticker]) {
      final match = _performancePattern.firstMatch(value.trim().toUpperCase());
      if (match != null) return match.group(0)!.toUpperCase();
    }
    return null;
  }

  String _slugify(String value) {
    var text = _decodeHtml(value).toLowerCase().trim();
    text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    text = text.replaceAll(RegExp(r'-+'), '-');
    return text.replaceAll(RegExp(r'^-|-$'), '');
  }

  String _stripTags(String value) {
    return value
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
  }

  String _decodeHtml(String value) {
    var result = value;
    const entities = {
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    entities.forEach((key, replacement) {
      result = result.replaceAll(key, replacement);
    });

    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!));
    });
    result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
      return String.fromCharCode(int.parse(m.group(1)!, radix: 16));
    });
    return result;
  }

  bool _isValidIsin(String isin) {
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) return false;

    var expanded = '';
    for (final char in isin.substring(0, 11).split('')) {
      final code = char.codeUnitAt(0);
      if (code >= 65 && code <= 90) {
        expanded += (code - 55).toString();
      } else {
        expanded += char;
      }
    }

    var sum = 0;
    var doubleDigit = true;
    for (var i = expanded.length - 1; i >= 0; i--) {
      var digit = int.parse(expanded[i]);
      if (doubleDigit) {
        digit *= 2;
        if (digit > 9) digit = digit ~/ 10 + digit % 10;
      }
      sum += digit;
      doubleDigit = !doubleDigit;
    }

    return (10 - (sum % 10)) % 10 == int.parse(isin[11]);
  }

  void _log(String message) {
    if (debug) print('InvestingV4: $message');
  }

  void dispose() => _client.close();
}

class _ParsedSearch {
  final Set<String> urls;
  final Set<String> isins;

  _ParsedSearch({required this.urls, required this.isins});
}

class _SearchResult {
  final Set<String> urls;
  final String? isin;

  _SearchResult({required this.urls, required this.isin});
}
