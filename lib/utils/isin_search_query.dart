import 'isin_validator.dart';

class IsinSearchQuery {
  static const int _minimumPrefixLength = 5;
  static final RegExp _partialFormat = RegExp(r'^[A-Z]{2}[A-Z0-9]{3,9}$');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String normalize(String query) =>
      query.toUpperCase().replaceAll(RegExp(r'[\s-]+'), '');

  static String? prefix(String query) {
    final normalized = normalize(query);

    // Un ISIN completo solo se acepta si pasa formato y checksum.
    if (normalized.length == 12) {
      return IsinValidator.isValid(normalized) ? normalized : null;
    }

    // Los prefijos tienen de 5 a 11 caracteres: dos letras de país,
    // seguidas de caracteres alfanuméricos, y al menos un dígito.
    if (normalized.length < _minimumPrefixLength ||
        !_partialFormat.hasMatch(normalized) ||
        !_hasDigit.hasMatch(normalized.substring(2))) {
      return null;
    }

    return normalized;
  }
}
