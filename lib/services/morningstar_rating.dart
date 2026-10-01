import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as parser;
import 'package:http/http.dart' as http;

class MorningstarRatingResult {
  final int? rating;
  final bool succeeded;

  const MorningstarRatingResult({
    required this.rating,
    required this.succeeded,
  });
}

class MorningstarRating {
  final String isin;
  final http.Client _client;
  final bool _ownsClient;

  MorningstarRating(this.isin, {http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  void close() {
    if (_ownsClient) _client.close();
  }

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

  Future<MorningstarRatingResult> fetchRating() async {
    if (isin.isEmpty) {
      return const MorningstarRatingResult(rating: null, succeeded: false);
    }

    final url = 'https://markets.ft.com/data/funds/tearsheet/ratings?s=$isin';
    final document = await _getDoc(url);

    if (document == null) {
      return const MorningstarRatingResult(rating: null, succeeded: false);
    }

    final rating = _parseRating(document);
    return MorningstarRatingResult(
      rating: rating == 0 ? null : rating,
      succeeded: true,
    );
  }

  Future<int> getRating() async => (await fetchRating()).rating ?? 0;
}
