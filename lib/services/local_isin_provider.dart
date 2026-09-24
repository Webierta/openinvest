import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/foreign_isin_provider.dart';
import '../utils/isin_validator.dart';

class MorningstarIds {
  final String? performanceId;
  final String? securityId;
  final String? fundId;

  const MorningstarIds({this.performanceId, this.securityId, this.fundId});
}

/// Entrada de la base local de ISIN.
class LocalIsinEntry {
  final String isin;
  final String name;
  final String? ticker;
  final MorningstarIds? morningstar;

  const LocalIsinEntry({
    required this.isin,
    required this.name,
    this.ticker,
    this.morningstar,
  });

  factory LocalIsinEntry.fromJson(Map<String, dynamic> json) {
    return LocalIsinEntry(
      isin: json['isin'].toString().toUpperCase(),
      name: json['name']?.toString() ?? '',
      ticker: json['ticker']?.toString(),
      morningstar: json['morningstar'] is Map<String, dynamic>
          ? MorningstarIds(
              performanceId: json['morningstar']['performanceId']?.toString(),
              securityId: json['morningstar']['securityId']?.toString(),
              fundId: json['morningstar']['fundId']?.toString(),
            )
          : null,
    );
  }
}

/// Resuelve ISIN exclusivamente desde assets/data/isin_database.json.
class LocalIsinProvider implements ForeignIsinProvider {
  static const String assetPath = 'assets/files/isin_database.json';

  final Future<String> Function(String path) _loadAsset;

  Map<String, LocalIsinEntry>? _byMorningstarId;
  Map<String, LocalIsinEntry>? _byTicker;
  List<LocalIsinEntry>? _entries;

  LocalIsinProvider({Future<String> Function(String path)? loadAsset})
    : _loadAsset = loadAsset ?? rootBundle.loadString;

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    await _ensureLoaded();

    final morningstarId =
        _extractMorningstarId(yahooSymbol) ?? _extractMorningstarId(ticker);

    if (morningstarId != null) {
      final entry = _byMorningstarId![morningstarId];
      if (entry != null) {
        _log(
          '  LocalIsinProvider: Morningstar $morningstarId -> ${entry.isin}',
        );
        return entry.isin;
      }
    }

    final symbols = <String>{
      yahooSymbol.trim().toUpperCase(),
      ticker.trim().toUpperCase(),
    };

    for (final symbol in symbols) {
      final entry = _byTicker![symbol];
      if (entry != null) {
        _log('  LocalIsinProvider: ticker $symbol -> ${entry.isin}');
        return entry.isin;
      }
    }

    final best = _findBestNameMatch(fundName, yahooName);
    if (best != null) {
      _log('  LocalIsinProvider: nombre -> ${best.isin} (${best.name})');
      return best.isin;
    }

    _log('  LocalIsinProvider: no encontrado.');
    return null;
  }

  Future<void> _ensureLoaded() async {
    if (_entries != null) return;

    final raw = await _loadAsset(assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map) {
      throw const FormatException(
        'isin_database.json debe contener un objeto JSON.',
      );
    }

    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException(
        'isin_database.json no contiene un array "entries".',
      );
    }

    final entries = <LocalIsinEntry>[];

    for (final item in rawEntries) {
      if (item is! Map) continue;

      try {
        final entry = LocalIsinEntry.fromJson(Map<String, dynamic>.from(item));

        //if (_isValidIsin(entry.isin)) {
        if (IsinValidator.isValid(entry.isin)) {
          entries.add(entry);
        }
      } catch (_) {
        // Ignorar una entrada corrupta y continuar con las demás.
      }
    }

    _entries = List.unmodifiable(entries);
    _byMorningstarId = <String, LocalIsinEntry>{};
    _byTicker = <String, LocalIsinEntry>{};

    for (final entry in entries) {
      final morningstar = entry.morningstar;

      // Morningstar puede identificar la misma clase mediante distintos
      // identificadores. Los indexamos todos para no depender únicamente
      // de performanceId.
      final morningstarIds = <String?>[
        morningstar?.performanceId,
        morningstar?.securityId,
        morningstar?.fundId,
      ];

      for (final id in morningstarIds) {
        if (id != null && id.trim().isNotEmpty) {
          _byMorningstarId![id.trim().toUpperCase()] = entry;
        }
      }

      final entryTicker = entry.ticker;
      if (entryTicker != null && entryTicker.isNotEmpty) {
        _byTicker![entryTicker.toUpperCase()] = entry;
      }
    }

    _log('LocalIsinProvider: ${entries.length} entradas cargadas.');
  }

  LocalIsinEntry? _findBestNameMatch(String fundName, String yahooName) {
    LocalIsinEntry? best;
    var bestScore = 0.0;

    for (final entry in _entries!) {
      final a = _nameSimilarity(fundName, entry.name);
      final b = _nameSimilarity(yahooName, entry.name);
      final score = a > b ? a : b;

      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }

    return bestScore >= 0.75 ? best : null;
  }

  String? _extractMorningstarId(String value) {
    final match = RegExp(
      r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    return match?.group(1)?.toUpperCase();
  }

  double _nameSimilarity(String a, String b) {
    final left = _normalizeName(a);
    final right = _normalizeName(b);

    if (left.isEmpty || right.isEmpty) return 0.0;
    if (left == right) return 1.0;

    final lt = left.split(' ').where((e) => e.length > 2).toSet();
    final rt = right.split(' ').where((e) => e.length > 2).toSet();

    if (lt.isEmpty || rt.isEmpty) return 0.0;

    return lt.intersection(rt).length / lt.union(rt).length;
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
}

void _log(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'LocalIsinProvider');
  }
}
