import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/foreign_isin_provider.dart';
import 'cnmv_local_fund_provider.dart';

class IsinResult {
  final String isin;
  final String source;
  final String? officialName;
  final int? cnmvRegistration;
  final String? cnmvNif;

  const IsinResult({
    required this.isin,
    required this.source,
    this.officialName,
    this.cnmvRegistration,
    this.cnmvNif,
  });

  @override
  String toString() =>
      'IsinResult('
      'isin: $isin, source: $source, officialName: $officialName, '
      'cnmvRegistration: $cnmvRegistration, cnmvNif: $cnmvNif)';
}

/// Resuelve el ISIN de una clase concreta de un fondo extranjero usando
/// Morningstar.
///
/// Yahoo Finance suele devolver para fondos un identificador de la forma
/// `0P000xxxxx.F`. Morningstar utiliza el mismo identificador `0P000xxxxx`
/// en sus fichas de fondos. Por ello podemos acceder directamente a la ficha
/// sin depender de un buscador externo ni de un slug construido a partir del
/// nombre.
class MorningstarForeignIsinProvider implements ForeignIsinProvider {
  final http.Client client;

  MorningstarForeignIsinProvider({http.Client? client})
    : client = client ?? http.Client();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    // Morningstar solo se utiliza cuando ya conocemos su identificador.
    //
    // Importante: no intentamos descubrir el ID mediante el buscador/API
    // interno de Morningstar. Esos endpoints están protegidos actualmente
    // por AWS WAF y desde Dart responden con HTTP 202 + challenge JavaScript.
    final morningstarId = _extractMorningstarId(yahooSymbol);

    if (morningstarId == null) {
      print(
        '  Morningstar: no hay ID Morningstar en Yahoo '
        '($yahooSymbol). Sin búsqueda por nombre.',
      );
      return null;
    }

    print('  Morningstar ID detectado: $morningstarId');

    final isin = await _resolveByMorningstarId(
      morningstarId,
      expectedNames: <String>[fundName, yahooName],
    );

    if (isin != null) return isin;

