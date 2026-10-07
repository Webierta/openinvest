import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:html/parser.dart' as html_parser;

import '../models/scraper_result.dart';

class FTFundScraper {
  final http.Client _client;
  FTFundScraper({required this._client});

  static const String baseUrl =
      'https://markets.ft.com/data/funds/tearsheet/summary';

  Future<ScraperResult?> scrape(String isin) async {
    if (isin.trim().isEmpty) return null;

    try {
      // FT acepta tanto el ISIN solo (LU2597552558) como con divisa (LU2597552558:EUR)
      final uri = Uri.parse('$baseUrl?s=$isin');

      final response = await _client
          .get(
            uri,
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
              'Accept-Language': 'en-US,en;q=0.5',
            },
          )
          .timeout(const Duration(seconds: 10)); // Timeout de seguridad

      if (response.statusCode == 200) {
        return _parseHtml(response.body);
      } else {
        throw Exception('FT respondió con HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error durante el scraping: $e');
    }
  }

  ScraperResult? _parseHtml(String html) {
    final document = html_parser.parse(html);

    // 1. NOMBRE: Priorizar el <h1>, que en FT contiene el nombre limpio del fondo.
    String? nombre = document
        .querySelector('h1.mod-tearsheet-overview__header__title')
        ?.text
        .trim();
    nombre ??= document.querySelector('h1')?.text.trim();
    //String? nombre = document.querySelector('h1')?.text.trim();

    // Limpieza de seguridad por si acaso el h1 trajera el sufijo del ISIN (muy raro, pero posible)
    if (nombre != null) {
      nombre = nombre
          .replaceAll(
            RegExp(
              r',\s*[A-Z]{2}\w+:\w+(?:\s+summary)?$',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }

    // FALLBACK: Usar el <title> solo si el <h1> no existe o está vacío
    if (nombre == null || nombre.isEmpty) {
      nombre = document.querySelector('title')?.text;
      if (nombre != null) {
        // Paso A: Eliminar sufijo estándar de FT
        nombre = nombre
            .replaceAll(RegExp(r'\s*-\s*FT\.com\s*$', caseSensitive: false), '')
            .trim();
        // Paso B: Eliminar la parte sucia del título: ", LU2597552558:EUR summary"
        nombre = nombre
            .replaceAll(
              RegExp(
                r',\s*[A-Z]{2}\w+:\w+(?:\s+summary)?$',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
      }
    }

    // 2. PRECIO Y DIVISA: Buscar en el texto plano del body (más seguro que regex en HTML crudo)
    final textContent = document.body?.text ?? '';

    String? valorLiquidativo;
    String? divisa;

    // El HTML real de FT muestra: "Price (EUR)112.10" (a veces sin espacio antes del número)
    final priceMatch = RegExp(r'Price\s*\(\s*([A-Z]{3})\s*\)\s*([\d,\.]+)')
        .firstMatch(textContent);
    if (priceMatch != null) {
      divisa = priceMatch.group(1);
      valorLiquidativo = priceMatch.group(2);
    }

    valorLiquidativo ??= document
        .querySelector(
          '.mod-tearsheet-overview__header__price-list span.mod-ui-data-list__value',
        )
        ?.text
        .trim();

    divisa ??= RegExp(r'\(\s*([A-Z]{3})\s*\)')
        .firstMatch(
          document
              .querySelector(
                '.mod-tearsheet-overview__header__price-list span.mod-ui-data-list__label',
              )!
              .text,
        )
        ?.group(1);

    divisa ??= document
        .querySelector('td[data-wsod-key="Price currency"]')
        ?.text
        .trim();

    // 3. FECHA
    String? fecha;
    final dateMatch = RegExp(
      r'as of\s+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})',
      caseSensitive: false,
    ).firstMatch(textContent);

    if (dateMatch != null) {
      final parsedDate = _parseFtDate(dateMatch.group(1)!);
      if (parsedDate != null) {
        fecha = DateFormat('dd/MM/yyyy').format(parsedDate);
      }
    }

    if (fecha == null) {
      final dateElement = document.querySelector(
        '.mod-tearsheet-overview__header__price-list .mod-ui-data-list__source',
      );
      if (dateElement != null) {
        final dateMatch = RegExp(
          r'as of\s+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})',
          caseSensitive: false,
        ).firstMatch(dateElement.text);

        if (dateMatch != null) {
          final parsedDate = _parseFtDate(dateMatch.group(1)!);
          if (parsedDate != null) {
            fecha = DateFormat('dd/MM/yyyy').format(parsedDate);
          }
        }
      }
    }

    // Validación mínima de éxito: si no encontramos nada, no devolvemos un objeto vacío
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

  DateTime? _parseFtDate(String rawDate) {
    final normalizedDate = rawDate.trim().replaceAll(',', '');
    for (final pattern in ['MMM d yyyy', 'MMMM d yyyy']) {
      try {
        return DateFormat(pattern, 'en_US').parseStrict(normalizedDate);
      } on FormatException {
        continue; // Prueba con el siguiente patrón si este falla
      }
    }
    return null;
  }
}
