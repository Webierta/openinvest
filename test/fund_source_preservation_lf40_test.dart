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

  const match = FundSearchMatch(
    isin: 'IE00B4L5Y983',
    symbol: 'TEST',
    name: 'Fondo de prueba',
    source: FundSource.cnmv,
  );

  FundData primary({
    required double value,
    required DateTime date,
    required List<PricePoint> history,
    FundSource valuationSource = FundSource.yahoo,
  }) {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: value,
      currency: 'EUR',
      date: date,
      history: history,
      source: FundSource.cnmv,
      valuationSource: valuationSource,
    );
  }

  Future<FundData> fetch({
    required FundData initial,
    ScraperResult? queFondos,
    ScraperResult? ft,
  }) async {
    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: initial, source: FundSource.cnmv),
      queFondosFetcher: (_) async => queFondos,
      ftFetcher: (_) async => ft,
      ftByIsinFetcher: (_) async => null,
    );

    final result = await provider.fetchFundMatch(match);

    expect(result.error, isNull);
    expect(result.data, isNotNull);
    return result.data!;
  }

  void expectHistory(
    FundData fund,
    List<DateTime> expectedDates,
    List<double> expectedPrices,
  ) {
    expect(fund.history.map((point) => point.date).toList(), expectedDates);
    expect(fund.history.map((point) => point.price).toList(), expectedPrices);

    final dates = fund.history.map((point) => point.date).toList();

    expect(
      dates.toSet().length,
      dates.length,
      reason: 'El historial no debe contener fechas duplicadas',
    );

    for (var i = 1; i < dates.length; i++) {
      expect(
        dates[i].isAfter(dates[i - 1]),
        isTrue,
        reason: 'El historial debe estar ordenado cronológicamente',
      );
    }

    expect(fund.history.last.price, fund.lastValue);
    expect(fund.history.last.date, fund.date);
  }

  test('LF-40.1: QueFondos añade una valoración sin duplicar fechas ni desordenar el historial', () async {
    final fund = await fetch(
      initial: primary(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      ),
      queFondos: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.lastValue, 105.0);
    expect(fund.date, dateOct2);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.queFondos);

    expectHistory(fund, [dateSep30, dateOct1, dateOct2], [95, 100, 105]);
  });

  test('LF-40.2: una valoración nueva conserva todos los puntos históricos anteriores', () async {
    final fund = await fetch(
      initial: primary(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      ),
      queFondos: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(
      fund.history.map((point) => point.price).toList(),
      containsAll([95.0, 100.0]),
    );
    expectHistory(fund, [dateSep30, dateOct1, dateOct2], [95, 100, 105]);
  });

  test('LF-40.3: Financial Times añade una valoración posterior sin perder el historial', () async {
    final fund = await fetch(
      initial: primary(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      ),
      ft: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.lastValue, 105.0);
    expect(fund.date, dateOct2);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.financialTimes);

    expectHistory(fund, [dateSep30, dateOct1, dateOct2], [95, 100, 105]);
  });

  test('LF-40.4: los fallbacks antiguos o inválidos no hacen retroceder la valoración', () async {
    final fund = await fetch(
      initial: primary(
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
        valorLiquidativo: '103,00',
        fecha: '01/10/2026',
        divisa: 'EUR',
      ),
      ft: const ScraperResult(
        valorLiquidativo: 'invalido',
        fecha: '04/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.lastValue, 110.0);
    expect(fund.date, dateOct3);
    expect(fund.source, FundSource.cnmv);
    expect(fund.valuationSource, FundSource.yahoo);

    expectHistory(
      fund,
      [dateSep30, dateOct1, dateOct2, dateOct3],
      [95, 100, 105, 110],
    );
  });

  test('LF-40.5: una valoración aceptada mantiene coherencia entre valor, fecha e historial', () async {
    final fund = await fetch(
      initial: primary(
        value: 100,
        date: dateOct1,
        history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      ),
      queFondos: const ScraperResult(
        valorLiquidativo: '105,00',
        fecha: '02/10/2026',
        divisa: 'EUR',
      ),
    );

    expect(fund.history, isNotEmpty);
    expect(fund.history.last.price, fund.lastValue);
    expect(fund.history.last.date, fund.date);
    expect(fund.date, dateOct2);
    expect(fund.lastValue, 105.0);
  });
}
