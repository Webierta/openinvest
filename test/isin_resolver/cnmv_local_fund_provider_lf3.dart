import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf3Tests() {
  group('CnmvLocalFundProvider — LF-3: matching y selección', () {
    test('LF-3.1 coincidencia exacta con nombre del fondo', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO EXACTO, FI',
          registrationNumber: 1,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(fundName: 'FONDO EXACTO, FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test(
      'LF-3.2 query con clase selecciona la clase correspondiente',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONDO CLASES, FI',
            registrationNumber: 2,
            classNumber: 0,
            className: 'CLASE A',
            isin: 'ES0138841038',
          ),
          _class(
            fundName: 'FONDO CLASES, FI',
            registrationNumber: 2,
            classNumber: 1,
            className: 'CLASE C',
            isin: 'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'FONDO CLASES, FI CLASE C',
        );

        expect(result, isNotNull);
        expect(result!.fundClass.name, 'CLASE C');
        expect(result.isin, 'ES0138841004');
      },
    );

    test('LF-3.3 nombre abreviado identifica un único fondo', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'GESIURIS IURISFOND, FI',
          registrationNumber: 3,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0156322036',
        ),
      ]);

      final result = await provider.resolve(fundName: 'GESIURIS');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0156322036');
    });

    test('LF-3.4 query igual al fondo con sufijo adicional coincide', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO PRINCIPAL, FI',
          registrationNumber: 4,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(
        fundName: 'FONDO PRINCIPAL, FI CLASE BASE',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-3.5 fondo con nombre contenido en query coincide', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO GLOBAL',
          registrationNumber: 5,
          classNumber: 0,
          className: 'CLASE A',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(fundName: 'FONDO GLOBAL FI');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test('LF-3.6 coincidencia por similitud Jaccard ≥ 0.82', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO EUROPA RENTA VARIABLE',
          registrationNumber: 6,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(
        fundName: 'FONDO EUROPA RENTA VARIABLE',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });

    test(
      'LF-3.7 coincidencia por similitud insuficiente no selecciona',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONDO EUROPA RENTA VARIABLE',
            registrationNumber: 7,
            classNumber: 0,
            className: 'CLASE BASE',
            isin: 'ES0138841038',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'FONDO RENTA EUROPA EXTRA',
        );

        expect(result, isNull);
      },
    );

    test(
      'LF-3.8 varias clases mismo fondo con query sin clase son ambiguas',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONMARCH, FI',
            registrationNumber: 8,
            classNumber: 0,
            className: 'CLASE A',
            isin: 'ES0138841038',
          ),
          _class(
            fundName: 'FONMARCH, FI',
            registrationNumber: 8,
            classNumber: 1,
            className: 'CLASE C',
            isin: 'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(fundName: 'FONMARCH, FI');

        expect(result, isNull);
      },
    );

    test(
      'LF-3.9 varias clases mismo ISIN permiten seleccionar resultado',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONDO DUPLICADO, FI',
            registrationNumber: 9,
            classNumber: 0,
            className: 'CLASE A',
            isin: 'ES0138841038',
          ),
          _class(
            fundName: 'FONDO DUPLICADO, FI',
            registrationNumber: 9,
            classNumber: 1,
            className: 'CLASE B',
            isin: 'ES0138841038',
          ),
        ]);

        final result = await provider.resolve(fundName: 'FONDO DUPLICADO, FI');

        expect(result, isNotNull);
        expect(result!.isin, 'ES0138841038');
      },
    );

    test(
      'LF-3.10 varios candidatos con ISIN diferentes son ambiguos',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONDO AMBIGUO, FI',
            registrationNumber: 10,
            classNumber: 0,
            className: 'CLASE A',
            isin: 'ES0138841038',
          ),
          _class(
            fundName: 'FONDO AMBIGUO, FI',
            registrationNumber: 10,
            classNumber: 1,
            className: 'CLASE B',
            isin: 'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(fundName: 'FONDO AMBIGUO, FI');

        expect(result, isNull);
      },
    );

    test(
      'LF-3.11 coincidencia exacta tiene prioridad sobre classMatches',
      () async {
        final provider = _providerWithClasses([
          _class(
            fundName: 'FONDO PRIORIDAD, FI',
            registrationNumber: 11,
            classNumber: 0,
            className: 'CLASE A',
            isin: 'ES0138841038',
          ),
          _class(
            fundName: 'FONDO PRIORIDAD, FI CLASE B',
            registrationNumber: 12,
            classNumber: 0,
            className: 'CLASE B',
            isin: 'ES0138841004',
          ),
        ]);

        final result = await provider.resolve(
          fundName: 'FONDO PRIORIDAD, FI CLASE B',
        );

        expect(result, isNotNull);
        expect(result!.registrationNumber, 12);
        expect(result.isin, 'ES0138841004');
      },
    );

    test('LF-3.12 query vacío devuelve null', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO CUALQUIERA, FI',
          registrationNumber: 13,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(fundName: '   ');

      expect(result, isNull);
    });

    test('LF-3.13 fondo inexistente devuelve null', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FONDO EXISTENTE, FI',
          registrationNumber: 14,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(fundName: 'FONDO INEXISTENTE, FI');

      expect(result, isNull);
    });

    test('LF-3.14 matching ignora mayúsculas y acentos', () async {
      final provider = _providerWithClasses([
        _class(
          fundName: 'FÓNDÖ ÉXÁCTO, FI',
          registrationNumber: 15,
          classNumber: 0,
          className: 'CLASE BASE',
          isin: 'ES0138841038',
        ),
      ]);

      final result = await provider.resolve(fundName: 'fondo exacto, fi');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
    });
  });
}

CnmvLocalFundProvider _providerWithClasses(List<_TestClass> classes) {
  final entities = <String>[];

  for (final entry in classes) {
    entities.add('''
{
  "Tipo": "FI",
  "NumeroRegistro": ${entry.registrationNumber},
  "Denominacion": "${entry.fundName}",
  "Compartimento": {
    "NumeroCompartimento": 0,
    "DenominacionCompartimento": "",
    "Clase": {
      "NumeroClase": ${entry.classNumber},
      "DenominacionClase": "${entry.className}",
      "ISIN": "${entry.isin}"
    }
  }
}
''');
  }

  final json =
      '''
{
  "FondRegistro": {
    "Entidad": [
      ${entities.join(',')}
    ]
  }
}
''';

  return CnmvLocalFundProvider(loadAsset: (_) async => json);
}

_TestClass _class({
  required String fundName,
  required int registrationNumber,
  required int classNumber,
  required String className,
  required String isin,
}) {
  return _TestClass(
    fundName: fundName,
    registrationNumber: registrationNumber,
    classNumber: classNumber,
    className: className,
    isin: isin,
  );
}

class _TestClass {
  final String fundName;
  final int registrationNumber;
  final int classNumber;
  final String className;
  final String isin;

  const _TestClass({
    required this.fundName,
    required this.registrationNumber,
    required this.classNumber,
    required this.className,
    required this.isin,
  });
}
