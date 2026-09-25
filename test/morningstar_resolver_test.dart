import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  group('MorningstarLtForeignIsinProvider Tests', () {
    test('0P00000FB4 resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['Id'], '0P00000FB4');
        return http.Response("var HoldingIsin='FR0010135103';", 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'Y9U6.HM',
        fundName: 'Carmignac',
        yahooSymbol: '0P00000FB4.F',
        yahooName: 'Carmignac',
      );

      expect(isin, 'FR0010135103');
    });

    test('0P0000X83M resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['Id'], '0P0000X83M');
        return http.Response("var HoldingIsin='IE00B8K7V925';", 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
        yahooSymbol: '0P0000X83M',
        yahooName: 'Test Fund',
      );

      expect(isin, 'IE00B8K7V925');
    });

    test('0P00006DAB resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['Id'], '0P00006DAB');
        return http.Response("var HoldingIsin='LU0261948904';", 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Fidelity',
        yahooSymbol: '0P00006DAB',
        yahooName: 'Fidelity',
      );

      expect(isin, 'LU0261948904');
    });

    test('HTML sin HoldingIsin devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response("<html><body>Sin datos relevantes</body></html>", 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test',
        yahooSymbol: '0P00000FB4',
        yahooName: 'Test',
      );

      expect(isin, isNull);
    });

    test('HoldingIsin inválido devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response("var HoldingIsin='FR0010135100';", 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test',
        yahooSymbol: '0P00000FB4',
        yahooName: 'Test',
      );

      expect(isin, isNull);
    });

    test('HTTP 404 devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test',
        yahooSymbol: '0P00000FB4',
        yahooName: 'Test',
      );

      expect(isin, isNull);
    });

    test('HTTP 500 devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);
      final isin = await provider.resolve(
        ticker: 'TEST',
        fundName: 'Test',
        yahooSymbol: '0P00000FB4',
        yahooName: 'Test',
      );

      expect(isin, isNull);
    });
  });
}
