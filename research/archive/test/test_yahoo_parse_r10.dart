import 'package:investing/utils/isin_validator.dart';
import 'package:test/test.dart';

/// R10 - Construcción y sanitización de _YahooResult desde JSON Yahoo.
///
/// OBJETIVO
/// --------
/// Validar exclusivamente la transformación de cada elemento del JSON
/// devuelto por Yahoo hacia _YahooResult.
///
/// NO se utiliza YahooProvider.resolve().
///
/// NO se modifica YahooProvider.
///
/// Se reproduce el bloque actual de _searchYahoo():
///
///   final symbol = item['symbol']?.toString();
///   ...
///   final type = item['quoteType']?.toString() ?? '';
///   final yahooIsin = item['isin']?.toString().trim().toUpperCase();
///
///   final incoming = _YahooResult(
///     symbol: symbol,
///     name:
///         item['longname']?.toString() ??
///         item['shortname']?.toString() ??
///         '',
///     exchange: item['exchange']?.toString() ?? '',
///     type: type,
///     isin:
///         (type.toUpperCase() == 'MUTUALFUND' &&
///             yahooIsin != null &&
///             IsinValidator.isValid(yahooIsin))
///         ? yahooIsin
///         : null,
///   );
///
/// ---------------------------------------------------------------------------
/// CASOS
/// ---------------------------------------------------------------------------
///
/// R10.1  longname tiene prioridad sobre shortname.
/// R10.2  si longname no existe, usa shortname.
/// R10.3  si ninguno existe, name = ''.
/// R10.4  symbol se conserva.
/// R10.5  exchange se conserva.
/// R10.6  quoteType se conserva.
/// R10.7  ISIN válido + MUTUALFUND => se acepta.
/// R10.8  ISIN válido + EQUITY => se descarta.
/// R10.9  ISIN válido + ETF => se descarta.
/// R10.10 ISIN inválido + MUTUALFUND => se descarta.
/// R10.11 ISIN con espacios/minúsculas => se normaliza.
/// R10.12 MUTUALFUND en minúsculas => se acepta el ISIN.
/// R10.13 ISIN ausente => null.
/// R10.14 ISIN vacío => null.
/// R10.15 symbol ausente => null (el resultado se descarta).
/// R10.16 campos null => comportamiento seguro.
/// R10.17 ISIN válido + otro tipo => se descarta.
/// R10.18 longname vacío NO hace fallback a shortname (comportamiento actual).
/// R10.19 múltiples quotes se transforman independientemente.
/// R10.20 ISIN válido determinista => IsinValidator lo acepta.
///
/// NOTA
/// ----
/// R10.18 es deliberadamente importante: el código actual usa `??`, no
/// comprobación de string vacío. Por tanto un longname == '' tiene prioridad
/// sobre shortname. El test documenta el comportamiento real actual, no una
/// posible mejora futura.
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

/// Réplica aislada de la construcción actual de _YahooResult dentro de
/// _searchYahoo().
class _YahooParser {
  _YahooResult? parse(Map<String, dynamic> item) {
    final symbol = item['symbol']?.toString();

    // Igual que producción:
    //
    // if (symbol == null || symbol.isEmpty) continue;
    //
    // Aquí devolvemos null para poder observar el comportamiento.
    if (symbol == null || symbol.isEmpty) {
      return null;
    }

    final type = item['quoteType']?.toString() ?? '';

    final yahooIsin = item['isin']?.toString().trim().toUpperCase();

    final incoming = _YahooResult(
      symbol: symbol,
      name: item['longname']?.toString() ?? item['shortname']?.toString() ?? '',
      exchange: item['exchange']?.toString() ?? '',
      type: type,
      isin:
          (type.toUpperCase() == 'MUTUALFUND' &&
              yahooIsin != null &&
              IsinValidator.isValid(yahooIsin))
          ? yahooIsin
          : null,
    );

    return incoming;
  }
}

void _printResult(String testName, _YahooResult? result) {
  print('');
  print('[$testName]');

  if (result == null) {
    print('  RESULTADO : null');
    return;
  }

  print('  SYMBOL     : ${result.symbol}');
  print('  NAME       : ${result.name}');
  print('  EXCHANGE   : ${result.exchange}');
  print('  TYPE       : ${result.type}');
  print('  ISIN       : ${result.isin}');
}

