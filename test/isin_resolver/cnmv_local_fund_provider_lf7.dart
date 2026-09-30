import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf7Tests() {
  group('CnmvLocalFundProvider — LF-7: caché global rootBundle', () {
    test('LF-7.1 provider por defecto puede cargar el catálogo real', () async {
      final provider = CnmvLocalFundProvider();

      final results = await provider.findAll(
        fundName: '__FONDO_INEXISTENTE_LF7__',
      );

      expect(results, isEmpty);
    });

    test(
      'LF-7.2 provider por defecto reutiliza su carga en consultas sucesivas',
      () async {
        final provider = CnmvLocalFundProvider();

        final first = await provider.findAll(
          fundName: '__FONDO_INEXISTENTE_LF7_A__',
        );
        final second = await provider.findAll(
          fundName: '__FONDO_INEXISTENTE_LF7_B__',
        );

        expect(first, isEmpty);
        expect(second, isEmpty);
      },
    );

    test(
      'LF-7.3 dos providers por defecto pueden reutilizar la caché global',
      () async {
        final providerA = CnmvLocalFundProvider();
        final providerB = CnmvLocalFundProvider();

        final resultsA = await providerA.findAll(
          fundName: '__FONDO_INEXISTENTE_LF7_A__',
        );
        final resultsB = await providerB.findAll(
          fundName: '__FONDO_INEXISTENTE_LF7_B__',
        );

        expect(resultsA, isEmpty);
        expect(resultsB, isEmpty);
      },
    );

    test(
      'LF-7.4 resolve y findAll funcionan con el provider por defecto',
      () async {
        final provider = CnmvLocalFundProvider();

        final all = await provider.findAll(
          fundName: '__FONDO_INEXISTENTE_LF7__',
        );
        final resolved = await provider.resolve(
          fundName: '__FONDO_INEXISTENTE_LF7__',
        );

        expect(all, isEmpty);
        expect(resolved, isNull);
      },
    );

    test('LF-7.5 un provider con loadAsset personalizado no depende de la caché global', () async {
      var loadCount = 0;

      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async {
          loadCount++;

          return '''
{
  "FondRegistro": {
    "FechaDatos": "LF7",
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 700,
        "Denominacion": "FONDO LF7, FI",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": [
            {
              "NumeroClase": 0,
              "DenominacionClase": "CLASE LF7",
              "ISIN": "ES0138841038"
            }
          ]
        }
      }
    ]
  }
}
''';
        },
      );

      final results = await provider.findAll(fundName: 'FONDO LF7, FI');

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0138841038');
      expect(loadCount, 1);
    });
  });
}
