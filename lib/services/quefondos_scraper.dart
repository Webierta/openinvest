import 'dart:convert';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/scraper_result.dart';

// scrape: Obtiene nombre, VL, fecha y divisa a partir de ISIN
// scrapeVdos: Obtiene categoria y rating VDOS a partir de ISIN
class QueFondosScraper {
  final http.Client _client;
  final bool _ownsClient;

  QueFondosScraper({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

  static const String _baseUrl =
      'https://www1.quefondos.com/m/es/fondos/ficha/index.html';

  Future<http.Response?> _getResponse(String isin) async {
    if (isin.trim().isEmpty) return null;

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
        return response;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<ScraperResult?> scrape(String isin) async {
    final response = await _getResponse(isin);
    if (response == null) return null;
    try {
      final html = utf8.decode(response.bodyBytes);
      return _parseHtml(html);
    } catch (e) {
      return null;
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
    //   Fecha 20/06/2024
    // y posteriormente:
    //   Fecha: 20/06/2024
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
    if (match == null) return null;
    return _clean(match.group(1));
  }

  String? _clean(String? value) {
    if (value == null) return null;
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
    if (result.isEmpty) return null;
    return result;
  }

  Future<({String? category, int? rating})> scrapeVdos(String isin) async {
    final response = await _getResponse(isin);
    if (response == null) return (category: null, rating: null);
    String? categoryName;
    int? ratingNumber;

    try {
      // 1. Parsear el HTML
      final document = html_parser.parse(response.body);

      // 2. Extraer Categoría VDOS
      final labelCategory = document
          .querySelectorAll('*')
          .where((e) => e.children.isEmpty)
          .where((e) => e.text.trim().toLowerCase() == 'categoría vdos:')
          .firstOrNull;
      categoryName = labelCategory?.nextElementSibling?.nextElementSibling?.text
          .trim();

      // 3. Extraer Rating VDOS
      final sub = document.querySelector('sub.print.star');
      String? rating = sub?.text.trim();
      if (rating != null && rating.isNotEmpty) {
        ratingNumber = int.tryParse(rating);
      }

      if (ratingNumber == null) {
        final labelRating = document
            .querySelectorAll('*')
            .where((e) => e.children.isEmpty)
            .where((e) => e.text.trim().toLowerCase() == 'rating vdos:')
            .firstOrNull;
        String? ratingVdos = labelRating?.nextElementSibling?.text.trim();

        if (ratingVdos != null && ratingVdos.isNotEmpty) {
          ratingNumber = int.tryParse(ratingVdos);
        }

        if (ratingNumber == null) {
          String? ratingImg = labelRating?.nextElementSibling
              ?.querySelector('img')
              ?.classes
              .first;
          if (ratingImg != null && ratingImg.isNotEmpty) {
            String rating = ratingImg[ratingImg.length - 1];
            ratingNumber = int.tryParse(rating);
          }
        }
      }

      return (category: categoryName, rating: ratingNumber);
    } catch (e) {
      return (category: categoryName, rating: ratingNumber);
    }
  }
}