    print(
      '  Morningstar: no se encontró ISIN en la ficha '
      '$morningstarId para $fundName',
    );
    return null;
  }

  String? _extractMorningstarId(String value) {
    final match = RegExp(
      r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    return match?.group(1)?.toUpperCase();
  }

  Future<String?> _resolveByMorningstarId(
    String morningstarId, {
    required List<String> expectedNames,
  }) async {
    final urls = <String>[
      'https://global.morningstar.com/es/inversiones/fondos/$morningstarId/cotizacion',
      'https://global.morningstar.com/es/inversiones/fondos/$morningstarId/documentos',
      'https://global.morningstar.com/en-eu/investments/funds/$morningstarId/risk',
      'https://global.morningstar.com/en-eu/investments/funds/$morningstarId/documents',
    ];

    for (final url in urls) {
      print('  Morningstar ficha: $url');
      final html = await _readPage(url);
      if (html == null) continue;

      final overviewIsin = _extractOverviewIsin(
        html,
        expectedNames: expectedNames,
      );
      if (overviewIsin != null) {
        print('  Morningstar ISIN encontrado en overview: $overviewIsin');
        return overviewIsin;
      }

      final rowIsin = _extractMatchingRowIsin(
        html,
        expectedNames: expectedNames,
      );
      if (rowIsin != null) {
        print('  Morningstar ISIN encontrado en fila: $rowIsin');
        return rowIsin;
      }

      final fallback = _extractUniqueIsin(html);
      if (fallback != null) {
        print('  Morningstar ISIN encontrado en HTML: $fallback');
        return fallback;
      }
    }

    return null;
  }

  Future<String?> _readPage(String url) async {
    try {
      final response = await client.get(
        Uri.parse(url),
        headers: const {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
          'Referer': 'https://global.morningstar.com/es/',
          'User-Agent':
              'Mozilla/5.0 (X11; Linux x86_64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/140.0.0.0 Safari/537.36',
        },
      );

      print('  Morningstar GET: HTTP ${response.statusCode}');
      if (response.statusCode != 200) {
        if (response.statusCode == 202) {
          print(
            '  Morningstar: HTTP 202; la ficha requiere un challenge '
            'de AWS WAF.',
          );
        }
        return null;
      }
      return response.body;
    } catch (e) {
      print('  Error leyendo Morningstar: $e');
      return null;
    }
  }

  String? _extractOverviewIsin(
    String html, {
    required List<String> expectedNames,
  }) {
    final pattern = RegExp(
      r'''<h2\b[^>]*id=["']overview-investment-name["'][^>]*>([\s\S]*?)</h2>\s*<div\b[^>]*class=["']symbol["'][^>]*>([^<]+)</div>''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final name = _cleanHtmlText(match.group(1) ?? '');
      final isin = _cleanHtmlText(match.group(2) ?? '').toUpperCase();
      if (!_isValidIsin(isin)) continue;
      if (expectedNames.any((n) => _namesCompatible(n, name))) return isin;
    }
    return null;
  }

  String? _extractMatchingRowIsin(
    String html, {
    required List<String> expectedNames,
  }) {
    for (final rowMatch in RegExp(
      r'<tr\b[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    ).allMatches(html)) {
      final row = rowMatch.group(1) ?? '';
      final text = _cleanHtmlText(row);
      if (!expectedNames.any((n) => _namesCompatible(n, text))) continue;

      final isinMatch = RegExp(
        r'''<td\b[^>]*class=["'][^"']*\bisin(?:-[^"']*)?\b[^"']*["'][^>]*>[\s\S]*?([A-Z]{2}[A-Z0-9]{9}\d)[\s\S]*?</td>''',
        caseSensitive: false,
      ).firstMatch(row);

      final isin = isinMatch?.group(1)?.toUpperCase();
      if (isin != null && _isValidIsin(isin)) return isin;
    }
    return null;
  }

  String? _extractUniqueIsin(String html) {
    final found = <String>{};
    for (final match in RegExp(
      r'\b([A-Z]{2}[A-Z0-9]{9}\d)\b',
      caseSensitive: false,
    ).allMatches(_stripHtml(html))) {
      final isin = match.group(1)!.toUpperCase();
      if (_isValidIsin(isin)) found.add(isin);
    }
    return found.length == 1 ? found.first : null;
  }

  bool _namesCompatible(String expected, String actual) {
    final a = _normalizeName(expected);
    final b = _normalizeName(actual);
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b || a.contains(b) || b.contains(a)) return true;
    return _nameSimilarity(expected, actual) >= 0.70;
  }

  String _normalizeName(String value) => value
      .toLowerCase()
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  String _cleanHtmlText(String html) => _stripHtml(html).trim();

  String _stripHtml(String html) => html
      .replaceAll(
        RegExp(r'<script\b[\s\S]*?</script>', caseSensitive: false),
        ' ',
      )
      .replaceAll(
        RegExp(r'<style\b[\s\S]*?</style>', caseSensitive: false),
        ' ',
      )
      .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\\u002F'), '/')
      .replaceAll(RegExp(r'\\u003A'), ':')
      .replaceAll(RegExp(r'\\u002D'), '-')
      .replaceAll(RegExp(r'\\u0026'), '&')
      .replaceAll(RegExp(r'\s+'), ' ');

  bool _isValidIsin(String isin) {
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$').hasMatch(isin)) return false;

    final digits = <int>[];
    for (final char in isin.split('')) {
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        final n = char.codeUnitAt(0) - 55;
        digits.add(n ~/ 10);
        digits.add(n % 10);
      } else {
        digits.add(int.parse(char));
      }
    }

    var sum = 0;
    final parity = digits.length % 2;
    for (var i = 0; i < digits.length; i++) {
      var digit = digits[i];
      if (i % 2 == parity) {
        digit *= 2;
        if (digit > 9) digit = digit ~/ 10 + digit % 10;
      }
      sum += digit;
    }
    return sum % 10 == 0;
  }

  double _nameSimilarity(String a, String b) {
    final left = _normalizeName(a);
    final right = _normalizeName(b);
    if (left.isEmpty || right.isEmpty) return 0.0;
    if (left == right) return 1.0;

    final lt = left.split(' ').where((e) => e.length > 2).toSet();
    final rt = right.split(' ').where((e) => e.length > 2).toSet();
    if (lt.isEmpty || rt.isEmpty) return 0.0;

    final intersection = lt.intersection(rt).length;
    final union = lt.union(rt).length;
    return union == 0 ? 0.0 : intersection / union;
  }
}

class IsinResolver {
  static const String _cnmvListBaseUrl =
      'https://www.cnmv.es/portal/consultas/mostrarlistados'
      '?id=5&lang=es&page=';

