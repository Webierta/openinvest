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

/// Servicio principal para resolver ISIN de fondos.
///
/// Estrategia, por orden de fiabilidad:
/// 1. ISIN explícito/embebido en el ticker.
/// 2. Sociedades de inversión libre (SIL) mediante registro CNMV.
/// 3. Fondos de inversión (FI) mediante el catálogo local CNMV.
/// 4. Yahoo Finance para identificar fondos extranjeros y, si Yahoo entrega
///    un ISIN válido, utilizarlo directamente.
/// 5. Proveedores extranjeros inyectados explícitamente.
///
/// Los proveedores extranjeros son opcionales. Por defecto no se utiliza
/// ningún proveedor que dependa de scraping, WAF, API keys o servicios
/// autenticados. Si no existe evidencia suficiente, `resolve()` devuelve null.
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
        foreignIsinProviders ?? const <ForeignIsinProvider>[];
  }

  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final normalizedTicker = ticker.trim().toUpperCase();
    final normalizedFundName = fundName.trim();

    if (normalizedTicker.isEmpty && normalizedFundName.isEmpty) return null;

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
        officialName: normalizedFundName,
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
        fundName: normalizedFundName,
      );
    }

    // Antes de consultar Yahoo/Morningstar, intentamos resolver el fondo
    // contra el catálogo local de FI de la CNMV. El proveedor solo devuelve
    // un resultado cuando la coincidencia es inequívoca; en fondos con varias
    // clases no elegimos una arbitrariamente.
    var cnmvFiResult;
    try {
      cnmvFiResult = await _cnmvLocalFundProvider.resolve(
        fundName: normalizedFundName,
      );
    } catch (e) {
      print('Error CNMV FI local: $e');
    }

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

    return _resolveForeignFund(
      ticker: normalizedTicker,
      fundName: normalizedFundName,
    );
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

    // Si Yahoo devuelve exactamente el ticker solicitado con un ISIN válido,
    // es una evidencia directa y preferible a cualquier heurística de nombre.
    final exactYahoo = results.where(
      (r) => r.symbol.trim().toUpperCase() == ticker.trim().toUpperCase(),
    );
    for (final yahooMatch in exactYahoo) {
      final directIsin = yahooMatch.isin;
      if (directIsin != null && _isIsin(directIsin)) {
        print('  Yahoo ISIN directo para ticker exacto: $directIsin');
        return IsinResult(
          isin: directIsin,
          source: 'Yahoo',
          officialName: yahooMatch.name,
        );
      }
    }

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

        final response = await _client
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent': 'OpenInvest/1.0',
              },
            )
            .timeout(const Duration(seconds: 15));

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
    Map<int, _CnmvEntity> entities;
    try {
      entities = await _loadCnmvSilIndex();
    } catch (e) {
      print('Error CNMV SIL índice: $e');
      return null;
    }
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
        final response = await _client
            .get(
              Uri.parse('$_cnmvListBaseUrl$page'),
              headers: const {
                'Accept': 'text/html',
                'User-Agent': 'OpenInvest/1.0',
              },
            )
            .timeout(const Duration(seconds: 15));

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
      final response = await _client
          .get(
            Uri.parse('$_cnmvSocietyUrl$nif'),
            headers: const {
              'Accept': 'text/html',
              'User-Agent': 'OpenInvest/1.0',
            },
          )
          .timeout(const Duration(seconds: 15));

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
