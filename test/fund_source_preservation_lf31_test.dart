import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FundProvider.disposeHttpClient();
  });

  final primaryDate = DateTime(2026, 10, 1);
  final fallbackDate = DateTime(2026, 10, 2);

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

  Future<void> verifyFallback({
    required FundSource expectedValuationSource,
    required ScraperResult? queFondosResult,
    required ScraperResult? ftResult,
  }) async {
    final primaryFund = createPrimaryFund();

    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: primaryFund, source: FundSource.cnmv),
      queFondosFetcher: (_) async => queFondosResult,
      ftFetcher: (_) async => ftResult,
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

    // El fondo sigue teniendo su procedencia original.
    expect(fund.source, FundSource.cnmv);

    // La valoración refleja el scraper que aportó el dato elegido.
    expect(fund.valuationSource, expectedValuationSource);

    // El fallback más reciente debe ser el seleccionado.
    expect(fund.lastValue, 105.0);
    expect(fund.date, fallbackDate);

    // El origen del resultado no debe sustituir la procedencia del fondo.
    expect(result.source, FundSource.cnmv);
  }

  test(
    'fetchFundMatch conserva source al seleccionar valoración de QueFondos',
    () async {
      await verifyFallback(
        expectedValuationSource: FundSource.queFondos,
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );
    },
  );

  test('fetchFundMatch conserva source al seleccionar valoración de Financial Times', () async {
    await verifyFallback(
      expectedValuationSource: FundSource.financialTimes,
      queFondosResult: null,
      ftResult: const ScraperResult(
        nombre: 'Test Fund',
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );
  });
}
