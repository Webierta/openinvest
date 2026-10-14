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

  FundData createPrimaryFund({List<PricePoint>? history}) {
    return FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 100,
      currency: 'EUR',
      date: dateOct1,
      history:
          history ?? [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<FundData> fetchWithQueFondos({
    required FundData primaryFund,
    required String value,
    required String date,
  }) async {
    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(data: primaryFund, source: FundSource.cnmv),
      queFondosFetcher: (_) async => ScraperResult(
        nombre: 'Test Fund',
        valorLiquidativo: value,
        fecha: date,
        divisa: 'EUR',
      ),
      ftFetcher: (_) async => null,
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
    expect(result.data!.valuationSource, FundSource.queFondos);

    return result.data!;
  }

  test(
    'LF-33.1: la valoración aceptada de QueFondos se incorpora al historial',
    () async {
      final fund = await fetchWithQueFondos(
        primaryFund: createPrimaryFund(),
        value: '105,00',
        date: '02/10/2026',
      );

      expect(fund.lastValue, 105.0);
      expect(fund.date, dateOct2);

      final fallbackPoints = fund.history
          .where((point) => point.date == dateOct2)
          .toList();

      expect(fallbackPoints, hasLength(1));
      expect(fallbackPoints.single.price, 105.0);
    },
  );

  test(
    'LF-33.2: se conservan los puntos anteriores y el historial queda ordenado',
    () async {
      final fund = await fetchWithQueFondos(
        primaryFund: createPrimaryFund(),
        value: '105,00',
        date: '02/10/2026',
      );

      expect(fund.history.map((point) => point.date).toList(), [
        dateSep30,
        dateOct1,
        dateOct2,
      ]);

      expect(fund.history.map((point) => point.price).toList(), [
        95.0,
        100.0,
        105.0,
      ]);

      for (var i = 1; i < fund.history.length; i++) {
        expect(
          fund.history[i].date.isAfter(fund.history[i - 1].date),
          isTrue,
          reason:
              'El historial debe estar estrictamente ordenado '
              'y no contener fechas repetidas.',
        );
      }
    },
  );

  test(
    'LF-33.3: se elimina la duplicidad de fechas en el historial combinado',
    () async {
      final fund = await fetchWithQueFondos(
        primaryFund: createPrimaryFund(
          history: [
            PricePoint(dateSep30, 94),
            PricePoint(dateSep30, 95),
            PricePoint(dateOct1, 100),
          ],
        ),
        value: '105,00',
        date: '02/10/2026',
      );

      final dates = fund.history.map((point) => point.date).toList();
      final uniqueDates = dates.toSet();

      expect(dates.length, uniqueDates.length);
      expect(dates, [dateSep30, dateOct1, dateOct2]);

      expect(
        fund.history.where((point) => point.date == dateOct2).single.price,
        105.0,
      );
    },
  );
}
