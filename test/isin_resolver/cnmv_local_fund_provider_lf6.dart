import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf6Tests() {
  group('CnmvLocalFundProvider — LF-6: carga y caché', () {
    test('LF-6.1 una misma instancia carga el asset una sola vez', () async {
      var loadCount = 0;

      final provider = _provider(
        onLoad: () {
          loadCount++;
          return _validJson();
        },
      );

      await provider.resolve(fundName: 'FONDO CACHE, FI');
      await provider.resolve(fundName: 'FONDO CACHE, FI');
      await provider.findAll(fundName: 'FONDO CACHE, FI');

      expect(loadCount, 1);
    });

    test(
      'LF-6.2 resolve y findAll comparten la caché de la instancia',
      () async {
        var loadCount = 0;

        final provider = _provider(
          onLoad: () {
            loadCount++;
            return _validJson();
          },
        );

        final first = await provider.resolve(fundName: 'FONDO CACHE, FI');
        final all = await provider.findAll(fundName: 'FONDO CACHE, FI');

        expect(first, isNotNull);
        expect(all, hasLength(1));
        expect(loadCount, 1);
      },
    );

    test(
      'LF-6.3 una carga válida sin resultados también queda cacheada',
      () async {
        var loadCount = 0;

        final provider = _provider(
          onLoad: () {
            loadCount++;
            return _validJsonWithoutClasses();
          },
        );

        final first = await provider.findAll(fundName: 'FONDO INEXISTENTE, FI');
        final second = await provider.findAll(fundName: 'OTRO FONDO, FI');

        expect(first, isEmpty);
        expect(second, isEmpty);
        expect(loadCount, 1);
      },
    );

    test(
      'LF-6.4 si la carga falla, el siguiente intento vuelve a cargar',
      () async {
        var loadCount = 0;

        final provider = _provider(
          onLoad: () {
            loadCount++;

            if (loadCount == 1) {
              throw const FormatException('JSON temporalmente inválido');
            }

            return _validJson();
          },
        );

        await expectLater(
          provider.resolve(fundName: 'FONDO CACHE, FI'),
          throwsA(isA<FormatException>()),
        );

        final result = await provider.resolve(fundName: 'FONDO CACHE, FI');

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
        expect(loadCount, 2);
      },
    );

    test('LF-6.5 dos instancias con loadAsset personalizado tienen cachés independientes', () async {
      var loadCountA = 0;
      var loadCountB = 0;

      final providerA = _provider(
        onLoad: () {
          loadCountA++;
          return _validJson();
        },
      );

      final providerB = _provider(
        onLoad: () {
          loadCountB++;
          return _validJson();
        },
      );

      await providerA.resolve(fundName: 'FONDO CACHE, FI');
      await providerA.resolve(fundName: 'FONDO CACHE, FI');

      await providerB.resolve(fundName: 'FONDO CACHE, FI');

      expect(loadCountA, 1);
      expect(loadCountB, 1);
    });

    test(
      'LF-6.6 construir el provider no carga el asset de forma inmediata',
      () async {
        var loadCount = 0;

        _provider(
          onLoad: () {
            loadCount++;
            return _validJson();
          },
        );

        expect(loadCount, 0);
      },
    );

    test(
      'LF-6.7 una vez cargado, las consultas vacías no fuerzan otra carga',
      () async {
        var loadCount = 0;

        final provider = _provider(
          onLoad: () {
            loadCount++;
            return _validJson();
          },
        );

        await provider.resolve(fundName: 'FONDO CACHE, FI');

        final result1 = await provider.findAll(fundName: '   ');
        final result2 = await provider.resolve(fundName: '');

        expect(result1, isEmpty);
        expect(result2, isNull);
        expect(loadCount, 1);
      },
    );
  });
}

CnmvLocalFundProvider _provider({required String Function() onLoad}) {
  return CnmvLocalFundProvider(loadAsset: (_) async => onLoad());
}

String _validJson() {
  return jsonEncode({
    'FondRegistro': {
      'FechaDatos': '202605',
      'Entidad': [
        {
          'Tipo': 'FI',
          'NumeroRegistro': 100,
          'Denominacion': 'FONDO CACHE, FI',
          'Compartimento': {
            'NumeroCompartimento': 0,
            'DenominacionCompartimento': '',
            'Clase': [
              {
                'NumeroClase': 0,
                'DenominacionClase': 'CLASE BASE',
                'ISIN': 'ES0138841038',
              },
            ],
          },
        },
      ],
    },
  });
}

String _validJsonWithoutClasses() {
  return jsonEncode({
    'FondRegistro': {
      'FechaDatos': '202605',
      'Entidad': [
        {
          'Tipo': 'FI',
          'NumeroRegistro': 101,
          'Denominacion': 'FONDO SIN CLASES, FI',
          'Compartimento': {
            'NumeroCompartimento': 0,
            'DenominacionCompartimento': '',
          },
        },
      ],
    },
  });
}
