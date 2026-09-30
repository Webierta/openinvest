import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf4Tests() {
  group('CnmvLocalFundProvider — LF-4: normalización', () {
    test('LF-4.1 vocales acentuadas se normalizan', () async {
      final provider = _providerWithFund('FÓNDÓ ÁÉÍÓÚ, FI', 'ES0138841038');

      final result = await provider.resolve(fundName: 'FONDO AEIOU, FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test(
      'LF-4.2 vocales con diéresis y variantes de acento se normalizan',
      () async {
        final provider = _providerWithFund('FÖNDÖ ÀÈÌÒÙ, FI', 'ES0138841038');

        final result = await provider.resolve(fundName: 'FONDO AEIOU, FI');

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
      },
    );

    test('LF-4.3 Ñ se normaliza a N', () async {
      final provider = _providerWithFund('FONDO ÑANDÚ, FI', 'ES0138841038');

      final result = await provider.resolve(fundName: 'FONDO NANDU, FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.4 ampersand se normaliza como espacio', () async {
      final provider = _providerWithFund('RENTA & VALOR, FI', 'ES0138841038');

      final result = await provider.resolve(fundName: 'RENTA VALOR, FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.5 guion se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO EUROPA-GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.6 guion bajo se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO EUROPA_GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.7 barra se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO EUROPA/GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.8 coma se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO EUROPA, GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(fundName: 'FONDO EUROPA GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.9 punto se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO.EUROPA.GLOBAL.FI',
        'ES0138841038',
      );

      final result = await provider.resolve(fundName: 'FONDO EUROPA GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.10 dos puntos se normalizan como espacio', () async {
      final provider = _providerWithFund(
        'FONDO:EUROPA:GLOBAL:FI',
        'ES0138841038',
      );

      final result = await provider.resolve(fundName: 'FONDO EUROPA GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.11 punto y coma se normaliza como espacio', () async {
      final provider = _providerWithFund(
        'FONDO;EUROPA;GLOBAL;FI',
        'ES0138841038',
      );

      final result = await provider.resolve(fundName: 'FONDO EUROPA GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.12 paréntesis se normalizan como espacios', () async {
      final provider = _providerWithFund(
        'FONDO (EUROPA) GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(fundName: 'FONDO EUROPA GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.13 múltiples espacios se reducen a uno', () async {
      final provider = _providerWithFund(
        'FONDO    EUROPA     GLOBAL, FI',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.14 espacios iniciales y finales se eliminan', () async {
      final provider = _providerWithFund(
        '  FONDO EUROPA GLOBAL, FI  ',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-4.15 normalización combinada', () async {
      final provider = _providerWithFund(
        '  FÓNDÓ-ÁÉÍÓÚ / ÑANDÚ & GLOBAL (CLASE A); FI  ',
        'ES0138841038',
      );

      final result = await provider.resolve(
        fundName: 'FONDO AEIOU NANDU GLOBAL CLASE A FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test(
      'LF-4.16 normalización es insensible a mayúsculas/minúsculas',
      () async {
        final provider = _providerWithFund(
          'Fondo Europa Global, FI',
          'ES0138841038',
        );

        final result = await provider.resolve(
          fundName: 'fOnDo eUrOpA gLoBaL, fI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
      },
    );
  });
}

CnmvLocalFundProvider _providerWithFund(String fundName, String isin) {
  final json =
      '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 1,
        "Denominacion": "$fundName",
        "Compartimento": {
          "NumeroCompartimento": 0,
          "DenominacionCompartimento": "",
          "Clase": {
            "NumeroClase": 0,
            "DenominacionClase": "CLASE BASE",
            "ISIN": "$isin"
          }
        }
      }
    ]
  }
}
''';

  return CnmvLocalFundProvider(loadAsset: (_) async => json);
}
