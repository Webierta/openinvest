import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

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
class CnmvLocalFundProvider {
  static const String assetPath = 'assets/files/fondos_no_armonizados.json';

  final Future<String> Function(String path) _loadAsset;
  List<CnmvFundResult>? _results;

  CnmvLocalFundProvider({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  Future<CnmvFundResult?> resolve({required String fundName}) async {
    await _ensureLoaded();

    final query = _normalizeName(fundName);
    if (query.isEmpty) return null;

    final candidates = _results!
        .where((entry) => _nameMatchesFund(query, entry))
        .toList();

    if (candidates.isEmpty) {
      print('CnmvLocalFundProvider: no encontrado: $fundName');
      return null;
    }

    final exact = candidates.where((entry) {
      final full = _normalizeName('${entry.fundName} ${entry.fundClass.name}');
      return full == query;
    }).toList();

    if (exact.length == 1) return exact.single;

    final classMatches = candidates.where((entry) {
      final className = _normalizeName(entry.fundClass.name);
      return className.isNotEmpty && query.contains(className);
    }).toList();

    if (classMatches.length == 1) return classMatches.single;

    final uniqueIsins = candidates.map((e) => e.isin).toSet();
    if (uniqueIsins.length == 1) return candidates.first;

    print(
      'CnmvLocalFundProvider: ambiguo "$fundName" '
      '(${candidates.length} clases).',
    );
    return null;
  }

  Future<List<CnmvFundResult>> findAll({required String fundName}) async {
    await _ensureLoaded();
    final query = _normalizeName(fundName);
    if (query.isEmpty) return const [];

    return List.unmodifiable(
      _results!.where((entry) => _nameMatchesFund(query, entry)).toList(),
    );
  }

  Future<void> _ensureLoaded() async {
    if (_results != null) return;

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
      if (registrationNumber == null || fundName.isEmpty) continue;

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
    print(
      'CnmvLocalFundProvider: ${results.length} clases cargadas '
      '(${registro['FechaDatos'] ?? 'sin fecha'}).',
    );
  }

  bool _nameMatchesFund(String query, CnmvFundResult entry) {
    final fund = _normalizeName(entry.fundName);
    if (query == fund) return true;
    if (query.startsWith('$fund ')) return true;
    if (fund.startsWith('$query ')) return true;
    return _nameSimilarity(query, fund) >= 0.82;
  }

  String _normalizeName(String value) {
    var result = value.toUpperCase();
    const replacements = <String, String>{
      'Á': 'A',
      'À': 'A',
      'Ä': 'A',
      'Â': 'A',
      'É': 'E',
      'È': 'E',
      'Ë': 'E',
      'Ê': 'E',
      'Í': 'I',
      'Ì': 'I',
      'Ï': 'I',
      'Î': 'I',
      'Ó': 'O',
      'Ò': 'O',
      'Ö': 'O',
      'Ô': 'O',
      'Ú': 'U',
      'Ù': 'U',
      'Ü': 'U',
      'Û': 'U',
      'Ñ': 'N',
      '&': ' ',
      '-': ' ',
      '_': ' ',
      '/': ' ',
      ',': ' ',
      '.': ' ',
      ':': ' ',
      ';': ' ',
      '(': ' ',
      ')': ' ',
    };
    replacements.forEach((from, to) => result = result.replaceAll(from, to));
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  double _nameSimilarity(String a, String b) {
    final aa = _normalizeName(a);
    final bb = _normalizeName(b);
    if (aa.isEmpty || bb.isEmpty) return 0.0;
    if (aa == bb) return 1.0;
    final ta = aa.split(' ').where((x) => x.length > 2).toSet();
    final tb = bb.split(' ').where((x) => x.length > 2).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    return ta.intersection(tb).length / ta.union(tb).length;
  }

  int? _toInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
}
