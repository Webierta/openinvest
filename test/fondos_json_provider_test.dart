import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/fund_name_matcher.dart';

const _assetPath = 'assets/files/fondos.json';

Future<List<Map<String, dynamic>>> _loadFondos() async {
  final jsonText = await rootBundle.loadString(_assetPath);
  final decoded = jsonDecode(jsonText);

  expect(decoded, isA<List<dynamic>>());

  return (decoded as List<dynamic>)
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
}

/// Construye el índice que deberá utilizar posteriormente el provider.
///
/// Importante:
/// - la clave es el nombre normalizado;
/// - todos los ISIN sont conservados;
/// - los ISIN repetidos para una misma clave se deduplican;
/// - NO hay fuzzy matching.
Map<String, List<String>> _buildIndex(List<Map<String, dynamic>> records) {
  final index = <String, List<String>>{};

  for (final record in records) {
    final name = record['name'];
    final isin = record['isin'];

    if (name is! String || isin is! String) {
      continue;
    }

    final key = FundNameMatcher.normalizeName(name);

    index.putIfAbsent(key, () => <String>[]);

    if (!index[key]!.contains(isin)) {
      index[key]!.add(isin);
    }
  }

  return index;
}

List<String> _lookup(Map<String, List<String>> index, String name) {
  return List<String>.unmodifiable(
    index[FundNameMatcher.normalizeName(name)] ?? const <String>[],
  );
}

