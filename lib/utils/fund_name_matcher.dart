class FundNameMatcher {
  FundNameMatcher._();

  static double nameSimilarity(String a, String b) {
    final aa = normalizeName(a);
    final bb = normalizeName(b);

    if (aa.isEmpty || bb.isEmpty) return 0.0;
    if (aa == bb) return 1.0;

    final ta = aa.split(' ').where((x) => x.isNotEmpty).toSet();
    final tb = bb.split(' ').where((x) => x.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;

    return ta.intersection(tb).length / ta.union(tb).length;
  }

  static String normalizeName(String value) {
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

      // Apóstrofes: se eliminan para preservar el token.
      "'": '',
      '’': '',

      // Separadores adicionales.
      '&': ' ',
      '+': ' ',
      '-': ' ',
      '_': ' ',
      '/': ' ',
      '=': ' ',
      ',': ' ',
      '.': ' ',
      ':': ' ',
      ';': ' ',
      '(': ' ',
      ')': ' ',
      '[': ' ',
      ']': ' ',
      '{': ' ',
      '}': ' ',
    };

    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool matchesAllTokens(String query, String candidateName) {
    final normalizedQuery = normalizeName(query);
    final queryTokens = normalizedQuery
        .split(' ')
        .where((token) => token.length >= 2)
        .toList();

    if (queryTokens.isEmpty) return false;

    final normalizedCandidate = normalizeName(candidateName);

    // Todos los tokens de la consulta deben aparecer como palabras completas en el candidato
    return queryTokens.every((qt) => normalizedCandidate.contains(qt));
  }
}
