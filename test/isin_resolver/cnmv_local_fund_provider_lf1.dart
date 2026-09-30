import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf1Tests() {
  group('CnmvLocalFundProvider — LF-1: carga y estructura', () {
    test('LF-1.1 JSON mal formado lanza FormatException', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '{ json inválido',
      );

      await expectLater(
        provider.resolve(fundName: 'CUALQUIER FONDO, FI'),
        throwsA(isA<FormatException>()),
      );
    });

    test('LF-1.2 raíz JSON que no es objeto lanza FormatException', () async {
      final provider = CnmvLocalFundProvider(loadAsset: (_) async => '[]');

      await expectLater(
        provider.resolve(fundName: 'CUALQUIER FONDO, FI'),
        throwsA(isA<FormatException>()),
      );
    });

    test('LF-1.3 ausencia de FondRegistro lanza FormatException', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "OtroRegistro": {}
}
''',
      );

      await expectLater(
        provider.resolve(fundName: 'CUALQUIER FONDO, FI'),
        throwsA(isA<FormatException>()),
      );
    });

    test('LF-1.4 Entidad que no es una lista lanza FormatException', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": {}
  }
}
''',
      );

      await expectLater(
        provider.resolve(fundName: 'CUALQUIER FONDO, FI'),
        throwsA(isA<FormatException>()),
      );
    });

    test('LF-1.5 entidad con Tipo distinto de FI se ignora', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "SIL",
        "NumeroRegistro": 123,
        "Denominacion": "SOCIEDAD NO FI"
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(fundName: 'SOCIEDAD NO FI');

      expect(result, isNull);
    });

    test('LF-1.6 entidad FI sin NumeroRegistro se ignora', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "Denominacion": "FONDO SIN REGISTRO"
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(fundName: 'FONDO SIN REGISTRO');

      expect(result, isNull);
    });

    test('LF-1.7 entidad FI sin Denominacion se ignora', () async {
      final provider = CnmvLocalFundProvider(
        loadAsset: (_) async => '''
{
  "FondRegistro": {
    "Entidad": [
      {
        "Tipo": "FI",
        "NumeroRegistro": 123
      }
    ]
  }
}
''',
      );

      final result = await provider.resolve(fundName: 'FONDO SIN DENOMINACION');

      expect(result, isNull);
    });
  });
}
