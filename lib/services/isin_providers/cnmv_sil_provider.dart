import 'package:http/http.dart' as http;
import '../isin_resolver.dart';
import '../../utils/http_config.dart';
import 'isin_source_provider.dart';

class CnmvSilProvider implements IsinSourceProvider {
  final http.Client _client;
  Map<int, _CnmvEntity>? _cnmvEntities;

  static const String _cnmvListBaseUrl =
      'https://www.cnmv.es/portal/consultas/mostrarlistados'
      '?id=5&lang=es&page=';

  static const String _cnmvSocietyUrl =
      'https://www.cnmv.es/portal/consultas/iic/sociedadiic?nif=';

  CnmvSilProvider({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final silMatch = RegExp(
      r'^SL(\d+)\.MC$',
      caseSensitive: false,
    ).firstMatch(ticker);

    if (silMatch == null) return null;

    final registrationNumber = int.tryParse(silMatch.group(1)!);
    if (registrationNumber == null) return null;

    return _resolveSil(registrationNumber: registrationNumber, fundName: fundName);
  }

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
    var page = 0;

    while (true) {
      try {
        final response = await _client
            .get(
              Uri.parse('$_cnmvListBaseUrl$page'),
              headers: const {
                'Accept': 'text/html',
                'User-Agent': 'OpenInvest/1.0',
              },
            )
            .timeout(HttpConfig.timeout);

        if (response.statusCode != 200) break;

        final pageEntities = _parseCnmvListPage(response.body);
        if (pageEntities.isEmpty) break;

        for (final entity in pageEntities) {
          entities[entity.registrationNumber] = entity;
        }

        page++;
      } catch (_) {
        break;
      }
    }

    _cnmvEntities = entities;
    return entities;
  }

  List<_CnmvEntity> _parseCnmvListPage(String html) {
    final entities = <_CnmvEntity>[];
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
      final response = await _client
          .get(
            Uri.parse('$_cnmvSocietyUrl$nif'),
            headers: const {'Accept': 'text/html', 'User-Agent': 'OpenInvest/1.0'},
          )
          .timeout(HttpConfig.timeout);

      return response.statusCode == 200 ? response.body : null;
    } catch (_) {
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
