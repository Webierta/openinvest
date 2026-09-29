import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'yahoo_resolver/yahoo_identity.dart';
import 'yahoo_resolver/yahoo_merge.dart';
import 'yahoo_resolver/yahoo_ranking.dart';
import 'yahoo_resolver/yahoo_search.dart';
import 'yahoo_resolver/yahoo_selection.dart';

import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  runYahooMergeTests();
  runYahooIdentityTests();
  runYahooSelectionTests();
  runYahooRankingTests();
  runYahooSearchTests();

  group('Yahoo Resolver Tests', () {
    test('ISIN directo desde Yahoo', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "CANC.PA", "longname": "Carmignac Court Terme", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}]}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(
        ticker: 'CANC.PA',
        fundName: 'Carmignac Court Terme',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('ticker inexistente devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(
        ticker: 'FAKE.SYMBOL',
        fundName: 'Nonexistent Fund',
      );

      expect(result, isNull);
    });

    test('sin ISIN ni proveedor foreign devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "TEST.PA", "longname": "Test Fund", "quoteType": "MUTUALFUND"}]}',
          200,
        );
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [],
      );
      final result = await resolver.resolve(
        ticker: 'TEST.PA',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'múltiples candidatos y preferencia MUTUALFUND vs ETF y ticker exacto',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('''
          {
            "quotes": [
              {"symbol": "MYFUND.PA", "longname": "My Fund ETF", "quoteType": "ETF"},
              {"symbol": "MYFUND.PA", "longname": "My Fund", "quoteType": "MUTUALFUND", "isin": "FR0010135103"},
              {"symbol": "OTHER.PA", "longname": "Other Fund", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}
            ]
          }
          ''', 200);
        });

        final resolver = IsinResolver(client: mockClient);
        final result = await resolver.resolve(
          ticker: 'MYFUND.PA',
          fundName: 'My Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0010135103');
      },
    );

    /* test(
      'F3 - el ISIN aportado por cualquiera de las consultas se conserva',
      () async {
        final client = FakeYahooClient({
          'XYZ.PA': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
            ),
          ],
        });

        final provider = provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expectIsin(result, 'FR0000000010', 'F3');

        debugPrint('[F3] ISIN de una de las consultas conservado -> OK');
      },
    ); */

    /* test(
      'F4 - ISIN diferentes para el mismo mergeKey generan conflicto',
      () async {
        final client = FakeYahooClient({
          'XYZ.PA': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'FR0000000010',
            ),
          ],
          'Alpha Growth Fund': [
            const Quote(
              symbol: 'XYZ.PA',
              longname: 'Alpha Growth Fund',
              quoteType: 'MUTUALFUND',
              isin: 'LU0000000020',
            ),
          ],
        });

        final provider = provider(client: client);

        final result = await provider.resolve(
          ticker: 'XYZ.PA',
          fundName: 'Alpha Growth Fund',
        );

        expect(result, isNull);

        debugPrint('[F4] conflicto de ISIN conservador -> OK');
      },
    ); */
  });
}
