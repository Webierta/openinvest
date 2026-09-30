import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CnmvLocalFundProvider - falsos positivos por similitud', () {
    test(
      'FP01 - 2025 frente a 2025 II: con ambas variantes debe ser ambiguo',
      () async {
        final provider = _provider([
          _fund(
            1,
            'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
            'ES0138841038',
          ),
          _fund(
            2,
            'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025 II, FI',
            'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
      },
    );

    test('FP02 - 2025 frente a 2025 2: consulta inexistente no debe adoptar la variante', () async {
      final provider = _provider([
        _fund(
          1,
          'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025 2, FI',
          'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(
        fundName: 'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
      );

      expect(result, isNull);
    });

    test('FP03 - 2025 frente a 2025 3: consulta inexistente no debe adoptar la variante', () async {
      final provider = _provider([
        _fund(
          1,
          'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025 3, FI',
          'ES0138841004',
        ),
      ]);

      final result = await provider.resolve(
        fundName: 'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
      );

      expect(result, isNull);
    });

    test(
      'FP04 - PLUS frente a PLUS II: consulta inexistente no debe adoptar II',
      () async {
        final provider = _provider([
          _fund(
            1,
            'BANKINTER EUROSTOXX 2024 PLUS II GARANTIZADO, FI',
            'ES0156322036',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'BANKINTER EUROSTOXX 2024 PLUS GARANTIZADO, FI',
        );

        expect(result, isNull);
      },
    );

    test('FP05 - corto plazo frente a MASTER: consulta inexistente no debe adoptar MASTER', () async {
      final provider = _provider([
        _fund(1, 'CAIXABANK MASTER RENTA FIJA CORTO PLAZO, FI', 'ES0138823036'),
      ]);

      final result = await provider.resolve(
        fundName: 'CAIXABANK RENTA FIJA CORTO PLAZO, FI',
      );

      expect(result, isNull);
    });

    test('FP06 - corto plazo frente a SMART: consulta inexistente no debe adoptar SMART', () async {
      final provider = _provider([
        _fund(1, 'CAIXABANK SMART RENTA FIJA CORTO PLAZO, FI', 'ES0138823002'),
      ]);

      final result = await provider.resolve(
        fundName: 'CAIXABANK RENTA FIJA CORTO PLAZO, FI',
      );

      expect(result, isNull);
    });

    test('FP07 - BOLSA frente a ACUMULACION: consulta inexistente no debe adoptar ACUMULACION', () async {
      final provider = _provider([
        _fund(1, 'BBVA MI INVERSION BOLSA ACUMULACION, FI', 'ES0138841038'),
      ]);

      final result = await provider.resolve(
        fundName: 'BBVA MI INVERSION BOLSA, FI',
      );

      expect(result, isNull);
    });

    test('FP08 - GLOBAL LENDING frente a DOLAR: consulta inexistente no debe adoptar DOLAR', () async {
      final provider = _provider([
        _fund(1, 'MCH GLOBAL LENDING STRATEGIES DOLAR, FIL', 'ES0138841004'),
      ]);

      final result = await provider.resolve(
        fundName: 'MCH GLOBAL LENDING STRATEGIES, FIL',
      );

      expect(result, isNull);
    });

    test('FP09 - ESPANA ITALIA frente a ABRIL: consulta inexistente no debe adoptar ABRIL', () async {
      final provider = _provider([
        _fund(1, 'IBERCAJA ESPANA ITALIA ABRIL 2024, FI', 'ES0156322036'),
      ]);

      final result = await provider.resolve(
        fundName: 'IBERCAJA ESPANA ITALIA 2024, FI',
      );

      expect(result, isNull);
    });

    test('FP10 - RENTA FIJA frente a FLEXIBLE: consulta inexistente no debe adoptar FLEXIBLE', () async {
      final provider = _provider([
        _fund(1, 'GVC GAESCO RENTA FIJA FLEXIBLE, FI', 'ES0138823036'),
      ]);

      final result = await provider.resolve(
        fundName: 'GVC GAESCO RENTA FIJA, FI',
      );

      expect(result, isNull);
    });
  });

  group('CnmvLocalFundProvider - ambigüedad entre variantes', () {
    test(
      'AMB01 - 2025, 2025 II y 2025 3: debe resolver la coincidencia exacta',
      () async {
        final provider = _provider([
          _fund(
            1,
            'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
            'ES0138841038',
          ),
          _fund(
            2,
            'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025 II, FI',
            'ES0138841004',
          ),
          _fund(
            3,
            'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025 3, FI',
            'ES0156322036',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'CAIXABANK DEUDA PUBLICA ESPANA ITALIA 2025, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
      },
    );

    test(
      'AMB02 - PLUS y PLUS II: debe resolver la coincidencia exacta',
      () async {
        final provider = _provider([
          _fund(
            1,
            'BANKINTER EUROSTOXX 2024 PLUS GARANTIZADO, FI',
            'ES0138841038',
          ),
          _fund(
            2,
            'BANKINTER EUROSTOXX 2024 PLUS II GARANTIZADO, FI',
            'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'BANKINTER EUROSTOXX 2024 PLUS II GARANTIZADO, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841004');
      },
    );

    test(
      'AMB03 - BOLSA y BOLSA ACUMULACION: debe resolver la coincidencia exacta',
      () async {
        final provider = _provider([
          _fund(1, 'BBVA MI INVERSION BOLSA, FI', 'ES0138841038'),
          _fund(2, 'BBVA MI INVERSION BOLSA ACUMULACION, FI', 'ES0138841004'),
        ]);

        final result = await provider.resolve(
          fundName: 'BBVA MI INVERSION BOLSA ACUMULACION, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841004');
      },
    );
  });

  group('CnmvLocalFundProvider - equivalencias que sí deben funcionar', () {
    test('EQ01 - mismo nombre con diferencias de acentuación', () async {
      final provider = _provider([
        _fund(1, 'FONDO SELECCIÓN GLOBAL, FI', 'ES0138841038'),
      ]);

      final result = await provider.resolve(
        fundName: 'FONDO SELECCION GLOBAL, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('EQ02 - nombre abreviado', () async {
      final provider = _provider([
        _fund(1, 'GESIURIS IURISFOND, FI', 'ES0138841004'),
      ]);

      final result = await provider.resolve(fundName: 'GESIURIS');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841004');
    });

    test('EQ03 - nombre completo con clase explícita', () async {
      final provider = _provider([
        _fund(1, 'FONMARCH, FI', 'ES0156322036', className: 'CLASE A'),
        _fund(2, 'FONMARCH, FI', 'ES0138823036', className: 'CLASE C'),
      ]);

      final result = await provider.resolve(fundName: 'FONMARCH, FI CLASE C');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138823036');
    });
  });
}

// ULTIMA PROPUESTA
/* CnmvLocalFundProvider _provider(List<Map<String, dynamic>> funds) {
  final json = jsonEncode({
    'FondRegistro': {
      'FechaDatos': 'TEST',
      'Entidad': funds.map((fund) {
        return {
          'Tipo': 'FI',
          'NumeroRegistro': fund['registrationNumber'] ?? 1,
          'Denominacion': fund['fundName'],
          'Compartimento': {
            'NumeroCompartimento': fund['compartmentNumber'] ?? 1,
            'DenominacionCompartimento': fund['compartmentName'],
            'Clase': {
              'NumeroClase': fund['classNumber'] ?? 1,
              'DenominacionClase': fund['className'] ?? '',
              'ISIN': fund['isin'],
            },
          },
        };
      }).toList(),
    },
  });

  return CnmvLocalFundProvider(loadAsset: (_) async => json);
}

Map<String, dynamic> _fund({
  required String fundName,
  required String isin,
  String className = '',
  int registrationNumber = 1,
  int compartmentNumber = 1,
  int classNumber = 1,
  String? compartmentName,
}) {
  return {
    'fundName': fundName,
    'className': className,
    'isin': isin,
    'registrationNumber': registrationNumber,
    'compartmentNumber': compartmentNumber,
    'classNumber': classNumber,
    'compartmentName': compartmentName,
  };
} */

CnmvLocalFundProvider _provider(List<Map<String, dynamic>> funds) {
  return CnmvLocalFundProvider(
    loadAsset: (_) async => jsonEncode({
      'FondRegistro': {'FechaDatos': 202605, 'Entidad': funds},
    }),
  );
}

Map<String, dynamic> _fund(
  int registrationNumber,
  String name,
  String isin, {
  String className = 'BASE',
}) {
  return {
    'Tipo': 'FI',
    'NumeroRegistro': registrationNumber,
    'Denominacion': name,
    'ETF': 'NO',
    'Compartimento': {
      'NumeroCompartimento': 0,
      'DenominacionCompartimento': 'COMPARTIMENTO 0',
      'Clase': {'NumeroClase': 1, 'DenominacionClase': className, 'ISIN': isin},
    },
    'Gestora': {},
    'Depositario': {},
  };
}
