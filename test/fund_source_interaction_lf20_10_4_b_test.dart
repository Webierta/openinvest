import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-20.10.4.b - FundSearchMatch → FundProvider → '
      'IsinResolver → ScrapeResult.source', () {
    const expectedIsin = 'ES0123456789';

    FundData makeFund({
      String isin = 'INVALID',
      String symbol = 'TEST',
      String name = 'Test Fund',
    }) {
      return FundData(
        isin: isin,
        symbol: symbol,
        name: name,
        lastValue: 100.0,
        currency: 'EUR',
        date: DateTime(2026, 1, 1),
        history: const [],
      );
    }

    ScrapeResult scrapedResult({
      String isin = 'INVALID',
      String symbol = 'TEST',
      String name = 'Test Fund',
      FundSource source = FundSource.yahoo,
    }) {
      return ScrapeResult(
        data: makeFund(isin: isin, symbol: symbol, name: name),
        isResolved: true,
        source: source,
      );
    }

    IsinResolver fakeResolver({
      required String source,
      String isin = expectedIsin,
    }) {
      return IsinResolver(
        providers: [
          _FakeIsinProvider(
            result: IsinResult(isin: isin, source: source),
          ),
        ],
      );
    }

    Future<ScrapeResult> run({
      required FundSource originalSource,
      required String resolverSource,
      String resolverIsin = expectedIsin,
      String symbol = 'TEST',
      String name = 'Test Fund',
    }) async {
      final match = FundSearchMatch(
        isin: null,
        symbol: symbol,
        name: name,
        source: originalSource,
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            scrapedResult(symbol: symbol, name: name, source: originalSource),
        isinResolverFactory: () =>
            fakeResolver(source: resolverSource, isin: resolverIsin),
      );

      return provider.fetchFundMatch(match);
    }

    test('1. Yahoo → ECB/IFS → source ECB', () async {
      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'ECB/IFS',
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.source, FundSource.ecb);
    });

    test('2. Yahoo → fondos.json → source LOCAL', () async {
      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'fondos.json',
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.source, FundSource.local);
    });

    test('3. Yahoo → Morningstar → source MORNINGSTAR', () async {
      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'Morningstar',
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.source, FundSource.morningstar);
    });

    test('4. Yahoo → CNMV/FI → source CNMV', () async {
      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'CNMV/FI',
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.source, FundSource.cnmv);
    });

    test('5. Yahoo → Yahoo → source YAHOO', () async {
      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'Yahoo',
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.source, FundSource.yahoo);
    });

    test('6. Resolver null → conserva source original Yahoo', () async {
      final match = const FundSearchMatch(
        isin: null,
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.yahoo,
      );

      var resolverCalled = false;

      final provider = FundProvider(
        fundSearchFetcher: (_) async => scrapedResult(),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(
              onResolve: () {
                resolverCalled = true;
              },
            ),
          ],
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(resolverCalled, isTrue);
      expect(result.data, isNotNull);
      expect(result.data!.isin, 'INVALID');
      expect(result.source, FundSource.yahoo);
    });

    test('7. ISIN válido → no llama al resolver y conserva source', () async {
      var resolverCalled = false;

      final match = const FundSearchMatch(
        isin: 'ES0123456789',
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.yahoo,
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async => scrapedResult(isin: 'ES0123456789'),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(
              onResolve: () {
                resolverCalled = true;
              },
            ),
          ],
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(resolverCalled, isFalse);
      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.yahoo);
    });

    test('8. Resolución conserva symbol, name y datos del fondo', () async {
      const symbol = 'ABC.MC';
      const name = 'Fondo de Prueba';

      final result = await run(
        originalSource: FundSource.yahoo,
        resolverSource: 'ECB/IFS',
        symbol: symbol,
        name: name,
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, expectedIsin);
      expect(result.data!.symbol, symbol);
      expect(result.data!.name, name);
      expect(result.data!.lastValue, 100.0);
      expect(result.data!.currency, 'EUR');
      expect(result.data!.date, DateTime(2026, 1, 1));
      expect(result.data!.history, hasLength(1));
      expect(result.source, FundSource.ecb);
    });
  });
}

class _FakeIsinProvider implements IsinSourceProvider {
  final IsinResult? result;
  final void Function()? onResolve;

  _FakeIsinProvider({this.result, this.onResolve});

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    onResolve?.call();
    return result;
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    onResolve?.call();
    return result == null ? [] : [result!];
  }
}
