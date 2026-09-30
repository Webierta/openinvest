import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';

void runCnmvLocalFundProviderLf5Tests() {
  group('CnmvLocalFundProvider — LF-5: findAll', () {
    test('LF-5.1 devuelve todas las clases del mismo fondo', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 1,
          fundName: 'FONDO MULTICLASE, FI',
          classes: [
            _class(number: 0, name: 'CLASE A', isin: 'ES0138841038'),
            _class(number: 1, name: 'CLASE C', isin: 'ES0138841004'),
            _class(number: 2, name: 'CLASE I', isin: 'ES0138823036'),
          ],
        ),
      ]);

      final results = await provider.findAll(fundName: 'FONDO MULTICLASE, FI');

      expect(results, hasLength(3));
      expect(results.map((e) => e.fundClass.name), [
        'CLASE A',
        'CLASE C',
        'CLASE I',
      ]);
    });

    test('LF-5.2 conserva el orden del catálogo', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 2,
          fundName: 'FONDO ORDEN, FI',
          classes: [
            _class(number: 5, name: 'CLASE QUINTA', isin: 'ES0138823036'),
            _class(number: 1, name: 'CLASE PRIMERA', isin: 'ES0138841038'),
            _class(number: 3, name: 'CLASE TERCERA', isin: 'ES0138841004'),
          ],
        ),
      ]);

      final results = await provider.findAll(fundName: 'FONDO ORDEN, FI');

      expect(results, hasLength(3));
      expect(results.map((e) => e.fundClass.number), [5, 1, 3]);
      expect(results.map((e) => e.fundClass.name), [
        'CLASE QUINTA',
        'CLASE PRIMERA',
        'CLASE TERCERA',
      ]);
    });

    test('LF-5.3 conserva candidatos con ISIN diferentes', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 3,
          fundName: 'FONDO ISIN DIFERENTES, FI',
          classes: [
            _class(number: 0, name: 'CLASE A', isin: 'ES0138841038'),
            _class(number: 1, name: 'CLASE B', isin: 'ES0138841004'),
          ],
        ),
      ]);

      final results = await provider.findAll(
        fundName: 'FONDO ISIN DIFERENTES, FI',
      );

      expect(results, hasLength(2));
      expect(results.map((e) => e.isin), ['ES0138841038', 'ES0138841004']);
    });

    test('LF-5.4 conserva candidatos con el mismo ISIN', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 4,
          fundName: 'FONDO ISIN IGUALES, FI',
          classes: [
            _class(number: 0, name: 'CLASE A', isin: 'ES0138841038'),
            _class(number: 1, name: 'CLASE B', isin: 'ES0138841038'),
          ],
        ),
      ]);

      final results = await provider.findAll(
        fundName: 'FONDO ISIN IGUALES, FI',
      );

      expect(results, hasLength(2));
      expect(results.every((e) => e.isin == 'ES0138841038'), isTrue);
    });

    test('LF-5.5 fondo inexistente devuelve lista vacía', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 5,
          fundName: 'FONDO EXISTENTE, FI',
          classes: [
            _class(number: 0, name: 'CLASE BASE', isin: 'ES0138841038'),
          ],
        ),
      ]);

      final results = await provider.findAll(fundName: 'FONDO INEXISTENTE, FI');

      expect(results, isEmpty);
    });

    test('LF-5.6 consulta vacía devuelve lista vacía', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 6,
          fundName: 'FONDO CUALQUIERA, FI',
          classes: [
            _class(number: 0, name: 'CLASE BASE', isin: 'ES0138841038'),
          ],
        ),
      ]);

      final results = await provider.findAll(fundName: '   ');

      expect(results, isEmpty);
    });

    test('LF-5.7 findAll aplica la misma normalización de nombres', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 7,
          fundName: 'FÓNDÓ EUROPA-GLOBAL, FI',
          classes: [
            _class(number: 0, name: 'CLASE BASE', isin: 'ES0138841038'),
          ],
        ),
      ]);

      final results = await provider.findAll(
        fundName: 'fondo europa global, fi',
      );

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0138841038');
    });

    test('LF-5.8 findAll devuelve una lista no modificable', () async {
      final provider = _providerWithEntities([
        _entity(
          registrationNumber: 8,
          fundName: 'FONDO INMUTABLE, FI',
          classes: [
            _class(number: 0, name: 'CLASE BASE', isin: 'ES0138841038'),
          ],
        ),
      ]);

      final results = await provider.findAll(fundName: 'FONDO INMUTABLE, FI');

      expect(results, hasLength(1));

      expect(() => results.clear(), throwsA(isA<UnsupportedError>()));
    });
  });
}

CnmvLocalFundProvider _providerWithEntities(List<_TestEntity> entities) {
  final entityJson = entities
      .map((entity) {
        final classJson = entity.classes
            .map((fundClass) {
              return '''
{
  "NumeroClase": ${fundClass.number},
  "DenominacionClase": "${fundClass.name}",
  "ISIN": "${fundClass.isin}"
}
''';
            })
            .join(',');

        return '''
{
  "Tipo": "FI",
  "NumeroRegistro": ${entity.registrationNumber},
  "Denominacion": "${entity.fundName}",
  "Compartimento": {
    "NumeroCompartimento": 0,
    "DenominacionCompartimento": "",
    "Clase": [
      $classJson
    ]
  }
}
''';
      })
      .join(',');

  final json =
      '''
{
  "FondRegistro": {
    "Entidad": [
      $entityJson
    ]
  }
}
''';

  return CnmvLocalFundProvider(loadAsset: (_) async => json);
}

_TestEntity _entity({
  required int registrationNumber,
  required String fundName,
  required List<_TestClass> classes,
}) {
  return _TestEntity(
    registrationNumber: registrationNumber,
    fundName: fundName,
    classes: classes,
  );
}

_TestClass _class({
  required int number,
  required String name,
  required String isin,
}) {
  return _TestClass(number: number, name: name, isin: isin);
}

class _TestEntity {
  final int registrationNumber;
  final String fundName;
  final List<_TestClass> classes;

  const _TestEntity({
    required this.registrationNumber,
    required this.fundName,
    required this.classes,
  });
}

class _TestClass {
  final int number;
  final String name;
  final String isin;

  const _TestClass({
    required this.number,
    required this.name,
    required this.isin,
  });
}
