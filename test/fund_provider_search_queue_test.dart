import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_search_mode.dart';
import 'package:investing/providers/fund_provider.dart';

void main() {
  const match = FundSearchMatch(
    isin: 'ES0123456789',
    symbol: 'TEST',
    name: 'Test Fund',
    source: FundSource.yahoo,
  );

  test(
    'serializes searches and only runs the latest pending request',
    () async {
      final firstSearch = Completer<List<FundSearchMatch>>();
      final executedQueries = <String>[];
      final provider = FundProvider(
        fundSearch: (query, {required mode}) {
          executedQueries.add(query);
          if (query == 'first') return firstSearch.future;
          return Future.value([match]);
        },
      );

      final firstResult = provider.searchFunds(
        'first',
        mode: FundSearchMode.name,
      );
      final supersededResult = provider.searchFunds(
        'second',
        mode: FundSearchMode.name,
      );
      final latestResult = provider.searchFunds(
        'ES016',
        mode: FundSearchMode.isin,
      );

      expect(provider.isBusy, isTrue);
      expect(await supersededResult, isEmpty);
      expect(executedQueries, ['first']);

      firstSearch.completeError(Exception('Obsolete search failed'));

      expect(await firstResult, isEmpty);
      expect(await latestResult, [match]);
      expect(executedQueries, ['first', 'ES016']);
      expect(provider.error, isNull);
      expect(provider.isBusy, isFalse);
    },
  );

  test(
    'rejects invalid ISIN queries before invoking the search function',
    () async {
      var searchFunctionCalls = 0;
      final provider = FundProvider(
        fundSearch: (query, {required mode}) {
          searchFunctionCalls++;
          return Future.value([match]);
        },
      );

      final results = await provider.searchFunds(
        'ESFOO',
        mode: FundSearchMode.isin,
      );

      expect(results, isEmpty);
      expect(searchFunctionCalls, 0);
    },
  );
}
