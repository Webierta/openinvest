import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/fund_name_matcher.dart';

void main() {
  group('FundNameMatcher.normalizeName', () {
    test('N1 - convierte a mayúsculas', () {
      expect(
        FundNameMatcher.normalizeName('global equity fund'),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N2 - elimina acentos', () {
      expect(
        FundNameMatcher.normalizeName('Áccénts ÀÉÍÓÚ Ü Ñ'),
        'ACCENTS AEIOU U N',
      );
    });

    test('N3 - convierte ñ en n', () {
      expect(FundNameMatcher.normalizeName('España Gestión'), 'ESPANA GESTION');
    });

    test('N4 - reemplaza ampersand por espacio', () {
      expect(FundNameMatcher.normalizeName('Fund & Income'), 'FUND INCOME');
    });

    test('N5 - reemplaza guion por espacio', () {
      expect(
        FundNameMatcher.normalizeName('Global-Equity-Fund'),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N6 - reemplaza underscore por espacio', () {
      expect(
        FundNameMatcher.normalizeName('Global_Equity_Fund'),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N7 - reemplaza barra por espacio', () {
      expect(
        FundNameMatcher.normalizeName('Global/Equity/Fund'),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N8 - reemplaza puntuación por espacios', () {
      expect(
        FundNameMatcher.normalizeName('Global, Equity. Fund: Class; A'),
        'GLOBAL EQUITY FUND CLASS A',
      );
    });

    test('N9 - reemplaza paréntesis por espacios', () {
      expect(
        FundNameMatcher.normalizeName('Global Equity (Class A)'),
        'GLOBAL EQUITY CLASS A',
      );
    });

    test('N10 - colapsa espacios múltiples', () {
      expect(
        FundNameMatcher.normalizeName('Global    Equity   Fund'),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N11 - elimina espacios iniciales y finales', () {
      expect(
        FundNameMatcher.normalizeName('   Global Equity Fund   '),
        'GLOBAL EQUITY FUND',
      );
    });

    test('N12 - cadena vacía permanece vacía', () {
      expect(FundNameMatcher.normalizeName(''), '');
    });

    test('N13 - combina todas las transformaciones', () {
      expect(
        FundNameMatcher.normalizeName(
          '  Áccénts & España - Global/Equity_(Class A);  ',
        ),
        'ACCENTS ESPANA GLOBAL EQUITY CLASS A',
      );
    });
  });

  group('FundNameMatcher.nameSimilarity', () {
    test('S1 - nombres idénticos devuelven 1.0', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global Equity Fund',
          'Global Equity Fund',
        ),
        1.0,
      );
    });

    test('S2 - diferencias de mayúsculas no afectan', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global Equity Fund',
          'global equity fund',
        ),
        1.0,
      );
    });

    test('S3 - diferencias de acentos no afectan', () {
      expect(
        FundNameMatcher.nameSimilarity('España Gestión', 'ESPANA GESTION'),
        1.0,
      );
    });

    test('S4 - diferencias de puntuación no afectan', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global-Equity Fund',
          'Global Equity Fund',
        ),
        1.0,
      );
    });

    test('S5 - cadenas vacías devuelven 0.0', () {
      expect(FundNameMatcher.nameSimilarity('', 'Global Equity Fund'), 0.0);

      expect(FundNameMatcher.nameSimilarity('Global Equity Fund', ''), 0.0);

      expect(FundNameMatcher.nameSimilarity('', ''), 0.0);
    });

    test('S6 - ningún token común devuelve 0.0', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global Equity Fund',
          'European Bond Portfolio',
        ),
        0.0,
      );
    });

    test('S7 - una coincidencia de tres tokens da 1/5', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL BOND PORTFOLIO',
        ),
        closeTo(1 / 5, 0.000001),
      );
    });

    test('S8 - dos tokens comunes de cuatro distintos da 1/2', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY BOND',
        ),
        closeTo(2 / 4, 0.000001),
      );
    });

    test('S9 - palabras repetidas no aumentan la similitud', () {
      expect(
        FundNameMatcher.nameSimilarity('GLOBAL GLOBAL EQUITY', 'GLOBAL EQUITY'),
        1.0,
      );
    });

    test('S10 - la similitud es simétrica', () {
      final a = 'PIMCO GIS Income E USD Inc';
      final b = 'PIMCO GIS Income Fund E USD Income';

      expect(
        FundNameMatcher.nameSimilarity(a, b),
        FundNameMatcher.nameSimilarity(b, a),
      );
    });

    test('S11 - mismo fondo con formato distinto', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income E USD Inc.',
        ),
        1.0,
      );
    });

    test('S12 - nombre real de fondo con clase añadida', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income E USD Inc',
        'PIMCO GIS Income Fund E USD Income',
      );

      expect(similarity, greaterThan(0.5));
      expect(similarity, lessThan(1.0));
    });

    test('S13 - dos nombres diferentes comparten términos genéricos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'ABC Global Equity Fund',
        'XYZ Global Equity Fund',
      );

      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('S14 - nombre completamente diferente de un fondo real', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income E USD Inc',
        'Carmignac Patrimoine A EUR Acc',
      );

      expect(similarity, 0.0);
    });

    test('S15 - diferencia entre clase y fondo mantiene tokens comunes', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Carmignac Patrimoine A EUR Acc',
        'Carmignac Patrimoine',
      );

      expect(similarity, closeTo(2 / 5, 0.000001));
    });

    test('S16 - nombres completamente iguales tras normalización', () {
      expect(
        FundNameMatcher.nameSimilarity(
          '  Fidelity - Global Equity (A) ',
          'FIDELITY GLOBAL EQUITY A',
        ),
        1.0,
      );
    });

    test('S17 - ampersand y palabra equivalente', () {
      expect(
        FundNameMatcher.nameSimilarity('Fund & Income', 'Fund Income'),
        1.0,
      );
    });

    test('S18 - solo coincide una palabra', () {
      expect(
        FundNameMatcher.nameSimilarity('GLOBAL', 'GLOBAL EQUITY FUND'),
        closeTo(1 / 3, 0.000001),
      );
    });

    test('S19 - el orden de las palabras no importa', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'FUND GLOBAL EQUITY',
        ),
        1.0,
      );
    });

    test('S20 - tokens repetidos se consideran una sola vez', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'GLOBAL GLOBAL GLOBAL EQUITY',
          'GLOBAL EQUITY',
        ),
        1.0,
      );
    });

    test('S21 - combinación de normalización y similitud', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Áccénts-GLOBAL/Equity',
          'ACCENTS GLOBAL EQUITY',
        ),
        1.0,
      );
    });

    test('S22 - una coincidencia parcial no debe ser 1.0', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income',
          'PIMCO GIS Income Fund',
        ),
        lessThan(1.0),
      );
    });

    test('S23 - los nombres con tokens disjuntos dan 0.0', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income',
          'JPMorgan European Bond',
        ),
        0.0,
      );

      expect(
        FundNameMatcher.nameSimilarity(
          'Fidelity Global Equity',
          'Carmignac Patrimoine',
        ),
        0.0,
      );
    });

    test('S24 - la similitud siempre está entre 0 y 1', () {
      final pairs = [
        ('ABC', 'XYZ'),
        ('ABC DEF', 'ABC'),
        ('ABC DEF', 'ABC DEF GHI'),
        ('ABC DEF', 'DEF ABC'),
        ('ABC', 'ABC'),
      ];

      for (final (a, b) in pairs) {
        final similarity = FundNameMatcher.nameSimilarity(a, b);

        expect(similarity, greaterThanOrEqualTo(0.0));
        expect(similarity, lessThanOrEqualTo(1.0));
      }
    });

    test('S25 - caso representativo de Morningstar/CNMV', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'JPMorgan Funds Global Equity',
        'JPMorgan Funds Global Equity A Acc EUR',
      );

      expect(similarity, greaterThan(0.5));
      expect(similarity, lessThan(1.0));
    });
  });
}
