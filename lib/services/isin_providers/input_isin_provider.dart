import '../isin_resolver.dart';
import 'isin_source_provider.dart';

class InputIsinProvider implements IsinSourceProvider {
  final String? Function(String) _extractEmbeddedIsin;

  InputIsinProvider({required String? Function(String) extractEmbeddedIsin})
    : _extractEmbeddedIsin = extractEmbeddedIsin;

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final inputIsin = _extractEmbeddedIsin(ticker);
    if (inputIsin != null) {
      return IsinResult(
        isin: inputIsin,
        source: 'INPUT',
        officialName: fundName,
      );
    }
    return null;
  }
}
