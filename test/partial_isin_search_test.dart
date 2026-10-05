import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Búsqueda por ISIN parcial', () {
    test('encuentra el fondo en el catálogo local', () {
      final matches = FundScraper.searchCatalogMatches({
        'mapfre private equity i fcr': 'ES0160483014',
      }, 'ES016048301');

      expect(matches, hasLength(1));
      expect(matches.single.isin, 'ES0160483014');
    });

    test('encuentra el fondo en el índice ECB/IFS', () async {
      final provider = EcbIfsProvider();

      final matches = await provider.searchByNameOrIsin('ES016048301');

      expect(
        matches,
        contains(
          isA<IsinResult>()
              .having((result) => result.isin, 'ISIN', 'ES0160483014')
              .having(
                (result) => result.officialName,
                'nombre oficial',
                'MAPFRE PRIVATE EQUITY I FCR',
              ),
        ),
      );
    });
  });
}
