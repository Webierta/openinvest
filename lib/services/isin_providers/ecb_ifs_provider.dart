import 'dart:convert';

import 'package:flutter/services.dart';

import '../isin_resolver.dart';
import '../../utils/fund_name_matcher.dart';
import '../../utils/isin_validator.dart';
import 'isin_source_provider.dart';

class EcbIfsProvider implements IsinSourceProvider {
  static const String _assetPath = 'assets/files/ECB_IFS_2024.json';
  static const String _source = 'ECB/IFS';

  Future<Map<String, List<_EcbRecord>>>? _indexFuture;

  EcbIfsProvider();

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final results = await resolveAll(ticker: ticker, fundName: fundName);

    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    final index = await _loadIndex();

    final normalizedName = FundNameMatcher.normalizeName(fundName);
    final records = index[normalizedName];

    if (records == null || records.isEmpty) {
      return const [];
    }

    return <IsinResult>[
      for (final record in records)
        IsinResult(
          isin: record.isin,
          source: _source,
          officialName: record.name,
        ),
    ];
  }

  Future<Map<String, List<_EcbRecord>>> _loadIndex() {
    return _indexFuture ??= _buildIndex();
  }

  Future<Map<String, List<_EcbRecord>>> _buildIndex() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(jsonString);

    if (decoded is! List<dynamic>) {
      throw const FormatException(
        'ECB_IFS_2024.json must contain a JSON array',
      );
    }

    final index = <String, List<_EcbRecord>>{};

    for (final item in decoded) {
      /* if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Each ECB IFS record must be a JSON object',
        );
      }

      final name = item['Name'];
      final isin = item['ISIN'];

      if (name is! String || isin is! String) {
        throw const FormatException(
          'Each ECB IFS record must contain string Name and ISIN',
        );
      } */

      if (item is! Map<String, dynamic>) {
        continue;
      }

      final name = item['Name'];
      final isin = item['ISIN'];

      if (name is! String || isin is! String) {
        continue;
      }

      final normalizedName = FundNameMatcher.normalizeName(name);
      final normalizedIsin = isin.trim().toUpperCase();

      if (normalizedName.isEmpty) {
        continue;
      }

      if (normalizedIsin == 'NO ENCONTRADO') {
        continue;
      }

      if (!IsinValidator.isValid(normalizedIsin)) {
        continue;
      }

      final records = index.putIfAbsent(normalizedName, () => <_EcbRecord>[]);

      if (records.any((record) => record.isin == normalizedIsin)) {
        continue;
      }

      records.add(_EcbRecord(name: name, isin: normalizedIsin));
    }

    return index;
  }
}

class _EcbRecord {
  final String name;
  final String isin;

  const _EcbRecord({required this.name, required this.isin});
}
