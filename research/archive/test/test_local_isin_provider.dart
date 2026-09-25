/*
import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/local_isin_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalIsinProvider', () {
    late LocalIsinProvider provider;

    setUp(() {
      provider = LocalIsinProvider(
        loadAsset: (path) async {
          if (path != LocalIsinProvider.assetPath) {
            throw StateError('Asset inesperado: $path');
          }

          return '''
{
  "version": 1,
  "generatedAt": "2026-09-20",
  "entries": [
    {
      "morningstarId": "0P00000FB4",
      "isin": "FR0010135103",
      "name": "Carmignac Patrimoine A EUR Acc",
      "ticker": "Y9U6.HM"
    },
    {
      "morningstarId": "0P00006DAB",
      "isin": "LU0261948904",
      "name": "Fidelity Iberia A-Acc-EUR",
      "ticker": "0P00006DAB.F"
    },
    {
      "morningstarId": "0P00000HZF",
      "isin": "LU0120690226",
      "name": "Vontobel Fund - US Dollar Money B USD",
      "ticker": "0P00000HZF.F"
    }
  ]
}
''';
        },
      );
    });

    test('Carmignac: Y9U6.HM -> FR0010135103', () async {
      final isin = await provider.resolve(
        ticker: 'Y9U6.HM',
        fundName: 'Carmignac Patrimoine A EUR Acc',
        yahooSymbol: 'Y9U6.HM',
        yahooName: 'Carmignac Patrimoine A EUR Acc',
      );

      expect(isin, 'FR0010135103');
    });

    test('Fidelity: 0P00006DAB.F -> LU0261948904', () async {
      final isin = await provider.resolve(
        ticker: '0P00006DAB.F',
        fundName: 'Fidelity Iberia A-Acc-EUR',
        yahooSymbol: '0P00006DAB.F',
        yahooName: 'Fidelity Iberia A-Acc-EUR',
      );

      expect(isin, 'LU0261948904');
    });

    test('Vontobel: 0P00000HZF.F -> LU0120690226', () async {
      final isin = await provider.resolve(
        ticker: '0P00000HZF.F',
        fundName: 'Vontobel Fund - US Dollar Money B USD',
        yahooSymbol: '0P00000HZF.F',
        yahooName: 'Vontobel US Dollar Money B USD',
      );

      expect(isin, 'LU0120690226');
    });

    test(
      'resuelve por Morningstar ID aunque el ticker sea diferente',
      () async {
        final isin = await provider.resolve(
          ticker: 'OTRO.TICKER',
          fundName: 'Fidelity Iberia A-Acc-EUR',
          yahooSymbol: '0P00006DAB.X',
          yahooName: 'Fidelity Iberia A-Acc-EUR',
        );

        expect(isin, 'LU0261948904');
      },
    );

    test('resuelve por ticker aunque no haya Morningstar ID', () async {
      final isin = await provider.resolve(
        ticker: 'Y9U6.HM',
        fundName: 'Nombre desconocido',
        yahooSymbol: 'Y9U6.HM',
        yahooName: 'Nombre desconocido',
      );

      expect(isin, 'FR0010135103');
    });

    test('resuelve por nombre', () async {
      final isin = await provider.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Carmignac Patrimoine A EUR Acc',
        yahooSymbol: 'UNKNOWN',
        yahooName: 'Carmignac Patrimoine A EUR Acc',
      );

      expect(isin, 'FR0010135103');
    });

    test('devuelve null cuando no encuentra el fondo', () async {
      final isin = await provider.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Fondo que no existe',
        yahooSymbol: 'UNKNOWN',
        yahooName: 'Fondo que no existe',
      );

      expect(isin, isNull);
    });

    test('rechaza ISIN con checksum incorrecto', () async {
      final invalidProvider = LocalIsinProvider(
        loadAsset: (_) async => '''
{
  "version": 1,
  "entries": [
    {
      "morningstarId": "0P99999999",
      "isin": "FR0010135104",
      "name": "ISIN incorrecto",
      "ticker": "BAD.F"
    }
  ]
}
''',
      );

      final isin = await invalidProvider.resolve(
        ticker: 'BAD.F',
        fundName: 'ISIN incorrecto',
        yahooSymbol: '0P99999999',
        yahooName: 'ISIN incorrecto',
      );

      expect(isin, isNull);
    });
  });
}
*/
