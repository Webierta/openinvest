/*
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'package:investing/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/local_isin_provider.dart';

class MockHttpClient extends http.BaseClient {
  final Map<String, String> _responses = {};

  void addResponse(String url, String body, {int statusCode = 200}) {
    _responses[url] = jsonEncode({'statusCode': statusCode, 'body': body});
  }

  void addJsonResponse(String url, dynamic json, {int statusCode = 200}) {
    addResponse(url, jsonEncode(json), statusCode: statusCode);
  }

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final key = url.toString();

    final encoded = _responses[key];

    if (encoded == null) {
      return http.Response(
        '',
        404,
        headers: const {'content-type': 'text/plain'},
      );
    }

    final data = jsonDecode(encoded) as Map<String, dynamic>;

    return http.Response(
      data['body'] as String,
      data['statusCode'] as int,
      headers: const {'content-type': 'text/html; charset=utf-8'},
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw UnimplementedError();
  }
}

class TestForeignProvider implements ForeignIsinProvider {
  final Map<String, String> values;

  TestForeignProvider(this.values);

  @override
  Future<String?> resolve({
    required String ticker,
    required String fundName,
    required String yahooSymbol,
    required String yahooName,
  }) async {
    return values[ticker.toUpperCase()];
  }
}

String yahooUrl(String query) {
  return Uri.parse('https://query1.finance.yahoo.com/v1/finance/search')
      .replace(
        queryParameters: {
          'q': query,
          'quotesCount': '20',
          'newsCount': '0',
          'enableFuzzyQuery': 'false',
        },
      )
      .toString();
}

String cnmvListUrl(int page) {
  return 'https://www.cnmv.es/portal/consultas/mostrarlistados'
      '?id=5&lang=es&page=$page';
}

String cnmvSocietyUrl(String nif) {
  return 'https://www.cnmv.es/portal/consultas/iic/sociedadiic?nif=$nif';
}

String cnmvListHtml(List<Map<String, String>> entities) {
  final buffer = StringBuffer();

  for (final entity in entities) {
    buffer.write('''
<a href="sociedadiic.aspx?nif=${entity['nif']}">
  ${entity['name']}
</a>
Número y fecha de registro oficial: ${entity['registration']}
''');
  }

  return '''
<html>
<body>
$buffer
</body>
</html>
''';
}

String cnmvSocietyHtml(String isin) {
  return '''
<html>
<body>
<div>
  Datos de la sociedad
</div>
<div>
  ISIN: $isin
</div>
</body>
</html>
''';
}

void main() {
  group('IsinResolver - regresión completa 6 fondos reales', () {
    late MockHttpClient client;
    late IsinResolver resolver;

    setUp(() {
      client = MockHttpClient();

      // ---------------------------------------------------------------
      // Yahoo
      // ---------------------------------------------------------------

      client.addJsonResponse(yahooUrl('Y9U6.HM'), {
        'quotes': [
          {
            'symbol': 'Y9U6.HM',
            'longname': 'Carmignac Patrimoine A EUR Acc',
            'shortname': 'Carmignac Patrimoine',
            'exchange': 'MUN',
            'quoteType': 'MUTUALFUND',
          },
        ],
      });

      client.addJsonResponse(yahooUrl('Carmignac Patrimoine A EUR Acc'), {
        'quotes': [
          {
            'symbol': 'Y9U6.HM',
            'longname': 'Carmignac Patrimoine A EUR Acc',
            'shortname': 'Carmignac Patrimoine',
            'exchange': 'MUN',
            'quoteType': 'MUTUALFUND',
          },
        ],
      });

      client.addJsonResponse(yahooUrl('0P00006DAB'), {
        'quotes': [
          {
            'symbol': '0P00006DAB.F',
            'longname': 'Fidelity Iberia A-Acc-EUR',
            'shortname': 'Fidelity Iberia',
            'exchange': 'FRA',
            'quoteType': 'MUTUALFUND',
          },
        ],
      });

      client.addJsonResponse(
        yahooUrl('Fidelity Funds - Iberia Fund A-Acc-EUR'),
        {
          'quotes': [
            {
              'symbol': '0P00006DAB.F',
              'longname': 'Fidelity Iberia A-Acc-EUR',
              'shortname': 'Fidelity Iberia',
              'exchange': 'FRA',
              'quoteType': 'MUTUALFUND',
            },
          ],
        },
      );

      client.addJsonResponse(yahooUrl('0P00000HZF'), {
        'quotes': [
          {
            'symbol': '0P00000HZF.F',
            'longname': 'Vontobel Fund - US Dollar Money B USD',
            'shortname': 'Vontobel USD Money',
            'exchange': 'FRA',
            'quoteType': 'MUTUALFUND',
          },
        ],
      });

      client.addJsonResponse(
        yahooUrl('Vontobel Fund - US Dollar Money B USD'),
        {
          'quotes': [
            {
              'symbol': '0P00000HZF.F',
              'longname': 'Vontobel Fund - US Dollar Money B USD',
              'shortname': 'Vontobel USD Money',
              'exchange': 'FRA',
              'quoteType': 'MUTUALFUND',
            },
          ],
        },
      );

      // ---------------------------------------------------------------
      // CNMV
      //
      // Las tres entidades están en la misma página simulada.
      // ---------------------------------------------------------------

      client.addResponse(
        cnmvListUrl(0),
        cnmvListHtml([
          {
            'registration': '20',
            'name': 'Elcano High Yield Opportunities SIL, S.A.',
            'nif': 'A00000020',
          },
          {
            'registration': '21',
            'name': 'Rosalita Capital SIL, S.A.',
            'nif': 'A00000021',
          },
          {
            'registration': '24',
            'name': 'Freecap Investment SIL, S.A.',
            'nif': 'A00000024',
          },
        ]),
      );

      // Página 1 vacía: el resolver deja de paginar.
      client.addResponse(cnmvListUrl(1), '<html><body></body></html>');

      client.addResponse(
        cnmvSocietyUrl('A00000020'),
        cnmvSocietyHtml('ES0128581008'),
      );

      client.addResponse(
        cnmvSocietyUrl('A00000021'),
        cnmvSocietyHtml('ES0134934001'),
      );

      client.addResponse(
        cnmvSocietyUrl('A00000024'),
        cnmvSocietyHtml('ES0139363008'),
      );

      // ---------------------------------------------------------------
      // Proveedor extranjero local
      // ---------------------------------------------------------------

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

      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => databaseJson,
      );

      resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider],
      );
    });

    tearDown(() {
      resolver.dispose();
    });

    test('resuelve los 6 fondos correctamente', () async {
      final cases = <Map<String, String>>[
        {
          'ticker': 'SL020.MC',
          'name': 'Elcano High Yield Opportunities SIL, S.A.',
          'isin': 'ES0128581008',
          'source': 'CNMV/SIL',
        },
        {
          'ticker': 'SL021.MC',
          'name': 'Rosalita Capital SIL, S.A.',
          'isin': 'ES0134934001',
          'source': 'CNMV/SIL',
        },
        {
          'ticker': 'SL024.MC',
          'name': 'Freecap Investment SIL, S.A.',
          'isin': 'ES0139363008',
          'source': 'CNMV/SIL',
        },
        {
          'ticker': 'Y9U6.HM',
          'name': 'Carmignac Patrimoine A EUR Acc',
          'isin': 'FR0010135103',
          'source': 'Yahoo/Foreign',
        },
        {
          'ticker': '0P00006DAB',
          'name': 'Fidelity Funds - Iberia Fund A-Acc-EUR',
          'isin': 'LU0261948904',
          'source': 'Yahoo/Foreign',
        },
        {
          'ticker': '0P00000HZF',
          'name': 'Vontobel Fund - US Dollar Money B USD',
          'isin': 'LU0120690226',
          'source': 'Yahoo/Foreign',
        },
      ];

      for (final item in cases) {
        print('');
        print('============================================================');
        print('TEST');
        print('Ticker: ${item['ticker']}');
        print('Nombre: ${item['name']}');
        print('ISIN esperado: ${item['isin']}');
        print('============================================================');

        final result = await resolver.resolve(
          ticker: item['ticker']!,
          fundName: item['name']!,
        );

        expect(result, isNotNull, reason: 'No se resolvió ${item['ticker']}');

        expect(result!.isin, item['isin']);
        expect(result.source, item['source']);

        print('ISIN obtenido: ${result.isin}');
        print('Source: ${result.source}');
        print('OK');
      }
    });
  });
}
*/