  static const String _cnmvSocietyUrl =
      'https://www.cnmv.es/portal/consultas/iic/sociedadiic?nif=';

  static const String _yahooSearchUrl =
      'https://query1.finance.yahoo.com/v1/finance/search';

  final http.Client _client;
  late final List<ForeignIsinProvider> _foreignIsinProviders;
  final CnmvLocalFundProvider _cnmvLocalFundProvider;
  Map<int, _CnmvEntity>? _cnmvEntities;

  IsinResolver({
    http.Client? client,
    List<ForeignIsinProvider>? foreignIsinProviders,
    CnmvLocalFundProvider? cnmvLocalFundProvider,
  }) : _client = client ?? http.Client(),
       _cnmvLocalFundProvider =
           cnmvLocalFundProvider ?? CnmvLocalFundProvider() {
    _foreignIsinProviders =
        foreignIsinProviders ??
        [MorningstarForeignIsinProvider(client: _client)];
  }

  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final normalizedTicker = ticker.trim().toUpperCase();

    print('');
    print('------------------------------------------------------------');
    print('IsinResolver');
    print('Ticker: $normalizedTicker');
    print('Nombre: $fundName');
    print('------------------------------------------------------------');

    // El ticker puede contener un ISIN embebido, por ejemplo:
    //   LU0297942194-USD.LU
    //   LU0319688791-USD.LU
    //   LU0940716078.LU
    //
    // Buscamos una secuencia candidata de 12 caracteres y la validamos
    // con el algoritmo ISIN antes de aceptarla.
    final inputIsin = _extractEmbeddedIsin(normalizedTicker);

    if (inputIsin != null) {
      print('ISIN detectado en el ticker: $inputIsin');
      return IsinResult(
        isin: inputIsin,
        source: 'INPUT',
        officialName: fundName,
      );
    }

    final silMatch = RegExp(
      r'^SL(\d+)\.MC$',
      caseSensitive: false,
    ).firstMatch(normalizedTicker);

    if (silMatch != null) {
      final registrationNumber = int.tryParse(silMatch.group(1)!);
      if (registrationNumber == null) return null;
      return _resolveSil(
        registrationNumber: registrationNumber,
        fundName: fundName,
      );
    }

    // Antes de consultar Yahoo/Morningstar, intentamos resolver el fondo
    // contra el catálogo local de FI de la CNMV. El proveedor solo devuelve
    // un resultado cuando la coincidencia es inequívoca; en fondos con varias
    // clases no elegimos una arbitrariamente.
    final cnmvFiResult = await _cnmvLocalFundProvider.resolve(
      fundName: fundName,
    );

    if (cnmvFiResult != null && _isIsin(cnmvFiResult.isin)) {
      print(
        'CNMV FI local: ${cnmvFiResult.fundName}'
        '${cnmvFiResult.compartmentName == null ? '' : ' / ${cnmvFiResult.compartmentName}'}'
        ' / ${cnmvFiResult.fundClass.name}'
        ' -> ${cnmvFiResult.isin}',
      );

      return IsinResult(
        isin: cnmvFiResult.isin.trim().toUpperCase(),
        source: 'CNMV/FI local',
        officialName: cnmvFiResult.fundName,
        cnmvRegistration: cnmvFiResult.registrationNumber,
      );
    }