void main() {
  final parser = _YahooParser();

  group('R10 - Construcción y sanitización de _YahooResult', () {
    test('R10.1 - longname tiene prioridad sobre shortname', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'shortname': 'Alpha Growth',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.1', result);

      expect(result, isNotNull);
      expect(result!.name, 'Alpha Growth Fund');
    });

    test('R10.2 - si longname no existe usa shortname', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'shortname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.2', result);

      expect(result, isNotNull);
      expect(result!.name, 'Alpha Growth Fund');
    });

    test('R10.3 - si ninguno existe name = vacío', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.3', result);

      expect(result, isNotNull);
      expect(result!.name, '');
    });

    test('R10.4 - symbol se conserva', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.4', result);

      expect(result, isNotNull);
      expect(result!.symbol, 'XYZ.PA');
    });

    test('R10.5 - exchange se conserva', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.5', result);

      expect(result, isNotNull);
      expect(result!.exchange, 'XPAR');
    });

    test('R10.6 - quoteType se conserva', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.6', result);

      expect(result, isNotNull);
      expect(result!.type, 'MUTUALFUND');
    });

    test('R10.7 - ISIN válido + MUTUALFUND => se acepta', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': 'FR0000000010',
      });

      _printResult('R10.7', result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R10.8 - ISIN válido + EQUITY => se descarta', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth',
        'exchange': 'XPAR',
        'quoteType': 'EQUITY',
        'isin': 'FR0000000010',
      });

      _printResult('R10.8', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.9 - ISIN válido + ETF => se descarta', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth ETF',
        'exchange': 'XPAR',
        'quoteType': 'ETF',
        'isin': 'FR0000000010',
      });

      _printResult('R10.9', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.10 - ISIN inválido + MUTUALFUND => se descarta', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': 'NOT-AN-ISIN',
      });

      _printResult('R10.10', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.11 - ISIN con espacios y minúsculas => se normaliza', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': '  fr0000000010  ',
      });

      _printResult('R10.11', result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R10.12 - MUTUALFUND en minúsculas => acepta ISIN válido', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'mutualfund',
        'isin': 'FR0000000010',
      });

      _printResult('R10.12', result);

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000000010');
    });

    test('R10.13 - ISIN ausente => null', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.13', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.14 - ISIN vacío => null', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': '   ',
      });

      _printResult('R10.14', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.15 - symbol ausente => resultado descartado', () {
      final result = parser.parse({
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': 'FR0000000010',
      });

      _printResult('R10.15', result);

      expect(result, isNull);
    });

    test('R10.16 - campos null => comportamiento seguro', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': null,
        'shortname': null,
        'exchange': null,
        'quoteType': null,
        'isin': null,
      });

      _printResult('R10.16', result);

      expect(result, isNotNull);
      expect(result!.name, '');
      expect(result.exchange, '');
      expect(result.type, '');
      expect(result.isin, isNull);
    });

    test('R10.17 - ISIN válido + otro tipo => se descarta', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth',
        'exchange': 'XPAR',
        'quoteType': 'INDEX',
        'isin': 'FR0000000010',
      });

      _printResult('R10.17', result);

      expect(result, isNotNull);
      expect(result!.isin, isNull);
    });

    test('R10.18 - longname vacío NO hace fallback a shortname', () {
      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': '',
        'shortname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
      });

      _printResult('R10.18', result);

      //
      // Comportamiento actual:
      //
      // item['longname']?.toString() ??
      // item['shortname']?.toString() ??
      // ''
      //
      // Como longname existe y es '', el operador ?? NO pasa
      // a shortname.
      //
      expect(result, isNotNull);
      expect(result!.name, '');
    });

    test('R10.19 - múltiples quotes se transforman independientemente', () {
      final quotes = [
        {
          'symbol': 'AAA.PA',
          'longname': 'Alpha Growth Fund',
          'exchange': 'XPAR',
          'quoteType': 'MUTUALFUND',
          'isin': 'FR0000000010',
        },
        {
          'symbol': 'BBB.PA',
          'shortname': 'Beta Growth Fund',
          'exchange': 'XPAR',
          'quoteType': 'MUTUALFUND',
          'isin': 'FR0000000028',
        },
        {
          'symbol': 'CCC.PA',
          'longname': 'Gamma ETF',
          'exchange': 'XPAR',
          'quoteType': 'ETF',
          'isin': 'FR0000000010',
        },
      ];

      final results = quotes
          .map(parser.parse)
          .whereType<_YahooResult>()
          .toList();

      print('');
      print('[R10.19]');
      print('  RESULTADOS : ${results.length}');

      for (final result in results) {
        print('  $result');
      }

      expect(results.length, 3);

      expect(results[0].symbol, 'AAA.PA');
      expect(results[0].isin, 'FR0000000010');

      expect(results[1].symbol, 'BBB.PA');
      expect(results[1].name, 'Beta Growth Fund');
      expect(results[1].isin, 'FR0000000028');

      expect(results[2].symbol, 'CCC.PA');
      expect(results[2].isin, isNull);
    });

    test('R10.20 - ISIN válido determinista => IsinValidator lo acepta', () {
      const isin = 'FR0000000010';

      expect(IsinValidator.isValid(isin), isTrue);

      final result = parser.parse({
        'symbol': 'XYZ.PA',
        'longname': 'Alpha Growth Fund',
        'exchange': 'XPAR',
        'quoteType': 'MUTUALFUND',
        'isin': isin,
      });

      _printResult('R10.20', result);

      expect(result, isNotNull);
      expect(result!.isin, isin);
    });
  });
}
