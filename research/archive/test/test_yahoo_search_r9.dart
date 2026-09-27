import 'dart:convert';

import 'package:test/test.dart';

/// R9 - Acumulación y deduplicación de resultados Yahoo.
///
/// OBJETIVO
/// --------
/// Validar exclusivamente el comportamiento de _searchYahoo():
///
///   1. Ejecutar una consulta por ticker.
///   2. Ejecutar una consulta por nombre.
///   3. Acumular los resultados en Map<String, _YahooResult>.
///   4. Deduplicar por symbol.
///   5. Fusionar observaciones repetidas mediante _mergeYahooResult().
///
/// NO se utiliza YahooProvider.resolve(), porque después de _searchYahoo()
/// intervienen _rankYahooResults() y _resolveForeignIsin().
///
/// NO modifica YahooProvider.
///
/// ---------------------------------------------------------------------------
/// CASOS
/// ---------------------------------------------------------------------------
///
/// R9.1  Dos consultas realmente se ejecutan.
/// R9.2  Mismo symbol en ambas consultas => un solo resultado.
/// R9.3  Symbol solo en ticker => se conserva.
/// R9.4  Symbol solo en nombre => se conserva.
/// R9.5  Tres symbols distintos => tres resultados.
/// R9.6  La segunda consulta aporta un ISIN al mismo symbol.
/// R9.7  ISIN conflictivo => null.
/// R9.8  La segunda consulta aporta el mejor nombre.
/// R9.9  Deduplicación exclusivamente por symbol.
/// R9.10 El número final coincide con el número de symbols únicos.

class _YahooResult {
  final String symbol;
  final String name;
  final String exchange;
  final String type;
  final String? isin;

  const _YahooResult({
    required this.symbol,
    required this.name,
    required this.exchange,
    required this.type,
    this.isin,
  });

  @override
  String toString() {
    return '_YahooResult('
        'symbol=$symbol, '
        'name=$name, '
        'exchange=$exchange, '
        'type=$type, '
        'isin=$isin'
        ')';
  }
}

/// Implementación aislada del algoritmo de acumulación utilizado por
/// _searchYahoo().
///
/// La estructura importante es:
///
///   final results = <String, _YahooResult>{};
///
/// y para cada quote:
///
///   final existing = results[symbol];
///
///   if (existing == null) {
///     results[symbol] = incoming;
///   } else {
///     results[symbol] = _mergeYahooResult(...);
///   }
///
/// Las dos listas representan respectivamente:
///
///   1. respuesta de Yahoo para ticker
///   2. respuesta de Yahoo para fundName
class _YahooSearchAccumulator {
  final Map<String, _YahooResult> _results = <String, _YahooResult>{};

  int tickerQueryCount = 0;
  int nameQueryCount = 0;

  void addTickerResults(List<_YahooResult> quotes, String fundName) {
    tickerQueryCount++;
    _addQuotes(quotes, fundName);
  }

  void addNameResults(List<_YahooResult> quotes, String fundName) {
    nameQueryCount++;
    _addQuotes(quotes, fundName);
  }

  void _addQuotes(List<_YahooResult> quotes, String fundName) {
    for (final incoming in quotes) {
      final symbol = incoming.symbol;

      if (symbol.isEmpty) {
        continue;
      }

      final existing = _results[symbol];

      if (existing == null) {
        _results[symbol] = incoming;
      } else {
        _results[symbol] = _mergeYahooResult(existing, incoming, fundName);
      }
    }
  }

  List<_YahooResult> get results => _results.values.toList();

  _YahooResult _mergeYahooResult(
    _YahooResult existing,
    _YahooResult incoming,
    String fundName,
  ) {
    final name = _chooseBestName(existing.name, incoming.name, fundName);

    final exchange = existing.exchange.trim().isNotEmpty
        ? existing.exchange
        : incoming.exchange;

    final type = _chooseBestType(existing.type, incoming.type);

    final existingIsin = existing.isin;
    final incomingIsin = incoming.isin;

    String? isin;

    if (existingIsin == null) {
      isin = incomingIsin;
    } else if (incomingIsin == null) {
      isin = existingIsin;
    } else if (existingIsin == incomingIsin) {
      isin = existingIsin;
    } else {
      isin = null;
    }

    return _YahooResult(
      symbol: existing.symbol,
      name: name,
      exchange: exchange,
      type: type,
      isin: isin,
    );
  }

  String _chooseBestName(String existing, String incoming, String fundName) {
    if (existing.trim().isEmpty) {
      return incoming;
    }

    if (incoming.trim().isEmpty) {
      return existing;
    }

    final existingSimilarity = _nameSimilarity(fundName, existing);

    final incomingSimilarity = _nameSimilarity(fundName, incoming);

    if (incomingSimilarity > existingSimilarity) {
      return incoming;
    }

    return existing;
  }

  String _chooseBestType(String existing, String incoming) {
    final existingType = existing.trim().toUpperCase();

    final incomingType = incoming.trim().toUpperCase();

    if (existingType.isEmpty) {
      return incoming;
    }

    if (incomingType.isEmpty) {
      return existing;
    }

    if (existingType == incomingType) {
      return existing;
    }

    if (existingType == 'MUTUALFUND') {
      return existing;
    }

    if (incomingType == 'MUTUALFUND') {
      return incoming;
    }

    return existing;
  }

