import 'dart:convert';
import 'dart:io';

/// Genera y valida assets/files/isin_database.json.
///
/// Arquitectura:
///   - fondos_no_armonizados.json es propiedad de CnmvLocalFundProvider.
///   - Las entradas CNMV/FI no se conservan en isin_database.json.
///   - isin_database.json contiene únicamente entradas de enriquecimiento
///     local/manual, por ejemplo fondos extranjeros y sus identificadores
///     Yahoo/Morningstar.
///
/// Uso:
///   dart run lib/tools/build_isin_database.dart
///   dart run lib/tools/build_isin_database.dart --check
///
/// --check valida el fichero existente y no escribe nada.

const _databasePath = 'assets/files/isin_database.json';
const _cnmvPath = 'assets/files/fondos_no_armonizados.json';

void main(List<String> args) {
  final checkOnly = args.contains('--check');

  if (args.any((arg) => arg != '--check')) {
    _fatal('Argumento no reconocido. Uso: [--check]');
  }

  final databaseFile = File(_databasePath);
  final cnmvFile = File(_cnmvPath);

  print('');
  print('=' * 72);
  print('BUILD ISIN DATABASE');
  print('=' * 72);
  print('CNMV    : ${cnmvFile.absolute.path}');
  print('DATABASE: ${databaseFile.absolute.path}');
  print('MODO    : ${checkOnly ? 'VALIDACIÓN' : 'GENERACIÓN'}');
  print('');

  if (!databaseFile.existsSync()) {
    _fatal('No existe $_databasePath');
  }

  if (!cnmvFile.existsSync()) {
    _fatal('No existe $_cnmvPath');
  }

  final database = _readJsonMap(databaseFile);
  final cnmv = _readJsonMap(cnmvFile);

  final allExistingEntries = _extractExistingEntries(database);

  print('Entradas existentes: ${allExistingEntries.length}');

  // Primero inspeccionamos el catálogo CNMV. Nunca se importa al database.
  final cnmvStats = _inspectCnmv(cnmv);

  print('');
  print('CNMV/FI');
  print('  FechaDatos       : ${cnmvStats.fechaDatos ?? '-'}');
  print('  Entidades FI     : ${cnmvStats.entities}');
  print('  Clases           : ${cnmvStats.classes}');
  print('  ISIN únicos      : ${cnmvStats.uniqueIsins}');
  print('  Clases inválidas : ${cnmvStats.invalidIsins}');

  if (cnmvStats.invalidIsins > 0) {
    _fatal(
      'El catálogo CNMV contiene ${cnmvStats.invalidIsins} ISIN inválidos.',
    );
  }

  // Validamos primero el fichero tal y como está para detectar corrupción,
  // duplicados o campos obligatorios ausentes antes de hacer la limpieza.
  _validateEntries(allExistingEntries);

  // En versiones anteriores el builder importó las 3116 clases CNMV.
  // Ahora las eliminamos de forma determinista usando source=cnmv-fi.
  //
  // Como salvaguarda adicional, si alguna entrada antigua no tiene source
  // cnmv-fi pero contiene el bloque "cnmv", también se considera CNMV/FI.
  final manualEntries = allExistingEntries
      .where((entry) => !_isCnmvFiEntry(entry))
      .toList();

  final removed = allExistingEntries.length - manualEntries.length;

  print('');
  print('LIMPIEZA CNMV/FI');
  print('  Entradas CNMV/FI eliminadas : $removed');
  print('  Entradas conservadas        : ${manualEntries.length}');

  _validateEntries(manualEntries);

  print('');
  print('VALIDACIÓN DE isin_database.json: OK');
  print('  ISIN únicos      : ${manualEntries.length}');
  print(
    '  Ticker no nulos  : ${manualEntries.where((e) => e['ticker'] != null).length}',
  );
  print(
    '  Morningstar IDs  : '
    '${_countMorningstarIds(manualEntries)}',
  );

  if (checkOnly) {
    print('');
    print('Modo --check: no se ha modificado ningún archivo.');
    return;
  }

  final output = <String, dynamic>{
    'version': _readVersion(database),
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'entries': manualEntries,
  };

  const encoder = JsonEncoder.withIndent('  ');

  databaseFile.writeAsStringSync('${encoder.convert(output)}\n');

  print('');
  print('Archivo generado: ${databaseFile.absolute.path}');
  print('Entradas conservadas: ${manualEntries.length}');
  print('Entradas CNMV/FI eliminadas: $removed');
  print('CNMV/FI NO importado: ${cnmvStats.classes} clases');
  print('VALIDACIÓN OK.');
}

