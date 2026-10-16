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
  final dateOct3 = DateTime(2026, 10, 3);

  FundData makeFund({
    required double value,
    required DateTime date,
    required List<PricePoint> history,
    FundSource source = FundSource.cnmv,
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
      source: source,
      valuationSource: valuationSource,
    );
  }

  const match = FundSearchMatch(
    isin: 'IE00B4L5Y983',
    symbol: 'TEST',
    name: 'Nombre original del fondo',
    source: FundSource.cnmv,
  );

  test(
    'LF-38.1: QueFondos actualiza la valoración sin sustituir el origen CNMV',
    () async {
      final primary = makeFund(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            ScrapeResult(data: primary, source: FundSource.cnmv),
        queFondosFetcher: (_) async => const ScraperResult(
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
        ftFetcher: (_) async => null,
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.lastValue, 105.0);
      expect(result.data!.date, dateOct2);
      expect(result.data!.source, FundSource.cnmv);
      expect(result.data!.valuationSource, FundSource.queFondos);
      expect(result.data!.history.map((p) => p.price).toList(), [
        95.0,
        100.0,
        105.0,
      ]);
    },
  );

  test('LF-38.2: una actualización posterior de Yahoo vuelve a establecer la fuente de valoración', () async {
    var primary = makeFund(
      value: 100,
      date: dateOct1,
      history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
    );

    ScraperResult? queFondosResult = const ScraperResult(
      valorLiquidativo: '105,00',
      fecha: '02/10/2026',
      divisa: 'EUR',
    );

    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: primary, source: FundSource.cnmv),
      queFondosFetcher: (_) async => queFondosResult,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );

    // Primera actualización: QueFondos aporta una valoración más reciente.
    final first = await provider.fetchFundMatch(match);

    expect(first.data, isNotNull);
    expect(first.data!.lastValue, 105.0);
    expect(first.data!.source, FundSource.cnmv);
    expect(first.data!.valuationSource, FundSource.queFondos);

    // Simulamos que la siguiente consulta principal ya trae una valoración
    // posterior de Yahoo, conservando el historial anterior.
    primary = makeFund(
      value: 110,
      date: dateOct3,
      history: [...first.data!.history, PricePoint(dateOct3, 110)],
      source: first.data!.source!,
      valuationSource: FundSource.yahoo,
    );

    // QueFondos ya no tiene una valoración tan reciente.
    queFondosResult = const ScraperResult(
      valorLiquidativo: '103,00',
      fecha: '01/10/2026',
      divisa: 'EUR',
    );

    final second = await provider.fetchFundMatch(match);

    expect(second.error, isNull);
    expect(second.data, isNotNull);
    expect(second.data!.lastValue, 110.0);
    expect(second.data!.date, dateOct3);
    expect(second.data!.source, FundSource.cnmv);
    expect(second.data!.valuationSource, FundSource.yahoo);
    expect(second.data!.history.map((p) => p.price).toList(), [
      95.0,
      100.0,
      105.0,
      110.0,
    ]);
  });

  test(
    'LF-38.3: Financial Times más antiguo no revierte la valoración vigente',
    () async {
      final primary = makeFund(
        value: 110,
        date: dateOct3,
        history: [
          PricePoint(dateSep30, 95),
          PricePoint(dateOct1, 100),
          PricePoint(dateOct2, 105),
          PricePoint(dateOct3, 110),
        ],
        valuationSource: FundSource.yahoo,
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            ScrapeResult(data: primary, source: FundSource.cnmv),
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => const ScraperResult(
          valorLiquidativo: '106,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.lastValue, 110.0);
      expect(result.data!.date, dateOct3);
      expect(result.data!.source, FundSource.cnmv);
      expect(result.data!.valuationSource, FundSource.yahoo);
      expect(result.data!.history.map((p) => p.price).toList(), [
        95.0,
        100.0,
        105.0,
        110.0,
      ]);
    },
  );

  test(
    'LF-38.4: un fallback inválido conserva valoración, historial y fuentes',
    () async {
      final primary = makeFund(
        value: 105,
        date: dateOct2,
        history: [
          PricePoint(dateSep30, 95),
          PricePoint(dateOct1, 100),
          PricePoint(dateOct2, 105),
        ],
        valuationSource: FundSource.queFondos,
      );

      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            ScrapeResult(data: primary, source: FundSource.cnmv),
        queFondosFetcher: (_) async => const ScraperResult(
          valorLiquidativo: 'valor-no-valido',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftFetcher: (_) async => const ScraperResult(
          valorLiquidativo: 'tampoco-valido',
          fecha: '04/10/2026',
          divisa: 'EUR',
        ),
        ftByIsinFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.error, isNull);
      expect(result.data, isNotNull);
      expect(result.data!.lastValue, 105.0);
      expect(result.data!.date, dateOct2);
      expect(result.data!.source, FundSource.cnmv);
      expect(result.data!.valuationSource, FundSource.queFondos);
      expect(result.data!.history.map((p) => p.price).toList(), [
        95.0,
        100.0,
        105.0,
      ]);
    },
  );
}