  double _nameSimilarity(String a, String b) {
    final aa = _normalizeName(a);
    final bb = _normalizeName(b);

    if (aa.isEmpty || bb.isEmpty) {
      return 0.0;
    }

    if (aa == bb) {
      return 1.0;
    }

    final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();

    final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();

    if (ta.isEmpty || tb.isEmpty) {
      return 0.0;
    }

    return ta.intersection(tb).length / ta.union(tb).length;
  }

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
}

_YahooResult _quote({
  required String symbol,
  required String name,
  required String exchange,
  required String type,
  String? isin,
}) {
  return _YahooResult(
    symbol: symbol,
    name: name,
    exchange: exchange,
    type: type,
    isin: isin,
  );
}

void _printResults(String testName, List<_YahooResult> results) {
  print('');
  print('[$testName]');
  print('  RESULTADOS : ${results.length}');

  for (final result in results) {
    print('  ----------------------------------------');
    print('  SYMBOL     : ${result.symbol}');
    print('  NAME       : ${result.name}');
    print('  EXCHANGE   : ${result.exchange}');
    print('  TYPE       : ${result.type}');
    print('  ISIN       : ${result.isin}');
  }
}

void main() {
  group('R9 - Acumulación y deduplicación de _searchYahoo()', () {
    test('R9.1 - se ejecutan las dos consultas', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      expect(accumulator.tickerQueryCount, 1);

      expect(accumulator.nameQueryCount, 1);

      expect(accumulator.results.length, 1);
    });

    test('R9.2 - mismo symbol en ambas consultas => un solo resultado', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Bond',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.2', results);

      expect(results.length, 1);
      expect(results.single.symbol, 'XYZ.PA');
      expect(results.single.name, 'Alpha Growth Fund');
    });

    test('R9.3 - symbol solo en ticker => se conserva', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'ONLYTICKER.PA',
          name: 'Ticker Only Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults(const [], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.3', results);

      expect(results.length, 1);
      expect(results.single.symbol, 'ONLYTICKER.PA');
      expect(results.single.isin, 'FR0000000010');
    });

    test('R9.4 - symbol solo en nombre => se conserva', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults(const [], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'ONLYNAME.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.4', results);

      expect(results.length, 1);
      expect(results.single.symbol, 'ONLYNAME.PA');
      expect(results.single.isin, 'FR0000000010');
    });

    test('R9.5 - tres symbols distintos => tres resultados', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'AAA.PA',
          name: 'Alpha Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'BBB.PA',
          name: 'Beta Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'CCC.PA',
          name: 'Gamma Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Fund');

      final results = accumulator.results;

      _printResults('R9.5', results);

      expect(results.length, 3);

      expect(results.map((r) => r.symbol).toSet(), {
        'AAA.PA',
        'BBB.PA',
        'CCC.PA',
      });
    });

    test('R9.6 - la segunda consulta aporta un ISIN al mismo symbol', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.6', results);

      expect(results.length, 1);
      expect(results.single.isin, 'FR0000000010');
    });

    test('R9.7 - ISIN conflictivo => null', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000028',
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.7', results);

      expect(results.length, 1);
      expect(results.single.isin, isNull);
    });

    test('R9.8 - la segunda consulta aporta el mejor nombre', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Bond',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.8', results);

      expect(results.length, 1);
      expect(results.single.name, 'Alpha Growth Fund');
    });

    test('R9.9 - deduplicación exclusivamente por symbol', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
      ], 'Alpha Growth Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'XYZ.PA',
          name: 'Completely Different Display Name',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: null,
        ),
      ], 'Alpha Growth Fund');

      final results = accumulator.results;

      _printResults('R9.9', results);

      //
      // El nombre puede cambiar por la fusión, pero el symbol
      // es la clave de deduplicación.
      //
      expect(results.length, 1);
      expect(results.single.symbol, 'XYZ.PA');
    });

    test('R9.10 - número final = número de symbols únicos', () {
      final accumulator = _YahooSearchAccumulator();

      accumulator.addTickerResults([
        _quote(
          symbol: 'AAA.PA',
          name: 'Alpha Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'BBB.PA',
          name: 'Beta Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'CCC.PA',
          name: 'Gamma Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Fund');

      accumulator.addNameResults([
        _quote(
          symbol: 'AAA.PA',
          name: 'Alpha Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'BBB.PA',
          name: 'Beta Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'DDD.PA',
          name: 'Delta Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
      ], 'Alpha Fund');

      final results = accumulator.results;

      _printResults('R9.10', results);

      //
      // Symbols únicos:
      //
      // AAA.PA
      // BBB.PA
      // CCC.PA
      // DDD.PA
      //
      expect(results.length, 4);

      expect(results.map((r) => r.symbol).toSet().length, results.length);
    });
  });
}

/* Ejecútalo con:

```bash
dart test research/archive/test/test_yahoo_search_r9.dart
```

### Qué nos interesa especialmente del resultado

Si obtenemos **10/10**, habremos validado:

```text
Yahoo ticker ─────┐
                  ├──> Map<symbol, _YahooResult> ──> resultados únicos
Yahoo fundName ───┘
                         │
                         └── mismo symbol → _mergeYahooResult()
```

Y entonces podremos pasar a revisar el siguiente aspecto de `_searchYahoo()`: **la construcción del `_YahooResult` a partir del JSON de Yahoo**, especialmente las reglas de `longname/shortname`, `quoteType`, `isin` y la validación del ISIN antes de almacenarlo.
 */
