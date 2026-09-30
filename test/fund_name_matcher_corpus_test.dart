import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/fund_name_matcher.dart';

void main() {
  group('FundNameMatcher - corpus real', () {
    // =========================================================================
    // IDENTIDAD
    // =========================================================================

    group('Identidad', () {
      test('nombres idénticos', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ABACO RENTA FIJA, FI',
            'ABACO RENTA FIJA, FI',
          ),
          1.0,
        );
      });

      test('diferencias de mayúsculas, espacios y puntuación', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'Abaco Renta Fija, FI',
            'ABACO   RENTA FIJA FI',
          ),
          1.0,
        );
      });

      test('acentos no alteran la similitud', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'FONDMAPFRE ELECCIÓN DECIDIDA, FI',
            'FONDMAPFRE ELECCION DECIDIDA, FI',
          ),
          1.0,
        );
      });
    });

    // =========================================================================
    // REORDENACIÓN
    // =========================================================================

    group('Reordenación', () {
      test('reordenación de tokens mantiene similitud 1', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'RURAL 2025 GARANTIA BOLSA, FI',
            'RURAL GARANTIA BOLSA 2025, FI',
          ),
          1.0,
        );
      });

      test('otra reordenación real del corpus', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'RURAL 2027 GARANTIA BOLSA, FI',
            'RURAL BOLSA 2027 GARANTIA, FI',
          ),
          1.0,
        );
      });
    });

    // =========================================================================
    // ADICIÓN / ELIMINACIÓN DE TOKEN
    // =========================================================================

    group('Adición y eliminación de tokens', () {
      test('añadir MASTER', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'CAIXABANK RENTA FIJA CORTO PLAZO, FI',
            'CAIXABANK MASTER RENTA FIJA CORTO PLAZO, FI',
          ),
          closeTo(0.8571428571, 0.0000000001),
        );
      });

      test('añadir FLEXIBLE', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'GVC GAESCO RENTA FIJA, FI',
            'GVC GAESCO RENTA FIJA FLEXIBLE, FI',
          ),
          closeTo(0.8333333333, 0.0000000001),
        );
      });

      test('eliminar II', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ALTERALIA DEBT FUND II, FIL',
            'ALTERALIA DEBT FUND, FIL',
          ),
          closeTo(0.8, 0.0000000001),
        );
      });

      test('eliminar EUROPA', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BBVA BOLSA EUROPA, FI',
            'BBVA BOLSA, FI',
          ),
          closeTo(0.75, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // AÑOS
    // =========================================================================

    group('Series por año', () {
      test('2025 frente a 2027', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BBVA BONOS 2025,FI',
            'BBVA BONOS 2027, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });

      test('2025 frente a 2026', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BANKINTER DEUDA PUBLICA 2025, FI',
            'BANKINTER DEUDA PUBLICA 2026, FI',
          ),
          closeTo(0.6666666667, 0.0000000001),
          //closeTo(0.6, 0.0000000001),
        );
      });

      test('mismo producto, distinto año y misma serie', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'CAIXABANK DEUDA PUBLICA ESPAÑA ITALIA 2025 2, FI',
            'CAIXABANK DEUDA PUBLICA ESPAÑA ITALIA 2027 2, FI',
          ),
          closeTo(0.7777777778, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // SERIES ROMANAS
    // =========================================================================

    group('Series romanas', () {
      test('II frente a III', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ALTERALIA DEBT FUND II, FIL',
            'ALTERALIA DEBT FUND III, FIL',
          ),
          closeTo(0.6666666667, 0.0000000001),
        );
      });

      test('II frente a III en una serie con año', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BBVA BONOS 2025 II, FI',
            'BBVA BONOS 2025 III, FI',
          ),
          closeTo(0.6666666667, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // VARIANTES DE PRODUCTO
    // =========================================================================

    group('Variantes de producto', () {
      test('RENTA FIJA frente a RENTA VARIABLE', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ABANCA RENTA FIJA MIXTA, FI',
            'ABANCA RENTA VARIABLE MIXTA, FI',
          ),
          closeTo(0.6666666667, 0.0000000001),
        );
      });

      test('CONSERVADOR frente a MODERADO', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'RURAL PERFIL CONSERVADOR, FI',
            'RURAL PERFIL MODERADO, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });

      test('PLATEA frente a PREMIUM', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BANKINTER PLATEA AGRESIVO, FI',
            'BANKINTER PREMIUM AGRESIVO, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });

      test('GARANTIZADO frente a OBJETIVO', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ABANCA GARANTIZADO 2025, FI',
            'ABANCA OBJETIVO 2025, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // GEOGRAFÍA
    // =========================================================================

    group('Variantes geográficas', () {
      test('ESPAÑA frente a USA', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'IBERCAJA BOLSA ESPAÑA, FI',
            'IBERCAJA BOLSA USA, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });

      test('EUROPA frente a USA', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'CAIXABANK BOLSA SELECCION EUROPA, FI',
            'CAIXABANK BOLSA SELECCION USA, FI',
          ),
          closeTo(0.6666666667, 0.0000000001),
        );
      });

      test('ESPAÑA frente a EUROPA', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ABANCA RENTA VARIABLE ESPAÑA, FI',
            'ABANCA RENTA VARIABLE EUROPA, FI',
          ),
          //closeTo(0.6, 0.0000000001),
          closeTo(0.6666666667, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // ENTIDAD / GESTORA
    // =========================================================================

    group('Cambio de entidad', () {
      test('BANKINTER frente a CAIXABANK', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'BANKINTER DEUDA PUBLICA 2025, FI',
            'CAIXABANK DEUDA PUBLICA 2025, FI',
          ),
          closeTo(0.6666666667, 0.0000000001),
        );
      });

      test('ABANCA frente a SANTANDER', () {
        expect(
          FundNameMatcher.nameSimilarity(
            'ABANCA GARANTIZADO 2025, FI',
            'SANTANDER GARANTIZADO 2025, FI',
          ),
          closeTo(0.6, 0.0000000001),
        );
      });
    });

    // =========================================================================
    // CASOS CONCRETOS DE ALTA SIMILITUD QUE DEBEMOS ESTUDIAR
    // =========================================================================

    group('Casos de alta similitud para decisión posterior', () {
      test('MASTER añadido: alta similitud', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'CAIXABANK RENTA FIJA CORTO PLAZO, FI',
          'CAIXABANK MASTER RENTA FIJA CORTO PLAZO, FI',
        );

        expect(similarity, greaterThan(0.80));
      });

      test('FIJA/VARIABLE: similitud alta pero diferencia significativa', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ABANCA RENTA FIJA MIXTA, FI',
          'ABANCA RENTA VARIABLE MIXTA, FI',
        );

        expect(similarity, greaterThan(0.60));
      });

      test('ESPAÑA/USA: similitud alta pero diferencia geográfica', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'IBERCAJA BOLSA ESPAÑA, FI',
          'IBERCAJA BOLSA USA, FI',
        );

        expect(similarity, greaterThanOrEqualTo(0.60));
      });

      test('entidad diferente con denominación similar', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025, FI',
          'CAIXABANK DEUDA PUBLICA 2025, FI',
        );

        expect(similarity, greaterThanOrEqualTo(0.60));
      });
    });

    group('Casos potencialmente peligrosos', () {
      test('RENTA FIJA frente a RENTA VARIABLE', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ABANCA RENTA FIJA MIXTA, FI',
          'ABANCA RENTA VARIABLE MIXTA, FI',
        );

        expect(similarity, 0.6666666666666666);
      });

      test('CONSERVADOR frente a MODERADO', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'RURAL PERFIL CONSERVADOR, FI',
          'RURAL PERFIL MODERADO, FI',
        );

        expect(similarity, 0.6);
      });

      test('ESPAÑA frente a USA', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'IBERCAJA BOLSA ESPAÑA, FI',
          'IBERCAJA BOLSA USA, FI',
        );

        expect(similarity, 0.6);
      });

      test('BANKINTER frente a CAIXABANK', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'BANKINTER DEUDA PUBLICA 2025, FI',
          'CAIXABANK DEUDA PUBLICA 2025, FI',
        );

        expect(similarity, 0.6666666666666666);
      });

      test('ALTERALIA II frente a ALTERALIA III', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ALTERALIA DEBT FUND II, FIL',
          'ALTERALIA DEBT FUND III, FIL',
        );

        expect(similarity, 0.6666666666666666);
      });

      test('ALTERALIA II frente a nombre sin número de serie', () {
        final similarity = FundNameMatcher.nameSimilarity(
          'ALTERALIA DEBT FUND II, FIL',
          'ALTERALIA DEBT FUND, FIL',
        );

        expect(similarity, 0.8);
      });
    });
  });
}
