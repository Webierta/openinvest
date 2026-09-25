import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SIL Resolver Tests', () {
    test('SL020.MC resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          if (request.url.toString().contains('page=0')) {
            return http.Response('''
              <a href="sociedadiic.aspx?nif=A11111111">SIL 20 FUND SICAV</a>
              Número y fecha de registro oficial: 20
            ''', 200);
          } else {
            return http.Response('', 404);
          }
        } else if (request.url.toString().contains('sociedadiic')) {
          return http.Response('''
            <html><body><div>ISIN: LU0261948904</div></body></html>
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL020.MC', fundName: 'SIL 20');

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
      expect(result.source, 'CNMV/SIL');
      expect(result.cnmvRegistration, 20);
    });

    test('SL021.MC resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          if (request.url.toString().contains('page=0')) {
            return http.Response('''
              <a href="sociedadiic.aspx?nif=A22222222">SIL 21 FUND SICAV</a>
              Número y fecha de registro oficial: 21
            ''', 200);
          } else {
            return http.Response('', 404);
          }
        } else if (request.url.toString().contains('sociedadiic')) {
          return http.Response('''
            <html><body><div>ISIN: FR0010135103</div></body></html>
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL021.MC', fundName: 'SIL 21');

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.cnmvRegistration, 21);
    });

    test('SL024.MC resuelve correctamente', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          if (request.url.toString().contains('page=0')) {
            return http.Response('''
              <a href="sociedadiic.aspx?nif=A44444444">SIL 24 FUND SICAV</a>
              Número y fecha de registro oficial: 24
            ''', 200);
          } else {
            return http.Response('', 404);
          }
        } else if (request.url.toString().contains('sociedadiic')) {
          return http.Response('''
            <html><body><div>ISIN: LU0120690226</div></body></html>
          ''', 200);
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL024.MC', fundName: 'SIL 24');

      expect(result, isNotNull);
      expect(result!.isin, 'LU0120690226');
      expect(result.cnmvRegistration, 24);
    });

    test('registro inexistente devuelve null', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          if (request.url.toString().contains('page=0')) {
            return http.Response('''
              <a href="sociedadiic.aspx?nif=A11111111">SIL 20 FUND SICAV</a>
              Número y fecha de registro oficial: 20
            ''', 200);
          } else {
            return http.Response('', 404);
          }
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL999.MC', fundName: 'SIL 999');

      expect(result, isNull);
    });

    test('CNMV timeout maneja error correctamente', () async {
      final mockClient = MockClient((request) async {
        throw TimeoutException('Connection timed out');
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL020.MC', fundName: 'SIL 20');

      expect(result, isNull);
    });

    test('HTML cambiado devuelve null', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('mostrarlistados')) {
          return http.Response('<html><body lang="es">Estructura completamente cambiada sin enlaces válidos</body></html>', 200);
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(ticker: 'SL020.MC', fundName: 'SIL 20');

      expect(result, isNull);
    });
  });
}
