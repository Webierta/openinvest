import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../models/scraper_result.dart';

/// Clase encargada de realizar el scraping de la web de Financial Times.
class FTFundScraper {
  final http.Client _client;
  FTFundScraper({required this._client});

  static const String baseUrl =
      'https://markets.ft.com/data/funds/tearsheet/summary';

  Future<ScraperResult?> scrape(String isin) async {
    if (isin.trim().isEmpty) {
      return null;
    }
    try {
      final uri = Uri.parse('$baseUrl?s=$isin');

      // Se añade un User-Agent completo para emular un navegador real y evitar bloqueos anti-scraping
      final response = await _client.get(
        uri,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.5',
        },
      );

      if (response.statusCode == 200) {
        final html = response.body;
        return _parseHtml(html);
      } else {
        throw Exception('FT respondió con HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error durante el scraping: $e');
    }
  }

  DateTime? _parseFtDate(String rawDate) {
    final normalizedDate = rawDate.trim().replaceAll(',', '');

    for (final pattern in ['MMM d yyyy', 'MMMM d yyyy']) {
      try {
        return DateFormat(pattern, 'en_US').parseStrict(normalizedDate);
      } on FormatException {
        continue;
      }
    }

    return null;
  }

  ScraperResult? _parseHtml(String html) {
    // 1. Nombre del Fondo: Extraído de la etiqueta <title> (ej: "Nombre Fondo - FT.com")
    // Si falla, intenta buscar en la etiqueta <h1> principal.
    String? nombre;
    final titleMatch = RegExp(
      r'<title>([^<]+?)\s*-\s*FT\.com</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      nombre = titleMatch.group(1)!.trim();
    } else {
      final h1Match = RegExp(
        r'<h1[^>]*>([^<]+)</h1>',
        caseSensitive: false,
      ).firstMatch(html);
      if (h1Match != null) {
        nombre = h1Match.group(1)!.trim();
      }
    }
    if (nombre != null) {
      // Limpieza básica de entidades HTML (opcional, pero recomendada)
      nombre = nombre.replaceAll(RegExp(r'&[a-z]+;|&#\d+;'), '').trim();
    }

    // 2. Valor liquidativo y Divisa: Patrón "Price (EUR) 112.10"
    // [^0-9]* permite saltar cualquier etiqueta HTML (como <span>) entre el texto y el número.
    String? valorLiquidativo;
    String? divisa;

    final priceMatch = RegExp(
      r'Price\s*\(\s*([A-Z]{3})\s*\)[^0-9]*([\d,\.]+)',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (priceMatch != null) {
      divisa = priceMatch.group(1)!.trim();
      valorLiquidativo = priceMatch.group(2)!.trim();
    } else {
      // Fallback: buscar la divisa en la tabla de perfil del fondo si el patrón anterior falla
      final currencyTableMatch = RegExp(
        r'Price currency[^>]*>([^<]+)',
        caseSensitive: false,
      ).firstMatch(html);
      if (currencyTableMatch != null) {
        divisa = currencyTableMatch.group(1)!.trim();
      }
    }

    // 3. Fecha: Patrón "as of Oct 05 2026" o "as of Oct 05, 2026"
    String? fecha;
    final dateMatch = RegExp(
      r'as of\s+([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})',
      caseSensitive: false,
    ).firstMatch(html);

    if (dateMatch != null) {
      //fecha = dateMatch.group(1)!.trim();
      final parsedDate = _parseFtDate(dateMatch.group(1)!);
      if (parsedDate != null) {
        fecha = DateFormat('dd/MM/yyyy').format(parsedDate);
      }
    }

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
}
