import 'package:test/test.dart';

/// R8 - Validación específica de la fusión de resultados Yahoo por symbol.
///
/// OBJETIVO
/// --------
/// Validar EXCLUSIVAMENTE la lógica de fusión de dos observaciones Yahoo
/// correspondientes al mismo symbol.
///
/// Este test NO utiliza YahooProvider.resolve(), porque ese método continúa
/// después de la fusión hacia:
///
///   _rankYahooResults()
///       -> _resolveForeignIsin()
///       -> IsinResult
///
/// y eso impediría observar directamente los campos internos de la fusión.
///
/// Por tanto, este fichero reproduce AISLADAMENTE la lógica actual de
/// _mergeYahooResult() de YahooProvider.
///
/// NO modifica YahooProvider.
///
/// Casos:
///   R8.1  Mejor nombre
///   R8.2  ISIN solo en ticker
///   R8.3  ISIN solo en nombre
///   R8.4  Mismo ISIN en ambas respuestas
///   R8.5  ISIN conflictivos
///   R8.6  Prioridad MUTUALFUND
///   R8.7  Conservación de exchange
///   R8.8  Symbol solo en ticker
///   R8.9  Symbol solo en nombre
///   R8.10 Fusión sucesiva estable
///   R8.11 Conflicto de ISIN no resuelto por nombre
///
/// ---------------------------------------------------------------------------
/// IMPORTANTE
/// ---------------------------------------------------------------------------
/// La lógica de _mergeYahooResult() que se reproduce aquí es la actual:
///
///   name     -> _chooseBestName()
///   exchange -> existing si no está vacío; si no incoming
///   type     -> _chooseBestType()
///   isin     ->
///       - uno null      -> conserva el otro
///       - ambos iguales -> conserva el ISIN
///       - diferentes    -> null
///
/// Si este test pasa 11/11, tendremos validada la lógica de fusión
/// independientemente del ranking y de la resolución de ISIN.
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

