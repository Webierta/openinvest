import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf2Tests() {
  group('CnmvLocalFundProvider — LF-2: jerarquía', () {
    test('LF-2.1 FI con una clase y un compartimento', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 1,
        "Denominacion": "FONDO SIMPLE, FI",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE BASE",
            "ISIN": "ES0138841038"
          }
        }
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(fundName: 'FONDO SIMPLE, FI');

      expect(result, isNotNull);
      expect(result!.registrationNumber, 1);
      expect(result.fundName, 'FONDO SIMPLE, FI');
      expect(result.compartmentNumber, 0);
      expect(result.compartmentName, '');
      expect(result.fundClass.number, 0);
      expect(result.fundClass.name, 'CLASE BASE');
      expect(result.isin, 'ES0138841038');
    });

    test('LF-2.2 FI con compartimento y una clase', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 2,
        "Denominacion": "FONDO COMPARTIMENTADO, FI",
        "Compartimento": {
          "NumeroCompartimento": 1,
          "DenominacionCompartimento": "COMPARTIMENTO EURO",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE BASE",
            "ISIN": "ES0138823036"
          }
        }
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(
        fundName: 'FONDO COMPARTIMENTADO, FI',
      );

      expect(result, isNotNull);
      expect(result!.registrationNumber, 2);
      expect(result.compartmentNumber, 1);
      expect(result.compartmentName, 'COMPARTIMENTO EURO');
      expect(result.fundClass.number, 0);
      expect(result.fundClass.name, 'CLASE BASE');
      expect(result.isin, 'ES0138823036');
    });

    test('LF-2.3 FI con varios compartimentos', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 3,
        "Denominacion": "FONDO MULTICOMPARTIMENTO, FI",
        "Compartimento": [
          {
            "NumeroCompartimento": 1,
            "DenominacionCompartimento": "COMPARTIMENTO EURO",
            "Clase": {
              "NumeroClase": 0,
              "DenominacionClase": "CLASE EURO",
              "ISIN": "ES0138823036"
            }
          },
          {
            "NumeroCompartimento": 2,
            "DenominacionCompartimento": "COMPARTIMENTO GLOBAL",
            "Clase": {
              "NumeroClase": 0,
              "DenominacionClase": "CLASE GLOBAL",
              "ISIN": "ES0138823002"
            }
          }
        ]
      }
    ]
  }
}
''',
      );

      final results = await provider.findAll(
        fundName: 'FONDO MULTICOMPARTIMENTO, FI',
      );

      expect(results, hasLength(2));

      expect(results[0].compartmentNumber, 1);
      expect(results[0].compartmentName, 'COMPARTIMENTO EURO');
      expect(results[0].fundClass.name, 'CLASE EURO');
      expect(results[0].isin, 'ES0138823036');

      expect(results[1].compartmentNumber, 2);
      expect(results[1].compartmentName, 'COMPARTIMENTO GLOBAL');
      expect(results[1].fundClass.name, 'CLASE GLOBAL');
      expect(results[1].isin, 'ES0138823002');
    });

    test('LF-2.4 un compartimento con varias clases', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 4,
        "Denominacion": "FONDO MULTICLASE, FI",
        "Compartimento": {
          "NumeroCompartimento": 1,
          "DenominacionCompartimento": "COMPARTIMENTO PRINCIPAL",
          "Clase": [
            {
              "NumeroClase": 0,
              "DenominacionClase": "CLASE A",
              "ISIN": "ES0138841038"
            },
            {
              "NumeroClase": 1,
              "DenominacionClase": "CLASE C",
              "ISIN": "ES0138841004"
            }
          ]
        }
      }
    ]
  }
}
''',
      );

      final results = await provider.findAll(fundName: 'FONDO MULTICLASE, FI');

      expect(results, hasLength(2));

      expect(results[0].fundClass.number, 0);
      expect(results[0].fundClass.name, 'CLASE A');
      expect(results[0].isin, 'ES0138841038');

      expect(results[1].fundClass.number, 1);
      expect(results[1].fundClass.name, 'CLASE C');
      expect(results[1].isin, 'ES0138841004');

      expect(results[0].compartmentNumber, 1);
      expect(results[1].compartmentNumber, 1);
      expect(results[0].compartmentName, 'COMPARTIMENTO PRINCIPAL');
      expect(results[1].compartmentName, 'COMPARTIMENTO PRINCIPAL');
    });

    test('LF-2.5 varios compartimentos y varias clases', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 5,
        "Denominacion": "FONDO COMPLEJO, FI",
        "Compartimento": [
          {
            "NumeroCompartimento": 1,
            "DenominacionCompartimento": "EURO",
            "Clase": [
              {
                "NumeroClase": 0,
                "DenominacionClase": "CLASE A",
                "ISIN": "ES0138841038"
              },
              {
                "NumeroClase": 1,
                "DenominacionClase": "CLASE C",
                "ISIN": "ES0138841004"
              }
            ]
          },
          {
            "NumeroCompartimento": 2,
            "DenominacionCompartimento": "GLOBAL",
            "Clase": {
              "NumeroClase": 0,
              "DenominacionClase": "CLASE GLOBAL",
              "ISIN": "ES0138823002"
            }
          }
        ]
      }
    ]
  }
}
''',
      );

      final results = await provider.findAll(fundName: 'FONDO COMPLEJO, FI');

      expect(results, hasLength(3));

      expect(
        results.map((e) => e.isin),
        containsAll(<String>['ES0138841038', 'ES0138841004', 'ES0138823002']),
      );

      final euroClasses = results
          .where((e) => e.compartmentNumber == 1)
          .toList();
      final globalClasses = results
          .where((e) => e.compartmentNumber == 2)
          .toList();

      expect(euroClasses, hasLength(2));
      expect(globalClasses, hasLength(1));

      expect(
        euroClasses.map((e) => e.fundClass.name),
        containsAll(<String>['CLASE A', 'CLASE C']),
      );

      expect(globalClasses.single.fundClass.name, 'CLASE GLOBAL');
    });

    test(
      'LF-2.6 varias entidades FI generan resultados independientes',
      () async {
        final provider = CnmvLocalFundProvider(
          loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 10,
        "Denominacion": "FONDO UNO, FI",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE UNO",
            "ISIN": "ES0138841038"
          }
        }
      },
      {
        "Tipo": "FI",
        "NumeroRegistro": 11,
        "Denominacion": "FONDO DOS, FI",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE DOS",
            "ISIN": "ES0138841004"
          }
        }
      }
    ]
  }
}
''',
        );

        final resultOne = await provider.resolve(fundName: 'FONDO UNO, FI');

        final resultTwo = await provider.resolve(fundName: 'FONDO DOS, FI');

        expect(resultOne, isNotNull);
        expect(resultOne!.registrationNumber, 10);
        expect(resultOne.isin, 'ES0138841038');

        expect(resultTwo, isNotNull);
        expect(resultTwo!.registrationNumber, 11);
        expect(resultTwo.isin, 'ES0138841004');
      },
    );

    test('LF-2.7 compartimentos sin Clase se ignoran', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 20,
        "Denominacion": "FONDO SIN CLASE, FI",
        "Compartimento": {
          "NumeroCompartimento": 1,
          "DenominacionCompartimento": "SIN CLASE"
        }
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(fundName: 'FONDO SIN CLASE, FI');

      expect(result, isNull);
    });

    test('LF-2.8 clases incompletas se ignoran', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 21,
        "Denominacion": "FONDO CLASES INCOMPLETAS, FI",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": [
            {
              "NumeroClase": 0,
              "DenominacionClase": "SIN ISIN"
            },
            {
              "NumeroClase": 1,
              "ISIN": "ES0138841038"
            },
            {
              "DenominacionClase": "SIN NUMERO",
              "ISIN": "ES0138841004"
            },
            {
              "NumeroClase": 3,
              "DenominacionClase": "CLASE VALIDA",
              "ISIN": "ES0138841038"
            }
          ]
        }
      }
    ]
  }
}
''',
      );

      final results = await provider.findAll(
        fundName: 'FONDO CLASES INCOMPLETAS, FI',
      );

      expect(results, hasLength(1));
      expect(results.single.fundClass.number, 3);
      expect(results.single.fundClass.name, 'CLASE VALIDA');
      expect(results.single.isin, 'ES0138841038');
    });

    test('LF-2.9 compartimento sin número conserva la clase válida', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 22,
        "Denominacion": "FONDO COMPARTIMENTO SIN NUMERO, FI",
        "Compartimento": {
          "DenominacionCompartimento": "EURO",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE EURO",
            "ISIN": "ES0138841038"
          }
        }
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(
        fundName: 'FONDO COMPARTIMENTO SIN NUMERO, FI',
      );

      expect(result, isNotNull);
      expect(result!.compartmentNumber, isNull);
      expect(result.compartmentName, 'EURO');
      expect(result.fundClass.name, 'CLASE EURO');
      expect(result.isin, 'ES0138841038');
    });

    test(
      'LF-2.10 clase con número textual numérico se convierte a int',
      () async {
        final provider = CnmvLocalFundProvider(
          loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": "23",
        "Denominacion": "FONDO NUMEROS TEXTO, FI",
        "Compartimento": {
          "NumeroCompartimento": "2",
          "DenominacionCompartimento": "GLOBAL",
          "Clase": {
            "NumeroClase": "4",
            "DenominacionClase": "CLASE GLOBAL",
            "ISIN": "ES0138841038"
          }
        }
      }
    ]
  }
}
''',
        );

        final result = await provider.resolve(
          fundName: 'FONDO NUMEROS TEXTO, FI',
        );

        expect(result, isNotNull);
        expect(result!.registrationNumber, 23);
        expect(result.compartmentNumber, 2);
        expect(result.fundClass.number, 4);
        expect(result.isin, 'ES0138841038');
      },
    );
  });
}
