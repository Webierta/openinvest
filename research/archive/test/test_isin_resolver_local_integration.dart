/*
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/local_isin_provider.dart';

void main() {
  group('IsinResolver + LocalIsinProvider', () {
    late String databaseJson;

    setUp(() {
      databaseJson = jsonEncode({
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
    });

    test('Y9U6.HM -> FR0010135103', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'query1.finance.yahoo.com');

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

    test('0P00006DAB -> LU0261948904', () async {
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

    test('0P00000HZF -> LU0120690226', () async {
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
  });
}
*/
