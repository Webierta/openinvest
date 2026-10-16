import 'package:flutter_test/flutter_test.dart';
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
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<FundData> fetchWithFallbacks({
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
    return result.data!;
  }

  void expectOriginalHistory(FundData fund) {
    expect(fund.history, hasLength(3));

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
  }

  void expectNoDuplicateDates(FundData fund) {
    final dates = fund.history.map((point) => point.date).toList();

    expect(dates.toSet(), hasLength(dates.length));
    expect(dates, [...dates]..sort((a, b) => a.compareTo(b)));
  }

  test(
    'LF-37.1: una valoración antigua de QueFondos no modifica el historial',
    () async {
      final fund = await fetchWithFallbacks(
        queFondosResult: const ScraperResult(
          nombre: 'Nombre alternativo',
          valorLiquidativo: '90,00',
          fecha: '01/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );

      expect(fund.lastValue, 100.0);
      expect(fund.date, dateOct2);
      expectOriginalHistory(fund);
    },
  );

  test(
    'LF-37.2: valoraciones inválidas no introducen puntos en el historial',
    () async {
      final fund = await fetchWithFallbacks(
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

      expectOriginalHistory(fund);
      expect(fund.history.any((p) => p.date == DateTime(2026, 10, 3)), isFalse);
      expect(fund.history.any((p) => p.date == DateTime(2026, 10, 4)), isFalse);
    },
  );

  test(
    'LF-37.3: el historial original permanece ordenado y sin fechas duplicadas',
    () async {
      final fund = await fetchWithFallbacks(
        queFondosResult: const ScraperResult(
          nombre: 'Nombre alternativo',
          valorLiquidativo: '90,00',
          fecha: '01/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );

      expectNoDuplicateDates(fund);
      expectOriginalHistory(fund);
    },
  );

  test(
    'LF-37.4: al rechazar ambos fallbacks se mantienen valoración e historial',
    () async {
      final fund = await fetchWithFallbacks(
        queFondosResult: const ScraperResult(
          nombre: 'Nombre alternativo',
          valorLiquidativo: 'invalido',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftResult: const ScraperResult(
          nombre: 'Nombre alternativo',
          valorLiquidativo: 'invalido',
          fecha: '04/10/2026',
          divisa: 'EUR',
        ),
      );

      expect(fund.lastValue, 100.0);
      expect(fund.date, dateOct2);
      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.yahoo);

      expectOriginalHistory(fund);
      expectNoDuplicateDates(fund);
    },
  );
}
