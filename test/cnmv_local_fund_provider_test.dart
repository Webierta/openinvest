import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

import 'isin_resolver/cnmv_local_fund_provider_lf1.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf2.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf3.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf4.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf5.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf6.dart';
import 'isin_resolver/cnmv_local_fund_provider_lf7.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  runCnmvLocalFundProviderLf1Tests();
  runCnmvLocalFundProviderLf2Tests();
  runCnmvLocalFundProviderLf3Tests();
  runCnmvLocalFundProviderLf4Tests();
  runCnmvLocalFundProviderLf5Tests();
  runCnmvLocalFundProviderLf6Tests();
  runCnmvLocalFundProviderLf7Tests();

  // Tests históricos/smoke del provider.
  late CnmvLocalFundProvider provider;

  setUp(() {
    provider = CnmvLocalFundProvider(loadAsset: (_) async => _sampleJson);
  });

  test('FI una clase', () async {
    final result = await provider.resolve(fundName: 'GESIURIS IURISFOND, FI');
    expect(result, isNotNull);
    expect(result!.isin, 'ES0156322036');
  });

  test('FI varias clases', () async {
    final resultA = await provider.resolve(fundName: 'FONMARCH, FI CLASE A');
    expect(resultA, isNotNull);
    expect(resultA!.isin, 'ES0138841038');

    final resultC = await provider.resolve(fundName: 'FONMARCH, FI CLASE C');
    expect(resultC, isNotNull);
    expect(resultC!.isin, 'ES0138841004');
  });

  test('compartimento', () async {
    final result = await provider.resolve(fundName: 'FONDOWORLD, FI');
    expect(result, isNotNull);
    expect(result!.compartmentName, 'COMPARTIMENTO EURO');
    expect(result.isin, 'ES0138823036');
  });

  test('nombre con acentos', () async {
    final result = await provider.resolve(fundName: 'FONDOS ACENTUADOS, FI');
    expect(result, isNotNull);
    expect(result!.isin, 'ES0138823002');
  });

  test('nombre abreviado no coincide', () async {
    final result = await provider.resolve(fundName: 'GESIURIS');
    expect(result, isNull);
  });

  test('ambigüedad', () async {
    final result = await provider.resolve(fundName: 'FONMARCH, FI');
    expect(result, isNull);
  });

  test('ISIN inválido', () async {
    final invalidProvider = CnmvLocalFundProvider(
      loadAsset: (_) async => _invalidIsinJson,
    );
    final result = await invalidProvider.resolve(
      fundName: 'FONDO ISIN INVALIDO, FI',
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
            {"NumeroClase": 2, "DenominacionClase": "CLASE C", "ISIN": "ES0138841004"}
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
        "NumeroRegistro": 100,
        "Denominacion": "FONDOWORLD, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 1,
          "DenominacionCompartimento": "COMPARTIMENTO EURO",
          "Clase": {"NumeroClase": 1, "DenominacionClase": "BASE", "ISIN": "ES0138823036"}
        },
        "Gestora": {}, "Depositario": {}
      },
      {
        "Tipo": "FI",
        "NumeroRegistro": 101,
        "Denominacion": "FONDOS ACENTUADOS, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "COMPARTIMENTO 0",
          "Clase": {"NumeroClase": 1, "DenominacionClase": "BASE", "ISIN": "ES0138823002"}
        },
        "Gestora": {}, "Depositario": {}
      }
    ]
  }
}
''';

const _invalidIsinJson = r'''
{
  "FondRegistro": {
    "FechaDatos": 202605,
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 999,
        "Denominacion": "FONDO ISIN INVALIDO, FI",
        "ETF": "NO",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "COMPARTIMENTO 0",
          "Clase": {"NumeroClase": 1, "DenominacionClase": "CLASE A", "ISIN": "ES0000000001"}
        },
        "Gestora": {}, "Depositario": {}
      }
    ]
  }
}
''';

// Este archivo corrige **solo el histórico 5**.
//Los dos fallos que acabas de obtener (`LF-3.3` y `LF-3.5`) están en `cnmv_local_fund_provider_lf3.dart`,
//por lo que seguirán apareciendo hasta que revisemos ese archivo.
