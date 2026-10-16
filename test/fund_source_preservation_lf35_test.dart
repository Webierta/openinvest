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

  final operation = FundOperation(
    id: 17,
    isin: 'IE00B4L5Y983',
    date: dateSep30,
    type: OperationType.buy,
    units: 10,
    price: 95,
    amount: 950,
  );

  final costPeriod = FundCostPeriod(
    uid: 'lf35-ter',
    concept: FundCostConcept.ter,
    ratePercent: 0.65,
    basis: FundCostRateBasis.annualBalance,
    treatment: FundCostTreatment.includedInNav,
    validFrom: DateTime(2026, 1, 1),
    description: 'TER anual',
  );

  final costCharge = FundCostCharge(
    uid: 'lf35-charge',
    concept: FundCostConcept.custody,
    date: dateSep30,
    amount: 2.50,
    description: 'Comisión de custodia',
  );

  FundData createPrimaryFund() {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Nombre original del fondo',
      lastValue: 100,
      currency: 'EUR',
      date: dateOct1,
      history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      operations: [operation],
      alertMin: 80,
      alertMax: 120,
      ter: 0.65,
      performanceFee: 10,
      costPeriods: [costPeriod],
      costCharges: [costCharge],
      morningstarRating: 4,
      morningstarCheckedAt: checkedAt,
      morningstarLastAttemptAt: lastAttemptAt,
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<FundData> fetchWithFallback({
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
        name: 'Nombre original del fondo',
        source: FundSource.cnmv,
      ),
    );

    expect(result.error, isNull);
    expect(result.data, isNotNull);
    expect(result.data!.lastValue, 105.0);
    expect(result.data!.date, dateOct2);

    return result.data!;
  }

  test('LF-35.1: se preservan ISIN, símbolo, nombre y divisa', () async {
    final fund = await fetchWithFallback(
      queFondosResult: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
      ),
      ftResult: null,
    );

    expect(fund.isin, 'IE00B4L5Y983');
    expect(fund.symbol, 'TEST');
    expect(fund.name, 'Nombre original del fondo');
    expect(fund.currency, 'EUR');
  });

  test('LF-35.2: se preservan operaciones, alertas y costes', () async {
    final fund = await fetchWithFallback(
      queFondosResult: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
      ),
      ftResult: null,
    );

    expect(fund.operations, hasLength(1));
    expect(fund.operations.single.id, 17);
    expect(fund.operations.single.isin, 'IE00B4L5Y983');
    expect(fund.operations.single.units, 10.0);
    expect(fund.operations.single.amount, 950.0);

    expect(fund.alertMin, 80.0);
    expect(fund.alertMax, 120.0);

    expect(fund.ter, 0.65);
    expect(fund.performanceFee, 10.0);

    expect(fund.costPeriods, hasLength(1));
    expect(fund.costPeriods.single.uid, 'lf35-ter');
    expect(fund.costPeriods.single.ratePercent, 0.65);

    expect(fund.costCharges, hasLength(1));
    expect(fund.costCharges.single.uid, 'lf35-charge');
    expect(fund.costCharges.single.amount, 2.50);
  });

  test(
    'LF-35.3: se preservan rating y marcas temporales de Morningstar',
    () async {
      final fund = await fetchWithFallback(
        queFondosResult: const ScraperResult(
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
        ),
        ftResult: null,
      );

      expect(fund.morningstarRating, 4);
      expect(fund.morningstarCheckedAt, checkedAt);
      expect(fund.morningstarLastAttemptAt, lastAttemptAt);
    },
  );

  test(
    'LF-35.4: source permanece CNMV y valuationSource pasa a QueFondos',
    () async {
      final fund = await fetchWithFallback(
        queFondosResult: const ScraperResult(
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
        ),
        ftResult: null,
      );

      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.queFondos);
    },
  );

  test(
    'LF-35.5: Financial Times no sustituye la fuente original del fondo',
    () async {
      final fund = await fetchWithFallback(
        queFondosResult: null,
        ftResult: const ScraperResult(
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
        ),
      );

      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.financialTimes);
    },
  );
}
