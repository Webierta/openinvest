// =============================================================================
// IsinResolver
// =============================================================================
//
// Motor de resolución de ISIN para OpenInvest.
//
// ENTRADA DEL USUARIO:
//   El usuario proporciona uno de los siguientes datos:
//
//   - ISIN: si el usuario ya conoce el identificador del fondo.
//   - Nombre del fondo: si desea localizar el ISIN correspondiente.
//
//   El motor puede utilizar adicionalmente un ticker o identificador asociado
//   al fondo como dato auxiliar para localizar y verificar la información
//   en fuentes externas. El ticker no constituye necesariamente la entrada
//   principal del usuario.
//
// FLUJO DE RESOLUCIÓN:
//
//   1. ISIN DIRECTO
//      Si el usuario proporciona un ISIN, se valida mediante el algoritmo
//      estándar de checksum ISIN. Si es válido, se devuelve directamente.
//
//   2. IDENTIFICACIÓN DEL FONDO
//      Si se proporciona el nombre del fondo, el motor intenta identificar
//      el fondo utilizando el nombre y, cuando está disponible, su ticker o
//      identificador asociado.
//
//   3. CNMV - FONDOS DE INVERSIÓN ESPAÑOLES
//      Se consulta la información local de la CNMV para identificar fondos,
//      compartimentos y clases españolas.
//
//   4. CNMV - SIL
//      Para Sociedades de Inversión Libre españolas se utiliza el registro
//      de la CNMV y se obtiene el ISIN desde la ficha oficial de la sociedad.
//
//   5. YAHOO FINANCE
//      Si el fondo no se identifica mediante CNMV, se utiliza Yahoo Finance
//      como fuente auxiliar para localizar el instrumento correspondiente.
//
//   6. MORNINGSTAR
//      Cuando Yahoo Finance proporciona un identificador Morningstar, este
//      identificador se utiliza para localizar la información del fondo y
//      obtener su ISIN.
//
//   7. VALIDACIÓN FINAL
//      Todo ISIN obtenido mediante fuentes externas se valida mediante el
//      algoritmo estándar de checksum ISIN antes de ser aceptado.
//
// RESULTADO:
//
//   Si se encuentra un ISIN válido y verificable:
//      -> IsinResult con el ISIN, la fuente utilizada y el nombre oficial
//         cuando está disponible.
//
//   Si no se puede obtener un ISIN suficientemente fiable:
//      -> null.
//
// PRINCIPIO DE SEGURIDAD:
//
//   El motor no intenta adivinar un ISIN. Solo devuelve un resultado cuando
//   puede obtener y validar un ISIN de una fuente o identificación verificable.
//
// =============================================================================

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/foreign_isin_provider.dart';
import 'local_isin_provider.dart';
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

/// Proveedor extranjero basado en la ficha clásica de Morningstar.
///
/// La ruta `lt.morningstar.com` sigue exponiendo una ficha HTML accesible
/// sin API key. Cuando Yahoo devuelve un identificador Morningstar del tipo
/// `0P000xxxxx.F`, podemos consultar directamente el snapshot y leer la
/// variable JavaScript `HoldingIsin`.
///
/// Ejemplos reales comprobados:
///   0P00000FB4 -> FR0010135103
///   0P0000X83M -> IE00B8K7V925
///   0P00006DAB -> LU0261948904
///
/// El proveedor es deliberadamente conservador: solo acepta el ISIN que
/// Morningstar publica explícitamente en `HoldingIsin` y además lo valida con
/// el checksum ISIN. Nunca intenta inferir una clase a partir del nombre.
class MorningstarLtForeignIsinProvider implements ForeignIsinProvider {
  final http.Client client;

  static const String _snapshotBaseUrl =
      'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

  MorningstarLtForeignIsinProvider({http.Client? client})
    : client = client ?? http.Client();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    final morningstarId = _extractMorningstarId(yahooSymbol);

    if (morningstarId == null) {
      _log(
        '  Morningstar LT: Yahoo no contiene un ID Morningstar '
        '($yahooSymbol).',
      );
      return null;
    }

    _log('  Morningstar LT ID: $morningstarId');

    final uri = Uri.parse(_snapshotBaseUrl).replace(
      queryParameters: <String, String>{
        'Id': morningstarId,
        'LanguageId': 'es-ES',
      },
    );

