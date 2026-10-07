import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scraper_result.dart';

/* class QueFondosResult {
  final String? nombre;
  final String? valorLiquidativo;
  final String? fecha;
  final String? divisa;

  const QueFondosResult({
    this.nombre,
    this.valorLiquidativo,
    this.fecha,
    this.divisa,
  });

  @override
  String toString() {
    return 'QueFondosResult('
        'nombre: $nombre, '
        'valorLiquidativo: $valorLiquidativo, '
        'fecha: $fecha, '
        'divisa: $divisa'
        ')';
  }
} */

// Obtiene nombre, VL, fecha y divisa a partir de ISIN
class QueFondosScraper {
  final http.Client _client;
  QueFondosScraper({required this._client});

  static const String _baseUrl =
      'https://www1.quefondos.com/m/es/fondos/ficha/index.html';

  Future<ScraperResult?> scrape(String isin) async {
    if (isin.trim().isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {'isin': isin});

      final response = await _client.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      );

      if (response.statusCode == 200) {
        final html = utf8.decode(response.bodyBytes);
        return _parseHtml(html);
      } else {
        throw Exception('QueFondos respondió con HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error durante el scraping: $e');
    }
  }

  ScraperResult? _parseHtml(String html) {
    // Eliminamos saltos de línea y espacios que dificultan
    // las expresiones regulares.
    final normalized = html
        .replaceAll(RegExp(r'\r?\n'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    final visibleText =
        _clean(normalized.replaceAll(RegExp(r'<[^>]*>'), ' ')) ?? '';

    // ------------------------------------------------------------
    // Nombre del fondo
    // ------------------------------------------------------------
    final nombre = _extract(
      normalized,
      RegExp(r'<h2[^>]*>\s*(.*?)\s*</h2>', caseSensitive: false),
    );

    // ------------------------------------------------------------
    // Valor liquidativo
    //
    // Ejemplo:
    // Valor liquidativo: 0,000010 EUR
    // ------------------------------------------------------------
    final valorLiquidativo = _extract(
      visibleText,
      RegExp(r'Valor\s+liquidativo:\s*([0-9.,]+)', caseSensitive: false),
    );

    // ------------------------------------------------------------
    // Fecha
    //
    // Hay dos fechas en la página:
    //
    //   Fecha 20/06/2024
    //
    // y posteriormente:
    //
    //   Fecha: 20/06/2024
    //
    // Nos interesa la fecha de la última valoración.
    // ------------------------------------------------------------
    final fecha =
        _extract(
          visibleText,
          RegExp(
            r'Última\s+valoración.*?Fecha:\s*'
            r'([0-9]{2}/[0-9]{2}/[0-9]{4})',
            caseSensitive: false,
          ),
        ) ??
        _extract(
          visibleText,
          RegExp(
            r'Valor\s+liquidativo:.*?'
            r'Fecha:\s*([0-9]{2}/[0-9]{2}/[0-9]{4})',
            caseSensitive: false,
          ),
        );

    // ------------------------------------------------------------
    // Divisa
    //
    // Ejemplo:
    // Divisa: EUR
    // ------------------------------------------------------------
    final divisa = _extract(
      visibleText,
      RegExp(r'Divisa:\s*([A-Z]{3})', caseSensitive: false),
    );

    // Si no hemos encontrado absolutamente nada,
    // probablemente no sea una página de fondo válida.
    if (nombre == null &&
        valorLiquidativo == null &&
        fecha == null &&
        divisa == null) {
      return null;
    }

    return ScraperResult(
      nombre: nombre,
      valorLiquidativo: valorLiquidativo,
      fecha: fecha,
      divisa: divisa,
    );
  }

  String? _extract(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);

    if (match == null) {
      return null;
    }

    return _clean(match.group(1));
  }

  String? _clean(String? value) {
    if (value == null) {
      return null;
    }

    var result = value;

    // Entidades HTML básicas.
    result = result
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');

    // Elimina cualquier etiqueta HTML residual.
    result = result.replaceAll(RegExp(r'<[^>]*>'), '');

    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }
}
