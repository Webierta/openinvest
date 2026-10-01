import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf7Tests() {
  group('LF-7.1: validación estructural del catálogo', () {
    test('LF-7.1 provider por defecto puede cargar el catálogo real', () async {
      final provider = CnmvLocalFundProvider();

      final results = await provider.findAll(
        fundName: '__FONDO_INEXISTENTE_LF7__',
      );

      expect(results, isEmpty);
    });
    test('LF-7.1a raíz JSON no objeto → FormatException', () async {
      final provider = _provider(onLoad: () => jsonEncode(['no es un objeto']));

      await expectLater(
        provider.findAll(fundName: 'CUALQUIER FONDO'),
        throwsA(isA<FormatException>()),
      );
    });
    test('LF-7.1b ausencia de FondRegistro → FormatException', () async {
      final provider = _provider(onLoad: () => jsonEncode({'OtraClave': {}}));

      await expectLater(
        provider.findAll(fundName: 'CUALQUIER FONDO'),
        throwsA(isA<FormatException>()),
      );
    });
    test('LF-7.1c Entidad inexistente o no lista → FormatException', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {'Entidad': {}},
        }),
      );

      await expectLater(
        provider.findAll(fundName: 'CUALQUIER FONDO'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Regresión de caché por instancia', () {
    test(
      'CACHE-1 provider por defecto reutiliza su carga en consultas sucesivas',
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
  });

  group('Caché global rootBundle y aislamiento', () {
    test(
      'CACHE-2 dos providers por defecto pueden reutilizar la caché global',
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
    test('CACHE-3 un provider con loadAsset personalizado no depende de la caché global', () async {
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

  group('Smoke tests del provider por defecto', () {
    test(
      'SMOKE-1 resolve y findAll funcionan con el provider por defecto',
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
  });

  group('LF-7.2: filtrado de entidades', () {
    test('LF-7.2a entidad que no es Map se ignora', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': ['esto no es una entidad', _validEntity()],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 100);
    });

    test('LF-7.2b Tipo distinto de FI se ignora', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(tipo: 'FIL'),
              _validEntity(
                numeroRegistro: 101,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 101);
    });

    test('LF-7.2c Tipo fi en minúsculas se acepta', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(tipo: 'fi', denominacion: 'FONDO MINUSCULAS, FI'),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO MINUSCULAS, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 100);
    });

    test('LF-7.2d Tipo con espacios se acepta', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(tipo: '  FI  ', denominacion: 'FONDO ESPACIOS, FI'),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO ESPACIOS, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 100);
    });

    test('LF-7.2e NumeroRegistro ausente se ignora', () async {
      final entity = _validEntity();
      entity.remove('NumeroRegistro');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              entity,
              _validEntity(
                numeroRegistro: 102,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 102);
    });

    test('LF-7.2f NumeroRegistro no convertible se ignora', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(numeroRegistro: 'ABC'),
              _validEntity(
                numeroRegistro: 103,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 103);
    });

    test('LF-7.2g Denominacion ausente se ignora', () async {
      final entity = _validEntity();
      entity.remove('Denominacion');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              entity,
              _validEntity(
                numeroRegistro: 104,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 104);
    });

    test('LF-7.2h Denominacion vacía se ignora', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(denominacion: ''),
              _validEntity(
                numeroRegistro: 105,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 105);
    });

    test('LF-7.2i Denominacion solo espacios se ignora', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [
              _validEntity(denominacion: '   '),
              _validEntity(
                numeroRegistro: 106,
                denominacion: 'FONDO VALIDO, FI',
              ),
            ],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 106);
    });

    test(
      'LF-7.2j entidad defectuosa no impide procesar las siguientes',
      () async {
        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [
                'entidad inválida',
                _validEntity(tipo: 'FIL'),
                _validEntity(numeroRegistro: 'ABC'),
                _validEntity(denominacion: ''),
                _validEntity(
                  numeroRegistro: 107,
                  denominacion: 'FONDO VALIDO, FI',
                ),
              ],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.registrationNumber, 107);
      },
    );
  });

  group('LF-7.3: extracción de Gestora y Depositario', () {
    test('LF-7.3a Gestora válida se extrae correctamente', () async {
      final entity = _validEntity();
      entity['Gestora'] = {'DenominacionGestora': 'GESTORA EJEMPLO, S.A.'};

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.managerName, 'GESTORA EJEMPLO, S.A.');
    });

    test('LF-7.3b Depositario válido se extrae correctamente', () async {
      final entity = _validEntity();
      entity['Depositario'] = {
        'DenominacionDepositario': 'DEPOSITARIO EJEMPLO, S.A.',
      };

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.depositaryName, 'DEPOSITARIO EJEMPLO, S.A.');
    });

    test('LF-7.3c Gestora ausente produce null', () async {
      final entity = _validEntity();
      entity.remove('Gestora');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.managerName, isNull);
    });

    test('LF-7.3d Depositario ausente produce null', () async {
      final entity = _validEntity();
      entity.remove('Depositario');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.depositaryName, isNull);
    });

    test('LF-7.3e Gestora null produce null', () async {
      final entity = _validEntity();
      entity['Gestora'] = null;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.managerName, isNull);
    });

    test('LF-7.3f Depositario null produce null', () async {
      final entity = _validEntity();
      entity['Depositario'] = null;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.depositaryName, isNull);
    });

    test('LF-7.3g Gestora que no es Map no invalida la entidad', () async {
      final entity = _validEntity();
      entity['Gestora'] = 'dato inesperado';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 100);
      expect(results.single.managerName, isNull);
    });

    test('LF-7.3h Depositario que no es Map no invalida la entidad', () async {
      final entity = _validEntity();
      entity['Depositario'] = 'dato inesperado';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 100);
      expect(results.single.depositaryName, isNull);
    });

    test('LF-7.3i DenominacionGestora vacía conserva cadena vacía', () async {
      final entity = _validEntity();
      entity['Gestora'] = {'DenominacionGestora': ''};

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.managerName, '');
    });

    test(
      'LF-7.3j DenominacionDepositario vacío conserva cadena vacía',
      () async {
        final entity = _validEntity();
        entity['Depositario'] = {'DenominacionDepositario': ''};

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.depositaryName, '');
      },
    );
  });

  group('LF-7.4: compartimentos, clases y construcción de resultados', () {
    // -------------------------------------------------------------------------
    // LF-7.4.1 — Compartimento
    // -------------------------------------------------------------------------

    test('LF-7.4.1a Compartimento ausente no genera resultados', () async {
      final entity = _validEntity();
      entity.remove('Compartimento');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.1b Compartimento null no genera resultados', () async {
      final entity = _validEntity();
      entity['Compartimento'] = null;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.1c Compartimento como Map se acepta', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [_validEntity()],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, 0);
      expect(results.single.compartmentName, '');
    });

    test(
      'LF-7.4.1d Compartimento como List procesa todos los elementos',
      () async {
        final entity = _validEntity();
        entity['Compartimento'] = [
          {
            'NumeroCompartimento': 1,
            'DenominacionCompartimento': 'COMPARTIMENTO UNO',
            'Clase': {
              'NumeroClase': 1,
              'DenominacionClase': 'CLASE UNO',
              'ISIN': 'ES0138841038',
            },
          },
          {
            'NumeroCompartimento': 2,
            'DenominacionCompartimento': 'COMPARTIMENTO DOS',
            'Clase': {
              'NumeroClase': 2,
              'DenominacionClase': 'CLASE DOS',
              'ISIN': 'ES0138841038',
            },
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(2));
        expect(results[0].compartmentNumber, 1);
        expect(results[0].compartmentName, 'COMPARTIMENTO UNO');
        expect(results[1].compartmentNumber, 2);
        expect(results[1].compartmentName, 'COMPARTIMENTO DOS');
      },
    );

    test('LF-7.4.1e elemento Compartimento no Map se ignora sin afectar a los válidos', () async {
      final entity = _validEntity();
      entity['Compartimento'] = [
        'compartimento inválido',
        {
          'NumeroCompartimento': 3,
          'DenominacionCompartimento': 'COMPARTIMENTO VALIDO',
          'Clase': {
            'NumeroClase': 3,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        },
      ];

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, 3);
      expect(results.single.compartmentName, 'COMPARTIMENTO VALIDO');
    });

    // -------------------------------------------------------------------------
    // LF-7.4.2 — Clase
    // -------------------------------------------------------------------------

    test('LF-7.4.2a Clase ausente no genera resultados', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      compartment.remove('Clase');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.2b Clase null no genera resultados', () async {
      final entity = _validEntity();

      entity['Compartimento'] = <String, dynamic>{
        'NumeroCompartimento': 0,
        'DenominacionCompartimento': '',
        'Clase': null,
      };

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.2c Clase como Map se acepta', () async {
      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [_validEntity()],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.fundClass.number, 0);
      expect(results.single.fundClass.name, 'CLASE BASE');
      expect(results.single.isin, 'ES0138841038');
    });

    test(
      'LF-7.4.2d Clase como List procesa todas las clases válidas',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;

        compartment['Clase'] = [
          {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE UNO',
            'ISIN': 'ES0138841038',
          },
          {
            'NumeroClase': 2,
            'DenominacionClase': 'CLASE DOS',
            'ISIN': 'ES0138841038',
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(2));
        expect(results[0].fundClass.number, 1);
        expect(results[0].fundClass.name, 'CLASE UNO');
        expect(results[1].fundClass.number, 2);
        expect(results[1].fundClass.name, 'CLASE DOS');
      },
    );

    // -------------------------------------------------------------------------
    // LF-7.4.3 — Validación de clase
    // -------------------------------------------------------------------------

    test('LF-7.4.3a NumeroClase ausente descarta la clase', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final clase = compartment['Clase'] as Map<String, dynamic>;
      clase.remove('NumeroClase');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.3b NumeroClase no convertible descarta la clase', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final clase = compartment['Clase'] as Map<String, dynamic>;
      clase['NumeroClase'] = 'ABC';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test('LF-7.4.3c DenominacionClase ausente descarta la clase', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final clase = compartment['Clase'] as Map<String, dynamic>;
      clase.remove('DenominacionClase');

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test(
      'LF-7.4.3d DenominacionClase vacía o espacios descarta la clase',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;
        final clase = compartment['Clase'] as Map<String, dynamic>;
        clase['DenominacionClase'] = '   ';

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, isEmpty);
      },
    );

    test(
      'LF-7.4.3e DenominacionClase aplica trim sin normalización adicional',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;
        final clase = compartment['Clase'] as Map<String, dynamic>;
        clase['DenominacionClase'] = '  CLASE CON ESPACIOS  ';

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.fundClass.name, 'CLASE CON ESPACIOS');
      },
    );

    test('LF-7.4.3f ISIN se recorta y convierte a mayúsculas', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final clase = compartment['Clase'] as Map<String, dynamic>;
      clase['ISIN'] = '  es0138841038  ';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.fundClass.isin, 'ES0138841038');
    });

    test('LF-7.4.3g ISIN inválido descarta la clase', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final clase = compartment['Clase'] as Map<String, dynamic>;
      clase['ISIN'] = 'ISIN_INVALIDO';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, isEmpty);
    });

    test(
      'LF-7.4.3h clase inválida no impide procesar las siguientes',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;

        compartment['Clase'] = [
          {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE INVALIDA',
            'ISIN': 'ISIN_INVALIDO',
          },
          {
            'NumeroClase': 2,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.fundClass.number, 2);
        expect(results.single.fundClass.name, 'CLASE VALIDA');
      },
    );

    // -------------------------------------------------------------------------
    // LF-7.4.4 — Construcción de CnmvFundResult
    // -------------------------------------------------------------------------

    test(
      'LF-7.4.4a conserva todos los datos de Entidad, Compartimento y Clase',
      () async {
        final entity = {
          'Tipo': 'FI',
          'NumeroRegistro': 700,
          'Denominacion': 'FONDO COMPLETO, FI',
          'Gestora': {'DenominacionGestora': 'GESTORA COMPLETA, S.A.'},
          'Depositario': {
            'DenominacionDepositario': 'DEPOSITARIO COMPLETO, S.A.',
          },
          'Compartimento': {
            'NumeroCompartimento': 7,
            'DenominacionCompartimento': 'COMPARTIMENTO COMPLETO',
            'Clase': {
              'NumeroClase': 9,
              'DenominacionClase': 'CLASE COMPLETA',
              'ISIN': 'ES0138841038',
            },
          },
        };

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO COMPLETO, FI');

        expect(results, hasLength(1));

        final result = results.single;

        expect(result.registrationNumber, 700);
        expect(result.fundName, 'FONDO COMPLETO, FI');
        expect(result.managerName, 'GESTORA COMPLETA, S.A.');
        expect(result.depositaryName, 'DEPOSITARIO COMPLETO, S.A.');

        expect(result.compartmentNumber, 7);
        expect(result.compartmentName, 'COMPARTIMENTO COMPLETO');

        expect(result.fundClass.number, 9);
        expect(result.fundClass.name, 'CLASE COMPLETA');
        expect(result.fundClass.isin, 'ES0138841038');
        expect(result.isin, 'ES0138841038');
      },
    );

    test(
      'LF-7.4.4b cada clase válida genera un resultado independiente',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;

        compartment['Clase'] = [
          {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE UNO',
            'ISIN': 'ES0138841038',
          },
          {
            'NumeroClase': 2,
            'DenominacionClase': 'CLASE DOS',
            'ISIN': 'ES0138841038',
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(2));
        expect(results[0].fundClass.number, 1);
        expect(results[0].fundClass.name, 'CLASE UNO');
        expect(results[1].fundClass.number, 2);
        expect(results[1].fundClass.name, 'CLASE DOS');
      },
    );

    test(
      'LF-7.4.4c varios compartimentos conservan su correspondencia',
      () async {
        final entity = _validEntity();

        entity['Compartimento'] = [
          {
            'NumeroCompartimento': 10,
            'DenominacionCompartimento': 'COMPARTIMENTO A',
            'Clase': {
              'NumeroClase': 1,
              'DenominacionClase': 'CLASE A',
              'ISIN': 'ES0138841038',
            },
          },
          {
            'NumeroCompartimento': 20,
            'DenominacionCompartimento': 'COMPARTIMENTO B',
            'Clase': {
              'NumeroClase': 2,
              'DenominacionClase': 'CLASE B',
              'ISIN': 'ES0138841038',
            },
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(2));

        expect(results[0].compartmentNumber, 10);
        expect(results[0].compartmentName, 'COMPARTIMENTO A');
        expect(results[0].fundClass.number, 1);
        expect(results[0].fundClass.name, 'CLASE A');

        expect(results[1].compartmentNumber, 20);
        expect(results[1].compartmentName, 'COMPARTIMENTO B');
        expect(results[1].fundClass.number, 2);
        expect(results[1].fundClass.name, 'CLASE B');
      },
    );
  });

  group('LF-7.5: conversión de valores numéricos', () {
    test('LF-7.5.1 NumeroRegistro int válido se conserva', () async {
      final entity = _validEntity(numeroRegistro: 123);

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 123);
    });

    test(
      'LF-7.5.2 NumeroRegistro string numérico se convierte a int',
      () async {
        final entity = _validEntity(numeroRegistro: '123');

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.registrationNumber, 123);
      },
    );

    test(
      'LF-7.5.3 NumeroRegistro no convertible descarta la entidad',
      () async {
        final entity = _validEntity(numeroRegistro: 'abc');

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, isEmpty);
      },
    );

    test('LF-7.5.4 NumeroCompartimento null produce null', () async {
      final entity = _validEntity();

      entity['Compartimento'] = <String, dynamic>{
        'NumeroCompartimento': null,
        'DenominacionCompartimento': '',
        'Clase': {
          'NumeroClase': 0,
          'DenominacionClase': 'CLASE BASE',
          'ISIN': 'ES0138841038',
        },
      };

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, isNull);
    });

    test(
      'LF-7.5.5 NumeroCompartimento string numérico se convierte a int',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;
        compartment['NumeroCompartimento'] = '123';

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.compartmentNumber, 123);
      },
    );

    test('LF-7.5.6 NumeroCompartimento no convertible produce null', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      compartment['NumeroCompartimento'] = 'abc';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, isNull);
    });

    test('LF-7.5.7 NumeroClase int válido se conserva', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final classe = compartment['Clase'] as Map<String, dynamic>;
      classe['NumeroClase'] = 123;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.fundClass.number, 123);
    });

    test('LF-7.5.8 NumeroClase string numérico se convierte a int', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final classe = compartment['Clase'] as Map<String, dynamic>;
      classe['NumeroClase'] = '123';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.fundClass.number, 123);
    });

    test('LF-7.5.9 NumeroClase no convertible descarta la clase', () async {
      final entity = _validEntity();
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      final classes = [
        {
          'NumeroClase': 'abc',
          'DenominacionClase': 'CLASE INVALIDA',
          'ISIN': 'ES0138841038',
        },
        {
          'NumeroClase': 2,
          'DenominacionClase': 'CLASE VALIDA',
          'ISIN': 'ES0138841038',
        },
      ];
      compartment['Clase'] = classes;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.fundClass.number, 2);
      expect(results.single.fundClass.name, 'CLASE VALIDA');
    });

    test('LF-7.5.10 valores cero y negativos son aceptados', () async {
      final entity = _validEntity(numeroRegistro: -1);
      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      compartment['NumeroCompartimento'] = -2;

      final classe = compartment['Clase'] as Map<String, dynamic>;
      classe['NumeroClase'] = 0;

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, -1);
      expect(results.single.compartmentNumber, -2);
      expect(results.single.fundClass.number, 0);
    });

    test('LF-7.5.11 espacios alrededor de un número son aceptados', () async {
      final entity = _validEntity(numeroRegistro: ' 123 ');

      final compartment = entity['Compartimento'] as Map<String, dynamic>;
      compartment['NumeroCompartimento'] = ' 456 ';

      final classe = compartment['Clase'] as Map<String, dynamic>;
      classe['NumeroClase'] = ' 789 ';

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.registrationNumber, 123);
      expect(results.single.compartmentNumber, 456);
      expect(results.single.fundClass.number, 789);
    });
  });

  group('LF-7.6: tolerancia a registros defectuosos durante la carga', () {
    test(
      'LF-7.6.1a elemento Entidad no Map se ignora y se procesa el siguiente',
      () async {
        final validEntity = _validEntity();

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': ['elemento inválido', validEntity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.registrationNumber, 100);
      },
    );

    test(
      'LF-7.6.1b entidad Map inválida no interrumpe la siguiente entidad',
      () async {
        final invalidEntity = <String, dynamic>{
          'Tipo': 'FI',
          'NumeroRegistro': 'abc',
          'Denominacion': 'FONDO INVALIDO, FI',
        };

        final validEntity = _validEntity(numeroRegistro: 200);

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [invalidEntity, validEntity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.registrationNumber, 200);
      },
    );

    test('LF-7.6.2a elemento Compartimento no Map se ignora y se procesa el siguiente', () async {
      final entity = _validEntity();
      entity['Compartimento'] = [
        'elemento inválido',
        {
          'NumeroCompartimento': 2,
          'DenominacionCompartimento': 'COMPARTIMENTO VALIDO',
          'Clase': {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        },
      ];

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, 2);
      expect(results.single.compartmentName, 'COMPARTIMENTO VALIDO');
    });

    test('LF-7.6.2b compartimento sin Clase no interrumpe el siguiente compartimento', () async {
      final entity = _validEntity();
      entity['Compartimento'] = [
        {'NumeroCompartimento': 1, 'DenominacionCompartimento': 'SIN CLASE'},
        {
          'NumeroCompartimento': 2,
          'DenominacionCompartimento': 'CON CLASE',
          'Clase': {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        },
      ];

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(1));
      expect(results.single.compartmentNumber, 2);
      expect(results.single.compartmentName, 'CON CLASE');
    });

    test(
      'LF-7.6.3a elemento Clase no Map se ignora y se procesa la siguiente',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;

        compartment['Clase'] = [
          'elemento inválido',
          {
            'NumeroClase': 2,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.fundClass.number, 2);
        expect(results.single.fundClass.name, 'CLASE VALIDA');
      },
    );

    test(
      'LF-7.6.3b clase inválida no interrumpe la siguiente clase válida',
      () async {
        final entity = _validEntity();
        final compartment = entity['Compartimento'] as Map<String, dynamic>;

        compartment['Clase'] = [
          {
            'NumeroClase': 'abc',
            'DenominacionClase': 'CLASE INVALIDA',
            'ISIN': 'ES0138841038',
          },
          {
            'NumeroClase': 2,
            'DenominacionClase': 'CLASE VALIDA',
            'ISIN': 'ES0138841038',
          },
        ];

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [entity],
            },
          }),
        );

        final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

        expect(results, hasLength(1));
        expect(results.single.fundClass.number, 2);
        expect(results.single.fundClass.name, 'CLASE VALIDA');
      },
    );

    test(
      'LF-7.6.4a entidad inválida entre dos válidas no afecta a las válidas',
      () async {
        final first = _validEntity(
          numeroRegistro: 101,
          denominacion: 'FONDO UNO, FI',
        );
        final invalid = <String, dynamic>{
          'Tipo': 'FI',
          'NumeroRegistro': 'abc',
          'Denominacion': 'FONDO INVALIDO, FI',
        };
        final third = _validEntity(
          numeroRegistro: 103,
          denominacion: 'FONDO TRES, FI',
        );

        final provider = _provider(
          onLoad: () => jsonEncode({
            'FondRegistro': {
              'Entidad': [first, invalid, third],
            },
          }),
        );

        final firstResults = await provider.findAll(fundName: 'FONDO UNO, FI');
        final thirdResults = await provider.findAll(fundName: 'FONDO TRES, FI');

        expect(firstResults, hasLength(1));
        expect(firstResults.single.registrationNumber, 101);

        expect(thirdResults, hasLength(1));
        expect(thirdResults.single.registrationNumber, 103);
      },
    );

    test('LF-7.6.4b compartimento inválido entre dos válidos no afecta a los válidos', () async {
      final entity = _validEntity();
      entity['Compartimento'] = [
        {
          'NumeroCompartimento': 1,
          'DenominacionCompartimento': 'PRIMERO',
          'Clase': {
            'NumeroClase': 1,
            'DenominacionClase': 'CLASE UNO',
            'ISIN': 'ES0138841038',
          },
        },
        'compartimento inválido',
        {
          'NumeroCompartimento': 3,
          'DenominacionCompartimento': 'TERCERO',
          'Clase': {
            'NumeroClase': 3,
            'DenominacionClase': 'CLASE TRES',
            'ISIN': 'ES0138841038',
          },
        },
      ];

      final provider = _provider(
        onLoad: () => jsonEncode({
          'FondRegistro': {
            'Entidad': [entity],
          },
        }),
      );

      final results = await provider.findAll(fundName: 'FONDO VALIDO, FI');

      expect(results, hasLength(2));

      expect(results[0].compartmentNumber, 1);
      expect(results[0].compartmentName, 'PRIMERO');
      expect(results[0].fundClass.number, 1);

      expect(results[1].compartmentNumber, 3);
      expect(results[1].compartmentName, 'TERCERO');
      expect(results[1].fundClass.number, 3);
    });
  });
}

CnmvLocalFundProvider _provider({required String Function() onLoad}) {
  return CnmvLocalFundProvider(loadAsset: (_) async => onLoad());
}

Map<String, dynamic> _validEntity({
  String tipo = 'FI',
  dynamic numeroRegistro = 100,
  String denominacion = 'FONDO VALIDO, FI',
}) {
  return {
    'Tipo': tipo,
    'NumeroRegistro': numeroRegistro,
    'Denominacion': denominacion,
    'Compartimento': {
      'NumeroCompartimento': 0,
      'DenominacionCompartimento': '',
      'Clase': {
        'NumeroClase': 0,
        'DenominacionClase': 'CLASE BASE',
        'ISIN': 'ES0138841038',
      },
    },
  };
}
