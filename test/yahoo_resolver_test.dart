import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Yahoo Resolver Tests', () {
    test('ISIN directo desde Yahoo', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "CANC.PA", "longname": "Carmignac Court Terme", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}]}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'CANC.PA', fundName: 'Carmignac Court Terme');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('ticker inexistente devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{"quotes": []}', 200);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'FAKE.SYMBOL', fundName: 'Nonexistent Fund');

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
      final result = await resolver.resolve(ticker: 'TEST.PA', fundName: 'Test Fund');

      expect(result, isNull);
    });

    test('múltiples candidatos y preferencia MUTUALFUND vs ETF y ticker exacto', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '''
          {
            "quotes": [
              {"symbol": "MYFUND.PA", "longname": "My Fund ETF", "quoteType": "ETF"},
              {"symbol": "MYFUND.PA", "longname": "My Fund", "quoteType": "MUTUALFUND", "isin": "FR0010135103"},
              {"symbol": "OTHER.PA", "longname": "Other Fund", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}
            ]
          }
          ''',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'MYFUND.PA', fundName: 'My Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
    });
  });
}
