import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_search_mode.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/fund_scraper.dart';

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
        'latest',
        mode: FundSearchMode.isin,
      );

      expect(provider.isBusy, isTrue);
      expect(await supersededResult, isEmpty);
      expect(executedQueries, ['first']);

      firstSearch.completeError(Exception('Obsolete search failed'));

      expect(await firstResult, isEmpty);
      expect(await latestResult, [match]);
      expect(executedQueries, ['first', 'latest']);
      expect(provider.error, isNull);
      expect(provider.isBusy, isFalse);
    },
  );
}
