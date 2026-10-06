import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/isin_search_query.dart';

void main() {
  group('IsinSearchQuery.normalize', () {
    test('N1 - convierte a mayúsculas', () {
      expect(IsinSearchQuery.normalize('es0160483014'), 'ES0160483014');
    });

    test('N2 - elimina espacios', () {
      expect(IsinSearchQuery.normalize('ES016048 3014'), 'ES0160483014');
    });

    test('N3 - elimina guiones', () {
      expect(IsinSearchQuery.normalize('ES016048-3014'), 'ES0160483014');
    });

    test('N4 - elimina separadores múltiples', () {
      expect(IsinSearchQuery.normalize(' ES-0160 4830-14 '), 'ES0160483014');
    });

    test('N5 - NO elimina otros caracteres no alfanuméricos', () {
      expect(IsinSearchQuery.normalize('ES0160/483014'), 'ES0160/483014');
    });

    test('N6 - cadena vacía permanece vacía', () {
      expect(IsinSearchQuery.normalize(''), '');
    });

    test('N7 - espacios solamente producen cadena vacía', () {
      expect(IsinSearchQuery.normalize('   '), '');
    });

    test('N8 - no elimina letras ni dígitos válidos', () {
      expect(IsinSearchQuery.normalize('LU0129445192'), 'LU0129445192');
    });
  });

  group('IsinSearchQuery.prefix', () {
    test('P1 - reconoce un ISIN completo válido', () {
      expect(IsinSearchQuery.prefix('ES0160483014'), 'ES0160483014');
    });

    test('P2 - reconoce un ISIN completo en minúsculas', () {
      expect(IsinSearchQuery.prefix('es0160483014'), 'ES0160483014');
    });

    test('P3 - reconoce un ISIN completo con separadores', () {
      expect(IsinSearchQuery.prefix('ES016048-3014'), 'ES0160483014');
    });

    test('P4 - reconoce un prefijo ISIN con dígitos', () {
      expect(IsinSearchQuery.prefix('ES0160483'), 'ES0160483');
    });

    test('P5 - reconoce un prefijo corto con estructura ISIN', () {
      expect(IsinSearchQuery.prefix('ES016'), 'ES016');
    });

    test('P6 - reconoce un prefijo con letras y dígitos', () {
      expect(IsinSearchQuery.prefix('LU0A1'), 'LU0A1');
    });

    test('P7 - normaliza un prefijo con separadores', () {
      expect(IsinSearchQuery.prefix('es-0160-483'), 'ES0160483');
    });

    test('P8 - rechaza texto normal', () {
      expect(IsinSearchQuery.prefix('AXONIC INCOME'), isNull);
    });

    test('P9 - rechaza un nombre de fondo sin dígitos', () {
      expect(IsinSearchQuery.prefix('ESFONDO'), isNull);
    });

    test('P10 - rechaza solamente el código de país', () {
      expect(IsinSearchQuery.prefix('ES'), isNull);
    });

    test('P11 - rechaza una cadena de un solo carácter', () {
      expect(IsinSearchQuery.prefix('E'), isNull);
    });

    test('P12 - rechaza números sin código de país', () {
      expect(IsinSearchQuery.prefix('160483'), isNull);
    });

    test('P13 - rechaza letras sin estructura ISIN', () {
      expect(IsinSearchQuery.prefix('ABCDEF'), isNull);
    });

    test('P14 - un ISIN válido de otro país también es ISIN', () {
      expect(IsinSearchQuery.prefix('IE00B8K7V925'), 'IE00B8K7V925');
    });

    test(
      'P15 - no clasifica un nombre que casualmente empieza por dos letras',
      () {
        expect(IsinSearchQuery.prefix('AXONIC'), isNull);
      },
    );
  });

  group('IsinSearchQuery - invariantes del contrato', () {
    test('C1 - normalización es estable', () {
      const input = ' ES016048-3014 ';

      final first = IsinSearchQuery.normalize(input);
      final second = IsinSearchQuery.normalize(first);

      expect(second, first);
    });

    test('C2 - un ISIN completo normalizado conserva su valor', () {
      const isin = 'ES0160483014';

      expect(IsinSearchQuery.prefix(IsinSearchQuery.normalize(isin)), isin);
    });

    test('C3 - el resultado siempre está normalizado', () {
      final result = IsinSearchQuery.prefix('es016048-3014');

      expect(result, 'ES0160483014');
      expect(result, isNot(contains('-')));
      expect(result, isNot(contains(' ')));
    });

    test('C4 - la consulta de nombre no se convierte en ISIN', () {
      const queries = [
        'AXONIC',
        'AXONIC INCOME',
        'ING DINAMICO',
        'PIMCO GIS INCOME',
      ];

      for (final query in queries) {
        expect(IsinSearchQuery.prefix(query), isNull, reason: query);
      }
    });
  });
}
