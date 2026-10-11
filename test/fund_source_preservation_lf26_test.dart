import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/fund_scraper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'getFundBySearchMatch conserva ECB como source del fondo seleccionado',
    () async {
      const match = FundSearchMatch(
        isin: 'ES0160483014',
        symbol: '',
        name: 'MAPFRE PRIVATE EQUITY I FCR',
        source: FundSource.ecb,
      );

      final result = await FundScraper.getFundBySearchMatch(match);

      expect(result.error, isNull);
      expect(result.data, isNotNull);

      final fund = result.data!;

      expect(fund.isin, 'ES0160483014');
      expect(fund.name, 'MAPFRE PRIVATE EQUITY I FCR');
      expect(fund.lastValue, 0.0);

      // La identificación procede de ECB.
      expect(fund.source, FundSource.ecb);

      // No se ha obtenido ninguna valoración de mercado.
      expect(fund.valuationSource, isNull);

      // El resultado debe conservar también esa procedencia.
      expect(result.source, FundSource.ecb);
      expect(result.isResolved, isTrue);
    },
  );
}
