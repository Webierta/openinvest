/* 

/// Interfaz para permitir sustituir la fuente extranjera sin tocar
/// IsinResolver.
abstract class ForeignIsinProvider {
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  });
}
 */