    try {
      final response = await client
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/140.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 15));

      _log('  Morningstar LT GET: HTTP ${response.statusCode}');

      if (response.statusCode != 200) return null;

      final isin = _extractHoldingIsin(response.body);
      if (isin == null) {
        _log(
          '  Morningstar LT: la ficha $morningstarId no contiene '
          'un HoldingIsin válido.',
        );
        return null;
      }

      _log('  Morningstar LT ISIN: $isin');
      return isin;
    } catch (e) {
      _log('  Morningstar LT error: $e');
      return null;
    }
  }

  String? _extractMorningstarId(String value) {
    final match = RegExp(
      r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    return match?.group(1)?.toUpperCase();
  }

  String? _extractHoldingIsin(String html) {
    // Estructura comprobada en lt.morningstar.com:
    //   var PerformanceId = '0P00000FB4';
    //   var HoldingId = '0P00000FB4';
    //   var HoldingIsin='FR0010135103';
    //
    // Buscamos exclusivamente HoldingIsin para no confundirlo con ISINs de
    // benchmarks, documentos, carteras u otros instrumentos del HTML.
    final patterns = <RegExp>[
      RegExp(
        r"""HoldingIsin\s*=\s*['"]([A-Z]{2}[A-Z0-9]{9}\d)['"]""",
        caseSensitive: false,
      ),
      RegExp(
        r"""HoldingIsin\s*:\s*['"]([A-Z]{2}[A-Z0-9]{9}\d)['"]""",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;

      final isin = match.group(1)!.toUpperCase();
      if (_isValidIsin(isin)) return isin;
    }

    return null;
  }

  bool _isValidIsin(String isin) {
    if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$').hasMatch(isin)) {
      return false;
    }

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
}

/// Alias de compatibilidad para código que utilizase el nombre anterior.
/// La implementación real es `MorningstarLtForeignIsinProvider`.
class MorningstarForeignIsinProvider extends MorningstarLtForeignIsinProvider {
  MorningstarForeignIsinProvider({super.client});
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
    /* _foreignIsinProviders =
        foreignIsinProviders ??
        [MorningstarForeignIsinProvider(client: _client)]; */
    _foreignIsinProviders =
        foreignIsinProviders ??
        [
          LocalIsinProvider(),
          MorningstarLtForeignIsinProvider(client: _client),
        ];
  }

  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final normalizedTicker = ticker.trim().toUpperCase();

    _log('');
    _log('------------------------------------------------------------');
    _log('IsinResolver');
    _log('Ticker: $normalizedTicker');
    _log('Nombre: $fundName');
    _log('------------------------------------------------------------');

    // El ticker puede contener un ISIN embebido, por ejemplo:
    //   LU0297942194-USD.LU
    //   LU0319688791-USD.LU
    //   LU0940716078.LU
    //
    // Buscamos una secuencia candidata de 12 caracteres y la validamos
    // con el algoritmo ISIN antes de aceptarla.
    final inputIsin = _extractEmbeddedIsin(normalizedTicker);

    if (inputIsin != null) {
      _log('ISIN detectado en el ticker: $inputIsin');
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

    if (cnmvFiResult != null) {
      _log(
        'CNMV FI local: ${cnmvFiResult.fundName}'
        '${cnmvFiResult.compartmentName == null ? '' : ' / ${cnmvFiResult.compartmentName}'}'
        ' / ${cnmvFiResult.fundClass.name}'
        ' -> ${cnmvFiResult.isin}',
      );

      return IsinResult(
        isin: cnmvFiResult.isin,
        source: 'CNMV/FI local',
        officialName: cnmvFiResult.fundName,
        cnmvRegistration: cnmvFiResult.registrationNumber,
      );
    }

    return _resolveForeignFund(ticker: normalizedTicker, fundName: fundName);
  }

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
      _log(
        'Yahoo candidato seleccionado para resolución: '
        '${yahooMatch.symbol} | ${yahooMatch.name}',
      );

      // Yahoo puede proporcionar directamente el ISIN en el resultado de
      // búsqueda. Es la vía más sencilla y no requiere consultar Morningstar.
      final yahooIsin = yahooMatch.isin;
      if (yahooIsin != null && _isIsin(yahooIsin)) {
        _log('  Yahoo ISIN directo: $yahooIsin');
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
        _log('Error Yahoo: $e');
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

              _log(
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
        _log('Error ${provider.runtimeType}: $e');
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
    if (isin == null) return null;

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
          _log('CNMV SIL: página $page -> HTTP ${response.statusCode}');
          break;
        }

        final pageEntities = _parseCnmvListPage(response.body);
        _log('CNMV SIL: página $page -> ${pageEntities.length} entidades');

        if (pageEntities.isEmpty) break;

        for (final entity in pageEntities) {
          entities[entity.registrationNumber] = entity;
        }
      } catch (e) {
        _log('Error CNMV SIL página $page: $e');
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

  Future<String?> _getCnmvSociety(String nif) async {
    if (nif.isEmpty) return null;

    try {
      final response = await _client.get(
        Uri.parse('$_cnmvSocietyUrl$nif'),
        headers: const {'Accept': 'text/html', 'User-Agent': 'OpenInvest/1.0'},
      );

      return response.statusCode == 200 ? response.body : null;
    } catch (e) {
      _log('Error CNMV society: $e');
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

void _log(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'IsinResolver');
  }
}
