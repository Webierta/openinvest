import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';

//import '../lib/models/foreign_isin_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/local_isin_provider.dart';

/// MockClient que:
///
/// 1. Simula las respuestas de Yahoo Finance.
/// 2. Deja pasar al cliente HTTP real todas las demás peticiones.
///
/// De esta forma:
/// - Yahoo no depende de Internet.
/// - Morningstar sí se consulta realmente.
class MockYahooClient extends http.BaseClient {
  final http.Client realClient;

  MockYahooClient({required this.realClient});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;

    // ---------------------------------------------------------------
    // Yahoo Finance
    // ---------------------------------------------------------------
    if (uri.host == 'query1.finance.yahoo.com' &&
        uri.path == '/v1/finance/search') {
      final query = uri.queryParameters['q'] ?? '';

      print('');
      print('MOCK YAHOO REQUEST');
      print('  q = $query');

      // Búsqueda por ticker.
      if (query.toUpperCase() == 'Y9U6.HM') {
        return _jsonResponse({
          'quotes': [
            {
              'symbol': 'Y9U6.HM',
              'shortname': 'Carmignac Patrimoine A EUR Acc',
              'longname': 'Carmignac Patrimoine A EUR Acc',
              'quoteType': 'MUTUALFUND',
            },
          ],
          'news': [],
        });
      }

      // Búsqueda por nombre.
      if (query.toLowerCase().contains('carmignac patrimoine')) {
        return _jsonResponse({
          'quotes': [
            {
              'symbol': 'Y9U6.HM',
              'shortname': 'Carmignac Patrimoine A EUR Acc',
              'longname': 'Carmignac Patrimoine A EUR Acc',
              'quoteType': 'MUTUALFUND',
            },
          ],
          'news': [],
        });
      }

      return _jsonResponse({'quotes': [], 'news': []});
    }

    // ---------------------------------------------------------------
    // Todo lo que no sea Yahoo:
    // dejarlo pasar al cliente HTTP real.
    //
    // Esto permite que MorningstarForeignIsinProvider consulte
    // Morningstar realmente.
    // ---------------------------------------------------------------
    print('');
    print('REAL HTTP REQUEST');
    print('  ${request.method} $uri');

    return realClient.send(request);
  }

  http.StreamedResponse _jsonResponse(
    Map<String, dynamic> body, {
    int statusCode = 200,
  }) {
    final bytes = utf8.encode(jsonEncode(body));

    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  group('MorningstarForeignIsinProvider', () {
    test('resuelve Carmignac mediante Morningstar cuando LocalIsinProvider no lo tiene', () async {
      print('');
      print('=' * 80);
      print('TEST: Morningstar fallback');
      print('=' * 80);

      const ticker = 'Y9U6.HM';
      const fundName = 'Carmignac Patrimoine A EUR Acc';
      const expectedIsin = 'FR0010135103';

      // -------------------------------------------------------------
      // Base de datos LOCAL VACÍA
      //
      // Esto es intencionado.
      //
      // Queremos demostrar que el resultado NO procede de
      // LocalIsinProvider, sino de MorningstarForeignIsinProvider.
      // -------------------------------------------------------------
      const emptyDatabase = '''
{
  "version": 1,
  "generatedAt": "2026-09-20",
  "entries": []
}
''';

      final realClient = http.Client();

      final client = MockYahooClient(realClient: realClient);

      // -------------------------------------------------------------
      // LocalIsinProvider vacío
      // -------------------------------------------------------------
      final localProvider = LocalIsinProvider(
        loadAsset: (_) async => emptyDatabase,
      );

      // -------------------------------------------------------------
      // Morningstar real
      // -------------------------------------------------------------
      final morningstarProvider = MorningstarForeignIsinProvider(
        client: client,
      );

      // -------------------------------------------------------------
      // Resolver
      //
      // ORDEN IMPORTANTE:
      //
      // 1. LocalIsinProvider -> NO encontrará nada.
      // 2. MorningstarForeignIsinProvider -> debe encontrar ISIN.
      // -------------------------------------------------------------
      final resolver = IsinResolver(
        client: client,
        foreignIsinProviders: [localProvider, morningstarProvider],
      );

      try {
        print('');
        print('DATOS DE ENTRADA');
        print('  Ticker: $ticker');
        print('  Nombre: $fundName');
        print('  ISIN esperado: $expectedIsin');

        print('');
        print('EJECUTANDO RESOLVER...');

        final result = await resolver.resolve(
          ticker: ticker,
          fundName: fundName,
        );

        print('');
        print('RESULTADO');

        if (result == null) {
          print('  RESULTADO: null');
        } else {
          print('  ISIN:          ${result.isin}');
          print('  Source:        ${result.source}');
          print('  Official name: ${result.officialName}');
          //print('  MS ID:         ${result.morningstarId}');
          print('  CNMV Reg:      ${result.cnmvRegistration}');
          print('  CNMV NIF:      ${result.cnmvNif}');
        }

        // -----------------------------------------------------------
        // Comprobaciones
        // -----------------------------------------------------------

        expect(
          result,
          isNotNull,
          reason: 'Morningstar debería haber resuelto el fondo.',
        );

        expect(
          result!.isin,
          equals(expectedIsin),
          reason:
              'El ISIN de Carmignac Patrimoine A EUR Acc debería ser '
              '$expectedIsin.',
        );

        // El resultado debe proceder de la cadena Yahoo/Foreign.
        expect(result.source, equals('Yahoo/Foreign'));

        // El nombre devuelto por Yahoo debe haberse conservado.
        expect(result.officialName, equals('Carmignac Patrimoine A EUR Acc'));

        print('');
        print('OK: ISIN correcto.');
        print('OK: LocalIsinProvider estaba vacío.');
        print(
          'OK: El resolver tuvo que continuar hacia '
          'MorningstarForeignIsinProvider.',
        );

        print('');
        print('=' * 80);
        print('TEST FINALIZADO CORRECTAMENTE');
        print('=' * 80);
      } finally {
        // IsinResolver cierra el client que recibe.
        resolver.dispose();

        // El realClient no pertenece al resolver.
        realClient.close();
      }
    });
  });
}
