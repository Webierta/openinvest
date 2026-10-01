import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../utils/fund_name_matcher.dart';
import '../utils/isin_validator.dart';

class CnmvFundClass {
  final int number;
  final String name;
  final String isin;

  const CnmvFundClass({
    required this.number,
    required this.name,
    required this.isin,
  });

  @override
  String toString() => '$name -> $isin';
}

class CnmvFundResult {
  final int registrationNumber;
  final String fundName;
  final String? compartmentName;
  final int? compartmentNumber;
  final CnmvFundClass fundClass;
  final String? managerName;
  final String? depositaryName;

  const CnmvFundResult({
    required this.registrationNumber,
    required this.fundName,
    required this.compartmentName,
    required this.compartmentNumber,
    required this.fundClass,
    required this.managerName,
    required this.depositaryName,
  });

  String get isin => fundClass.isin;

  @override
  String toString() =>
      '$fundName | ${compartmentName ?? ''} | '
      '${fundClass.name} -> $isin';
}

/// Proveedor local para el catálogo CNMV de fondos de inversión (FI).
///
/// Conserva la jerarquía Entidad -> Compartimento -> Clase -> ISIN.
/// No selecciona arbitrariamente una clase cuando existen varias.
///
/// La resolución por nombre es deliberadamente conservadora:
/// - coincidencia exacta tras normalización;
/// - coincidencia con exactamente los mismos tokens, independientemente
///   de su orden.
///
/// No utiliza coincidencias por prefijo ni similitud aproximada, ya que
/// pueden confundir fondos distintos que solamente comparten gran parte
/// de la denominación.
class CnmvLocalFundProvider {
  static const String assetPath = 'assets/files/fondos_no_armonizados.json';

  static List<CnmvFundResult>? _globalResults;

  final Future<String> Function(String path) _loadAsset;
  List<CnmvFundResult>? _results;

  // Future de la carga actualmente en curso.
  //
  // Permite que varias llamadas concurrentes a _ensureLoaded() compartan
  // una única operación de lectura y parseo.
  Future<void>? _loading;

