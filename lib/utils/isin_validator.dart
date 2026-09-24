/// Utilidad común para validar identificadores ISIN.
///
/// Implementa:
///   - validación de formato ISIN
///   - cálculo estándar del dígito de control mediante Luhn
///
/// Ejemplo:
///
///   if (IsinValidator.isValid('ES0128581008')) {
///     ...
///   }
///
/// Todos los proveedores de ISIN de OpenInvest deben utilizar esta clase
/// en lugar de implementar su propia validación.
class IsinValidator {
  IsinValidator._();

  static final RegExp _format = RegExp(r'^[A-Z]{2}[A-Z0-9]{9}\d$');

  /// Devuelve true si [isin] tiene formato ISIN válido y su dígito de
  /// control es correcto.
  static bool isValid(String? isin) {
    if (isin == null) return false;

    final normalized = isin.trim().toUpperCase();

    if (!_format.hasMatch(normalized)) {
      return false;
    }

    final digits = <int>[];

    // Convertimos las letras a sus valores numéricos:
    //
    // A = 10
    // B = 11
    // ...
    // Z = 35
    //
    // Después aplicamos el algoritmo Luhn sobre la secuencia resultante.
    for (final char in normalized.split('')) {
      final code = char.codeUnitAt(0);

      if (code >= 65 && code <= 90) {
        final value = code - 55;
        digits.add(value ~/ 10);
        digits.add(value % 10);
      } else {
        digits.add(int.parse(char));
      }
    }

    var sum = 0;
    final parity = digits.length % 2;

    for (var i = 0; i < digits.length; i++) {
      var digit = digits[i];

      if (i % 2 == parity) {
        digit *= 2;

        if (digit > 9) {
          digit = digit ~/ 10 + digit % 10;
        }
      }

      sum += digit;
    }

    return sum % 10 == 0;
  }

  /// Devuelve el ISIN normalizado o null si no tiene un formato válido.
  ///
  /// Este método NO sustituye a [isValid]. Solo normaliza el texto.
  static String? normalize(String? isin) {
    if (isin == null) return null;

    final normalized = isin.trim().toUpperCase();

    return _format.hasMatch(normalized) ? normalized : null;
  }
}
