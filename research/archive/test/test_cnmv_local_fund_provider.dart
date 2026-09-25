/*
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/cnmv_local_fund_provider.dart';

void main() {
  late CnmvLocalFundProvider provider;

  setUp(() {
    provider = CnmvLocalFundProvider(
      loadAsset: (_) async => _sampleJson,
    );
  });

  test('carga una clase única de un FI', () async {
    final result = await provider.resolve(
      fundName: 'GESIURIS IURISFOND, FI',
    );

    expect(result, isNotNull);
    expect(result!.registrationNumber, 11);
    expect(result.fundClass.name, 'CLASE 0');
    expect(result.isin, 'ES0156322036');
  });

  test('selecciona la clase cuando el nombre la identifica', () async {
    final result = await provider.resolve(
      fundName: 'FONMARCH, FI CLASE A',
    );

    expect(result, isNotNull);
    expect(result!.registrationNumber, 9);
    expect(result.fundClass.name, 'CLASE A');
    expect(result.isin, 'ES0138841038');
  });

  test('selecciona otra clase del mismo fondo', () async {
    final result = await provider.resolve(
      fundName: 'FONMARCH FI CLASE C',
    );

    expect(result, isNotNull);
    expect(result!.isin, 'ES0138841004');
    expect(result.fundClass.name, 'CLASE C');
  });

  test('no elige arbitrariamente entre varias clases', () async {
    final result = await provider.resolve(fundName: 'FONMARCH, FI');
    expect(result, isNull);
  });

  test('findAll devuelve todas las clases de un fondo', () async {
    final results = await provider.findAll(
      fundName: 'SANTANDER ACCIONES ESPAÑOLAS, FI',
    );

    expect(results.length, 7);
    expect(
      results.map((e) => e.isin).toSet(),
      containsAll(<String>[
        'ES0138823036', 'ES0138823002', 'ES0138823010',
        'ES0138823028', 'ES0138823044', 'ES0138823051',
        'ES0138823069',
      ]),
    );
  });

  test('devuelve null para un fondo inexistente', () async {
    final result = await provider.resolve(
      fundName: 'FONDO QUE NO EXISTE, FI',
    );
    expect(result, isNull);
  });
}

const _sampleJson = r'''
{
  "FondRegistro": {
    "FechaDatos": 202605,
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 9,
        "Denominacion": "FONMARCH, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "COMPARTIMENTO 0",
          "Clase": [
            {"NumeroClase": 1, "DenominacionClase": "CLASE A", "ISIN": "ES0138841038"},
            {"NumeroClase": 2, "DenominacionClase": "CLASE C", "ISIN": "ES0138841004"},
            {"NumeroClase": 3, "DenominacionClase": "CLASE S", "ISIN": "ES0138841012"}
          ]
        },
        "Gestora": {}, "Depositario": {}
      },
      {
        "Tipo": "FI",
        "NumeroRegistro": 11,
        "Denominacion": "GESIURIS IURISFOND, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "COMPARTIMENTO 0",
          "Clase": {"NumeroClase": 0, "DenominacionClase": "CLASE 0", "ISIN": "ES0156322036"}
        },
        "Gestora": {}, "Depositario": {}
      },
      {
        "Tipo": "FI",
        "NumeroRegistro": 58,
        "Denominacion": "SANTANDER ACCIONES ESPAÑOLAS, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "COMPARTIMENTO 0",
          "Clase": [
            {"NumeroClase": 1, "DenominacionClase": "CLASE A", "ISIN": "ES0138823036"},
            {"NumeroClase": 2, "DenominacionClase": "CLASE C", "ISIN": "ES0138823002"},
            {"NumeroClase": 3, "DenominacionClase": "CLASE B", "ISIN": "ES0138823010"},
            {"NumeroClase": 4, "DenominacionClase": "CLASE CARTERA", "ISIN": "ES0138823028"},
            {"NumeroClase": 5, "DenominacionClase": "CLASE D", "ISIN": "ES0138823044"},
            {"NumeroClase": 6, "DenominacionClase": "CLASE MASTER", "ISIN": "ES0138823051"},
            {"NumeroClase": 7, "DenominacionClase": "CLASE OL", "ISIN": "ES0138823069"}
          ]
        },
        "Gestora": {}, "Depositario": {}
      }
    ]
  }
}
''';
*/
