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
  });
}
