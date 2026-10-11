import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    FundProvider.disposeHttpClient();
  });

  test('fetchFundOnly conserva ECB como source cuando Financial Times aporta la valoración', () async {
    const isin = 'ES0160483014';

    final provider = FundProvider(
      // Fuerza el fallback de identificación ECB/IFS.
      fundIsinFetcher: (_) async =>
          ScrapeResult(error: AppError.notFound('ISIN no encontrado.')),

      // Financial Times no proporciona una resolución directa por ISIN.
      ftByIsinFetcher: (_) async => null,

      // No se utiliza QueFondos en este escenario.
      queFondosFetcher: (_) async => null,

      // Financial Times aporta la valoración del fondo identificado por ECB.
      ftFetcher: (_) async => const ScraperResult(
        nombre: 'MAPFRE PRIVATE EQUITY I FCR',
        valorLiquidativo: '12.34',
        fecha: '06/10/2026',
        divisa: 'EUR',
      ),
    );

    final result = await provider.fetchFundOnly(isin);

    expect(result.error, isNull);
    expect(result.data, isNotNull);

    final fund = result.data!;

    expect(fund.isin, isin);
    expect(fund.name, 'MAPFRE PRIVATE EQUITY I FCR');
    expect(fund.lastValue, 12.34);
    expect(fund.date, DateTime(2026, 10, 6));

    // ECB identifica el fondo.
    expect(fund.source, FundSource.ecb);

    // Financial Times aporta la valoración.
    expect(fund.valuationSource, FundSource.financialTimes);

    // El resultado también debe conservar la procedencia ECB.
    expect(result.source, FundSource.ecb);
    expect(result.isResolved, isTrue);
  });
}
