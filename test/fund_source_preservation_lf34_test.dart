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
      name: 'Test Fund',
      lastValue: 100,
      currency: 'EUR',
      date: dateOct1,
      history: [PricePoint(dateSep30, 95), PricePoint(dateOct1, 100)],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
    );
  }

  Future<FundData> fetchFund({
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

    expect(result.data, isNotNull);
    expect(result.error, isNull);

    return result.data!;
  }

  void expectLatestHistoryPoint(FundData fund) {
    expect(fund.history, isNotEmpty);

    final latestPoint = fund.history.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );

    expect(
      latestPoint.date,
      fund.date,
      reason:
          'La fecha del último punto debe coincidir con la fecha del fondo.',
    );
    expect(
      latestPoint.price,
      fund.lastValue,
      reason: 'El precio del último punto debe coincidir con lastValue.',
    );
  }

  test(
    'LF-34.1: QueFondos mantiene coherentes el valor, la fecha y el historial',
    () async {
      final fund = await fetchFund(
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '105,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );

      expect(fund.lastValue, 105.0);
      expect(fund.date, dateOct2);
      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.queFondos);

      expectLatestHistoryPoint(fund);
    },
  );

  test(
    'LF-34.2: una valoración anterior no altera los datos principales',
    () async {
      final fund = await fetchFund(
        queFondosResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '90,00',
          fecha: '30/09/2026',
          divisa: 'EUR',
        ),
        ftResult: null,
      );

      expect(fund.lastValue, 100.0);
      expect(fund.date, dateOct1);
      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.yahoo);

      expect(fund.history.map((point) => point.date).toList(), [
        dateSep30,
        dateOct1,
      ]);
      expect(fund.history.map((point) => point.price).toList(), [95.0, 100.0]);

      expectLatestHistoryPoint(fund);
    },
  );

  test(
    'LF-34.3: Financial Times mantiene coherentes el valor y el historial',
    () async {
      final fund = await fetchFund(
        queFondosResult: null,
        ftResult: const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '106,00',
          fecha: '02/10/2026',
          divisa: 'EUR',
        ),
      );

      expect(fund.lastValue, 106.0);
      expect(fund.date, dateOct2);
      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.financialTimes);

      expectLatestHistoryPoint(fund);
    },
  );
}
