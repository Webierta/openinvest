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
  final dateOct3 = DateTime(2026, 10, 3);
  final checkedAt = DateTime(2026, 10, 5, 12);
  final lastAttemptAt = DateTime(2026, 10, 6, 9);

  FundData makePrimary({
    required double value,
    required DateTime date,
    required List<PricePoint> history,
    FundSource valuationSource = FundSource.yahoo,
  }) {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Nombre original del fondo',
      lastValue: value,
      currency: 'EUR',
      date: date,
      history: history,
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
          uid: 'lf39-ter',
          concept: FundCostConcept.ter,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          description: 'TER anual',
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf39-charge',
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
      valuationSource: valuationSource,
    );
  }

  const match = FundSearchMatch(
    isin: 'IE00B4L5Y983',
    symbol: 'TEST',
    name: 'Nombre original del fondo',
    source: FundSource.cnmv,
  );

  void expectMetadata(FundData fund) {
    expect(fund.isin, 'IE00B4L5Y983');
    expect(fund.symbol, 'TEST');
    expect(fund.name, 'Nombre original del fondo');
    expect(fund.currency, 'EUR');

    expect(fund.operations, hasLength(1));
    expect(fund.operations.single.id, 17);
    expect(fund.operations.single.amount, 950.0);

    expect(fund.alertMin, 80.0);
    expect(fund.alertMax, 120.0);

    expect(fund.ter, 0.65);
    expect(fund.performanceFee, 10.0);

    expect(fund.costPeriods, hasLength(1));
    expect(fund.costPeriods.single.uid, 'lf39-ter');
    expect(fund.costPeriods.single.ratePercent, 0.65);

    expect(fund.costCharges, hasLength(1));
    expect(fund.costCharges.single.uid, 'lf39-charge');
    expect(fund.costCharges.single.amount, 2.50);

    expect(fund.morningstarRating, 4);
    expect(fund.morningstarCheckedAt, checkedAt);
    expect(fund.morningstarLastAttemptAt, lastAttemptAt);
  }

  Future<FundData> fetch({
    required FundData primary,
    required ScraperResult? queFondos,
    required ScraperResult? ft,
  }) async {
    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: primary, source: FundSource.cnmv),
      queFondosFetcher: (_) async => queFondos,
      ftFetcher: (_) async => ft,
      ftByIsinFetcher: (_) async => null,
    );

    final result = await provider.fetchFundMatch(match);

    expect(result.error, isNull);
    expect(result.data, isNotNull);
    return result.data!;
  }

  test('LF-39.1: una valoración aceptada de QueFondos conserva todos los metadatos', () async {
    final fund = await fetch(
      primary: makePrimary(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      ),
      queFondos: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
      ft: null,
    );

    expect(fund.lastValue, 105.0);
    expect(fund.date, dateOct2);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);
    expectMetadata(fund);
  });

  test(
    'LF-39.2: una valoración posterior de Yahoo conserva todos los metadatos',
    () async {
      final fund = await fetch(
        primary: makePrimary(
          value: 110,
          date: dateOct3,
          history: [
            PricePoint(dateSep30, 95),
            PricePoint(dateOct1, 100),
            PricePoint(dateOct2, 105),
            PricePoint(dateOct3, 110),
          ],
        ),
        queFondos: const ScraperResult(
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
        ft: null,
      );

      expect(fund.lastValue, 110.0);
      expect(fund.date, dateOct3);
      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.yahoo);
      expectMetadata(fund);
    },
  );

  test('LF-39.3: Financial Times antiguo no modifica metadatos ni valoración vigente', () async {
    final fund = await fetch(
      primary: makePrimary(
        value: 110,
        date: dateOct3,
        history: [
          PricePoint(dateSep30, 95),
          PricePoint(dateOct1, 100),
          PricePoint(dateOct2, 105),
          PricePoint(dateOct3, 110),
        ],
      ),
      queFondos: null,
      ft: const ScraperResult(
        valorLiquidativo: '106,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.lastValue, 110.0);
    expect(fund.date, dateOct3);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);
    expectMetadata(fund);
  });

  test('LF-39.4: los metadatos y fuentes se conservan cuando se rechazan ambos fallbacks', () async {
    final fund = await fetch(
      primary: makePrimary(
        value: 105,
        date: dateOct2,
        history: [
          PricePoint(dateSep30, 95),
          PricePoint(dateOct1, 100),
          PricePoint(dateOct2, 105),
        ],
        valuationSource: FundSource.queFondos,
      ),
      queFondos: const ScraperResult(
        valorLiquidativo: 'invalido',
        fecha: '03/10/2026',
        divisa: 'EUR',
      ),
      ft: const ScraperResult(
        valorLiquidativo: 'tampoco-valido',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.lastValue, 105.0);
    expect(fund.date, dateOct2);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);
    expectMetadata(fund);
  });
}
