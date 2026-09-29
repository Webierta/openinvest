import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

// TODO: Incluir rating en FundData y en DatabaseService (upgrade version)
// TODO: Establecer lógica para actualizar rating cada 3 meses.

class MorningstarRating {
  final String isin;
  final http.Client _client;

  MorningstarRating(this.isin, {http.Client? client})
    : _client = client ?? http.Client(); // o http.Client()

  int _parseRating(Document document) {
    try {
      final candidates = document
          .getElementsByTagName('span')
          .where(
            (element) =>
                element.attributes['data-mod-stars-highlighted'] == 'true',
          );

      for (final candidate in candidates) {
        final rating = candidate.getElementsByTagName('i').length;

        if (rating >= 1 && rating <= 5) {
          return rating;
        }
      }
    } catch (e) {
      debugPrint('Error parsing Morningstar rating: $e');
    }

    return 0;
  }

  Future<Document?> _getDoc(String url) async {
    try {
      final response = await _client
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'text/html,application/xhtml+xml',
              'User-Agent': 'OpenInvest/1.0',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return parser.parse(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching Morningstar rating: $e');
    }

    return null;
  }

  Future<int> getRating() async {
    if (isin.isEmpty) return 0;

    final url = 'https://markets.ft.com/data/funds/tearsheet/ratings?s=$isin';
    final document = await _getDoc(url);

    if (document == null) return 0;

    return _parseRating(document);
  }
}
