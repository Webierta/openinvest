import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test instala un HttpOverrides que bloquea la red.
  // El resolver necesita acceder a CNMV/Yahoo/Morningstar.
  HttpOverrides.global = null;

  test('IsinResolver - integración completa', () async {
    final resolver = IsinResolver();

    final tests = [
      // ------------------------------------------------------------------
      // CNMV / SIL
      // ------------------------------------------------------------------
      (
        name: 'Elcano High Yield Opportunities SIL, S.A.',
        ticker: 'SL020.MC',
        expected: 'ES0128581008',
      ),
      (
        name: 'Rosalita Capital SIL, S.A.',
        ticker: 'SL021.MC',
        expected: 'ES0134934001',
      ),
      (
        name: 'Freecap Investment SIL, S.A.',
        ticker: 'SL024.MC',
        expected: 'ES0139363008',
      ),

      // ------------------------------------------------------------------
      // CNMV / FI - distintas clases del mismo fondo
      // ------------------------------------------------------------------
      (
        name: 'FONMARCH, FI CLASE A',
        ticker: 'FONMARCH-A',
        expected: 'ES0138841038',
      ),
      (
        name: 'FONMARCH, FI CLASE C',
        ticker: 'FONMARCH-C',
        expected: 'ES0138841004',
      ),
      (
        name: 'FONMARCH, FI CLASE S',
        ticker: 'FONMARCH-S',
        expected: 'ES0138841012',
      ),

      // ------------------------------------------------------------------
      // Yahoo / Morningstar - casos extranjeros ya conocidos
      // ------------------------------------------------------------------
      (
        name: 'Carmignac Patrimoine A EUR Acc',
        ticker: 'Y9U6.HM',
        expected: 'FR0010135103',
      ),
      (
        name: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
        ticker: '0P00006DAB',
        expected: 'LU0261948904',
      ),
      (
        name: 'Vontobel Fund - US Dollar Money B USD',
        ticker: '0P00000HZF',
        expected: 'LU0120690226',
      ),

      // ------------------------------------------------------------------
      // NUEVOS: fondos extranjeros reales encontrados en Yahoo Finance.
      //
      // En estos tres casos el ticker de Yahoo contiene el ISIN de la
      // clase, por lo que son especialmente útiles para comprobar la
      // nueva ruta Yahoo -> ISIN directo.
      // ------------------------------------------------------------------
      (
        name: 'BGF Global Corporate Bond Fund A2 USD',
        ticker: 'LU0297942194-USD.LU',
        expected: 'LU0297942194',
      ),
      (
        name: 'AMUNDI FUNDS GLOBAL CORPORATE BOND A USD',
        ticker: 'LU0319688791-USD.LU',
        expected: 'LU0319688791',
      ),
      (
        name: 'UBAM - Global Convertible Bond AC EUR',
        ticker: 'LU0940716078.LU',
        expected: 'LU0940716078',
      ),
    ];

    var correct = 0;

    try {
      for (final testCase in tests) {
        print('\n${'-' * 70}');
        print('TEST: ${testCase.name}');
        print('Ticker:   ${testCase.ticker}');
        print('Esperado: ${testCase.expected}');

        try {
          final result = await resolver.resolve(
            ticker: testCase.ticker,
            fundName: testCase.name,
          );

          print('Obtenido: ${result?.isin ?? 'null'}');
          print('Fuente:   ${result?.source ?? '-'}');
          print('Nombre:   ${result?.officialName ?? '-'}');

          if (result?.isin.toUpperCase() == testCase.expected) {
            print('RESULTADO: CORRECTO');
            correct++;
          } else {
            print('RESULTADO: INCORRECTO');

            fail(
              'ISIN incorrecto para ${testCase.ticker}: '
              'esperado ${testCase.expected}, '
              'obtenido ${result?.isin ?? 'null'}',
            );
          }
        } catch (e, stackTrace) {
          print('EXCEPCION: $e');
          print(stackTrace);
          fail('Excepción resolviendo ${testCase.ticker}: $e');
        }
      }
    } finally {
      resolver.dispose();
    }

    print('\n${'=' * 70}');
    print('RESULTADO FINAL: $correct / ${tests.length}');
    print('${'=' * 70}');

    expect(correct, tests.length);
  });
}
