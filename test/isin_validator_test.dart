import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/isin_validator.dart';

void main() {
  group('IsinValidator Tests', () {
    test('ISINs reales y válidos', () {
      // Ejemplos reales y válidos probados
      expect(IsinValidator.isValid('ES0128581008'), isTrue);
      expect(IsinValidator.isValid('FR0000993172'), isTrue);
      expect(IsinValidator.isValid('IE00B4L5Y983'), isTrue);
    });

    test('ISINs ficticios, malformados e inválidos', () {
      // Nulos y vacíos
      expect(IsinValidator.isValid(null), isFalse);
      expect(IsinValidator.isValid(''), isFalse);
      expect(IsinValidator.isValid('   '), isFalse);

      // Longitud incorrecta
      expect(IsinValidator.isValid('ES012858100'), isFalse);
      expect(IsinValidator.isValid('ES01285810080'), isFalse);

      // Checksum inválido (dígito de control incorrecto)
      expect(IsinValidator.isValid('ES0128581009'), isFalse);
      expect(IsinValidator.isValid('FR0000993170'), isFalse);

      // Caracteres no permitidos / formato incorrecto
      expect(IsinValidator.isValid('123456789012'), isFalse);
      expect(IsinValidator.isValid('ABCDEFGHIJKL'), isFalse);
      expect(IsinValidator.isValid('ES-0128581008'), isFalse);
    });

    test('Normalización de ISIN', () {
      expect(IsinValidator.normalize('es0128581008'), 'ES0128581008');
      expect(IsinValidator.normalize('  fr0000993172 '), 'FR0000993172');
      expect(IsinValidator.normalize('INVALID'), isNull);
      expect(IsinValidator.normalize(null), isNull);
    });
  });
}
