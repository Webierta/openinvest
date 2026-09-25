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

class _TrackingForeignProvider implements ForeignIsinProvider {
  final String? resolvedIsin;
  final void Function()? onResolve;

  _TrackingForeignProvider({required this.resolvedIsin, this.onResolve});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    onResolve?.call();
    return resolvedIsin;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IsinResolver E2E Integration Tests', () {
    test('1. INPUT (ISIN embebido)', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );
      final result = await resolver.resolve(
        ticker: 'LU0297942194-USD.LU',
        fundName: 'Test',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    group('1b. INPUT (8 casos reales: ticker = ISIN)', () {
      final cases = <Map<String, String>>[
        {
          'name': 'JPM Europe Strategic Value A Acc EUR',
          'ticker': 'LU0210531983',
        },
        {
          'name': 'JPM Europe Strategic Value A Dist EUR',
          'ticker': 'LU0107398884',
        },
        {
          'name': 'Fidelity European Growth A Acc EUR',
          'ticker': 'LU0296857971',
        },
        {
          'name': 'Fidelity European Growth A Dist EUR',
          'ticker': 'LU0048578792',
        },
        {
          'name': 'Fidelity European Growth E Acc EUR',
          'ticker': 'LU0115764192',
        },
        {
          'name': 'BlackRock Next Generation Technology A2 SEK',
          'ticker': 'LU1861216940',
        },
        {
          'name': 'BlackRock Next Generation Technology A2 EUR',
          'ticker': 'LU2400291972',
        },
        {
          'name': 'BlackRock Next Generation Technology A2 USD',
          'ticker': 'LU1861215975',
        },
      ];

      for (final testCase in cases) {
        test(testCase['name']!, () async {
          final ticker = testCase['ticker']!;
          final resolver = IsinResolver(
            client: MockClient((_) async => http.Response('', 404)),
          );

          final result = await resolver.resolve(
            ticker: ticker,
            fundName: testCase['name']!,
          );

          expect(result, isNotNull);
          expect(result!.isin, ticker);
          expect(result.source, 'INPUT');
        });
      }
    });

    test('2. CNMV (FI local)', () async {
      final mockCnmv = _MockCnmvProvider(
        const CnmvFundResult(
          registrationNumber: 123,
          fundName: 'TEST FUND FI',
          compartmentName: null,
          compartmentNumber: null,
          fundClass: CnmvFundClass(
            number: 0,
            name: 'BASE',
            isin: 'ES0138841038',
          ),
          managerName: 'Test Gestora',
          depositaryName: 'Test Depositario',
        ),
      );

      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

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
          return http.Response(
            '<html><body lang="es">ISIN: LU0261948904</body></html>',
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);
      final result = await resolver.resolve(
        ticker: 'SL050.MC',
        fundName: 'SIL Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
      expect(result.source, 'CNMV/SIL');
    });

    test('4. LOCAL (Catálogo local / Foreign provider)', () async {
      final resolver = IsinResolver(
        client: MockClient(
          (_) async => http.Response(
            '{"quotes": [{"symbol": "TEST", "longname": "Test", "quoteType": "MUTUALFUND"}]}',
            200,
          ),
        ),
        foreignIsinProviders: [_MockForeignProvider('FR0010135103')],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

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
      final result = await resolver.resolve(
        ticker: 'YHOO',
        fundName: 'Yahoo Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('6. MORNINGSTAR (Vía Morningstar LT provider)', () async {
      final resolver = IsinResolver(
        client: MockClient(
          (_) async => http.Response(
            '{"quotes": [{"symbol": "0P00000FB4", "longname": "Morningstar Fund", "quoteType": "MUTUALFUND"}]}',
            200,
          ),
        ),
        foreignIsinProviders: [_MockForeignProvider('FR0010135103')],
      );

      final result = await resolver.resolve(
        ticker: '0P00000FB4',
        fundName: 'Morningstar Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('7. null (No se encuentra ningún ISIN válido)', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('{"quotes": []}', 200)),
        foreignIsinProviders: [_MockForeignProvider(null)],
      );

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Unknown Fund',
      );

      expect(result, isNull);
    });
  });

  group('A. INPUT / detección de ISIN - casos críticos', () {
    test('A1. ISIN válido exacto', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await resolver.resolve(
        ticker: 'LU0297942194',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    test('A2. ISIN en minúsculas', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await resolver.resolve(
        ticker: 'lu0297942194',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    test('A3. ISIN con checksum incorrecto debe rechazarse', () async {
      // LU0297942194 es válido.
      // Modificamos el último dígito para provocar un checksum incorrecto.
      const invalidIsin = 'LU0297942195';

      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await resolver.resolve(
        ticker: invalidIsin,
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('A4. ISIN embebido dentro de una cadena', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await resolver.resolve(
        ticker: 'ABC-LU0297942194-USD.LU',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    test('A5. Dos ISIN válidos: debe devolver el primero', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
      );

      final result = await resolver.resolve(
        ticker: 'LU0297942194 / IE00B8K7V925',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });
  });

  group('B. Prioridad y cadena de providers - casos críticos', () {
    test('B1. INPUT tiene prioridad sobre CNMV/FI y Yahoo', () async {
      final mockCnmv = _MockCnmvProvider(
        const CnmvFundResult(
          registrationNumber: 999,
          fundName: 'CNMV Fund',
          compartmentName: null,
          compartmentNumber: null,
          fundClass: CnmvFundClass(
            number: 0,
            name: 'BASE',
            isin: 'ES0138841038',
          ),
          managerName: 'Test Gestora',
          depositaryName: 'Test Depositario',
        ),
      );

      final resolver = IsinResolver(
        client: MockClient((_) async {
          return http.Response(
            '{"quotes": [{"symbol": "TEST", "longname": "Yahoo Fund", '
            '"quoteType": "MUTUALFUND", "isin": "FR0000993172"}]}',
            200,
          );
        }),
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(
        ticker: 'LU0297942194',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
    });

    test('B2. Si INPUT falla, continúa con CNMV/FI', () async {
      final mockCnmv = _MockCnmvProvider(
        const CnmvFundResult(
          registrationNumber: 123,
          fundName: 'TEST FUND FI',
          compartmentName: null,
          compartmentNumber: null,
          fundClass: CnmvFundClass(
            number: 0,
            name: 'BASE',
            isin: 'ES0138841038',
          ),
          managerName: 'Test Gestora',
          depositaryName: 'Test Depositario',
        ),
      );

      final resolver = IsinResolver(
        client: MockClient((_) async => http.Response('', 404)),
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0138841038');
      expect(result.source, 'CNMV/FI local');
    });

    test('B3. Si SIL no resuelve, la cadena continúa', () async {
      final mockClient = MockClient((request) async {
        // Las consultas de SIL no encuentran ningún fondo.
        if (request.url.toString().contains('mostrarlistados')) {
          return http.Response('', 404);
        }

        // Yahoo tampoco encuentra nada.
        return http.Response('{"quotes": []}', 200);
      });

      final mockCnmv = _MockCnmvProvider(null);

      final resolver = IsinResolver(
        client: mockClient,
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Unknown Fund',
      );

      expect(result, isNull);
    });

    test('B4. Si FI no resuelve, continúa hasta Yahoo', () async {
      final mockCnmv = _MockCnmvProvider(null);

      final resolver = IsinResolver(
        client: MockClient((_) async {
          return http.Response(
            '{"quotes": [{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}]}',
            200,
          );
        }),
        cnmvLocalFundProvider: mockCnmv,
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('B5. Un provider que devuelve null no bloquea la cadena', () async {
      final nullProvider = _MockForeignProvider(null);
      final validProvider = _MockForeignProvider('FR0010135103');

      final resolver = IsinResolver(
        client: MockClient((_) async {
          return http.Response(
            '{"quotes": [{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND"}]}',
            200,
          );
        }),
        foreignIsinProviders: [nullProvider, validProvider],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('B6. El primer provider válido detiene la cadena', () async {
      var secondProviderCalled = false;

      final firstProvider = _TrackingForeignProvider(
        resolvedIsin: 'FR0010135103',
      );

      final secondProvider = _TrackingForeignProvider(
        resolvedIsin: 'LU0261948904',
        onResolve: () {
          secondProviderCalled = true;
        },
      );

      final resolver = IsinResolver(
        client: MockClient((_) async {
          return http.Response(
            '{"quotes": [{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND"}]}',
            200,
          );
        }),
        foreignIsinProviders: [firstProvider, secondProvider],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');

      expect(secondProviderCalled, isFalse);
    });

    test(
      'B7. Un resultado válido no es reemplazado por otro posterior',
      () async {
        final resolver = IsinResolver(
          client: MockClient((_) async {
            return http.Response(
              '{"quotes": [{"symbol": "TEST", '
              '"longname": "Test Fund", '
              '"quoteType": "MUTUALFUND", '
              '"isin": "FR0000993172"}]}',
              200,
            );
          }),
          foreignIsinProviders: [_MockForeignProvider('LU0261948904')],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);

        // Yahoo ya ha proporcionado un ISIN válido.
        // El Foreign provider no debe sustituirlo.
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('B8. Si todos los providers fallan, devuelve null', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async {
          return http.Response('{"quotes": []}', 200);
        }),
        cnmvLocalFundProvider: _MockCnmvProvider(null),
        foreignIsinProviders: [
          _MockForeignProvider(null),
          _MockForeignProvider(null),
        ],
      );

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Unknown Fund',
      );

      expect(result, isNull);
    });
  });

  group('C. YAHOO / resolución y casos límite', () {
    test('C1. Yahoo devuelve un ISIN válido directamente', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "YHOO", '
          '"longname": "Yahoo Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'YHOO',
        fundName: 'Yahoo Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test(
      'C2. Yahoo devuelve ISIN con checksum incorrecto y debe rechazarse',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993173"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(
          client: mockClient,
          foreignIsinProviders: [_MockForeignProvider(null)],
        );

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test('C3. Yahoo devuelve ISIN en minúsculas y debe normalizarse', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "fr0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('C4. Yahoo sin ISIN utiliza ForeignIsinProvider', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND"'
          '}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [_MockForeignProvider('FR0010135103')],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
    });

    test('C5. Yahoo sin ISIN y Foreign devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND"'
          '}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(
        client: mockClient,
        foreignIsinProviders: [_MockForeignProvider(null)],
      );

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test(
      'C6. Yahoo devuelve JSON inválido y no debe lanzar excepción',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('{"quotes": [INVALID JSON', 200);
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
      },
    );

    test('C7. Yahoo devuelve HTTP 404 y no debe lanzar excepción', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('C8. Yahoo devuelve HTTP 500 y no debe lanzar excepción', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('C9. Yahoo ignora elementos malformed dentro de quotes', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          'null,'
          '"texto",'
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });

    test('C10. Yahoo EQUITY no debe tratarse como fondo válido', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "EQUITY", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('C11. Yahoo ETF no debe tratarse como fondo válido', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "ETF", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('C12. Yahoo MUTUALFUND sí puede devolver el ISIN', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
      expect(result.source, 'Yahoo');
    });
  });

  group('D. YAHOO / ranking de resultados', () {
    test(
      'D1. Coincidencia exacta de nombre + MUTUALFUND supera el umbral',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('D2. Mismo ticker + nombre incompatible: debe quedar fuera', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST", '
          '"longname": "Completely Different Company", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'TEST',
        fundName: 'My Investment Fund',
      );

      expect(result, isNull);
    });

    test(
      'D3. Nombre exacto + ticker diferente puede superar el umbral',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "OTHER", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
        expect(result.source, 'Yahoo');
      },
    );

    test('D4. Mismo Morningstar ID con sufijo debe reconocerse', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "0P00000FB4.F", '
          '"longname": "PIMCO Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0010135103"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: '0P00000FB4',
        fundName: 'PIMCO Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo');
    });

    test(
      'D5. Dos candidatos: el de mayor similitud de nombre debe quedar primero',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "OTHER1", '
            '"longname": "Test Fund Global", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"},'
            '{"symbol": "OTHER2", '
            '"longname": "Test Fund", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "LU0261948904"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'UNKNOWN',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'LU0261948904');
      },
    );

    test('D6. MUTUALFUND supera a un candidato EQUITY equivalente', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST-EQ", '
          '"longname": "Test Fund", '
          '"quoteType": "EQUITY", '
          '"isin": "FR0000993172"},'
          '{"symbol": "TEST-FUND", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "LU0261948904"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
    });

    test('D7. ETF recibe penalización frente a MUTUALFUND', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "TEST-ETF", '
          '"longname": "Test Fund", '
          '"quoteType": "ETF", '
          '"isin": "FR0000993172"},'
          '{"symbol": "TEST-FUND", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "LU0261948904"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
    });

    test(
      'D8. EQUITY con nombre incompatible queda por debajo del umbral',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Completely Unrelated Equity", '
            '"quoteType": "EQUITY", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'Test Investment Fund',
        );

        expect(result, isNull);
      },
    );

    test('D9. ISIN válido aporta puntuación adicional al ranking', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          '{"quotes": ['
          '{"symbol": "OTHER", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND"},'
          '{"symbol": "OTHER2", '
          '"longname": "Test Fund", '
          '"quoteType": "MUTUALFUND", '
          '"isin": "FR0000993172"}'
          ']}',
          200,
        );
      });

      final resolver = IsinResolver(client: mockClient);

      final result = await resolver.resolve(
        ticker: 'UNKNOWN',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0000993172');
    });

    test(
      'D10. La comparación de nombres ignora mayúsculas y acentos',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            '{"quotes": ['
            '{"symbol": "TEST", '
            '"longname": "Fidelity Européen Growth", '
            '"quoteType": "MUTUALFUND", '
            '"isin": "FR0000993172"}'
            ']}',
            200,
          );
        });

        final resolver = IsinResolver(client: mockClient);

        final result = await resolver.resolve(
          ticker: 'TEST',
          fundName: 'FIDELITY EUROPEEN GROWTH',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'FR0000993172');
      },
    );
  });

  // ===========================================================================
  // GRUPO E — MORNINGSTAR FOREIGN ISIN PROVIDER
  // ===========================================================================

  group('Grupo E - Morningstar', () {
    test('E1. Morningstar ID válido sin sufijo', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), contains('snapshot.aspx'));

        return http.Response('''
          <html>
            <script>
              var HoldingIsin = 'IE00B8K7V925';
            </script>
          </html>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        yahooSymbol: '0P0000X83M',
        yahooName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, 'IE00B8K7V925');
    });

    test('E2. Morningstar ID con sufijo .F', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            HoldingIsin = 'FR0010135103';
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P00000FB4.F',
        fundName: 'Carmignac Patrimoine A EUR Acc',
        yahooSymbol: '0P00000FB4.F',
        yahooName: 'Carmignac Patrimoine A EUR Acc',
      );

      expect(result, 'FR0010135103');
    });

    test('E3. Morningstar ID en minúsculas se normaliza', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            HoldingIsin = 'LU0261948904';
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0p00006dab.f',
        fundName: 'Fidelity Iberia A-Acc-EUR',
        yahooSymbol: '0p00006dab.f',
        yahooName: 'Fidelity Iberia A-Acc-EUR',
      );

      expect(result, 'LU0261948904');
    });

    test('E4. Símbolo que no es Morningstar ID devuelve null', () async {
      var called = false;

      final mockClient = MockClient((request) async {
        called = true;
        return http.Response('', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: 'ABC.MC',
        fundName: 'Test Fund',
        yahooSymbol: 'ABC.MC',
        yahooName: 'Test Fund',
      );

      expect(result, isNull);
      expect(called, isFalse);
    });

    test('E5. HoldingIsin con sintaxis de asignación funciona', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            HoldingIsin = 'LU0129445192';
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P00000Z1Y.F',
        fundName: 'JPM Europe Strategic Value C acc EUR',
        yahooSymbol: '0P00000Z1Y.F',
        yahooName: 'JPM Europe Strategic Value C acc EUR',
      );

      expect(result, 'LU0129445192');
    });

    test('E6. HoldingIsin con sintaxis de dos puntos funciona', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            var data = {
              HoldingIsin: 'IE00B8K7V925'
            };
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        yahooSymbol: '0P0000X83M',
        yahooName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, 'IE00B8K7V925');
    });

    test('E7. HoldingIsin ausente devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <html>
            <body>Morningstar page without ISIN</body>
          </html>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
        yahooSymbol: '0P0000X83M',
        yahooName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('E8. HoldingIsin inválido devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            HoldingIsin = 'INVALIDISIN';
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
        yahooSymbol: '0P0000X83M',
        yahooName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('E9. HTTP 404 devuelve null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
        yahooSymbol: '0P0000X83M',
        yahooName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('E10. Error de red devuelve null', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network error');
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'Test Fund',
        yahooSymbol: '0P0000X83M',
        yahooName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('E11. ISIN en minúsculas se devuelve normalizado', () async {
      final mockClient = MockClient((request) async {
        return http.Response('''
          <script>
            HoldingIsin = 'ie00b8k7v925';
          </script>
          ''', 200);
      });

      final provider = MorningstarLtForeignIsinProvider(client: mockClient);

      final result = await provider.resolve(
        ticker: '0P0000X83M',
        fundName: 'PIMCO GIS Income Fund E Class USD Income',
        yahooSymbol: '0P0000X83M',
        yahooName: 'PIMCO GIS Income Fund E Class USD Income',
      );

      expect(result, 'IE00B8K7V925');
    });

    test(
      'E12. ID Morningstar con sufijo distinto también se normaliza',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('''
          <script>
            HoldingIsin = 'LU0261948904';
          </script>
          ''', 200);
        });

        final provider = MorningstarLtForeignIsinProvider(client: mockClient);

        final result = await provider.resolve(
          ticker: '0P00006DAB.XY',
          fundName: 'Fidelity Iberia A-Acc-EUR',
          yahooSymbol: '0P00006DAB.XY',
          yahooName: 'Fidelity Iberia A-Acc-EUR',
        );

        expect(result, 'LU0261948904');
      },
    );
  });
}
