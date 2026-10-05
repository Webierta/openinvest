class IsinSearchQuery {
  static final RegExp _format = RegExp(r'^[A-Z]{2}[A-Z0-9]{3,10}$');
  static final RegExp _hasDigit = RegExp(r'\d');

  static String normalize(String query) =>
      query.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static String? prefix(String query) {
    final normalized = normalize(query);
    if (!_format.hasMatch(normalized) ||
        !_hasDigit.hasMatch(normalized.substring(2))) {
      return null;
    }
    return normalized;
  }
}