bool _isCnmvFiEntry(Map<String, dynamic> entry) {
  final source = entry['source'];

  if (source is String && source.trim().toLowerCase() == 'cnmv-fi') {
    return true;
  }

  // Compatibilidad con cualquier versión anterior que hubiera guardado
  // información CNMV aunque source no fuera exactamente "cnmv-fi".
  return entry['cnmv'] is Map;
}

Map<String, dynamic> _readJsonMap(File file) {
  try {
    final decoded = jsonDecode(file.readAsStringSync());

    if (decoded is! Map<String, dynamic>) {
      _fatal('El JSON ${file.path} debe tener un objeto como raíz.');
    }

    return decoded;
  } on FormatException catch (e) {
    _fatal('JSON inválido en ${file.path}: ${e.message}');
  }

  throw StateError('Unreachable');
}

int _readVersion(Map<String, dynamic> database) {
  final value = database['version'];

  if (value is int && value > 0) {
    return value;
  }

  if (value is num && value.toInt() > 0) {
    return value.toInt();
  }

  _fatal('Campo "version" ausente o inválido en $_databasePath.');
  throw StateError('Unreachable');
}

List<Map<String, dynamic>> _extractExistingEntries(
  Map<String, dynamic> database,
) {
  final rawEntries = database['entries'];

  if (rawEntries is! List) {
    _fatal('El campo "entries" de $_databasePath debe ser una lista.');
  }

  final entries = <Map<String, dynamic>>[];

  for (var i = 0; i < rawEntries.length; i++) {
    final raw = rawEntries[i];

    if (raw is! Map) {
      _fatal('entries[$i] no es un objeto.');
    }

    entries.add(_normalizeEntry(Map<String, dynamic>.from(raw), i));
  }

  return entries;
}

Map<String, dynamic> _normalizeEntry(Map<String, dynamic> entry, int index) {
  final result = Map<String, dynamic>.from(entry);

  final isin = result['isin'];
  if (isin is String) {
    result['isin'] = isin.trim().toUpperCase();
  }

  final ticker = result['ticker'];
  if (ticker is String) {
    final normalizedTicker = ticker.trim();
    result['ticker'] = normalizedTicker.isEmpty ? null : normalizedTicker;
  }

  final name = result['name'];
  if (name is String) {
    result['name'] = name.trim();
  }

  final source = result['source'];
  if (source is String) {
    result['source'] = source.trim();
  }

  final status = result['status'];
  if (status is String) {
    result['status'] = status.trim();
  }

  final morningstar = result['morningstar'];

  if (morningstar != null) {
    if (morningstar is! Map) {
      _fatal('entries[$index].morningstar debe ser un objeto o null.');
    }

    final normalizedMorningstar = <String, dynamic>{};

    for (final key in const ['performanceId', 'securityId', 'fundId']) {
      final value = morningstar[key];

      if (value == null) {
        normalizedMorningstar[key] = null;
      } else if (value is String) {
        final normalized = value.trim();
        normalizedMorningstar[key] = normalized.isEmpty ? null : normalized;
      } else {
        _fatal('entries[$index].morningstar.$key debe ser String o null.');
      }
    }

    result['morningstar'] = normalizedMorningstar;
  }

  return result;
}

void _validateEntries(List<Map<String, dynamic>> entries) {
  final seenIsins = <String, int>{};
  final seenTickers = <String, int>{};
  final seenMorningstar = <String, String>{};

  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];

    final isin = entry['isin'];

    if (isin is! String || isin.isEmpty) {
      _fatal('entries[$i]: falta el campo obligatorio "isin".');
    }

    if (!_isValidIsin(isin)) {
      _fatal('ISIN inválido en entrada existente: $isin');
    }

    final previousIsin = seenIsins[isin];

    if (previousIsin != null) {
      _fatal(
        'ISIN duplicado: $isin '
        '(entries[$previousIsin] y entries[$i]).',
      );
    }

    seenIsins[isin] = i;

    final name = entry['name'];

    if (name is! String || name.trim().isEmpty) {
      _fatal('entries[$i]: falta el campo obligatorio "name".');
    }

    final source = entry['source'];

    if (source is! String || source.trim().isEmpty) {
      _fatal('entries[$i]: falta el campo obligatorio "source".');
    }

    final status = entry['status'];

    if (status is! String || status.trim().isEmpty) {
      _fatal('entries[$i]: falta el campo obligatorio "status".');
    }

    final ticker = entry['ticker'];

    if (ticker != null) {
      if (ticker is! String || ticker.trim().isEmpty) {
        _fatal('entries[$i].ticker debe ser String no vacío o null.');
      }

      final normalizedTicker = ticker.trim().toUpperCase();
      final previousTicker = seenTickers[normalizedTicker];

      if (previousTicker != null) {
        _fatal(
          'Ticker duplicado: $ticker '
          '(entries[$previousTicker] y entries[$i]).',
        );
      }

      seenTickers[normalizedTicker] = i;
    }

    _validateMorningstar(entry, i, seenMorningstar);
  }
}