  CnmvLocalFundProvider({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  Future<CnmvFundResult?> resolve({required String fundName}) async {
    await _ensureLoaded();

    final query = FundNameMatcher.normalizeName(fundName);
    if (query.isEmpty) return null;

    final candidates = _results!
        .where((entry) => _nameMatchesFund(query, entry))
        .toList();

    if (candidates.isEmpty) {
      _log('CnmvLocalFundProvider: no encontrado: $fundName');
      return null;
    }

    // 1. Coincidencia exacta de fondo + clase.
    //
    // Ejemplo:
    //   FONMARCH FI CLASE C
    //
    // Esto tiene prioridad porque identifica explícitamente una clase.
    final exactClass = candidates.where((entry) {
      final fullName = FundNameMatcher.normalizeName(
        '${entry.fundName} ${entry.fundClass.name}',
      );
      return fullName == query;
    }).toList();

    if (exactClass.length == 1) {
      return exactClass.single;
    }

    // Si hubiera más de un registro exactamente igual, solamente podemos
    // resolverlo si todos conducen al mismo ISIN.
    if (exactClass.length > 1) {
      final isins = exactClass.map((entry) => entry.isin).toSet();

      if (isins.length == 1) {
        return exactClass.first;
      }

      _log(
        'CnmvLocalFundProvider: ambiguo "$fundName" '
        '(${exactClass.length} clases exactas).',
      );
      return null;
    }

    // 2. Coincidencia exacta de la denominación del fondo.
    //
    // Puede haber varias clases para la misma denominación. En ese caso
    // no elegimos una clase arbitrariamente.
    final exactFund = candidates.where((entry) {
      final fund = FundNameMatcher.normalizeName(entry.fundName);
      return fund == query;
    }).toList();

    if (exactFund.isNotEmpty) {
      final isins = exactFund.map((entry) => entry.isin).toSet();

      // Varias clases que apuntan al mismo ISIN son equivalentes para
      // resolver el ISIN.
      if (isins.length == 1) {
        return exactFund.first;
      }

      _log(
        'CnmvLocalFundProvider: ambiguo "$fundName" '
        '(${exactFund.length} clases, ${isins.length} ISIN).',
      );
      return null;
    }

    // 3. Coincidencia por conjunto exacto de tokens.
    //
    // _nameMatchesFund() ya ha garantizado que los tokens coinciden
    // exactamente. Llegar aquí significa que la diferencia es solamente
    // el orden de los tokens.
    //
    // Si hay varios registros, seguimos sin escoger arbitrariamente.
    final isins = candidates.map((entry) => entry.isin).toSet();

    if (isins.length == 1) {
      return candidates.first;
    }

    _log(
      'CnmvLocalFundProvider: ambiguo "$fundName" '
      '(${candidates.length} candidatos, ${isins.length} ISIN).',
    );
    return null;
  }

  Future<List<CnmvFundResult>> findAll({required String fundName}) async {
    await _ensureLoaded();

    final query = FundNameMatcher.normalizeName(fundName);
    if (query.isEmpty) return const [];

    return List.unmodifiable(
      _results!.where((entry) => _nameMatchesFund(query, entry)).toList(),
    );
  }

  /// Garantiza que el catálogo esté cargado.
  ///
  /// Si ya está cargado, retorna inmediatamente.
  ///
  /// Si existe una carga en curso, comparte su Future en lugar de iniciar
  /// otra lectura y otro parseo del asset.
  ///
  /// Si no existe ninguna carga, inicia una nueva.
  Future<void> _ensureLoaded() {
    if (_results != null) {
      return Future.value();
    }

    final current = _loading;
    if (current != null) {
      return current;
    }

    late Future<void> future;

    future = _loadAndCache().whenComplete(() {
      // Solamente limpiamos _loading si sigue siendo la misma operación.
      //
      // Esto evita que una operación antigua pueda limpiar accidentalmente
      // el Future de una carga posterior.
      if (identical(_loading, future)) {
        _loading = null;
      }
    });

    _loading = future;
    return future;
  }

  /// Carga, valida y transforma el catálogo CNMV.
  ///
  /// Esta función representa la operación de carga compartida por
  /// _ensureLoaded().
  Future<void> _loadAndCache() async {
    if (_loadAsset == rootBundle.loadString && _globalResults != null) {
      _results = _globalResults;
      return;
    }

    final raw = await _loadAsset(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'fondos_no_armonizados.json debe contener un objeto JSON.',
      );
    }

    final registro = decoded['FondRegistro'];
    if (registro is! Map) {
      throw const FormatException(
        'fondos_no_armonizados.json no contiene "FondRegistro".',
      );
    }

    final entidades = registro['Entidad'];
    if (entidades is! List) {
      throw const FormatException(
        'FondRegistro no contiene un array "Entidad".',
      );
    }

    final results = <CnmvFundResult>[];

    for (final rawEntity in entidades) {
      if (rawEntity is! Map) continue;

      if (rawEntity['Tipo']?.toString().trim().toUpperCase() != 'FI') {
        continue;
      }

      final registrationNumber = _toInt(rawEntity['NumeroRegistro']);
      final fundName = rawEntity['Denominacion']?.toString().trim() ?? '';

      if (registrationNumber == null || fundName.isEmpty) {
        continue;
      }

      final manager = rawEntity['Gestora'];
      final depositary = rawEntity['Depositario'];

      final managerName = manager is Map
          ? manager['DenominacionGestora']?.toString()
          : null;

      final depositaryName = depositary is Map
          ? depositary['DenominacionDepositario']?.toString()
          : null;

      final rawCompartments = rawEntity['Compartimento'];
      if (rawCompartments == null) continue;

      final compartments = rawCompartments is List
          ? rawCompartments
          : <dynamic>[rawCompartments];

      for (final rawCompartment in compartments) {
        if (rawCompartment is! Map) continue;

        final compartmentNumber = _toInt(rawCompartment['NumeroCompartimento']);

        final compartmentName = rawCompartment['DenominacionCompartimento']
            ?.toString();

        final rawClasses = rawCompartment['Clase'];
        if (rawClasses == null) continue;

        final classes = rawClasses is List ? rawClasses : <dynamic>[rawClasses];

        for (final rawClass in classes) {
          if (rawClass is! Map) continue;

          final classNumber = _toInt(rawClass['NumeroClase']);

          final className =
              rawClass['DenominacionClase']?.toString().trim() ?? '';

          final isin = rawClass['ISIN']?.toString().trim().toUpperCase() ?? '';

          if (classNumber == null ||
              className.isEmpty ||
              !IsinValidator.isValid(isin)) {
            continue;
          }

          results.add(
            CnmvFundResult(
              registrationNumber: registrationNumber,
              fundName: fundName,
              compartmentName: compartmentName,
              compartmentNumber: compartmentNumber,
              fundClass: CnmvFundClass(
                number: classNumber,
                name: className,
                isin: isin,
              ),
              managerName: managerName,
              depositaryName: depositaryName,
            ),
          );
        }
      }
    }

    _results = List.unmodifiable(results);

    if (_loadAsset == rootBundle.loadString) {
      _globalResults = _results;
    }

    _log(
      'CnmvLocalFundProvider: ${results.length} clases cargadas '
      '(${registro['FechaDatos'] ?? 'sin fecha'}).',
    );
  }

  /// Determina si [entry] puede considerarse una coincidencia nominal
  /// segura para [query].
  ///
  /// Solamente se aceptan:
  ///
  /// 1. igualdad exacta después de normalización;
  /// 2. igualdad exacta del conjunto de tokens, independientemente
  ///    de su orden.
  ///
  /// No se aceptan:
  ///
  /// - prefijos;
  /// - nombres contenidos en otros nombres;
  /// - similitud Jaccard;
  /// - umbrales de similitud;
  /// - variantes que añaden o eliminan tokens.
  bool _nameMatchesFund(String query, CnmvFundResult entry) {
    final fund = FundNameMatcher.normalizeName(entry.fundName);

    if (query.isEmpty || fund.isEmpty) {
      return false;
    }

    if (query == fund || _sameTokens(query, fund)) {
      return true;
    }

    final fullName = FundNameMatcher.normalizeName(
      '${entry.fundName} ${entry.fundClass.name}',
    );

    return query == fullName || _sameTokens(query, fullName);
  }

  /// Comprueba igualdad exacta de tokens ignorando solamente su orden.
  ///
  /// No utiliza frecuencia de aparición: los nombres de fondos se
  /// consideran conjuntos de tokens para este criterio concreto.
  bool _sameTokens(String a, String b) {
    final aTokens = a.split(' ').where((token) => token.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((token) => token.isNotEmpty).toSet();

    if (aTokens.length != bTokens.length) {
      return false;
    }

    return aTokens.containsAll(bTokens);
  }

  int? _toInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}

void _log(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'CnmvLocalFundProvider');
  }
}
