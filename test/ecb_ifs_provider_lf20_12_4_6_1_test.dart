import 'package:flutter_test/flutter_test.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.6.1 — FundProvider + ECB/IFS', () {
    test(
      'ES0160483014 se recupera mediante ECB/IFS cuando Yahoo no lo encuentra',
      () async {
        final provider = FundProvider(
          fundIsinFetcher: (_) async =>
              ScrapeResult(error: AppError.notFound('ISIN no encontrado.')),
        );

        final result = await provider.fetchFundOnly('ES0160483014');

        expect(result.error, isNull);
        expect(result.data, isNotNull);

        final fund = result.data!;

        expect(fund.isin, 'ES0160483014');
        expect(fund.name, 'MAPFRE PRIVATE EQUITY I FCR');
        expect(fund.symbol, isEmpty);
        expect(fund.lastValue, 0);
        expect(fund.history, isEmpty);

        expect(result.isResolved, isTrue);
        expect(result.source, FundSource.ecb);
      },
    );
  });
}
