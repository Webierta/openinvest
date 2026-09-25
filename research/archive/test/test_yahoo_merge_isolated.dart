import 'package:test/test.dart';

void main() {
  group('YahooResult merge - pruebas aisladas', () {
    // =========================================================================
    // 1. ISIN: uno informado y otro null
    // =========================================================================

    test('conserva el ISIN informado cuando el otro es null', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.symbol, 'FUND.PA');
      expect(merged.isin, 'FR0010135103');
    });

    // =========================================================================
    // 2. ISIN: ambos iguales
    // =========================================================================

    test('conserva el mismo ISIN cuando ambos resultados lo tienen', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.isin, 'FR0010135103');
    });

    // =========================================================================
    // 3. ISIN: conflicto
    // =========================================================================

    test('detecta conflicto de ISIN y no lo resuelve silenciosamente', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0000993172',
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      // En caso de conflicto no elegimos arbitrariamente un ISIN.
      expect(merged.isin, isNull);
      expect(merged.isinConflict, isTrue);
      expect(
        merged.conflictingIsins,
        containsAll(['FR0010135103', 'FR0000993172']),
      );
    });

    // =========================================================================
    // 4. NOMBRE: uno es mucho más parecido al nombre buscado
    // =========================================================================

    test('elige el nombre más adecuado al fundName', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'ABC Asset Management Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.name, 'My Fund');
    });

    // =========================================================================
    // 5. TYPE: uno vacío
    // =========================================================================

    test('conserva el type informado cuando el otro está vacío', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: '',
        isin: null,
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.type, 'MUTUALFUND');
    });

    // =========================================================================
    // 6. TYPE: MUTUALFUND vs ETF
    // =========================================================================

    test('conserva MUTUALFUND frente a ETF cuando el resto es equivalente', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'ETF',
        isin: null,
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.type, 'MUTUALFUND');
    });

    // =========================================================================
    // 7. CASO REAL MYFUND.PA
    // =========================================================================

    test('caso real MYFUND.PA: ETF + MUTUALFUND con ISIN', () {
      final tickerSearch = _YahooResult(
        symbol: 'MYFUND.PA',
        name: 'My Fund ETF',
        exchange: 'PAR',
        type: 'ETF',
        isin: null,
      );

      final nameSearch = _YahooResult(
        symbol: 'MYFUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final merged = _mergeYahooResult(tickerSearch, nameSearch, 'My Fund');

      expect(merged.symbol, 'MYFUND.PA');
      expect(merged.name, 'My Fund');
      expect(merged.type, 'MUTUALFUND');
      expect(merged.isin, 'FR0010135103');
      expect(merged.isinConflict, isFalse);
    });

    // =========================================================================
    // 8. TICKER SEARCH + NAME SEARCH
    // =========================================================================

    test('fusiona correctamente resultados de ticker y nombre', () {
      final tickerResult = _YahooResult(
        symbol: '0P0000X83M.F',
        name: 'PIMCO GIS Income Fund E Class USD Inc',
        exchange: 'FRA',
        type: 'MUTUALFUND',
        isin: null,
      );

      final nameResult = _YahooResult(
        symbol: '0P0000X83M.F',
        name: 'PIMCO GIS Income Fund E Class USD Income',
        exchange: 'FRA',
        type: 'MUTUALFUND',
        isin: 'IE00B8K7V925',
      );

      final merged = _mergeYahooResult(
        tickerResult,
        nameResult,
        'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(merged.symbol, '0P0000X83M.F');
      expect(merged.type, 'MUTUALFUND');
      expect(merged.isin, 'IE00B8K7V925');
      expect(merged.name, 'PIMCO GIS Income Fund E Class USD Income');
    });

    // =========================================================================
    // 9. DUPLICADOS DENTRO DE UNA MISMA RESPUESTA
    // =========================================================================

    test('fusiona duplicados procedentes de la misma respuesta Yahoo', () {
      final first = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final second = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final merged = _mergeYahooResult(first, second, 'My Fund');

      expect(merged.isin, 'FR0010135103');
      expect(merged.name, 'My Fund');
      expect(merged.type, 'MUTUALFUND');
    });

    // =========================================================================
    // 10. NO PERDER INFORMACIÓN
    // =========================================================================

    test('un resultado posterior no destruye información válida', () {
      final existing = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final incoming = _YahooResult(
        symbol: 'FUND.PA',
        name: '',
        exchange: '',
        type: '',
        isin: null,
      );

      final merged = _mergeYahooResult(existing, incoming, 'My Fund');

      expect(merged.name, 'My Fund');
      expect(merged.exchange, 'PAR');
      expect(merged.type, 'MUTUALFUND');
      expect(merged.isin, 'FR0010135103');
    });

    // =========================================================================
    // 11. EL ORDEN DE LLEGADA NO DEBE DESTRUIR LA INFORMACIÓN
    // =========================================================================

    test('la fusión es equivalente independientemente del orden', () {
      final a = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: null,
      );

      final b = _YahooResult(
        symbol: 'FUND.PA',
        name: 'My Fund Investment Fund',
        exchange: 'PAR',
        type: 'MUTUALFUND',
        isin: 'FR0010135103',
      );

      final ab = _mergeYahooResult(a, b, 'My Fund');
      final ba = _mergeYahooResult(b, a, 'My Fund');

      expect(ab.name, ba.name);
      expect(ab.type, ba.type);
      expect(ab.isin, ba.isin);
    });
  });
}

