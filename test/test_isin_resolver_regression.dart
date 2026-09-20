import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/local_isin_provider.dart';

void main() {
  // Fixture con la misma estructura que assets/files/isin_database.json.
  final databaseJson = jsonEncode({
    'version': 1,
    'generatedAt': '2026-09-20',
    'entries': [
      {
        'morningstarId': '0P00000FB4',
        'isin': 'FR0010135103',
        'name': 'Carmignac Patrimoine A EUR Acc',
        'ticker': 'Y9U6.HM',
      },
      {
        'morningstarId': '0P00006DAB',
        'isin': 'LU0261948904',
        'name': 'Fidelity Iberia A-Acc-EUR',
        'ticker': '0P00006DAB.F',
      },
      {
        'morningstarId': '0P00000HZF',
        'isin': 'LU0120690226',
        'name': 'Vontobel Fund - US Dollar Money B USD',
        'ticker': '0P00000HZF.F',
      },
    ],
  });

  group('IsinResolver - regresión', () {
    test('un ISIN de entrada se devuelve directamente', () async {
      final resolver = IsinResolver(
        client: MockClient((_) async {
          fail('No debe realizar ninguna petición HTTP');
        }),
        foreignIsinProviders: const [],
      );

      final result = await resolver.resolve(
        ticker: 'LU0261948904',
        fundName: 'Fidelity Iberia A-Acc-EUR',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
      expect(result.source, 'INPUT');
      expect(result.officialName, 'Fidelity Iberia A-Acc-EUR');

      resolver.dispose();
    });

    test('Y9U6.HM -> FR0010135103 usando LocalIsinProvider', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': 'Y9U6.HM',
                'shortname': 'Carmignac Patrimoine A EUR Acc',
                'longname': 'Carmignac Patrimoine A EUR Acc',
              },
            ],
          }),
          200,
        );
      });

      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => databaseJson,
      );

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider],
      );

      final result = await resolver.resolve(
        ticker: 'Y9U6.HM',
        fundName: 'Carmignac Patrimoine A EUR Acc',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'FR0010135103');
      expect(result.source, 'Yahoo/Foreign');
      expect(result.officialName, 'Carmignac Patrimoine A EUR Acc');

      resolver.dispose();
    });

    test('0P00006DAB -> LU0261948904 usando LocalIsinProvider', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P00006DAB.F',
                'shortname': 'Fidelity Iberia A-Acc-EUR',
                'longname': 'Fidelity Iberia A-Acc-EUR',
              },
            ],
          }),
          200,
        );
      });

      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => databaseJson,
      );

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider],
      );

      final result = await resolver.resolve(
        ticker: '0P00006DAB',
        fundName: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0261948904');
      expect(result.source, 'Yahoo/Foreign');
      expect(result.officialName, 'Fidelity Iberia A-Acc-EUR');

      resolver.dispose();
    });

    test('0P00000HZF -> LU0120690226 usando LocalIsinProvider', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'quotes': [
              {
                'symbol': '0P00000HZF.F',
                'shortname': 'Vontobel Fund - US Dollar Money B USD',
                'longname': 'Vontobel Fund - US Dollar Money B USD',
              },
            ],
          }),
          200,
        );
      });

      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => databaseJson,
      );

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider],
      );

      final result = await resolver.resolve(
        ticker: '0P00000HZF',
        fundName: 'Vontobel Fund - US Dollar Money B USD',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0120690226');
      expect(result.source, 'Yahoo/Foreign');
      expect(result.officialName, 'Vontobel Fund - US Dollar Money B USD');

      resolver.dispose();
    });

    test('ticker desconocido devuelve null sin excepción', () async {
      final client = MockClient((request) async {
        return http.Response(jsonEncode({'quotes': []}), 200);
      });

      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => databaseJson,
      );

      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider],
      );

      final result = await resolver.resolve(
        ticker: 'UNKNOWN.X',
        fundName: 'Fondo que no existe',
      );

      expect(result, isNull);

      resolver.dispose();
    });

    test(
      'continúa con el siguiente proveedor si el local no encuentra ISIN',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'quotes': [
                {
                  'symbol': 'TEST.X',
                  'shortname': 'Test Fund',
                  'longname': 'Test Fund',
                },
              ],
            }),
            200,
          );
        });

        final localProvider = LocalIsinProvider(
          loadAsset: (_) async => databaseJson,
        );

        const fallback = _FakeForeignIsinProvider(
          // ISIN real y válido utilizado únicamente para comprobar
          // el encadenamiento de proveedores.
          isin: 'IE00B4L5Y983',
        );

        final resolver = IsinResolver(
          client: client,
          foreignIsinProviders: [localProvider, fallback],
        );

        final result = await resolver.resolve(
          ticker: 'TEST.X',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'IE00B4L5Y983');
        expect(result.source, 'Yahoo/Foreign');

        resolver.dispose();
      },
    );
  });
}

class _FakeForeignIsinProvider implements ForeignIsinProvider {
  final String isin;

  const _FakeForeignIsinProvider({required this.isin});

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    return isin;
  }
}
