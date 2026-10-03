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

    test(
      'LF-8.1.1 - espacios y separadores equivalentes producen identidad',
      () {
        expect(
          FundNameMatcher.nameSimilarity(
            'PIMCO   GIS - Income / E USD Inc',
            'PIMCO GIS Income E USD Inc',
          ),
          1.0,
        );
      },
    );

    test('LF-8.1.2 - puntuación distinta no altera los tokens', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'JPMorgan Funds, Global Equity - A',
          'JPMorgan Funds Global Equity A',
        ),
        1.0,
      );
    });

    test('LF-8.1.3 - reordenación múltiple de tokens mantiene identidad', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND A',
          'A FUND GLOBAL EQUITY',
        ),
        1.0,
      );
    });

    test('LF-8.1.4 - añadir un único token reduce pero no anula similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL EQUITY FUND INCOME',
      );

      expect(similarity, closeTo(0.75, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test(
      'LF-8.1.5 - eliminar un único token reduce pero conserva similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND INCOME',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.000001));
        expect(similarity, lessThan(1.0));
      },
    );

    test('LF-8.1.6 - conjuntos de tokens completamente distintos dan cero', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME USD',
          'JPMORGAN EUROPEAN BOND EUR',
        ),
        0.0,
      );
    });
    test('LF-8.2.1 - misma gestora pero producto diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Global Bond Fund',
      );

      expect(similarity, closeTo(0.5, 0.000001));
    });

    test('LF-8.2.2 - mismo producto pero clase diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund E Class USD Income',
        'PIMCO GIS Income Fund E Class EUR Income',
      );

      expect(similarity, greaterThan(0.7));
      expect(similarity, lessThan(1.0));
    });

    test('LF-8.2.3 - diferencia de divisa reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund USD',
        'Global Equity Fund EUR',
      );

      expect(similarity, closeTo(0.6, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test('LF-8.2.4 - diferencia geográfica evita identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'European Equity Fund',
        'US Equity Fund',
      );

      expect(similarity, closeTo(0.5, 0.000001));
    });

    test('LF-8.2.5 - diferencia de estrategia evita similitud alta', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund Conservative',
        'Global Equity Fund Aggressive',
      );

      expect(similarity, closeTo(0.6, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test('LF-8.2.6 - nombres muy parecidos pero con producto diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Sustainable Equity Fund',
        'Global Sustainable Bond Fund',
      );

      expect(similarity, closeTo(0.6, 0.000001));
      expect(similarity, lessThan(1.0));
    });
    test('LF-8.3.1 - añadir token de clase mantiene similitud alta pero no identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Income Fund Institutional',
      );

      expect(similarity, closeTo(0.8, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test('LF-8.3.2 - repetir un token no modifica la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD',
        'PIMCO GIS Income Fund USD Income',
      );

      expect(similarity, 1.0);
    });

    test(
      'LF-8.3.3 - diferencia entre acumulación y distribución es detectable',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund USD Acc',
          'Global Equity Fund USD Inc',
        );

        expect(similarity, closeTo(0.666667, 0.000001));
        expect(similarity, lessThan(1.0));
      },
    );

    test('LF-8.3.4 - una variante numérica no produce identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund I',
        'Global Equity Fund II',
      );

      expect(similarity, closeTo(0.6, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test(
      'LF-8.3.5 - diferencia de serie mantiene similitud pero evita identidad',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'European Equity Fund A',
          'European Equity Fund B',
        );

        expect(similarity, closeTo(0.6, 0.000001));
        expect(similarity, lessThan(1.0));
      },
    );

    test('LF-8.3.6 - producto con token distintivo no alcanza identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Select Fund',
      );

      expect(similarity, closeTo(0.75, 0.000001));
      expect(similarity, lessThan(1.0));
    });

    test('LF-8.4.1 - apóstrofe no debe alterar la identidad del nombre', () {
      expect(
        FundNameMatcher.nameSimilarity(
          "Schroder's Global Equity Fund",
          'Schroders Global Equity Fund',
        ),
        1.0,
      );
    });

    test(
      'LF-8.4.2 - signo más como separador no debe alterar la identidad',
      () {
        expect(
          FundNameMatcher.nameSimilarity(
            'Global Equity + Income Fund',
            'Global Equity Income Fund',
          ),
          1.0,
        );
      },
    );

    test('LF-8.4.3 - corchetes no deben alterar la identidad', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global Equity Fund [Class A]',
          'Global Equity Fund Class A',
        ),
        1.0,
      );
    });

    test('LF-8.4.4 - llaves no deben alterar la identidad', () {
      expect(
        FundNameMatcher.nameSimilarity(
          'Global Equity Fund {Class A}',
          'Global Equity Fund Class A',
        ),
        1.0,
      );
    });

    test(
      'LF-8.4.5 - signo igual como separador no debe alterar la identidad',
      () {
        expect(
          FundNameMatcher.nameSimilarity(
            'Global Equity Fund = Class A',
            'Global Equity Fund Class A',
          ),
          1.0,
        );
      },
    );

    test(
      'LF-8.4.6 - combinación de símbolos no cubiertos no debe crear tokens',
      () {
        expect(
          FundNameMatcher.nameSimilarity(
            "PIMCO's Global Equity + Income [Class A]",
            'PIMCOs Global Equity Income Class A',
          ),
          1.0,
        );
      },
    );

    test('LF-8.5.1 - apóstrofe ASCII: documentar comportamiento posesivo', () {
      final similarity = FundNameMatcher.nameSimilarity(
        "Schroder's Global Equity Fund",
        'Schroders Global Equity Fund',
      );
      expect(similarity, 1.0);
    });

    test(
      'LF-8.5.2 - apóstrofe tipográfico: documentar comportamiento posesivo',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Schroder’s Global Equity Fund',
          'Schroders Global Equity Fund',
        );
        expect(similarity, 1.0);
      },
    );

    test('LF-8.5.3 - signo más: actualmente actúa como separador', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity + Income Fund',
        'Global Equity Income Fund',
      );
      expect(similarity, 1.0);
    });

    test('LF-8.5.4 - corchetes: actualmente actúan como separadores', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund [Class A]',
        'Global Equity Fund Class A',
      );
      expect(similarity, 1.0);
    });

    test('LF-8.5.5 - símbolo igual: actualmente actúa como separador', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund = Class A',
        'Global Equity Fund Class A',
      );
      expect(similarity, 1.0);
    });

    test('LF-8.5.6 - símbolos dentro de palabras: no deben confundirse con separadores', () {
      final similarity = FundNameMatcher.nameSimilarity('CLASS-A', 'CLASS A');

      expect(similarity, 1.0);
    });
    test(
      'LF-8.6.1 - apóstrofe ASCII: debería eliminarse y preservar el token',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          "Schroder's Global Equity Fund",
          'Schroders Global Equity Fund',
        );

        expect(similarity, 1.0);
      },
    );

    test('LF-8.6.2 - apóstrofe tipográfico: debería eliminarse y preservar el token', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Schroder’s Global Equity Fund',
        'Schroders Global Equity Fund',
      );

      expect(similarity, 1.0);
    });

    test('LF-8.6.3 - signo más: debería actuar como separador', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity + Income Fund',
        'Global Equity Income Fund',
      );

      expect(similarity, 1.0);
    });

    test('LF-8.6.4 - corchetes: deberían actuar como separadores', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund [Class A]',
        'Global Equity Fund Class A',
      );

      expect(similarity, 1.0);
    });

    test('LF-8.6.5 - llaves: deberían actuar como separadores', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund {Class A}',
        'Global Equity Fund Class A',
      );

      expect(similarity, 1.0);
    });

    test('LF-8.6.6 - signo igual: debería actuar como separador', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund = Class A',
        'Global Equity Fund Class A',
      );

      expect(similarity, 1.0);
    });
    test('LF-8.7.1 - signo más entre palabras debe equivaler a un espacio', () {
      final similarity = FundNameMatcher.nameSimilarity('A+B', 'A B');
      expect(similarity, 1.0);
    });

    test('LF-8.7.2 - signo más sin espacio no debe fusionar las palabras', () {
      final similarity = FundNameMatcher.nameSimilarity('A+B', 'AB');
      expect(similarity, lessThan(1.0));
    });

    test(
      'LF-8.7.3 - apóstrofe posesivo no debe convertirse en un token separado',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          "Schroder's",
          'Schroders',
        );
        expect(similarity, 1.0);
      },
    );

    test(
      'LF-8.7.4 - apóstrofe posesivo debe diferenciarse de una S separada',
      () {
        final similarity = FundNameMatcher.nameSimilarity("PIMCO's", 'PIMCO S');
        expect(similarity, lessThan(1.0));
      },
    );

    test('LF-8.7.5 - corchetes deben actuar como separadores', () {
      final similarity = FundNameMatcher.nameSimilarity('[Class A]', 'Class A');
      expect(similarity, 1.0);
    });

    test('LF-8.7.6 - llaves deben actuar como separadores', () {
      final similarity = FundNameMatcher.nameSimilarity('{Class A}', 'Class A');
      expect(similarity, 1.0);
    });

    test('LF-8.8.1 - separar con + no debe fusionar palabras distintas', () {
      final similarity = FundNameMatcher.nameSimilarity('A+B', 'AB');
      expect(similarity, lessThan(1.0));
    });

    test(
      'LF-8.8.2 - eliminar apóstrofe no debe equivaler a separar una palabra',
      () {
        final similarity = FundNameMatcher.nameSimilarity("PIMCO's", 'PIMCO S');
        expect(similarity, lessThan(1.0));
      },
    );

    test('LF-8.8.3 - corchetes no deben cambiar los tokens internos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity [Class A]',
        'Global Equity Class A',
      );
      expect(similarity, 1.0);
    });

    test('LF-8.8.4 - llaves no deben cambiar los tokens internos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity {Class A}',
        'Global Equity Class A',
      );
      expect(similarity, 1.0);
    });

    test(
      'LF-8.8.5 - combinación de separadores debe preservar todos los tokens',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity + Income [Class A]',
          'Global Equity Income Class A',
        );
        expect(similarity, 1.0);
      },
    );

    test('LF-8.8.6 - combinación de apóstrofe y separadores debe preservar la identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        "PIMCO's Global Equity + Income [Class A]",
        'PIMCOs Global Equity Income Class A',
      );
      expect(similarity, 1.0);
    });

    test('LF-9.1.1 - tres tokens comunes frente a un token específico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Fund Europe',
      );
      expect(similarity, closeTo(0.75, 0.000001));
    });

    test('LF-9.1.2 - tres tokens comunes frente a dos tokens específicos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Fund Europe Growth',
      );
      expect(similarity, closeTo(0.6, 0.000001));
    });

    test('LF-9.1.3 - un token específico compartido no debe producir similitud alta', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Bond Fund',
      );
      expect(similarity, closeTo(0.5, 0.000001));
    });

    test('LF-9.1.4 - dos tokens genéricos compartidos deben quedar por debajo de 0.5', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Bond Strategy',
      );
      expect(similarity, closeTo(0.2, 0.000001));
    });

    test('LF-9.1.5 - nombres largos con un único token compartido deben tener baja similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO Global Investment Grade Credit Fund',
        'European Investment Strategy Fund',
      );
      expect(similarity, closeTo(2 / 8, 0.000001));
    });

    test('LF-9.1.6 - añadir tokens específicos reduce la similitud', () {
      final base = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Fund',
      );

      final extended = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Fund Europe Growth',
      );

      expect(base, 1.0);
      expect(extended, lessThan(base));
    });

    test('LF-9.2.1 - añadir un token específico reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Income Fund Europe',
      );
      expect(similarity, closeTo(0.8, 0.000001));
    });

    test(
      'LF-9.2.2 - añadir dos tokens específicos reduce más la similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund',
          'PIMCO GIS Income Fund Europe Institutional',
        );
        expect(similarity, closeTo(2 / 3, 0.000001));
      },
    );

    test(
      'LF-9.2.3 - eliminar un token específico produce la misma similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund Europe',
          'PIMCO GIS Income Fund',
        );
        expect(similarity, closeTo(0.8, 0.000001));
      },
    );

    test(
      'LF-9.2.4 - eliminar dos tokens específicos produce la misma similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund Europe Institutional',
          'PIMCO GIS Income Fund',
        );
        expect(similarity, closeTo(2 / 3, 0.000001));
      },
    );

    test('LF-9.2.5 - añadir un token repetido no modifica la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Income Fund Income',
      );
      expect(similarity, 1.0);
    });

    test(
      'LF-9.2.6 - añadir un token nuevo y repetir otro solo cuenta una vez',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund',
          'PIMCO GIS Income Fund Income Europe',
        );
        expect(similarity, closeTo(0.8, 0.000001));
      },
    );

    test('LF-9.3.1 - mismo gestor pero productos claramente distintos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO Global Bond Fund',
        'PIMCO Global Equity Fund',
      );
      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('LF-9.3.2 - gestor y estrategia comunes pero activo diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO Global Bond Fund',
        'PIMCO Global Bond Equity Fund',
      );
      expect(similarity, closeTo(4 / 5, 0.000001));
    });

    test('LF-9.3.3 - términos genéricos comunes con productos diferentes', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Strategy',
      );
      expect(similarity, closeTo(0.5, 0.000001));
    });

    test('LF-9.3.4 - mismo nombre base pero clase diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund Class A',
        'PIMCO GIS Income Fund Class I',
      );
      expect(similarity, closeTo(5 / 7, 0.000001));
    });

    test('LF-9.3.5 - mismo nombre base pero divisa diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD',
        'PIMCO GIS Income Fund EUR',
      );
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test('LF-9.3.6 - mismo gestor pero estrategia y producto diferentes', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Global Real Return Fund',
      );
      expect(similarity, closeTo(3 / 7, 0.000001));
    });
    test('LF-9.4.1 - acumulación frente a distribución', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund Acc',
        'PIMCO GIS Income Fund Inc',
      );
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test('LF-9.4.2 - acumulación frente a distribución con divisa', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund EUR Acc',
        'PIMCO GIS Income Fund EUR Inc',
      );
      expect(similarity, closeTo(5 / 7, 0.000001));
    });

    test('LF-9.4.3 - clases A e I con misma divisa', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD A',
        'PIMCO GIS Income Fund USD I',
      );
      expect(similarity, closeTo(5 / 7, 0.000001));
    });

    test('LF-9.4.4 - clases A e I con acumulación', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD Acc A',
        'PIMCO GIS Income Fund USD Acc I',
      );
      expect(similarity, closeTo(6 / 8, 0.000001));
    });

    test('LF-9.4.5 - cambio simultáneo de divisa y distribución', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD Inc',
        'PIMCO GIS Income Fund EUR Acc',
      );
      expect(similarity, closeTo(4 / 8, 0.000001));
    });

    test('LF-9.4.6 - variante de clase y divisa simultáneamente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund USD A',
        'PIMCO GIS Income Fund EUR I',
      );
      expect(similarity, closeTo(4 / 8, 0.000001));
    });

    test('LF-9.5.1 - la similitud es simétrica en un caso básico', () {
      final ab = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Equity Fund Europe',
      );
      final ba = FundNameMatcher.nameSimilarity(
        'Global Equity Fund Europe',
        'Global Equity Fund',
      );

      expect(ab, closeTo(0.75, 0.000001));
      expect(ba, closeTo(0.75, 0.000001));
      expect(ab, closeTo(ba, 0.000001));
    });

    test('LF-9.5.2 - cambiar el orden de tokens no modifica la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Income PIMCO GIS Fund',
        'PIMCO GIS Income Fund',
      );

      expect(similarity, 1.0);
    });

    test(
      'LF-9.5.3 - el orden diferente de ambos nombres conserva la similitud',
      () {
        final ab = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund Europe',
          'Europe PIMCO Fund GIS Income',
        );
        final ba = FundNameMatcher.nameSimilarity(
          'Europe PIMCO Fund GIS Income',
          'PIMCO GIS Income Fund Europe',
        );

        expect(ab, 1.0);
        expect(ba, 1.0);
      },
    );

    test('LF-9.5.4 - simetría con tokens parcialmente compartidos', () {
      final ab = FundNameMatcher.nameSimilarity(
        'PIMCO Global Bond Fund',
        'PIMCO Global Equity Fund',
      );
      final ba = FundNameMatcher.nameSimilarity(
        'PIMCO Global Equity Fund',
        'PIMCO Global Bond Fund',
      );

      expect(ab, closeTo(3 / 5, 0.000001));
      expect(ba, closeTo(3 / 5, 0.000001));
      expect(ab, closeTo(ba, 0.000001));
    });

    test('LF-9.5.5 - repetir tokens no rompe la simetría', () {
      final ab = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund Income',
        'Fund PIMCO GIS Income',
      );
      final ba = FundNameMatcher.nameSimilarity(
        'Fund PIMCO GIS Income',
        'PIMCO GIS Income Fund Income',
      );

      expect(ab, 1.0);
      expect(ba, 1.0);
    });

    test('LF-9.5.6 - nombres reales con orden y puntuación diferentes', () {
      final ab = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund, Class A',
        'Class A PIMCO GIS Income Fund',
      );
      final ba = FundNameMatcher.nameSimilarity(
        'Class A PIMCO GIS Income Fund',
        'PIMCO GIS Income Fund, Class A',
      );

      expect(ab, 1.0);
      expect(ba, 1.0);
    });

    test('LF-9.6.1 - dos nombres vacíos tienen similitud cero', () {
      final similarity = FundNameMatcher.nameSimilarity('', '');

      expect(similarity, 0.0);
    });

    test(
      'LF-9.6.2 - un nombre vacío frente a uno no vacío tiene similitud cero',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          '',
          'PIMCO GIS Income Fund',
        );

        expect(similarity, 0.0);
      },
    );

    test('LF-9.6.3 - un único token idéntico produce similitud uno', () {
      final similarity = FundNameMatcher.nameSimilarity('PIMCO', 'PIMCO');

      expect(similarity, 1.0);
    });

    test('LF-9.6.4 - dos tokens únicos diferentes producen similitud cero', () {
      final similarity = FundNameMatcher.nameSimilarity('PIMCO', 'BlackRock');

      expect(similarity, 0.0);
    });

    test('LF-9.6.5 - un único token compartido entre dos nombres produce la similitud esperada', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO',
        'PIMCO Income Fund',
      );

      expect(similarity, closeTo(1 / 3, 0.000001));
    });

    test('LF-9.6.6 - un único token compartido entre nombres largos produce una similitud baja', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO Global Investment Grade Credit Fund',
        'European Equity Investment Strategy Bond Fund',
      );

      expect(similarity, closeTo(2 / 10, 0.000001));
    });

    test('LF-10.1.1 - cambio de Equity a Bond reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'Global Equity Fund',
        'Global Bond Fund',
      );

      expect(similarity, closeTo(2 / 4, 0.000001));
    });

    test('LF-10.1.2 - cambio de Income a Growth reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Growth Fund',
      );

      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('LF-10.1.3 - cambio de una sola clase mantiene alta similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund Class A',
        'PIMCO GIS Income Fund Class I',
      );

      expect(similarity, closeTo(5 / 7, 0.000001));
    });

    test(
      'LF-10.1.4 - una variante de divisa mantiene la identidad textual base',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund USD',
          'PIMCO GIS Income Fund EUR',
        );

        expect(similarity, closeTo(4 / 6, 0.000001));
      },
    );

    test(
      'LF-10.1.5 - diferencia de estrategia y clase reduce más la similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund Class A',
          'PIMCO GIS Global Bond Fund Class I',
        );
        expect(similarity, closeTo(4 / 9, 0.000001));
      },
    );

    test(
      'LF-10.1.6 - formato diferente sin cambio de identidad produce uno',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund, Class A',
          'class-a pimco gis income fund',
        );

        expect(similarity, 1.0);
      },
    );

    test(
      'LF-10.2.1 - mayúsculas, acentos y puntuación no alteran la identidad',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund',
          'pímco gis income fund.',
        );

        expect(similarity, 1.0);
      },
    );

    test('LF-10.2.2 - reordenar tokens y cambiar separadores no altera la identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund Class A',
        'Class-A / PIMCO / GIS / Income / Fund',
      );

      expect(similarity, 1.0);
    });

    test(
      'LF-10.2.3 - añadir un token realmente nuevo sí reduce la similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund',
          'PIMCO GIS Income Fund Europe',
        );

        // A = {PIMCO, GIS, INCOME, FUND} → 4
        // B = {PIMCO, GIS, INCOME, FUND, EUROPE} → 5
        // Intersección = 4, unión = 5 → 4/5.
        expect(similarity, closeTo(4 / 5, 0.000001));
      },
    );

    test(
      'LF-10.2.4 - dos tokens realmente nuevos reducen más la similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund',
          'PIMCO GIS Income Fund Europe Institutional',
        );

        // A → 4 tokens
        // B → 6 tokens
        // Intersección = 4, unión = 6 → 4/6 = 2/3.
        expect(similarity, closeTo(4 / 6, 0.000001));
      },
    );

    test('LF-10.2.5 - repetir un token existente no cambia la identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'PIMCO GIS Income Income Fund Fund',
      );

      // Ambos conjuntos son {PIMCO, GIS, INCOME, FUND}.
      expect(similarity, 1.0);
    });

    test('LF-10.2.6 - formato diferente más un token nuevo solo penaliza el token nuevo', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS Income Fund',
        'Fund, Income / PIMCO GIS Europe',
      );

      // A → {PIMCO, GIS, INCOME, FUND} → 4
      // B → {FUND, INCOME, PIMCO, GIS, EUROPE} → 5
      // Intersección = 4, unión = 5 → 4/5.
      expect(similarity, closeTo(4 / 5, 0.000001));
    });

    test('LF-10.3.1 - cambio de gestora con producto idéntico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'BANKINTER DEUDA PUBLICA 2025 FI',
        'CAIXABANK DEUDA PUBLICA 2025 FI',
      );

      // A = {BANKINTER, DEUDA, PUBLICA, 2025, FI} → 5
      // B = {CAIXABANK, DEUDA, PUBLICA, 2025, FI} → 5
      // Comunes = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test('LF-10.3.2 - cambio geográfico con misma estrategia', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'IBERCAJA BOLSA ESPAÑA FI',
        'IBERCAJA BOLSA USA FI',
      );

      // A → {IBERCAJA, BOLSA, ESPAÑA, FI} → 4
      // B → {IBERCAJA, BOLSA, USA, FI} → 4
      // Comunes = 3
      // Unión = 5
      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('LF-10.3.3 - cambio de renta fija a renta variable', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'ABANCA RENTA FIJA MIXTA FI',
        'ABANCA RENTA VARIABLE MIXTA FI',
      );

      // A → {ABANCA, RENTA, FIJA, MIXTA, FI} → 5
      // B → {ABANCA, RENTA, VARIABLE, MIXTA, FI} → 5
      // Comunes = {ABANCA, RENTA, MIXTA, FI} → 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test('LF-10.3.4 - cambio de perfil de riesgo', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'RURAL PERFIL CONSERVADOR FI',
        'RURAL PERFIL MODERADO FI',
      );

      // A → {RURAL, PERFIL, CONSERVADOR, FI} → 4
      // B → {RURAL, PERFIL, MODERADO, FI} → 4
      // Comunes = 3
      // Unión = 5
      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('LF-10.3.5 - serie II frente a serie III', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'ALTERALIA DEBT FUND II FIL',
        'ALTERALIA DEBT FUND III FIL',
      );

      // A → {ALTERALIA, DEBT, FUND, II, FIL} → 5
      // B → {ALTERALIA, DEBT, FUND, III, FIL} → 5
      // Comunes = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test(
      'LF-10.3.6 - diferencia semántica con similitud exactamente en el umbral',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL BOND FUND',
        );

        // A → {GLOBAL, EQUITY, FUND} → 3
        // B → {GLOBAL, BOND, FUND} → 3
        // Comunes = {GLOBAL, FUND} → 2
        // Unión = 4
        // Resultado = 0.5, exactamente el umbral externo actual.
        expect(similarity, closeTo(0.5, 0.000001));
      },
    );

    test('LF-10.4.1 - añadir una clase mantiene todo el núcleo', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL EQUITY FUND CLASS A',
      );

      // A = {GLOBAL, EQUITY, FUND} → 3
      // B = {GLOBAL, EQUITY, FUND, CLASS, A} → 5
      // Comunes = 3
      // Unión = 5
      expect(similarity, closeTo(3 / 5, 0.000001));
    });

    test('LF-10.4.2 - añadir clase y moneda reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL EQUITY FUND CLASS A USD',
      );

      // A = {GLOBAL, EQUITY, FUND} → 3
      // B = {GLOBAL, EQUITY, FUND, CLASS, A, USD} → 6
      // Comunes = 3
      // Unión = 6
      expect(similarity, closeTo(3 / 6, 0.000001));
    });

    test('LF-10.4.3 - añadir varios atributos al nombre PIMCO', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'PIMCO GIS INCOME FUND CLASS A USD ACC',
      );

      // A = {PIMCO, GIS, INCOME, FUND} → 4
      // B = {PIMCO, GIS, INCOME, FUND, CLASS, A, USD, ACC} → 8
      // Comunes = 4
      // Unión = 8
      expect(similarity, closeTo(4 / 8, 0.000001));
    });

    test('LF-10.4.4 - añadir un único descriptor geográfico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'EUROPEAN EQUITY FUND',
        'EUROPEAN EQUITY FUND EUROPE',
      );

      // A = {EUROPEAN, EQUITY, FUND} → 3
      // B = {EUROPEAN, EQUITY, FUND, EUROPE} → 4
      // Comunes = 3
      // Unión = 4
      expect(similarity, closeTo(3 / 4, 0.000001));
    });

    test('LF-10.4.5 - añadir dos tokens de clase sin modificar el núcleo', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'IBERCAJA BOLSA ESPAÑA FI',
        'IBERCAJA BOLSA ESPAÑA FI CLASE A',
      );

      // A = {IBERCAJA, BOLSA, ESPAÑA, FI} → 4
      // B = {IBERCAJA, BOLSA, ESPAÑA, FI, CLASE, A} → 6
      // Comunes = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 0.000001));
    });

    test(
      'LF-10.4.6 - expansión simétrica con un token distinto en cada lado',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND USD',
          'PIMCO GIS INCOME FUND EUR',
        );

        // A = {PIMCO, GIS, INCOME, FUND, USD} → 5
        // B = {PIMCO, GIS, INCOME, FUND, EUR} → 5
        // Comunes = {PIMCO, GIS, INCOME, FUND} → 4
        // Unión = {PIMCO, GIS, INCOME, FUND, USD, EUR} → 6
        expect(similarity, closeTo(4 / 6, 0.000001));
      },
    );

    test('LF-10.5.1 - repetir un token no cambia un nombre idéntico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'PIMCO PIMCO GIS INCOME FUND',
      );

      // A = {PIMCO, GIS, INCOME, FUND} → 4
      // B = {PIMCO, GIS, INCOME, FUND} → 4
      // Comunes = 4
      // Unión = 4
      expect(similarity, closeTo(1.0, 0.000001));
    });

    test('LF-10.5.2 - una repetición no cuenta como token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'PIMCO PIMCO GIS INCOME FUND CLASS',
      );

      // A = {PIMCO, GIS, INCOME, FUND} → 4
      // B = {PIMCO, GIS, INCOME, FUND, CLASS} → 5
      // Comunes = 4
      // Unión = 5
      expect(similarity, closeTo(4 / 5, 0.000001));
    });

    test(
      'LF-10.5.3 - repeticiones en ambos nombres siguen contando una sola vez',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO PIMCO GIS INCOME FUND',
          'PIMCO GIS INCOME FUND FUND CLASS',
        );

        // A = {PIMCO, GIS, INCOME, FUND} → 4
        // B = {PIMCO, GIS, INCOME, FUND, CLASS} → 5
        // Comunes = 4
        // Unión = 5
        expect(similarity, closeTo(4 / 5, 0.000001));
      },
    );

    test(
      'LF-10.5.4 - repetir distintos tokens no altera un conjunto idéntico',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL GLOBAL EQUITY FUND',
          'GLOBAL EQUITY EQUITY FUND',
        );

        // A = {GLOBAL, EQUITY, FUND} → 3
        // B = {GLOBAL, EQUITY, FUND} → 3
        // Comunes = 3
        // Unión = 3
        expect(similarity, closeTo(1.0, 0.000001));
      },
    );

    test('LF-10.5.5 - las repeticiones no compensan una diferencia real', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO PIMCO INCOME FUND',
        'PIMCO INCOME GLOBAL FUND',
      );

      // A = {PIMCO, INCOME, FUND} → 3
      // B = {PIMCO, INCOME, GLOBAL, FUND} → 4
      // Comunes = {PIMCO, INCOME, FUND} → 3
      // Unión = {PIMCO, INCOME, FUND, GLOBAL} → 4
      expect(similarity, closeTo(3 / 4, 0.000001));
    });

    test(
      'LF-10.5.6 - repetir un único token varias veces no altera la similitud',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'FUND FUND FUND FUND',
          'FUND',
        );

        // A = {FUND} → 1
        // B = {FUND} → 1
        // Comunes = 1
        // Unión = 1
        expect(similarity, closeTo(1.0, 0.000001));
      },
    );

    // ===========================================================================
    // LF-10.6 — Normalización combinada en nameSimilarity()
    // ===========================================================================

    test('LF-10.6.1 — guion normalizado + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO-GIS INCOME FUND',
        'PIMCO GIS INCOME FUND CLASS A',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {PIMCO, GIS, INCOME, FUND, CLASS, A}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.6.2 — acento normalizado + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'FONDOS DE INVERSIÓN GLOBAL',
        'FONDOS DE INVERSION GLOBAL CLASE A',
      );

      // A = {FONDOS, DE, INVERSION, GLOBAL}
      // B = {FONDOS, DE, INVERSION, GLOBAL, CLASE, A}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.6.3 — apóstrofe + guion + acento normalizados', () {
      final similarity = FundNameMatcher.nameSimilarity(
        "PIMCO O'BRIEN-ÉQUITY FUND",
        'PIMCO OBRIEN EQUITY FUND CLASS A',
      );

      // A = {PIMCO, OBRIEN, EQUITY, FUND}
      // B = {PIMCO, OBRIEN, EQUITY, FUND, CLASS, A}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.6.4 — slash + ampersand + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL/ASIA EQUITY & INCOME FUND',
        'GLOBAL ASIA EQUITY INCOME FUND CLASS A',
      );

      // A = {GLOBAL, ASIA, EQUITY, INCOME, FUND}
      // B = {GLOBAL, ASIA, EQUITY, INCOME, FUND, CLASS, A}
      // Intersección = 5
      // Unión = 7
      expect(similarity, closeTo(5 / 7, 1e-12));
    });

    test('LF-10.6.5 — paréntesis + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'EUROPEAN EQUITY FUND (EUR)',
        'EUROPEAN EQUITY FUND EUR CLASS A',
      );

      // A = {EUROPEAN, EQUITY, FUND, EUR}
      // B = {EUROPEAN, EQUITY, FUND, EUR, CLASS, A}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.6.6 — múltiples separadores + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL-EQUITY/INCOME_FUND',
        'GLOBAL EQUITY INCOME FUND USD',
      );

      // A = {GLOBAL, EQUITY, INCOME, FUND}
      // B = {GLOBAL, EQUITY, INCOME, FUND, USD}
      // Intersección = 4
      // Unión = 5
      expect(similarity, closeTo(4 / 5, 1e-12));
    });

    // ===========================================================================
    // LF-10.7 — Orden y multiplicidad de tokens tras normalización
    // ===========================================================================

    test('LF-10.7.1 — mismo contenido en orden diferente', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'FUND INCOME GIS PIMCO',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {FUND, INCOME, GIS, PIMCO}
      // Intersección = 4
      // Unión = 4
      expect(similarity, closeTo(1.0, 1e-12));
    });

    test('LF-10.7.2 — orden diferente + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'CLASS A FUND PIMCO INCOME GIS',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {CLASS, A, FUND, PIMCO, INCOME, GIS}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.7.3 — duplicación de token en un solo nombre', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'FUND GLOBAL GLOBAL EQUITY',
      );

      // A = {GLOBAL, EQUITY, FUND}
      // B = {FUND, GLOBAL, EQUITY}
      // El segundo GLOBAL es duplicado y no altera el conjunto.
      // Intersección = 3
      // Unión = 3
      expect(similarity, closeTo(1.0, 1e-12));
    });

    test('LF-10.7.4 — duplicaciones diferentes + token adicional', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'FUND FUND PIMCO GIS INCOME CLASS',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {FUND, PIMCO, GIS, INCOME, CLASS}
      // Intersección = 4
      // Unión = 5
      expect(similarity, closeTo(4 / 5, 1e-12));
    });

    test(
      'LF-10.7.5 — mismo conjunto con repetición múltiple y distinto orden',
      () {
        final similarity = FundNameMatcher.nameSimilarity(
          'EUROPEAN EQUITY FUND',
          'EQUITY FUND EUROPEAN EUROPEAN FUND',
        );

        // A = {EUROPEAN, EQUITY, FUND}
        // B = {EQUITY, FUND, EUROPEAN}
        // Las repeticiones no cuentan.
        // Intersección = 3
        // Unión = 3
        expect(similarity, closeTo(1.0, 1e-12));
      },
    );

    test('LF-10.7.6 — orden + duplicados + dos tokens adicionales', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND',
        'CLASS A FUND FUND INCOME GIS PIMCO USD',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {CLASS, A, FUND, INCOME, GIS, PIMCO, USD}
      // Intersección = 4
      // Unión = 7
      expect(similarity, closeTo(4 / 7, 1e-12));
    });

    // ===========================================================================
    // LF-10.8 — Normalización vs. cambios reales de identidad
    // ===========================================================================

    test('LF-10.8.1 — separadores diferentes no cambian la identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO-GIS/INCOME_FUND',
        'PIMCO GIS INCOME FUND',
      );

      // A = {PIMCO, GIS, INCOME, FUND}
      // B = {PIMCO, GIS, INCOME, FUND}
      // Intersección = 4
      // Unión = 4
      expect(similarity, closeTo(1.0, 1e-12));
    });

    test('LF-10.8.2 — acentos y mayúsculas no cambian la identidad', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'FONDOS DE INVERSIÓN GLOBAL',
        'fondos de inversion global',
      );

      // A = {FONDOS, DE, INVERSION, GLOBAL}
      // B = {FONDOS, DE, INVERSION, GLOBAL}
      // Intersección = 4
      // Unión = 4
      expect(similarity, closeTo(1.0, 1e-12));
    });

    test('LF-10.8.3 — cambio de divisa reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND USD',
        'PIMCO GIS INCOME FUND EUR',
      );

      // A = {PIMCO, GIS, INCOME, FUND, USD}
      // B = {PIMCO, GIS, INCOME, FUND, EUR}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    test('LF-10.8.4 — cambio de estrategia reduce la similitud', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL BOND FUND',
      );

      // A = {GLOBAL, EQUITY, FUND}
      // B = {GLOBAL, BOND, FUND}
      // Intersección = 2
      // Unión = 4
      expect(similarity, closeTo(2 / 4, 1e-12));
    });

    test('LF-10.8.5 — cambio de clase mantiene solo los tokens comunes', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND CLASS A',
        'PIMCO GIS INCOME FUND CLASS I',
      );

      // A = {PIMCO, GIS, INCOME, FUND, CLASS, A}
      // B = {PIMCO, GIS, INCOME, FUND, CLASS, I}
      // Intersección = 5
      // Unión = 7
      expect(similarity, closeTo(5 / 7, 1e-12));
    });

    test('LF-10.8.6 — normalización compleja no oculta un cambio real', () {
      final similarity = FundNameMatcher.nameSimilarity(
        "PIMCO O'BRIEN-EQUITY FUND USD",
        'PIMCO OBRIEN BOND FUND USD',
      );

      // A = {PIMCO, OBRIEN, EQUITY, FUND, USD}
      // B = {PIMCO, OBRIEN, BOND, FUND, USD}
      // Intersección = 4
      // Unión = 6
      expect(similarity, closeTo(4 / 6, 1e-12));
    });

    // ===========================================================================
    // LF-11 — Sensibilidad del Jaccard a cambios de tokens
    // ===========================================================================

    test('LF-11.1 — un token sustituido entre cuatro', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND EUROPE',
        'GLOBAL BOND FUND EUROPE',
      );

      // A = {GLOBAL, EQUITY, FUND, EUROPE}
      // B = {GLOBAL, BOND, FUND, EUROPE}
      // Intersección = 3
      // Unión = 5
      expect(similarity, closeTo(3 / 5, 1e-12));
    });

    test('LF-11.2 — dos tokens sustituidos entre cinco', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND USD',
        'PIMCO GIS GLOBAL FUND EUR',
      );

      // A = {PIMCO, GIS, INCOME, FUND, USD}
      // B = {PIMCO, GIS, GLOBAL, FUND, EUR}
      // Intersección = 3
      // Unión = 7
      expect(similarity, closeTo(3 / 7, 1e-12));
    });

    test('LF-11.3 — tres tokens sustituidos entre seis', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO GIS INCOME FUND USD ACC',
        'PIMCO GIS GLOBAL BOND EUR INC',
      );

      // A = {PIMCO, GIS, INCOME, FUND, USD, ACC}
      // B = {PIMCO, GIS, GLOBAL, BOND, EUR, INC}
      // Intersección = 2
      // Unión = 10
      expect(similarity, closeTo(2 / 10, 1e-12));
    });

    test('LF-11.4 — añadir un token a un conjunto idéntico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL EQUITY FUND EUROPE',
      );

      // A = {GLOBAL, EQUITY, FUND}
      // B = {GLOBAL, EQUITY, FUND, EUROPE}
      // Intersección = 3
      // Unión = 4
      expect(similarity, closeTo(3 / 4, 1e-12));
    });

    test('LF-11.5 — añadir dos tokens a un conjunto idéntico', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'GLOBAL EQUITY FUND',
        'GLOBAL EQUITY FUND EUROPE CLASS A',
      );

      // A = {GLOBAL, EQUITY, FUND}
      // B = {GLOBAL, EQUITY, FUND, EUROPE, CLASS, A}
      // Intersección = 3
      // Unión = 6
      expect(similarity, closeTo(3 / 6, 1e-12));
    });

    test('LF-11.6 — solo un token común entre dos conjuntos', () {
      final similarity = FundNameMatcher.nameSimilarity(
        'PIMCO INCOME FUND',
        'PIMCO GLOBAL EQUITY',
      );

      // A = {PIMCO, INCOME, FUND}
      // B = {PIMCO, GLOBAL, EQUITY}
      // Intersección = 1
      // Unión = 5
      expect(similarity, closeTo(1 / 5, 1e-12));
    });

    // ===========================================================================
    // LF-12.1 — Gestora vs producto
    // ===========================================================================
    group('LF-12.1 — Gestora vs producto', () {
      test('LF-12.1.1 — misma gestora, productos claramente distintos', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025 FI',
          'BANKINTER RENTA VARIABLE ESPAÑA FI',
        );

        expect(similarity, closeTo(0.25, 0.0001));
      });

      test(
        'LF-12.1.2 — productos distintos pero vocabulario parcialmente común',
        () {
          final similarity = FundNameMatcher.nameSimilarity(
            'BANKINTER DEUDA PUBLICA 2025 FI',
            'CAIXABANK DEUDA PUBLICA 2025 FI',
          );

          expect(similarity, closeTo(2 / 3, 0.0001));
        },
      );
    });

    // ===========================================================================
    // LF-12.3 — Moneda como elemento de identidad
    // ===========================================================================
    group('LF-12.3 — Moneda como elemento de identidad', () {
      test('LF-12.3.1 — PIMCO USD vs EUR', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund USD',
          'PIMCO GIS Income Fund EUR',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-12.3.2 — Global Equity EUR vs USD', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund EUR Acc',
          'Global Equity Fund USD Acc',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-12.3.3 — EUR vs GBP', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund EUR Acc',
          'Global Equity Fund GBP Acc',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-12.3.4 — moneda y clase simultáneamente diferentes', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund Class A EUR',
          'Global Equity Fund Class B USD',
        );

        expect(similarity, closeTo(0.5, 0.0001));
      });
    });

    // ===========================================================================
    // LF-12.4 — Tokens semánticamente opuestos
    // ===========================================================================
    group('LF-12.4 — Tokens semánticamente opuestos', () {
      test('LF-12.4.1 — Equity vs Bond', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund',
          'Global Bond Fund',
        );

        expect(similarity, closeTo(0.5, 0.0001));
      });

      test('LF-12.4.2 — European Equity vs European Bond', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'European Equity Fund',
          'European Bond Fund',
        );

        expect(similarity, closeTo(0.5, 0.0001));
      });

      test('LF-12.4.3 — Income vs Growth', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Income Fund',
          'Growth Fund',
        );

        expect(similarity, closeTo(1 / 3, 0.0001));
      });

      test('LF-12.4.4 — Acc vs Inc', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund Acc',
          'Global Equity Fund Inc',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test(
        'LF-12.4.5 — Growth vs Income dentro del mismo producto nominal',
        () {
          final similarity = FundNameMatcher.nameSimilarity(
            'Global Equity Growth Fund',
            'Global Equity Income Fund',
          );

          expect(similarity, closeTo(0.6, 0.0001));
        },
      );
    });

    // ===========================================================================
    // LF-12.5 — Nombres reales / representativos de las fuentes
    // ===========================================================================
    group('LF-12.5 — Nombres reales de las fuentes', () {
      test('LF-12.5.1 — PIMCO Yahoo vs Morningstar/CNMV', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });

      test('LF-12.5.2 — JPMorgan nombre corto vs nombre de clase', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'JPMorgan Funds Global Equity',
          'JPMorgan Funds Global Equity A Acc EUR',
        );

        expect(similarity, closeTo(4 / 7, 0.0001));
      });

      test('LF-12.5.3 — Carmignac nombre completo vs nombre base', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Carmignac Patrimoine A EUR Acc',
          'Carmignac Patrimoine',
        );

        expect(similarity, closeTo(0.4, 0.0001));
      });

      test('LF-12.5.4 — mismo nombre tras normalización', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'pimco gis income e usd inc',
        );

        expect(similarity, 1.0);
      });

      test(
        'LF-12.5.5 — fuente española vs nombre con metadatos adicionales',
        () {
          final similarity = FundNameMatcher.nameSimilarity(
            'Carmignac Patrimoine',
            'Carmignac Patrimoine A EUR Acc',
          );

          expect(similarity, closeTo(0.4, 0.0001));
        },
      );
    });

    // ===========================================================================
    // LF-12.6 — Similitud léxica no equivale a identidad
    // ===========================================================================
    group('LF-12.6 — Similitud léxica no equivale a identidad', () {
      test('LF-12.6.1 — clases diferentes con similitud > 0.7', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund Class A USD',
          'Global Equity Fund Class B USD',
        );

        expect(similarity, greaterThan(0.7));
        expect(similarity, closeTo(5 / 7, 0.0001));
      });

      test('LF-12.6.2 — Equity vs Bond mantiene similitud significativa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund',
          'Global Bond Fund',
        );

        expect(similarity, closeTo(0.5, 0.0001));
        expect(similarity, greaterThan(0.0));
      });

      test('LF-12.6.3 — misma familia nominal con clase distinta', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income Fund E Class USD Income',
          'PIMCO GIS Income Fund I Class USD Income',
        );

        expect(similarity, closeTo(0.75, 0.0001));
        expect(similarity, lessThan(1.0));
      });

      test('LF-12.6.4 — mismo producto con nombre abreviado', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
        expect(similarity, lessThan(0.7));
      });

      test('LF-12.6.5 — identidad distinta puede superar 0.6', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'Global Equity Fund Class A',
          'Global Equity Fund Class B',
        );

        expect(similarity, greaterThan(0.6));
        expect(similarity, lessThan(1.0));
      });
    });

    // ===========================================================================
    // LF-13.1 — Gestora / identidad de producto
    // ===========================================================================
    group('LF-13.1 — Gestora / identidad de producto', () {
      test('LF-13.1.1 — misma gestora, producto diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025 FI',
          'BANKINTER RENTA VARIABLE ESPAÑA FI',
        );

        expect(similarity, closeTo(0.25, 0.0001));
      });

      test('LF-13.1.2 — gestora diferente, mismo producto nominal', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025 FI',
          'CAIXABANK DEUDA PUBLICA 2025 FI',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-13.1.3 — mismo producto sin gestora', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'DEUDA PUBLICA 2025 FI',
          'DEUDA PUBLICA 2025 FI',
        );

        expect(similarity, 1.0);
      });

      test('LF-13.1.4 — solo cambia la gestora', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025 FI',
          'CAIXABANK DEUDA PUBLICA 2025 FI',
        );

        expect(similarity, greaterThan(0.5));
        expect(similarity, lessThan(1.0));
      });
    });

    // ===========================================================================
    // LF-13.2 — Clase
    // ===========================================================================
    group('LF-13.2 — Clase', () {
      test('LF-13.2.1 — clase A vs B', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND CLASS B',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-13.2.2 — clase E vs I', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND E CLASS USD INCOME',
          'PIMCO GIS INCOME FUND I CLASS USD INCOME',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-13.2.3 — misma clase explícita', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND CLASS A',
        );

        expect(similarity, 1.0);
      });

      test('LF-13.2.4 — clase omitida en uno de los nombres', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test(
        'LF-13.2.5 — clase y nombre completamente iguales salvo formato',
        () {
          final similarity = FundNameMatcher.nameSimilarity(
            'Global Equity Fund - Class A',
            'GLOBAL EQUITY FUND CLASS A',
          );

          expect(similarity, 1.0);
        },
      );
    });

    // ===========================================================================
    // LF-13.3 — Divisa
    // ===========================================================================
    group('LF-13.3 — Divisa', () {
      test('LF-13.3.1 — EUR vs USD', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND USD',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.3.2 — misma divisa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND EUR',
        );

        expect(similarity, 1.0);
      });

      test('LF-13.3.3 — divisa omitida', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-13.3.4 — clase y divisa diferentes', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR',
          'GLOBAL EQUITY FUND CLASS B USD',
        );

        expect(similarity, 0.5);
      });

      test('LF-13.3.5 — misma clase, divisa diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR',
          'GLOBAL EQUITY FUND CLASS A USD',
        );
        expect(similarity, closeTo(5 / 7, 0.0001));
      });
    });

    // ===========================================================================
    // LF-13.4 — Distribución / acumulación
    // ===========================================================================
    group('LF-13.4 — Distribución / acumulación', () {
      test('LF-13.4.1 — Acc vs Inc', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND INC',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.4.2 — Acc vs Distribution', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND DISTRIBUTION',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.4.3 — Income vs Growth', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY INCOME FUND',
          'GLOBAL EQUITY GROWTH FUND',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.4.4 — misma modalidad de distribución', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND ACC',
        );

        expect(similarity, 1.0);
      });

      test('LF-13.4.5 — modalidad omitida', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });
    });

    // ===========================================================================
    // LF-13.5 — Tokens accesorios
    // ===========================================================================
    group('LF-13.5 — Tokens accesorios', () {
      test('LF-13.5.1 — Fund', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME',
          'PIMCO GIS INCOME FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-13.5.2 — FI', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025',
          'BANKINTER DEUDA PUBLICA 2025 FI',
        );

        expect(similarity, closeTo(0.8, 0.0001));
      });

      test('LF-13.5.3 — Class', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND A',
          'GLOBAL EQUITY FUND CLASS A',
        );

        expect(similarity, closeTo(4 / 5, 0.0001));
      });

      test('LF-13.5.4 — UCITS', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY FUND UCITS',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-13.5.5 — múltiples tokens accesorios', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY FUND UCITS SICAV',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });
    });

    // ===========================================================================
    // LF-13.6 — Combinaciones estructurales
    // ===========================================================================
    group('LF-13.6 — Combinaciones estructurales', () {
      test('LF-13.6.1 — misma clase, moneda diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND E CLASS EUR INCOME',
          'PIMCO GIS INCOME FUND E CLASS USD INCOME',
        );
        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-13.6.2 — clase y distribución diferentes', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND E CLASS USD ACC',
          'PIMCO GIS INCOME FUND I CLASS USD INC',
        );
        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.6.3 — clase, moneda y distribución diferentes', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND E CLASS EUR ACC',
          'PIMCO GIS INCOME FUND I CLASS USD INC',
        );
        expect(similarity, closeTo(5 / 11, 0.0001));
      });

      test('LF-13.6.4 — nombre abreviado frente a nombre estructurado', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME E USD INC',
          'PIMCO GIS INCOME FUND E CLASS USD INCOME',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });
    });

    // ===========================================================================
    // LF-13.7 — Ausencia de información vs diferencia explícita
    // ===========================================================================
    group('LF-13.7 — Ausencia de información vs diferencia explícita', () {
      test('LF-13.7.1 — clase ausente no equivale a clase diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND',
        );
        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.7.2 — moneda ausente no equivale a moneda diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test(
        'LF-13.7.3 — distribución ausente no equivale a distribución diferente',
        () {
          final similarity = FundNameMatcher.nameSimilarity(
            'GLOBAL EQUITY FUND ACC',
            'GLOBAL EQUITY FUND',
          );

          expect(similarity, closeTo(0.75, 0.0001));
        },
      );

      test('LF-13.7.4 — diferencia explícita de clase', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND CLASS B',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-13.7.5 — diferencia explícita de moneda', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND USD',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-13.7.6 — diferencia explícita de distribución', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND INC',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.1 — Variantes de clase
    // ===========================================================================
    group('LF-14.1 — Variantes de clase', () {
      test('LF-14.1.1 — Class A vs A', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND A',
        );

        expect(similarity, closeTo(4 / 5, 0.0001));
      });

      test('LF-14.1.2 — Class A vs Class A Share', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND CLASS A SHARE',
        );

        expect(similarity, closeTo(5 / 6, 0.0001));
      });

      test('LF-14.1.3 — Class A vs A Acc', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND A ACC',
        );

        expect(similarity, closeTo(4 / 6, 0.0001));
      });

      test('LF-14.1.4 — clase expresada como palabra vs letra', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND A',
        );

        expect(similarity, closeTo(4 / 5, 0.0001));
      });

      test('LF-14.1.5 — clase E real de PIMCO', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME FUND E CLASS USD INCOME',
          'PIMCO GIS INCOME E USD INC',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.2 — Variantes de moneda
    // ===========================================================================
    group('LF-14.2 — Variantes de moneda', () {
      test('LF-14.2.1 — EUR explícito en ambos', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND EUR',
        );

        expect(similarity, 1.0);
      });

      test('LF-14.2.2 — EUR vs USD', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND USD',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.2.3 — moneda ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.2.4 — EUR con clase', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND A EUR',
          'GLOBAL EQUITY FUND A EUR',
        );

        expect(similarity, 1.0);
      });

      test('LF-14.2.5 — EUR/Acc vs USD/Acc', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND A EUR ACC',
          'GLOBAL EQUITY FUND A USD ACC',
        );
        expect(similarity, closeTo(5 / 7, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.3 — Variantes de distribución
    // ===========================================================================
    group('LF-14.3 — Variantes de distribución', () {
      test('LF-14.3.1 — ACC vs ACC', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND ACC',
        );

        expect(similarity, 1.0);
      });

      test('LF-14.3.2 — ACC vs INC', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND INC',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.3.3 — ACC vs INCOME', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND INCOME',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.3.4 — INC vs INCOME', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND INC',
          'GLOBAL EQUITY FUND INCOME',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.3.5 — distribución ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.4 — Descriptores jurídicos / estructurales
    // ===========================================================================
    group('LF-14.4 — Descriptores jurídicos / estructurales', () {
      test('LF-14.4.1 — FUND presente/ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS INCOME',
          'PIMCO GIS INCOME FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.4.2 — FI presente/ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025',
          'BANKINTER DEUDA PUBLICA 2025 FI',
        );

        expect(similarity, closeTo(0.8, 0.0001));
      });

      test('LF-14.4.3 — UCITS presente/ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY FUND UCITS',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.4.4 — SICAV presente/ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY FUND SICAV',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.4.5 — múltiples descriptores', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY FUND UCITS SICAV',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.5 — Nombres reales internacionales
    // ===========================================================================
    group('LF-14.5 — Nombres reales internacionales', () {
      test('LF-14.5.1 — PIMCO abreviado vs completo', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income Fund E Class USD Income',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });

      test('LF-14.5.2 — PIMCO misma clase y moneda', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income E USD Inc',
        );

        expect(similarity, 1.0);
      });

      test('LF-14.5.3 — PIMCO clase diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income I USD Inc',
        );
        expect(similarity, closeTo(5 / 7, 0.0001));
      });

      test('LF-14.5.4 — PIMCO moneda diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income E EUR Inc',
        );
        expect(similarity, closeTo(5 / 7, 0.0001));
      });

      test('LF-14.5.5 — PIMCO clase y moneda diferentes', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Income I EUR Inc',
        );
        expect(similarity, 0.5);
      });
    });

    // ===========================================================================
    // LF-14.6 — Ausencia frente a contradicción
    // ===========================================================================
    group('LF-14.6 — Ausencia frente a contradicción', () {
      test('LF-14.6.1 — clase A vs clase ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.6.2 — clase A vs clase B', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A',
          'GLOBAL EQUITY FUND CLASS B',
        );

        expect(similarity, closeTo(2 / 3, 0.0001));
      });

      test('LF-14.6.3 — EUR vs moneda ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.6.4 — EUR vs USD', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND EUR',
          'GLOBAL EQUITY FUND USD',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });

      test('LF-14.6.5 — ACC vs distribución ausente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND',
        );

        expect(similarity, closeTo(0.75, 0.0001));
      });

      test('LF-14.6.6 — ACC vs INC', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND ACC',
          'GLOBAL EQUITY FUND INC',
        );

        expect(similarity, closeTo(0.6, 0.0001));
      });
    });

    // ===========================================================================
    // LF-14.7 — Composición de atributos estructurales
    // ===========================================================================
    group('LF-14.7 — Composición de atributos estructurales', () {
      test('LF-14.7.1 — mismo producto, misma clase, misma moneda', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
        );

        expect(similarity, 1.0);
      });

      test('LF-14.7.2 — cambia solo clase', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS B EUR ACC',
        );
        expect(similarity, 0.75);
      });

      test('LF-14.7.3 — cambia solo moneda', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS A USD ACC',
        );
        expect(similarity, 0.75);
      });

      test('LF-14.7.4 — cambia solo distribución', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS A EUR INC',
        );
        expect(similarity, 0.75);
      });

      test('LF-14.7.5 — cambia clase y moneda', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS B USD ACC',
        );
        expect(similarity, closeTo(5 / 9, 0.0001));
      });

      test('LF-14.7.6 — cambia clase, moneda y distribución', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL EQUITY FUND CLASS B USD INC',
        );
        expect(similarity, 0.4);
      });
    });

    // ============================================================================
    // LF-15 — FALSOS POSITIVOS POR COINCIDENCIA PARCIAL
    // ============================================================================
    //
    // Objetivo:
    //   Medir hasta qué punto dos fondos diferentes pueden obtener una similitud
    //   elevada simplemente porque comparten muchos tokens.
    //
    // No se evalúa aquí si una pareja es realmente la misma clase de fondo.
    // Se documenta exclusivamente el comportamiento léxico actual de Jaccard.
    //
    // Regla:
    //   No modificar FundNameMatcher para hacer pasar estos tests.
    // ============================================================================

    group('LF-15 — Falsos positivos por coincidencia parcial', () {
      // --------------------------------------------------------------------------
      // LF-15.1 — Mismo nombre base, vehículo/instrumento diferente
      // --------------------------------------------------------------------------

      test('LF-15.1.1 — Equity Fund vs Equity ETF', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY ETF',
        );

        expect(similarity, closeTo(2 / 4, 0.0001));
      });

      test('LF-15.1.2 — Equity Fund vs Equity Index Fund', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY INDEX FUND',
        );
        expect(similarity, 0.75);
      });

      test('LF-15.1.3 — Equity Fund vs Equity Select Fund', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY SELECT FUND',
        );
        expect(similarity, 0.75);
      });

      test('LF-15.1.4 — Global Equity Fund vs Global Equity Income Fund', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EQUITY INCOME FUND',
        );
        expect(similarity, 0.75);
      });

      // --------------------------------------------------------------------------
      // LF-15.2 — Diferencia en una palabra sustantiva
      // --------------------------------------------------------------------------

      test('LF-15.2.1 — Equity vs Bond', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL BOND FUND',
        );

        expect(similarity, closeTo(2 / 4, 0.0001));
      });

      test('LF-15.2.2 — Equity vs Credit', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL CREDIT FUND',
        );

        expect(similarity, closeTo(2 / 4, 0.0001));
      });

      test('LF-15.2.3 — Equity vs Emerging Markets', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL EMERGING MARKETS FUND',
        );

        expect(similarity, closeTo(2 / 5, 0.0001));
      });

      test('LF-15.2.4 — Global Equity vs Global Allocation', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND',
          'GLOBAL ALLOCATION FUND',
        );

        expect(similarity, closeTo(2 / 4, 0.0001));
      });

      // --------------------------------------------------------------------------
      // LF-15.3 — Diferencia en varios atributos semánticamente relevantes
      // --------------------------------------------------------------------------

      test('LF-15.3.1 — Equity vs Bond con misma clase y divisa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(6 / 8, 0.0001));
      });

      test('LF-15.3.2 — Equity vs Credit con misma clase y divisa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL CREDIT FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(6 / 8, 0.0001));
      });

      test('LF-15.3.3 — Equity vs Allocation con misma clase y divisa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL ALLOCATION FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(6 / 8, 0.0001));
      });

      // --------------------------------------------------------------------------
      // LF-15.4 — Fondos de la misma gestora / familia nominal
      // --------------------------------------------------------------------------

      test('LF-15.4.1 — PIMCO Income vs PIMCO Credit', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Credit E USD Inc',
        );

        expect(similarity, closeTo(5 / 7, 0.0001));
      });

      test('LF-15.4.2 — PIMCO Income vs PIMCO Global Bond', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Global Bond E USD Inc',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });

      test('LF-15.4.3 — PIMCO Income vs PIMCO Short Duration', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Short Duration E USD Inc',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });

      test('LF-15.4.4 — PIMCO Income vs PIMCO Emerging Markets', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'PIMCO GIS Income E USD Inc',
          'PIMCO GIS Emerging Markets E USD Inc',
        );

        expect(similarity, closeTo(5 / 8, 0.0001));
      });

      // --------------------------------------------------------------------------
      // LF-15.5 — Tokens genéricos dominantes
      // --------------------------------------------------------------------------

      test('LF-15.5.1 — muchos tokens genéricos, estrategia diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL INVESTMENT FUND CLASS A EUR ACC',
          'GLOBAL INVESTMENT FUND CLASS B EUR ACC',
        );

        expect(similarity, 0.75);
      });

      test('LF-15.5.2 — misma estructura, diferente producto', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL EQUITY FUND CLASS A EUR ACC',
          'GLOBAL BOND FUND CLASS B USD INC',
        );
        expect(similarity, closeTo(3 / 11, 0.0001));
      });

      test('LF-15.5.3 — nombre largo con una diferencia sustantiva', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL SUSTAINABLE EQUITY FUND CLASS A EUR ACC',
          'GLOBAL SUSTAINABLE BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(7 / 9, 0.0001));
      });

      // --------------------------------------------------------------------------
      // LF-15.6 — Coincidencia por tokens de estructura, sin identidad nominal
      // --------------------------------------------------------------------------

      test('LF-15.6.1 — misma estructura completa, producto diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'EUROPEAN EQUITY FUND CLASS A EUR ACC',
          'EUROPEAN BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(6 / 8, 0.0001));
      });

      test('LF-15.6.2 — misma gestora y estructura, estrategia diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ACME GLOBAL EQUITY FUND CLASS A EUR ACC',
          'ACME GLOBAL BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(7 / 9, 0.0001));
      });

      test('LF-15.6.3 — familia muy parecida, producto diferente', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ACME GLOBAL SUSTAINABLE EQUITY FUND CLASS A EUR ACC',
          'ACME GLOBAL SUSTAINABLE BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(8 / 10, 0.0001));
      });

      // --------------------------------------------------------------------------
      // LF-15.7 — Casos extremos: similitud alta sin identidad
      // --------------------------------------------------------------------------

      test('LF-15.7.1 — una sola diferencia sustantiva en nombre largo', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL SUSTAINABLE RESPONSIBLE EQUITY FUND CLASS A EUR ACC',
          'GLOBAL SUSTAINABLE RESPONSIBLE BOND FUND CLASS A EUR ACC',
        );

        expect(similarity, closeTo(8 / 10, 0.0001));
      });

      test('LF-15.7.2 — dos diferencias sustantivas en nombre largo', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL SUSTAINABLE EQUITY FUND CLASS A EUR ACC',
          'GLOBAL SUSTAINABLE BOND FUND CLASS B EUR ACC',
        );
        expect(similarity, 0.6);
      });

      test('LF-15.7.3 — familia idéntica salvo estrategia y clase', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'GLOBAL SUSTAINABLE EQUITY FUND CLASS A EUR ACC',
          'GLOBAL SUSTAINABLE BOND FUND CLASS B EUR ACC',
        );

        expect(similarity, closeTo(6 / 10, 0.0001));
      });
    });
  });
}