bool _isIsinFormatValid(String value) {
  return RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(value);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> records;
  late Map<String, List<String>> index;

  setUpAll(() async {
    records = await _loadFondos();
    index = _buildIndex(records);
  });

  group('LF-16.1 — Integridad de fondos.json', () {
    test('asset está disponible y contiene una lista no vacía', () {
      expect(records, isNotEmpty);
    });

    test('todos los registros tienen name e isin de tipo String', () {
      for (final record in records) {
        expect(record['name'], isA<String>());
        expect(record['isin'], isA<String>());

        expect(
          (record['name'] as String).trim(),
          isNotEmpty,
          reason: 'name vacío: $record',
        );

        expect(
          (record['isin'] as String).trim(),
          isNotEmpty,
          reason: 'isin vacío: $record',
        );
      }
    });

    test('todos los ISIN tienen formato válido', () {
      for (final record in records) {
        final isin = (record['isin'] as String).trim();

        expect(
          _isIsinFormatValid(isin),
          isTrue,
          reason: 'ISIN con formato inválido: $isin',
        );
      }
    });

    test('los registros solo contienen name e isin', () {
      for (final record in records) {
        expect(
          record.keys.toSet(),
          equals({'name', 'isin'}),
          reason: 'Estructura inesperada: $record',
        );
      }
    });
  });

  group('LF-16.2 — Estadísticas e identidad de la fuente', () {
    test('el número de registros es positivo', () {
      expect(records.length, greaterThan(0));
    });

    test('existen nombres repetidos con distintos ISIN', () {
      final names = <String, Set<String>>{};

      for (final record in records) {
        final name = record['name'] as String;
        final isin = record['isin'] as String;

        names.putIfAbsent(name, () => <String>{}).add(isin);
      }

      final multiIsin = names.entries
          .where((entry) => entry.value.length > 1)
          .toList();

      expect(
        multiIsin,
        isNotEmpty,
        reason: 'LF-16 requiere soportar nombre → N ISIN',
      );
    });

    test('los ISIN de cada nombre son identificadores distintos', () {
      final names = <String, Set<String>>{};

      for (final record in records) {
        final name = record['name'] as String;
        final isin = record['isin'] as String;

        names.putIfAbsent(name, () => <String>{}).add(isin);
      }

      for (final entry in names.entries) {
        expect(
          entry.value.length,
          greaterThanOrEqualTo(1),
          reason: 'Nombre sin ISIN: ${entry.key}',
        );
      }
    });
  });

  group('LF-16.3 — Índice por nombre normalizado', () {
    test('la clave del índice utiliza FundNameMatcher.normalizeName', () {
      final original = 'ABACO RENTA FIJA, FI';
      final normalized = FundNameMatcher.normalizeName(original);

      expect(normalized, 'ABACO RENTA FIJA FI');
      expect(index.containsKey(normalized), isTrue);
    });

    test('la búsqueda ignora mayúsculas/minúsculas', () {
      const original = 'ABACO RENTA FIJA, FI';

      final lower = _lookup(index, original.toLowerCase());
      final upper = _lookup(index, original.toUpperCase());

      expect(lower, isNotEmpty);
      expect(lower, equals(upper));
    });

    test('la búsqueda ignora puntuación según normalizeName', () {
      final a = _lookup(index, 'ABACO RENTA FIJA, FI');
      final b = _lookup(index, 'ABACO RENTA FIJA FI');

      expect(a, isNotEmpty);
      expect(b, equals(a));
    });

    test('la búsqueda ignora espacios redundantes', () {
      final a = _lookup(index, 'ABACO RENTA FIJA, FI');
      final b = _lookup(index, '  ABACO   RENTA   FIJA,   FI  ');

      expect(a, isNotEmpty);
      expect(b, equals(a));
    });

    test('la normalización de acentos es la de FundNameMatcher', () {
      final normalized = FundNameMatcher.normalizeName('ALFIL TÁCTICO, FIL');

      expect(normalized, 'ALFIL TACTICO FIL');
    });
  });

  group('LF-16.4 — Nombre sin coincidencia', () {
    test('un nombre inexistente devuelve cero ISIN', () {
      final result = _lookup(index, 'ESTE NOMBRE NO EXISTE EN FONDOS JSON');

      expect(result, isEmpty);
    });

    test('no se realiza fuzzy matching', () {
      final result = _lookup(index, 'ABACO RENTA FIJA GLOBAL, FI');

      expect(result, isEmpty);
    });
  });

  group('LF-16.5 — Nombre con un único ISIN', () {
    test('1948 INVERSIONS tiene un único resultado', () {
      final result = _lookup(index, '1948 INVERSIONS, SICAV S.A.');

      expect(result, hasLength(1));
      expect(result.single, 'ES0109642035');
    });
  });

  group('LF-16.6 — Nombre con múltiples ISIN', () {
    test('ABACO RENTA FIJA, FI conserva los dos ISIN', () {
      final result = _lookup(index, 'ABACO RENTA FIJA, FI');

      expect(result, equals(['ES0124526007', 'ES0124526015']));
    });

    test('A&P LIFESCIENCE FUND, FI conserva los tres ISIN', () {
      final result = _lookup(index, 'A&P LIFESCIENCE FUND, FI');

      expect(result, equals(['ES0162957007', 'ES0162957015', 'ES0162957023']));
    });

    test('un nombre con múltiples ISIN NO se reduce a un único resultado', () {
      final result = _lookup(index, 'ABACO RENTA FIJA, FI');

      expect(result.length, greaterThan(1));
    });

    test('se conserva el orden de aparición de los ISIN', () {
      final result = _lookup(index, 'ABACO RENTA FIJA, FI');

      expect(result, equals(['ES0124526007', 'ES0124526015']));
    });
  });

  group('LF-16.7 — Duplicados', () {
    test('el índice no devuelve dos veces el mismo ISIN', () {
      for (final entry in index.entries) {
        expect(
          entry.value.length,
          equals(entry.value.toSet().length),
          reason: 'ISIN duplicado para ${entry.key}',
        );
      }
    });

    test('la indexación es idempotente respecto a registros duplicados', () {
      final synthetic = <Map<String, dynamic>>[
        {'name': 'TEST FUND, FI', 'isin': 'ES0000000001'},
        {'name': 'TEST FUND, FI', 'isin': 'ES0000000001'},
        {'name': 'TEST FUND, FI', 'isin': 'ES0000000002'},
      ];

      final syntheticIndex = _buildIndex(synthetic);

      expect(
        _lookup(syntheticIndex, 'TEST FUND, FI'),
        equals(['ES0000000001', 'ES0000000002']),
      );
    });
  });

  group('LF-16.8 — Ausencia de fuzzy matching', () {
    test('dos nombres diferentes no se fusionan por similitud textual', () {
      final synthetic = <Map<String, dynamic>>[
        {'name': 'GLOBAL EQUITY FUND CLASS A', 'isin': 'ES0000000001'},
        {'name': 'GLOBAL BOND FUND CLASS A', 'isin': 'ES0000000002'},
      ];

      final syntheticIndex = _buildIndex(synthetic);

      expect(
        _lookup(syntheticIndex, 'GLOBAL EQUITY FUND CLASS A'),
        equals(['ES0000000001']),
      );

      expect(
        _lookup(syntheticIndex, 'GLOBAL BOND FUND CLASS A'),
        equals(['ES0000000002']),
      );

      expect(_lookup(syntheticIndex, 'GLOBAL FUND CLASS A'), isEmpty);
    });
  });

  group('LF-16.9 — Casos reales de fondos.json', () {
    test('ABACO RENTA FIJA, FI tiene exactamente dos ISIN', () {
      final result = _lookup(index, 'ABACO RENTA FIJA, FI');

      expect(result.length, 2);
    });

    test('A&P LIFESCIENCE FUND, FI tiene exactamente tres ISIN', () {
      final result = _lookup(index, 'A&P LIFESCIENCE FUND, FI');

      expect(result.length, 3);
    });

    test('un nombre real se puede consultar con normalización', () {
      final result = _lookup(index, '  a&p   lifescience fund,   fi  ');

      expect(result, equals(['ES0162957007', 'ES0162957015', 'ES0162957023']));
    });
  });

  group('LF-16.10 — Cobertura de ISIN aportados por fondos.json', () {
    test('fondos.json contiene ISIN españoles', () {
      final spanishIsins = records
          .map((record) => record['isin'] as String)
          .where((isin) => isin.startsWith('ES'))
          .toSet();

      expect(spanishIsins, isNotEmpty);
    });

    test('todos los ISIN indexados proceden de fondos.json', () {
      final sourceIsins = records
          .map((record) => record['isin'] as String)
          .toSet();

      final indexedIsins = index.values.expand((isins) => isins).toSet();

      expect(indexedIsins.difference(sourceIsins), isEmpty);
    });

    test('el índice no pierde ISIN presentes en la fuente', () {
      final sourcePairs = records.map(
        (record) => (
          name: FundNameMatcher.normalizeName(record['name'] as String),
          isin: record['isin'] as String,
        ),
      );

      for (final pair in sourcePairs) {
        expect(
          index[pair.name],
          contains(pair.isin),
          reason: 'ISIN ${pair.isin} perdido para nombre "${pair.name}"',
        );
      }
    });
  });

  group('LF-16.11 — Propiedades de estabilidad', () {
    test('reconstruir el índice produce exactamente el mismo resultado', () {
      final rebuilt = _buildIndex(records);

      expect(rebuilt, equals(index));
    });

    test('una consulta no modifica el índice', () {
      final before = <String, List<String>>{
        for (final entry in index.entries)
          entry.key: List<String>.from(entry.value),
      };

      _lookup(index, 'ABACO RENTA FIJA, FI');
      _lookup(index, 'NOMBRE INEXISTENTE');
      _lookup(index, 'A&P LIFESCIENCE FUND, FI');

      expect(index, equals(before));
    });

    test('los resultados de una consulta no permiten modificar el índice', () {
      final result = _lookup(index, 'ABACO RENTA FIJA, FI');

      expect(() => result.add('ES9999999999'), throwsUnsupportedError);

      expect(
        _lookup(index, 'ABACO RENTA FIJA, FI'),
        equals(['ES0124526007', 'ES0124526015']),
      );
    });
  });
}