void _validateMorningstar(
  Map<String, dynamic> entry,
  int index,
  Map<String, String> seenMorningstar,
) {
  final raw = entry['morningstar'];

  if (raw == null) {
    return;
  }

  if (raw is! Map) {
    _fatal('entries[$index].morningstar debe ser un objeto o null.');
  }

  for (final key in const ['performanceId', 'securityId', 'fundId']) {
    final value = raw[key];

    if (value == null) {
      continue;
    }

    if (value is! String || value.trim().isEmpty) {
      _fatal(
        'entries[$index].morningstar.$key '
        'debe ser String no vacío o null.',
      );
    }

    final normalized = value.trim().toUpperCase();
    final identity = 'morningstar:$key:$normalized';
    final previous = seenMorningstar[identity];

    if (previous != null && previous != entry['isin']) {
      _fatal(
        'Identificador Morningstar duplicado: '
        '$key=$value ($previous y ${entry['isin']}).',
      );
    }

    seenMorningstar[identity] = entry['isin'].toString();
  }
}

int _countMorningstarIds(List<Map<String, dynamic>> entries) {
  var count = 0;

  for (final entry in entries) {
    final morningstar = entry['morningstar'];

    if (morningstar is Map) {
      for (final key in const ['performanceId', 'securityId', 'fundId']) {
        final value = morningstar[key];

        if (value is String && value.trim().isNotEmpty) {
          count++;
        }
      }
    }
  }

  return count;
}

/// Inspecciona el catálogo CNMV/FI sin incorporarlo al database.
_CnmvStats _inspectCnmv(Map<String, dynamic> root) {
  final registro = root['FondRegistro'];

  if (registro is! Map) {
    _fatal('El CNMV JSON no contiene "FondRegistro".');
  }

  final fechaDatos = registro['FechaDatos']?.toString();
  final rawEntities = registro['Entidad'];

  if (rawEntities is! List) {
    _fatal('FondRegistro.Entidad debe ser una lista.');
  }

  var entities = 0;
  var classes = 0;
  var invalidIsins = 0;
  final isins = <String>{};

  for (final rawEntity in rawEntities) {
    if (rawEntity is! Map) {
      continue;
    }

    if (rawEntity['Tipo']?.toString().toUpperCase() != 'FI') {
      continue;
    }

    entities++;

    final compartments = _asListOrSingle(rawEntity['Compartimento']);

    for (final compartment in compartments) {
      if (compartment is! Map) {
        continue;
      }

      final classEntries = _asListOrSingle(compartment['Clase']);

      for (final rawClass in classEntries) {
        if (rawClass is! Map) {
          continue;
        }

        classes++;

        final isin = rawClass['ISIN']?.toString().trim().toUpperCase();

        if (isin == null || isin.isEmpty || !_isValidIsin(isin)) {
          invalidIsins++;
          continue;
        }

        isins.add(isin);
      }
    }
  }

  return _CnmvStats(
    fechaDatos: fechaDatos,
    entities: entities,
    classes: classes,
    uniqueIsins: isins.length,
    invalidIsins: invalidIsins,
  );
}

List<dynamic> _asListOrSingle(dynamic value) {
  if (value == null) {
    return const [];
  }

  if (value is List) {
    return value;
  }

  return [value];
}

/// Validador ISIN mediante expansión alfanumérica + Luhn.
bool _isValidIsin(String value) {
  final isin = value.trim().toUpperCase();

  if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) {
    return false;
  }

  final digits = <int>[];

  for (final char in isin.split('')) {
    final code = char.codeUnitAt(0);

    if (code >= 65 && code <= 90) {
      final number = code - 55;
      digits.add(number ~/ 10);
      digits.add(number % 10);
    } else {
      digits.add(int.parse(char));
    }
  }

  var sum = 0;

  for (var i = 0; i < digits.length; i++) {
    var digit = digits[digits.length - 1 - i];

    if (i.isOdd) {
      digit *= 2;

      if (digit > 9) {
        digit -= 9;
      }
    }

    sum += digit;
  }

  return sum % 10 == 0;
}

class _CnmvStats {
  final String? fechaDatos;
  final int entities;
  final int classes;
  final int uniqueIsins;
  final int invalidIsins;

  const _CnmvStats({
    required this.fechaDatos,
    required this.entities,
    required this.classes,
    required this.uniqueIsins,
    required this.invalidIsins,
  });
}

Never _fatal(String message) {
  stderr.writeln('');
  stderr.writeln('ERROR: $message');
  throw StateError(message);
}
