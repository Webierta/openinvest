import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FundProvider.disposeHttpClient();
  });

  final primaryDate = DateTime(2026, 10, 2);

  FundData createPrimaryFund() {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 100,
      currency: 'EUR',
      date: primaryDate,
      history: [PricePoint(primaryDate, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<void> verifyPrimaryPreserved({
    required ScraperResult? queFondosResult,
    required ScraperResult? ftResult,
    required bool expectFtCalled,
  }) async {
    final primaryFund = createPrimaryFund();
    var ftCalled = false;

    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: primaryFund, source: FundSource.cnmv),
      queFondosFetcher: (_) async => queFondosResult,
      ftFetcher: (_) async {
        ftCalled = true;
        return ftResult;
      },
      ftByIsinFetcher: (_) async => null,
    );

    final result = await provider.fetchFundMatch(
      const FundSearchMatch(
        isin: 'IE00B4L5Y983',
        symbol: 'TEST',
        name: 'Test Fund',
        source: FundSource.cnmv,
      ),
    );

    expect(result.error, isNull);
    expect(result.data, isNotNull);

    final fund = result.data!;

    // Debe conservarse la valoración principal.
    expect(fund.isin, 'IE00B4L5Y983');
    expect(fund.lastValue, 100.0);
    expect(fund.date, primaryDate);

    // Deben conservarse ambas fuentes originales.
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);
    expect(result.source, FundSource.cnmv);

    // Verifica que se haya intentado FT cuando corresponde.
    expect(ftCalled, expectFtCalled);
  }

  test(
    'LF-32.1: una valoración anterior de QueFondos no sustituye la principal',
    () async {
      await verifyPrimaryPreserved(
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '90,00',
          fecha: '01/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
        expectFtCalled: false,
      );
    },
  );

  test(
    'LF-32.2: datos inválidos en ambos fallbacks no sustituyen la principal',
    () async {
      await verifyPrimaryPreserved(
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: 'valor-invalido',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: 'tambien-invalido',
          fecha: '04/10/2026',
          divisa: 'EUR',
        ),
        expectFtCalled: true,
      );
    },
  );

  test(
    'LF-32.3: sin datos de los fallbacks se conserva la valoración principal',
    () async {
      await verifyPrimaryPreserved(
        queFondosResult: null,
        ftResult: null,
        expectFtCalled: true,
      );
    },
  );
}
