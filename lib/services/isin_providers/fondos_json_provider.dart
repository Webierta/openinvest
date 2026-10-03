import 'dart:convert';

import 'package:flutter/services.dart';

import '../isin_resolver.dart';
import '../../utils/fund_name_matcher.dart';
import '../../utils/isin_validator.dart';
import 'isin_source_provider.dart';

class FondosJsonProvider implements IsinSourceProvider {
  static const String _assetPath = 'assets/files/fondos.json';
  static const String _source = 'fondos.json';

  Future<Map<String, List<_FundRecord>>>? _indexFuture;

  FondosJsonProvider();

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

  Future<Map<String, List<_FundRecord>>> _loadIndex() {
    return _indexFuture ??= _buildIndex();
  }

  Future<Map<String, List<_FundRecord>>> _buildIndex() async {
    final jsonString = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(jsonString);

    if (decoded is! List<dynamic>) {
      throw const FormatException('fondos.json must contain a JSON array');
    }

    final index = <String, List<_FundRecord>>{};

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException(
          'Each fondos.json record must be a JSON object',
        );
      }

      final name = item['name'];
      final isin = item['isin'];

      if (name is! String || isin is! String) {
        throw const FormatException(
          'Each fondos.json record must contain string name and isin',
        );
      }

      final normalizedName = FundNameMatcher.normalizeName(name);
      final normalizedIsin = isin.trim().toUpperCase();

      if (normalizedName.isEmpty) {
        continue;
      }

      if (!IsinValidator.isValid(normalizedIsin)) {
        continue;
      }

      final records = index.putIfAbsent(normalizedName, () => <_FundRecord>[]);

      if (records.any((record) => record.isin == normalizedIsin)) {
        continue;
      }

      records.add(_FundRecord(name: name, isin: normalizedIsin));
    }

    return index;
  }
}

class _FundRecord {
  final String name;
  final String isin;

  const _FundRecord({required this.name, required this.isin});
}
