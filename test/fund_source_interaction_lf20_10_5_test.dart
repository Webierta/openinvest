import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  tearDown(() async {
    FundProvider.disposeHttpClient();
  });
  group('LF-20.10.5 - interacción con ScrapeResult/error', () {
    const match = FundSearchMatch(
      isin: null,
      symbol: 'TEST',
      name: 'Test Fund',
      source: FundSource.yahoo,
    );

    test(
      '1. data == null + error → devuelve el error sin resolver ISIN',
      () async {
        var resolverCalled = false;
        final error = AppError.notFound('Fondo no encontrado.');

        final provider = FundProvider(
          fundSearchFetcher: (_) async => ScrapeResult(error: error),
          isinResolverFactory: () => IsinResolver(
            providers: [
              _FakeIsinProvider(onResolve: () => resolverCalled = true),
            ],
          ),
        );

        final result = await provider.fetchFundMatch(match);

        expect(result.data, isNull);
        expect(result.error, same(error));
        expect(result.errorMessage, 'Fondo no encontrado.');
        expect(resolverCalled, isFalse);
        expect(provider.lastError, same(error));
      },
    );

    test('2. data == null + error → conserva exactamente AppError', () async {
      final error = AppError.remote('Servicio de cotizaciones no disponible.');

      final provider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          error: error,
          isResolved: false,
          source: FundSource.yahoo,
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.error, same(error));
      expect(result.error!.type, AppErrorType.remote);
      expect(result.error!.message, 'Servicio de cotizaciones no disponible.');
      expect(result.isResolved, isFalse);
      expect(result.source, FundSource.yahoo);
      expect(provider.lastError, same(error));
    });

    test('3. data == null sin error → no intenta resolver', () async {
      var resolverCalled = false;

      final provider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          data: null,
          error: null,
          isResolved: false,
          source: FundSource.yahoo,
        ),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(onResolve: () => resolverCalled = true),
          ],
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.data, isNull);
      expect(result.error, isNull);
      expect(result.source, FundSource.yahoo);
      expect(result.isResolved, isFalse);
      expect(resolverCalled, isFalse);
      expect(provider.lastError, isNull);
    });

    test(
      '4. data válida + ISIN inválido → el resolver puede completar el ISIN',
      () async {
        const resolvedIsin = 'ES0123456789';

        final provider = FundProvider(
          fundSearchFetcher: (_) async => ScrapeResult(
            data: _makeFund(isin: 'INVALID'),
            isResolved: false,
            source: FundSource.yahoo,
          ),
          isinResolverFactory: () => IsinResolver(
            providers: [
              _FakeIsinProvider(
                result: const IsinResult(isin: resolvedIsin, source: 'ECB/IFS'),
              ),
            ],
          ),
        );

        final result = await provider.fetchFundMatch(match);

        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!.isin, resolvedIsin);
        expect(result.isResolved, isTrue);
        expect(result.source, FundSource.ecb);
      },
    );

    test(
      '5. data válida + resolver null → conserva ScrapeResult original',
      () async {
        final fund = _makeFund(isin: 'INVALID');

        final provider = FundProvider(
          fundSearchFetcher: (_) async => ScrapeResult(
            data: fund,
            isResolved: true,
            source: FundSource.yahoo,
          ),
          isinResolverFactory: () =>
              IsinResolver(providers: [_FakeIsinProvider()]),
        );

        final result = await provider.fetchFundMatch(match);

        expect(result.error, isNull);
        expect(result.data, isNotNull);
        expect(result.data!.isin, 'INVALID');
        expect(result.data!.symbol, fund.symbol);
        expect(result.data!.name, fund.name);
        expect(result.isResolved, isTrue);
        expect(result.source, FundSource.yahoo);
      },
    );

    test('6. error del scraper → lastError queda sincronizado', () async {
      final error = AppError.data(
        'La respuesta de cotizaciones no tiene un formato válido.',
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            ScrapeResult(error: error, source: FundSource.yahoo),
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.data, isNull);
      expect(result.error, same(error));
      expect(provider.lastError, same(error));
      expect(provider.error, error.message);
      expect(provider.info, isNull);
    });
  });
}

FundData _makeFund({required String isin}) {
  return FundData(
    isin: isin,
    symbol: 'TEST',
    name: 'Test Fund',
    lastValue: 100.0,
    currency: 'EUR',
    date: DateTime(2026, 1, 1),
    history: [PricePoint(DateTime(2026, 1, 1), 100.0)],
  );
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