/// Réplica aislada de la lógica actual de YahooProvider.
///
/// Se mantiene deliberadamente con la misma estructura y reglas que
/// _mergeYahooResult(), _chooseBestName() y _chooseBestType().
class _YahooMergeLogic {
  _YahooResult merge(
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
      // Hay dos ISIN distintos para el mismo symbol.
      // No elegimos arbitrariamente ninguno.
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
    if (existing.trim().isEmpty) return incoming;
    if (incoming.trim().isEmpty) return existing;

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

    if (existingType.isEmpty) return incoming;
    if (incomingType.isEmpty) return existing;

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

    if (aa.isEmpty || bb.isEmpty) return 0.0;
    if (aa == bb) return 1.0;

    final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();

    final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();

    if (ta.isEmpty || tb.isEmpty) return 0.0;

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

void _printResult(String testName, _YahooResult result) {
  print('');
  print('[$testName]');
  print('  SYMBOL     : ${result.symbol}');
  print('  NAME       : ${result.name}');
  print('  EXCHANGE   : ${result.exchange}');
  print('  TYPE       : ${result.type}');
  print('  ISIN       : ${result.isin}');
}

void main() {
  final merge = _YahooMergeLogic();

  group('R8 - Fusión de resultados Yahoo por symbol', () {
    test('R8.1 - mismo symbol + nombres diferentes => conserva el nombre más parecido', () {
      final result = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Bond',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.1', result);

      expect(result.name, 'Alpha Growth Fund');
    });

    test('R8.2 - mismo symbol + ISIN solo en ticker => conserva ISIN', () {
      final result = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: null,
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.2', result);

      expect(result.isin, 'FR0000000010');
    });

    test(
      'R8.3 - mismo symbol + ISIN solo en consulta por nombre => conserva ISIN',
      () {
        final result = merge.merge(
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          'Alpha Growth Fund',
        );

        _printResult('R8.3', result);

        expect(result.isin, 'FR0000000010');
      },
    );

    test(
      'R8.4 - mismo symbol + mismo ISIN en ambas consultas => conserva ISIN',
      () {
        final result = merge.merge(
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund Class A',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          'Alpha Growth Fund',
        );

        _printResult('R8.4', result);

        expect(result.isin, 'FR0000000010');
      },
    );

    test('R8.5 - mismo symbol + ISIN diferentes => NO elegir ninguno', () {
      final result = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund Class A',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000028',
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.5', result);

      expect(result.isin, isNull);
    });

    test('R8.6 - mismo symbol + MUTUALFUND en una respuesta y EQUITY en otra => MUTUALFUND', () {
      final result = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'EQUITY',
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.6', result);

      expect(result.type, 'MUTUALFUND');
    });

    test('R8.7 - mismo symbol + exchange vacío en una respuesta => conserva exchange válido', () {
      final result = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: '',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.7', result);

      expect(result.exchange, 'XPAR');
    });

    /* test(
      'R8.8 - symbol presente solo en consulta por ticker => se conserva',
      () {
        final result = merge.merge(
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          _quote(
            symbol: 'OTHER.PA',
            name: 'Other Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
          'Alpha Growth Fund',
        );

        _printResult('R8.8', result);

        expect(result.symbol, 'XYZ.PA');
        expect(result.isin, 'FR0000000010');
      },
    ); */

    /* test(
      'R8.9 - symbol presente solo en consulta por nombre => se conserva',
      () {
        final result = merge.merge(
          _quote(
            symbol: 'OTHER.PA',
            name: 'Other Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: null,
          ),
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          'Alpha Growth Fund',
        );

        _printResult('R8.9', result);

        //
        // Nota:
        // Este caso comprueba el comportamiento de una observación
        // individual. La incorporación en el Map de _searchYahoo()
        // se produce antes de _mergeYahooResult().
        //
        expect(result.symbol, 'OTHER.PA');

        // Al fusionar dos symbols diferentes, la lógica real de
        // _mergeYahooResult() conserva existing.symbol.
        //
        // Este test NO pretende validar el Map de _searchYahoo().
        // Por ello el comportamiento esperado aquí es explícito:
        expect(result.symbol, 'OTHER.PA');
      },
    ); */

    test('R8.10 - mismo symbol repetido con dos nombres y un ISIN => fusión estable', () {
      final firstMerge = merge.merge(
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Bond',
          exchange: '',
          type: 'EQUITY',
          isin: null,
        ),
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        'Alpha Growth Fund',
      );

      final finalResult = merge.merge(
        firstMerge,
        _quote(
          symbol: 'XYZ.PA',
          name: 'Alpha Growth Fund Class A',
          exchange: 'XPAR',
          type: 'MUTUALFUND',
          isin: 'FR0000000010',
        ),
        'Alpha Growth Fund',
      );

      _printResult('R8.10', finalResult);

      expect(finalResult.symbol, 'XYZ.PA');
      expect(finalResult.name, 'Alpha Growth Fund');
      expect(finalResult.exchange, 'XPAR');
      expect(finalResult.type, 'MUTUALFUND');
      expect(finalResult.isin, 'FR0000000010');
    });

    test(
      'R8.11 - conflicto de ISIN no debe ser resuelto por el mejor nombre',
      () {
        final result = merge.merge(
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000010',
          ),
          _quote(
            symbol: 'XYZ.PA',
            name: 'Alpha Growth Fund Class A',
            exchange: 'XPAR',
            type: 'MUTUALFUND',
            isin: 'FR0000000028',
          ),
          'Alpha Growth Fund',
        );

        _printResult('R8.11', result);

        // El nombre más parecido NO debe decidir qué ISIN conservar.
        expect(result.name, 'Alpha Growth Fund');

        expect(result.isin, isNull);
      },
    );
  });
}

/* ### Una corrección importante antes de ejecutarlo

He dejado R8.8/R8.9 como casos de **observación individual**, pero esto revela que no debemos intentar probar la lógica del `Map<String, _YahooResult>` mediante `merge()`.

Por tanto, **R8.9 tal como está arriba no es un buen test de `_searchYahoo()`**. Prefiero corregirlo ahora antes de que lo ejecutes: R8 debería centrarse únicamente en `_mergeYahooResult()`, y los casos de “solo aparece en una consulta” pertenecen realmente a `_searchYahoo()`.

Así que mi recomendación es **eliminar R8.8 y R8.9 de este test** y dejar R8 en **9 pruebas puras de fusión**, para después preparar un R9 específico de la acumulación `Map<symbol, result>`.

Si quieres mantener exactamente el objetivo original de R8, ejecuta primero el fichero anterior; pero **para una batería limpia y metodológicamente correcta, haría esa separación antes de continuar**.
 */
