// =============================================================================
// IsinResolver
// =============================================================================
//
// Motor de resolución de ISIN para OpenInvest (Orquestador).
//
// =============================================================================

//import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/foreign_isin_provider.dart';
import '../utils/http_config.dart';
import '../utils/isin_validator.dart';
//import 'local_isin_provider.dart';
import 'cnmv_local_fund_provider.dart';
import 'isin_providers/isin_source_provider.dart';
import 'isin_providers/input_isin_provider.dart';
import 'isin_providers/cnmv_sil_provider.dart';
import 'isin_providers/cnmv_fi_provider.dart';
import 'isin_providers/yahoo_provider.dart';

class IsinResult {
  final String isin;
  final String source;
  final String? officialName;
  final int? cnmvRegistration;
  final String? cnmvNif;

  const IsinResult({
    required this.isin,
    required this.source,
    this.officialName,
    this.cnmvRegistration,
    this.cnmvNif,
  });

  @override
  String toString() =>
      'IsinResult('
      'isin: $isin, source: $source, officialName: $officialName, '
      'cnmvRegistration: $cnmvRegistration, cnmvNif: $cnmvNif)';
}

/// Proveedor extranjero basado en la ficha clásica de Morningstar.
class MorningstarLtForeignIsinProvider implements ForeignIsinProvider {
  final http.Client client;

  static const String _snapshotBaseUrl =
      'https://lt.morningstar.com/2nhcdckzon/snapshot/snapshot.aspx';

  MorningstarLtForeignIsinProvider({http.Client? client})
    : client = client ?? http.Client();

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    final morningstarId = _extractMorningstarId(yahooSymbol);

    if (morningstarId == null) {
      _log(
        '  Morningstar LT: Yahoo no contiene un ID Morningstar '
        '($yahooSymbol).',
      );
      return null;
    }

    _log('  Morningstar LT ID: $morningstarId');

    final uri = Uri.parse(_snapshotBaseUrl).replace(
      queryParameters: <String, String>{
        'Id': morningstarId,
        'LanguageId': 'es-ES',
      },
    );

    try {
      final response = await client
          .get(
            uri,
            headers: const <String, String>{
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'es-ES,es;q=0.9,en;q=0.8',
              'User-Agent':
                  'Mozilla/5.0 (X11; Linux x86_64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/140.0.0.0 Safari/537.36',
            },
          )
          .timeout(HttpConfig.timeout);

      _log('  Morningstar LT GET: HTTP ${response.statusCode}');

      if (response.statusCode != 200) return null;

      final isin = _extractHoldingIsin(response.body);
      if (isin == null) {
        _log(
          '  Morningstar LT: la ficha $morningstarId no contiene '
          'un HoldingIsin válido.',
        );
        return null;
      }

      _log('  Morningstar LT ISIN: $isin');
      return isin;
    } catch (e) {
      _log('  Morningstar LT error: $e');
      return null;
    }
  }

  String? _extractMorningstarId(String value) {
    final match = RegExp(
      r'^(0P[0-9A-Z]+)(?:\.[A-Z]+)?$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    return match?.group(1)?.toUpperCase();
  }

  String? _extractHoldingIsin(String html) {
    final patterns = <RegExp>[
      RegExp(
        r"""HoldingIsin\s*=\s*['"]([A-Z]{2}[A-Z0-9]{9}\d)['"]""",
        caseSensitive: false,
      ),
      RegExp(
        r"""HoldingIsin\s*:\s*['"]([A-Z]{2}[A-Z0-9]{9}\d)['"]""",
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) continue;

      final isin = match.group(1)!.toUpperCase();
      if (IsinValidator.isValid(isin)) return isin;
    }

    return null;
  }
}

class MorningstarForeignIsinProvider extends MorningstarLtForeignIsinProvider {
  MorningstarForeignIsinProvider({super.client});
}

class IsinResolver {
  final http.Client _client;
  final List<IsinSourceProvider> _providers;

  IsinResolver({
    http.Client? client,
    List<ForeignIsinProvider>? foreignIsinProviders,
    CnmvLocalFundProvider? cnmvLocalFundProvider,
    List<IsinSourceProvider>? providers,
  }) : _client = client ?? http.Client(),
       _providers = providers ?? [
         InputIsinProvider(extractEmbeddedIsin: _extractEmbeddedIsin),
         CnmvSilProvider(client: client ?? http.Client()),
         CnmvFiProvider(cnmvLocalFundProvider: cnmvLocalFundProvider),
         YahooProvider(
           client: client ?? http.Client(),
           foreignIsinProviders: foreignIsinProviders,
         ),
       ];

  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    final normalizedTicker = ticker.trim().toUpperCase();

    _log('');
    _log('------------------------------------------------------------');
    _log('IsinResolver');
    _log('Ticker: $normalizedTicker');
    _log('Nombre: $fundName');
    _log('------------------------------------------------------------');

    for (final provider in _providers) {
      final result = await provider.resolve(
        ticker: normalizedTicker,
        fundName: fundName,
      );
      if (result != null) return result;
    }

    return null;
  }

  static String? _extractEmbeddedIsin(String value) {
    final upper = value.toUpperCase();
    final regex = RegExp(r'[A-Z]{2}[A-Z0-9]{9}[0-9]');

    for (final match in regex.allMatches(upper)) {
      final candidate = match.group(0);

      if (candidate != null && IsinValidator.isValid(candidate)) {
        return candidate;
      }
    }

    return null;
  }

  void dispose() => _client.close();
}

void _log(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'IsinResolver');
  }
}
