import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../isin_resolver.dart';
import '../cnmv_local_fund_provider.dart';
import 'isin_source_provider.dart';

class CnmvFiProvider implements IsinSourceProvider {
  final CnmvLocalFundProvider _cnmvLocalFundProvider;

  CnmvFiProvider({CnmvLocalFundProvider? cnmvLocalFundProvider})
    : _cnmvLocalFundProvider = cnmvLocalFundProvider ?? CnmvLocalFundProvider();

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    final result = await resolve(ticker: ticker, fundName: fundName);

    return result == null ? const [] : [result];
  }

  void _log(String event, {Object? error, StackTrace? stackTrace}) {
    if (!kDebugMode) return;

    developer.log(
      jsonEncode({
        'event': event,
        if (error != null) 'error': error.toString(),
      }),
      name: 'CnmvFiProvider',
      error: error,
      stackTrace: stackTrace,
    );
  }

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    _log('resolve_start');

    try {
      final cnmvFiResult = await _cnmvLocalFundProvider.resolve(
        fundName: fundName,
      );

      if (cnmvFiResult != null) {
        _log('resolve_success');

        return IsinResult(
          isin: cnmvFiResult.isin,
          source: 'CNMV/FI local',
          officialName: cnmvFiResult.fundName,
          cnmvRegistration: cnmvFiResult.registrationNumber,
        );
      }

      return null;
    } catch (e, stackTrace) {
      _log('local_exception', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
