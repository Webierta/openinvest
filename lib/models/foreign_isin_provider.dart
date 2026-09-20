abstract class ForeignIsinProvider {
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  });
}

/// Proveedor que todavía no tiene una implementación concreta.
///
/// Lo dejamos como punto de extensión para:
/// - fuente oficial de la gestora
/// - base pública de fondos
/// - otra fuente que descubramos posteriormente
class NullForeignIsinProvider implements ForeignIsinProvider {
  const NullForeignIsinProvider();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    return null;
  }
}
