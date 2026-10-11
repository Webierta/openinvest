import 'package:flutter_test/flutter_test.dart';

//import 'package:investing/models/fund_data.dart';
//import 'package:investing/services/fund_scraper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /* test('getFundBySearchMatch conserva la fuente de identidad '
      'y distingue la fuente de valoración', () async {
    final match = FundSearchMatch(
      isin: 'ES0000000010',
      symbol: 'TEST.MC',
      name: 'Fondo de prueba',
      source: FundSource.local,
    );

    final result = await FundScraper.getFundBySearchMatch(match);

    expect(result.data, isNotNull);
    expect(result.data!.source, FundSource.local);
    expect(result.data!.valuationSource, FundSource.yahoo); 
  }); */
}