// =============================================================================
// MODELO AISLADO
// =============================================================================

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String? isin;

  final bool isinConflict;
  final List<String> conflictingIsins;

  const _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    required this.isin,
    this.isinConflict = false,
    this.conflictingIsins = const [],
  });

  _YahooResult copyWith({
    String? name,
    String? exchange,
    String? type,
    String? isin,
    bool clearIsin = false,
    bool? isinConflict,
    List<String>? conflictingIsins,
  }) {
    return _YahooResult(
      symbol: symbol,
      name: name ?? this.name,
      exchange: exchange ?? this.exchange,
      type: type ?? this.type,
      isin: clearIsin ? null : (isin ?? this.isin),
      isinConflict: isinConflict ?? this.isinConflict,
      conflictingIsins: conflictingIsins ?? this.conflictingIsins,
    );
  }
}

// =============================================================================
// FUSIÓN
// =============================================================================

_YahooResult _mergeYahooResult(
  _YahooResult existing,
  _YahooResult incoming,
  String fundName,
) {
  if (existing.symbol != incoming.symbol) {
    throw ArgumentError(
      'No se pueden fusionar símbolos diferentes: '
      '${existing.symbol} != ${incoming.symbol}',
    );
  }

  // ---------------------------------------------------------------------------
  // ISIN
  // ---------------------------------------------------------------------------

  final existingIsin = existing.isin?.trim().toUpperCase();
  final incomingIsin = incoming.isin?.trim().toUpperCase();

  String? mergedIsin;
  var isinConflict = false;

  final conflictingIsins = <String>{
    ...existing.conflictingIsins,
    ...incoming.conflictingIsins,
  };

  if (existingIsin != null &&
      existingIsin.isNotEmpty &&
      incomingIsin != null &&
      incomingIsin.isNotEmpty &&
      existingIsin != incomingIsin) {
    // Conflicto explícito: no elegimos arbitrariamente.
    isinConflict = true;
    conflictingIsins.add(existingIsin);
    conflictingIsins.add(incomingIsin);
    mergedIsin = null;
  } else if (existingIsin != null && existingIsin.isNotEmpty) {
    mergedIsin = existingIsin;
  } else if (incomingIsin != null && incomingIsin.isNotEmpty) {
    mergedIsin = incomingIsin;
  }

  // ---------------------------------------------------------------------------
  // NAME
  // ---------------------------------------------------------------------------

  final existingName = existing.name.trim();
  final incomingName = incoming.name.trim();

  final name = _chooseBestName(existingName, incomingName, fundName);

  // ---------------------------------------------------------------------------
  // TYPE
  // ---------------------------------------------------------------------------

  final type = _chooseBestType(existing.type, incoming.type);

  // ---------------------------------------------------------------------------
  // EXCHANGE
  // ---------------------------------------------------------------------------

  final exchange = existing.exchange.trim().isNotEmpty
      ? existing.exchange
      : incoming.exchange;

  return _YahooResult(
    symbol: existing.symbol,
    name: name,
    exchange: exchange,
    type: type,
    isin: mergedIsin,
    isinConflict:
        isinConflict || existing.isinConflict || incoming.isinConflict,
    conflictingIsins: conflictingIsins.toList()..sort(),
  );
}

// =============================================================================
// ELECCIÓN DEL NOMBRE
// =============================================================================

String _chooseBestName(String existing, String incoming, String fundName) {
  if (existing.isEmpty) return incoming;
  if (incoming.isEmpty) return existing;

  final existingSimilarity = _nameSimilarity(fundName, existing);

  final incomingSimilarity = _nameSimilarity(fundName, incoming);

  if (incomingSimilarity > existingSimilarity) {
    return incoming;
  }

  return existing;
}

// =============================================================================
// ELECCIÓN DEL TYPE
// =============================================================================

String _chooseBestType(String existing, String incoming) {
  final a = existing.trim().toUpperCase();
  final b = incoming.trim().toUpperCase();

  if (a.isEmpty) return incoming;
  if (b.isEmpty) return existing;

  if (a == b) return existing;

  // Preferencia conservadora para la naturaleza del instrumento.
  //
  // MUTUALFUND es especialmente relevante para OpenInvest porque estamos
  // resolviendo fondos de inversión.
  if (a == 'MUTUALFUND') return existing;
  if (b == 'MUTUALFUND') return incoming;

  return existing;
}

// =============================================================================
// SIMILITUD DE NOMBRES
// =============================================================================

double _nameSimilarity(String a, String b) {
  final aa = _normalizeName(a);
  final bb = _normalizeName(b);

  if (aa.isEmpty || bb.isEmpty) return 0.0;
  if (aa == bb) return 1.0;

  final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();

  final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();

  if (ta.isEmpty || tb.isEmpty) return 0.0;

  return ta.intersection(tb).length / ta.union(tb).length;
}

// =============================================================================
// NORMALIZACIÓN
// =============================================================================

String _normalizeName(String value) {
  var result = value.toUpperCase();

  const replacements = <String, String>{
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'Ñ': 'N',
    '&': ' ',
    '-': ' ',
    '_': ' ',
    '/': ' ',
    ',': ' ',
    '.': ' ',
    ':': ' ',
    ';': ' ',
    '(': ' ',
    ')': ' ',
  };

  replacements.forEach((from, to) => result = result.replaceAll(from, to));

  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}
