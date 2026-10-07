/* import 'package:http/http.dart' as http;

import '../../utils/http_config.dart';
import '../../utils/isin_validator.dart';
import '../isin_resolver.dart';
import '../quefondos_scraper.dart';
import 'isin_source_provider.dart';

class QueFondosProvider implements IsinSourceProvider {
  final http.Client _client;
  final QueFondosScraper _scraper;
  final bool _ownsClient;

  factory QueFondosProvider({http.Client? client}) {
    final ownsClient = client == null;
    final sharedClient = client ?? http.Client();

    return QueFondosProvider._(client: sharedClient, ownsClient: ownsClient);
  }

  QueFondosProvider._({required http.Client client, required this._ownsClient})
    : _client = client,
      _scraper = QueFondosScraper(client: client);

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    final result = await resolve(ticker: ticker, fundName: fundName);

    return result == null ? const [] : [result];
  }

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final isin = _extractIsin(ticker);
    if (isin == null) return null;

    try {
      final result = await _scraper.scrape(isin).timeout(HttpConfig.timeout);
      if (result == null) return null;

      return IsinResult(
        isin: isin,
        source: 'QueFondos',
        officialName: result.nombre,
      );
    } catch (_) {
      return null;
    }
  }

  String? _extractIsin(String value) {
    final normalized = value.toUpperCase();
    final candidates = RegExp(r'[A-Z]{2}[A-Z0-9]{9}[0-9]')
        .allMatches(normalized);

    for (final candidate in candidates) {
      final isin = candidate.group(0)!;
      if (IsinValidator.isValid(isin)) return isin;
    }

    return null;
  }
}
 */
