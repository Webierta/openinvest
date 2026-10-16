import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    FundProvider.disposeHttpClient();
  });

  final dateSep30 = DateTime(2026, 9, 30);
  final dateOct1 = DateTime(2026, 10, 1);
  final dateOct2 = DateTime(2026, 10, 2);
  final checkedAt = DateTime(2026, 10, 5, 12);
  final lastAttemptAt = DateTime(2026, 10, 6, 9);

  FundData createPrimaryFund() {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Nombre original del fondo',
      lastValue: 100,
      currency: 'EUR',
      date: dateOct2,
      history: [
        PricePoint(dateSep30, 95),
        PricePoint(dateOct1, 98),
        PricePoint(dateOct2, 100),
      ],
      operations: [
        FundOperation(
          id: 17,
          isin: 'IE00B4L5Y983',
          date: dateSep30,
          type: OperationType.buy,
          units: 10,
          price: 95,
          amount: 950,
        ),
      ],
      alertMin: 80,
      alertMax: 120,
      ter: 0.65,
      performanceFee: 10,
      costPeriods: [
        FundCostPeriod(
          uid: 'lf36-ter',
          concept: FundCostConcept.ter,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          description: 'TER anual',
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf36-charge',
          concept: FundCostConcept.custody,
          date: dateSep30,
          amount: 2.50,
          description: 'Comisión de custodia',
        ),
      ],
      morningstarRating: 4,
      morningstarCheckedAt: checkedAt,
      morningstarLastAttemptAt: lastAttemptAt,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<ScrapeResult> fetchWithFallbacks({
    required ScraperResult? queFondosResult,
    required ScraperResult? ftResult,
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
        name: 'Nombre original del fondo',
        source: FundSource.cnmv,
      ),
    );

    expect(result.error, isNull);
    expect(result.data, isNotNull);

    // Se comprueba en cada caso si el fallback de Financial Times
    // llegó a ejecutarse.
    expect(
      ftCalled,
      queFondosResult == null ||
          (queFondosResult.valorLiquidativo != null &&
              queFondosResult.valorLiquidativo!.contains('invalido')),
    );

    return result;
  }

  void expectPrimaryFundPreserved(FundData fund) {
    expect(fund.isin, 'IE00B4L5Y983');
    expect(fund.symbol, 'TEST');
    expect(fund.name, 'Nombre original del fondo');
    expect(fund.currency, 'EUR');

    expect(fund.lastValue, 100.0);
    expect(fund.date, dateOct2);

    expect(fund.history.map((point) => point.date).toList(), [
      dateSep30,
      dateOct1,
      dateOct2,
    ]);
    expect(fund.history.map((point) => point.price).toList(), [
      95.0,
      98.0,
      100.0,
    ]);

    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);
  }

  void expectMetadataPreserved(FundData fund) {
    expect(fund.operations, hasLength(1));
    expect(fund.operations.single.id, 17);
    expect(fund.operations.single.amount, 950.0);

    expect(fund.alertMin, 80.0);
    expect(fund.alertMax, 120.0);

    expect(fund.ter, 0.65);
    expect(fund.performanceFee, 10.0);

    expect(fund.costPeriods, hasLength(1));
    expect(fund.costPeriods.single.uid, 'lf36-ter');
    expect(fund.costPeriods.single.ratePercent, 0.65);

    expect(fund.costCharges, hasLength(1));
    expect(fund.costCharges.single.uid, 'lf36-charge');
    expect(fund.costCharges.single.amount, 2.50);

    expect(fund.morningstarRating, 4);
    expect(fund.morningstarCheckedAt, checkedAt);
    expect(fund.morningstarLastAttemptAt, lastAttemptAt);
  }

  test(
    'LF-36.1: una valoración antigua de QueFondos no altera el fondo principal',
    () async {
      final result = await fetchWithFallbacks(
        queFondosResult: const ScraperResult(
          nombre: 'Nombre alternativo',
          valorLiquidativo: '90,00',
          fecha: '01/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );

      expectPrimaryFundPreserved(result.data!);
    },
  );

  test('LF-36.2: datos inválidos de ambos fallbacks no sustituyen la valoración principal', () async {
    final result = await fetchWithFallbacks(
      queFondosResult: const ScraperResult(
        nombre: 'Nombre alternativo',
        valorLiquidativo: 'invalido',
        fecha: '03/10/2026',
        divisa: 'EUR',
      ),
      ftResult: const ScraperResult(
        nombre: 'Nombre alternativo',
        valorLiquidativo: 'tambien-invalido',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
    );

    expectPrimaryFundPreserved(result.data!);
  });

  test(
    'LF-36.3: sin valoraciones válidas se conservan todos los metadatos',
    () async {
      final result = await fetchWithFallbacks(
        queFondosResult: null,
        ftResult: null,
      );

      expectPrimaryFundPreserved(result.data!);
      expectMetadataPreserved(result.data!);
    },
  );

  test(
    'LF-36.4: al rechazar ambos fallbacks se mantienen las fuentes originales',
    () async {
      final result = await fetchWithFallbacks(
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: 'invalido',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: 'invalido',
          fecha: '04/10/2026',
          divisa: 'EUR',
        ),
      );

      expect(result.data!.source, FundSource.cnmv);
      expect(result.data!.valuationSource, FundSource.yahoo);
      expect(result.source, FundSource.cnmv);
    },
  );
}
