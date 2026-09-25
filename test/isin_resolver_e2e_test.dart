//import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/cnmv_local_fund_provider.dart';
import 'package:investing/models/foreign_isin_provider.dart';

class _MockForeignProvider implements ForeignIsinProvider {
  final String? resolvedIsin;
  _MockForeignProvider(this.resolvedIsin);

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    return resolvedIsin;
  }
}

class _MockCnmvProvider extends CnmvLocalFundProvider {
  final CnmvFundResult? mockResult;
  _MockCnmvProvider(this.mockResult);

  @override
  Future<CnmvFundResult?> resolve({required String fundName}) async {
    return mockResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IsinResolver E2E Integration Tests', () {
    test('1. INPUT (ISIN embebido)', () async {
      final resolver = IsinResolver(client: MockClient((_) async => http.Response('', 404)));
      final result = await resolver.resolve(ticker: 'LU0297942194-USD.LU', fundName: 'Test');

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    test('2. CNMV (FI local)', () async {
      final mockCnmv = _MockCnmvProvider(
        const CnmvFundResult(
          registrationNumber: 123,
          fundName: 'TEST FUND FI',
          compartmentName: null,
          compartmentNumber: null,
          fundClass: CnmvFundClass(number: 0, name: 'BASE', isin: 'ES0138841038'),
          managerName: 'Test Gestora',
          depositaryName: 'Test Depositario',
        ),
      );

      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
      expect(result.source, 'CNMV/FI local');
    });

    test('3. SIL (Sociedad de Inversión Libre)', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          if (request.url.toString().contains('page=0')) {
            return http.Response('''
              <a href="sociedadiic.aspx?nif=A12345678">SIL FUND SICAV</a>
              SL-50
            ''', 200);
          } else {
            return http.Response('', 404);
          }
        } else if (request.url.toString().contains('sociedadiic')) {
          return http.Response('<html><body lang="es">ISIN: LU0261948904</body></html>', 200);
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL050.MC', fundName: 'SIL Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
      expect(result.source, 'CNMV/SIL');
    });

    test('4. LOCAL (Catálogo local / Foreign provider)', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('{"quotes": [{"symbol": "TEST", "longname": "Test", "quoteType": "MUTUALFUND"}]}', 200)),
        foreignIsinProviders: [_MockForeignProvider('FR0010135103')],
      );

      final result = await resolver.resolve(ticker: 'TEST', fundName: 'Test Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('5. YAHOO (ISIN directo en búsqueda de Yahoo)', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": [{"symbol": "YHOO", "longname": "Yahoo Fund", "quoteType": "MUTUALFUND", "isin": "FR0000993172"}]}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'YHOO', fundName: 'Yahoo Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('6. MORNINGSTAR (Vía Morningstar LT provider)', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('{"quotes": [{"symbol": "0P00000FB4", "longname": "Morningstar Fund", "quoteType": "MUTUALFUND"}]}', 200)),
        foreignIsinProviders: [_MockForeignProvider('FR0010135103')],
      );

      final result = await resolver.resolve(ticker: '0P00000FB4', fundName: 'Morningstar Fund');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('7. null (No se encuentra ningún ISIN válido)', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('{"quotes": []}', 200)),
        foreignIsinProviders: [_MockForeignProvider(null)],
      );

      final result = await resolver.resolve(ticker: 'UNKNOWN', fundName: 'Unknown Fund');

      expect(result, isNull);
    });
  });
}