    return _resolveForeignFund(ticker: normalizedTicker, fundName: fundName);
  }

  /// Intenta resolver fondos no cubiertos por CNMV.
  ///
  /// Un proveedor extranjero nunca se considera autoridad por sí mismo:
  /// el resultado solo se acepta si devuelve un ISIN válido según el
  /// checksum ISIN. Si ningún proveedor puede demostrarlo, devuelve null.
  Future<IsinResult?> _resolveForeignFund({
    required String ticker,
    required String fundName,
  }) async {
    final results = await _searchYahoo(ticker: ticker, fundName: fundName);

    if (results.isEmpty) return null;

    // No nos quedamos con un único resultado de Yahoo. Un mismo nombre puede
    // devolver varias clases del mismo fondo, ETF, acción, etc. Probamos los
    // candidatos por orden de relevancia hasta encontrar un ISIN verificable.
    final rankedResults = _rankYahooResults(results, ticker, fundName);

    for (final yahooMatch in rankedResults) {
      print(
        'Yahoo candidato seleccionado para resolución: '
        '${yahooMatch.symbol} | ${yahooMatch.name}',
      );

      // Yahoo puede proporcionar directamente el ISIN en el resultado de
      // búsqueda. Es la vía más sencilla y no requiere consultar Morningstar.
      final yahooIsin = yahooMatch.isin;
      if (yahooIsin != null && _isIsin(yahooIsin)) {
        print('  Yahoo ISIN directo: $yahooIsin');
        return IsinResult(
          isin: yahooIsin,
          source: 'Yahoo',
          officialName: yahooMatch.name,
        );
      }

      final isin = await _resolveForeignIsin(
        yahooResult: yahooMatch,
        fundName: fundName,
        ticker: ticker,
      );

      if (isin != null) {
        return IsinResult(
          isin: isin,
          source: 'Yahoo/Foreign',
          officialName: yahooMatch.name,
        );
      }
    }

    return null;
  }

  Future<List<_YahooResult>> _searchYahoo({
    required String ticker,
    required String fundName,
  }) async {
    final results = <String, _YahooResult>{};

    for (final query in <String>[ticker, fundName]) {
      try {
        final uri = Uri.parse(_yahooSearchUrl).replace(
          queryParameters: {
            'q': query,
            'quotesCount': '20',
            'newsCount': '0',
            'enableFuzzyQuery': 'false',
          },
        );

        final response = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'OpenInvest/1.0',
          },
        );

        if (response.statusCode != 200) continue;

        final json = jsonDecode(response.body);
        if (json is! Map<String, dynamic>) continue;

        final quotes = json['quotes'];
        if (quotes is! List) continue;

        for (final item in quotes) {
          if (item is! Map) continue;
          final symbol = item['symbol']?.toString();
          if (symbol == null || symbol.isEmpty) continue;

          final yahooIsin = item['isin']?.toString().trim().toUpperCase();

          results[symbol] = _YahooResult(
            symbol: symbol,
            name:
                item['longname']?.toString() ??
                item['shortname']?.toString() ??
                '',
            exchange: item['exchange']?.toString() ?? '',
            type: item['quoteType']?.toString() ?? '',
            isin: yahooIsin != null && _isIsin(yahooIsin) ? yahooIsin : null,
          );
        }
      } catch (e) {
        print('Error Yahoo: $e');
      }
    }

    return results.values.toList();
  }

  List<_YahooResult> _rankYahooResults(
    List<_YahooResult> results,
    String ticker,
    String fundName,
  ) {
    final normalizedTicker = ticker.toUpperCase();

    final scored =
        results
            .map((result) {
              final symbol = result.symbol.toUpperCase();
              final type = result.type.toUpperCase();
              final nameSimilarity = _nameSimilarity(fundName, result.name);
              var score = nameSimilarity * 0.55;

              if (symbol == normalizedTicker) score += 0.20;
              if (symbol.startsWith(normalizedTicker)) score += 0.05;

              if (type == 'MUTUALFUND') {
                score += 0.30;
              } else if (type == 'ETF') {
                score -= 0.20;
              } else if (type == 'EQUITY' || type == 'INDEX') {
                score -= 0.30;
              }

              if (_sameMorningstarId(symbol, normalizedTicker)) score += 0.10;

              // Un ISIN proporcionado por Yahoo es una señal especialmente útil.
              if (result.isin != null) score += 0.10;

              print(
                'Yahoo candidato ${result.symbol}: '
                'score=${score.toStringAsFixed(3)} '
                '| name=${nameSimilarity.toStringAsFixed(3)} '
                '| type=${result.type}'
                '${result.isin == null ? '' : ' | isin=${result.isin}'}',
              );

              return (result: result, score: score);
            })
            .where((item) => item.score >= 0.50)
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));

    return scored.map((item) => item.result).toList();
  }

  bool _sameMorningstarId(String a, String b) {
    String normalize(String value) {
      final match = RegExp(r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$')
          .firstMatch(value.trim().toUpperCase());
      return match?.group(1) ?? value.trim().toUpperCase();
    }

    return normalize(a) == normalize(b);
  }

  Future<String?> _resolveForeignIsin({
    required _YahooResult yahooResult,
    required String fundName,
    required String ticker,
  }) async {
    for (final provider in _foreignIsinProviders) {
      try {
        final isin = await provider.resolve(
          ticker: ticker,
          fundName: fundName,
          yahooSymbol: yahooResult.symbol,
          yahooName: yahooResult.name,
        );

        if (isin == null) continue;
        final normalized = isin.trim().toUpperCase();
        if (_isIsin(normalized)) return normalized;
      } catch (e) {
        print('Error ${provider.runtimeType}: $e');
      }
    }

    return null;
  }

  // --------------------------------------------------------------------------
  // CNMV SIL
  // --------------------------------------------------------------------------

  Future<IsinResult?> _resolveSil({
    required int registrationNumber,
    required String fundName,
  }) async {
    final entities = await _loadCnmvSilIndex();
    final entity = entities[registrationNumber];
    if (entity == null) return null;

    final html = await _getCnmvSociety(entity.nif);
    if (html == null) return null;

    final isin = _extractIsin(html);
    if (isin == null || !_isIsin(isin)) return null;

    return IsinResult(
      isin: isin,
      source: 'CNMV/SIL',
      officialName: entity.name,
      cnmvRegistration: entity.registrationNumber,
      cnmvNif: entity.nif,
    );
  }

  Future<Map<int, _CnmvEntity>> _loadCnmvSilIndex() async {
    if (_cnmvEntities != null) return _cnmvEntities!;

    final entities = <int, _CnmvEntity>{};

    // La CNMV pagina desde page=0 y actualmente este listado tiene 20 páginas.
    // No dependemos de textos como "siguiente", porque la navegación puede
    // cambiar y no forma parte de los datos de las entidades.
    for (var page = 0; page < 20; page++) {
      try {
        final response = await _client.get(
          Uri.parse('$_cnmvListBaseUrl$page'),
          headers: const {
            'Accept': 'text/html',
            'User-Agent': 'OpenInvest/1.0',
          },
        );

        if (response.statusCode != 200) {
          print('CNMV SIL: página $page -> HTTP ${response.statusCode}');
          break;
        }

        final pageEntities = _parseCnmvListPage(response.body);
        print('CNMV SIL: página $page -> ${pageEntities.length} entidades');

        if (pageEntities.isEmpty) break;

        for (final entity in pageEntities) {
          entities[entity.registrationNumber] = entity;
        }
      } catch (e) {
        print('Error CNMV SIL página $page: $e');
        break;
      }
    }

    _cnmvEntities = entities;
    return entities;
  }

  List<_CnmvEntity> _parseCnmvListPage(String html) {
    final entities = <_CnmvEntity>[];

    // El listado actual de la CNMV no utiliza filas <tr>/<td> para las
    // entidades. Cada entidad aparece como un enlace a sociedadiic.aspx
    // seguido del texto "Número y fecha de registro oficial: N ...".
    final anchorPattern = RegExp(
      r"""<a\b[^>]*href\s*=\s*["']([^"']*sociedadiic[^"']*)["'][^>]*>([\s\S]*?)</a>""",
      caseSensitive: false,
    );

    final matches = anchorPattern.allMatches(html).toList();

    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final href = match.group(1) ?? '';
      final name = _cleanHtmlText(match.group(2) ?? '');

      if (name.isEmpty) continue;

      final nextStart = i + 1 < matches.length
          ? matches[i + 1].start
          : html.length;
      final tailEnd = (match.end + 800 < nextStart)
          ? match.end + 800
          : nextStart;
      final tail = html.substring(match.end, tailEnd);

      final registrationNumber = _extractRegistrationNumber(tail);
      if (registrationNumber == null) continue;

      final nif = _extractNifFromUrl(href);

      entities.add(
        _CnmvEntity(
          registrationNumber: registrationNumber,
          name: name,
          nif: nif,
          url: _absoluteCnmvUrl(href),
        ),
      );
    }

    return entities;
  }

  String _extractNifFromUrl(String url) {
    final match = RegExp(
      r"""[?&]nif=([^&#"']+)""",
      caseSensitive: false,
    ).firstMatch(url);

    if (match == null) return '';
    return Uri.decodeComponent(match.group(1)!).trim().toUpperCase();
  }

  int? _extractRegistrationNumber(String html) {
    final text = _cleanHtmlText(html);
    final patterns = <RegExp>[
      RegExp(
        r'(?:N[ºo°]?\s*Registro|Registro\s+oficial)\s*[:\-]?\s*(\d+)',
        caseSensitive: false,
      ),
      RegExp(r'\bSL\s*[-/]?\s*(\d+)\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return int.tryParse(match.group(1)!);
    }

    return null;
  }

  String _extractSocietyUrl(String html) {
    final matches = RegExp(
      //r'href\s*=\s*["\']([^"\']+)["\']',
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html);

    for (final match in matches) {
      final href = match.group(1) ?? '';
      if (href.toLowerCase().contains('sociedadiic')) {
        return _absoluteCnmvUrl(href);
      }
    }

    return '';
  }

  Future<String?> _getCnmvSociety(String nif) async {
    if (nif.isEmpty) return null;

    try {
      final response = await _client.get(
        Uri.parse('$_cnmvSocietyUrl$nif'),
        headers: const {'Accept': 'text/html', 'User-Agent': 'OpenInvest/1.0'},
      );

      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      print('Error CNMV society: $e');
      return null;
    }
  }

  String? _extractIsin(String html) {
    final text = _cleanHtmlText(html);
    final matches = RegExp(
      r'\b([A-Z]{2}[A-Z0-9]{9}\d)\b',
      caseSensitive: false,
    ).allMatches(text);

    for (final match in matches) {
      final isin = match.group(1)!.toUpperCase();
      if (_isIsin(isin)) return isin;
    }

    return null;
  }

  /// Extrae un ISIN que aparezca dentro de una cadena y lo valida.
  ///
  /// Ejemplos:
  ///   LU0297942194-USD.LU -> LU0297942194
  ///   LU0319688791-USD.LU -> LU0319688791
  ///   LU0940716078.LU -> LU0940716078
  String? _extractEmbeddedIsin(String value) {
    final upper = value.toUpperCase();
    final regex = RegExp(r'[A-Z]{2}[A-Z0-9]{9}[0-9]');

    for (final match in regex.allMatches(upper)) {
      final candidate = match.group(0);

      if (candidate != null && _isIsin(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  bool _isIsin(String value) {
    final normalized = value.trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$').hasMatch(normalized)) {
      return false;
    }
    return _isValidIsinChecksum(normalized);
  }

  bool _isValidIsinChecksum(String isin) {
    final value = isin.toUpperCase();
    final digits = <int>[];

    for (final char in value.split('')) {
      if (RegExp(r'[A-Z]').hasMatch(char)) {
        final n = char.codeUnitAt(0) - 55;
        digits.add(n ~/ 10);
        digits.add(n % 10);
      } else {
        digits.add(int.parse(char));
      }
    }

    var sum = 0;
    final parity = digits.length % 2;

    for (var i = 0; i < digits.length; i++) {
      var digit = digits[i];
      if (i % 2 == parity) {
        digit *= 2;
        if (digit > 9) digit = digit ~/ 10 + digit % 10;
      }
      sum += digit;
    }

    return sum % 10 == 0;
  }

  double _nameSimilarity(String a, String b) {
    final aa = _normalizeName(a);
    final bb = _normalizeName(b);
    if (aa.isEmpty || bb.isEmpty) return 0.0;
    if (aa == bb) return 1.0;

    final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();
    final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;

    return ta.intersection(tb).length / ta.union(tb).length;
  }

  String _normalizeName(String value) {
    var result = value.toUpperCase();
    const replacements = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'Ñ': 'N',
      '&': ' ',
      '-': ' ',
      '_': ' ',
      '/': ' ',
      ',': ' ',
      '.': ' ',
      ':': ' ',
      ';': ' ',
      '(': ' ',
      ')': ' ',
    };

    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _cleanHtmlText(String html) {
    var text = html;
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ');
    text = text.replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _absoluteCnmvUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return 'https://www.cnmv.es$url';
    return 'https://www.cnmv.es/$url';
  }

  bool _hasNextPage(String html) {
    final text = _cleanHtmlText(html).toLowerCase();
    return text.contains('siguiente') || text.contains('next');
  }

  /// Libera el cliente HTTP. Se mantiene `void` para conservar la API actual.
  void dispose() => _client.close();
}

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String? isin;

  const _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    this.isin,
  });
}

class _CnmvEntity {
  final int registrationNumber;
  final String name;
  final String nif;
  final String url;

  const _CnmvEntity({
    required this.registrationNumber,
    required this.name,
    required this.nif,
    required this.url,
  });
}

double maxDouble(double a, double b) => a > b ? a : b;
