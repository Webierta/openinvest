import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/isin_providers/cnmv_sil_provider.dart';

const _indexUrlBase =
    'https://www.cnmv.es/portal/consultas/mostrarlistados?id=5&lang=es&page=';

const _societyUrlBase =
    'https://www.cnmv.es/portal/consultas/iic/sociedadiic?nif=';

String _indexPage({
  required int registrationNumber,
  required String name,
  required String nif,
}) {
  return '''
<html>
  <body>
    <a href="/portal/consultas/iic/sociedadiic?nif=$nif">
      $name
    </a>
    <span>Nº Registro: $registrationNumber</span>
  </body>
</html>
''';
}

String _emptyIndexPage() {
  return '''
<html>
  <body>
    <p>Sin resultados</p>
  </body>
</html>
''';
}

String _societyPage({required String isin}) {
  return '''
<html>
  <body>
    <div>ISIN: $isin</div>
  </body>
</html>
''';
}

void main() {
  group('CnmvSilProvider', () {
    test(
      'SIL-1 - ticker que no es SLxxx.MC devuelve null sin realizar HTTP',
      () async {
        var requestCount = 0;

        final client = MockClient((request) async {
          requestCount++;
          throw StateError('No debería realizarse ninguna petición HTTP');
        });

        final provider = CnmvSilProvider(client: client);

        final result = await provider.resolve(
          ticker: 'ABC.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
        expect(requestCount, 0);
      },
    );

    test('SIL-2 - ticker SLxxx.MC con entidad en el índice continúa hasta la sociedad', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '${_indexUrlBase}0') {
          return http.Response(
            _indexPage(
              registrationNumber: 21,
              name: 'Rosalita Capital SIL S.A.',
              nif: 'A12345678',
            ),
            200,
          );
        }

        if (request.url.toString() == '${_indexUrlBase}1') {
          return http.Response(_emptyIndexPage(), 200);
        }

        if (request.url.toString() == '${_societyUrlBase}A12345678') {
          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Rosalita Capital SIL S.A.',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0000000010');
      expect(result.source, 'CNMV/SIL');
      expect(result.officialName, 'Rosalita Capital SIL S.A.');
      expect(result.cnmvRegistration, 21);
      expect(result.cnmvNif, 'A12345678');
    });

    test('SIL-3 - error HTTP al cargar el índice devuelve null', () async {
      var requestCount = 0;

      final client = MockClient((request) async {
        requestCount++;

        if (request.url.toString() == '${_indexUrlBase}0') {
          return http.Response('Internal Server Error', 500);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
      expect(requestCount, 1);
    });

    test('SIL-4 - excepción HTTP al cargar el índice devuelve null', () async {
      final client = MockClient((request) async {
        throw StateError('CNMV index failure');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('SIL-5 - error HTTP al consultar la sociedad devuelve null', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '${_indexUrlBase}0') {
          return http.Response(
            _indexPage(
              registrationNumber: 21,
              name: 'Rosalita Capital SIL S.A.',
              nif: 'A12345678',
            ),
            200,
          );
        }

        if (request.url.toString() == '${_indexUrlBase}1') {
          return http.Response(_emptyIndexPage(), 200);
        }

        if (request.url.toString() == '${_societyUrlBase}A12345678') {
          return http.Response('Service unavailable', 503);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('SIL-6 - sociedad sin ISIN válido devuelve null', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '${_indexUrlBase}0') {
          return http.Response(
            _indexPage(
              registrationNumber: 21,
              name: 'Rosalita Capital SIL S.A.',
              nif: 'A12345678',
            ),
            200,
          );
        }

        if (request.url.toString() == '${_indexUrlBase}1') {
          return http.Response(_emptyIndexPage(), 200);
        }

        if (request.url.toString() == '${_societyUrlBase}A12345678') {
          return http.Response(_societyPage(isin: 'AA0000000000'), 200);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNull);
    });

    test('SIL-7 - ISIN válido devuelve IsinResult completo', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '${_indexUrlBase}0') {
          return http.Response(
            _indexPage(
              registrationNumber: 21,
              name: 'Rosalita Capital SIL S.A.',
              nif: 'A12345678',
            ),
            200,
          );
        }

        if (request.url.toString() == '${_indexUrlBase}1') {
          return http.Response(_emptyIndexPage(), 200);
        }

        if (request.url.toString() == '${_societyUrlBase}A12345678') {
          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0000000010');
      expect(result.source, 'CNMV/SIL');
      expect(result.officialName, 'Rosalita Capital SIL S.A.');
      expect(result.cnmvRegistration, 21);
      expect(result.cnmvNif, 'A12345678');
    });

    test('SIL-8 - error en una página intermedia no debe cachear un índice parcial', () async {
      var page0Requests = 0;
      var page1Requests = 0;

      final client = MockClient((request) async {
        final url = request.url.toString();

        if (url == '${_indexUrlBase}0') {
          page0Requests++;

          return http.Response(
            _indexPage(
              registrationNumber: 21,
              name: 'Rosalita Capital SIL S.A.',
              nif: 'A12345678',
            ),
            200,
          );
        }

        if (url == '${_indexUrlBase}1') {
          page1Requests++;

          return http.Response('Internal Server Error', 500);
        }

        if (url == '${_societyUrlBase}A12345678') {
          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        throw StateError('URL inesperada: ${request.url}');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test Fund',
      );

      /*
         * El comportamiento deseado después de corregir CnmvSilProvider
         * es que un error durante la carga del índice invalide toda la
         * carga. Por tanto, no debe resolverse usando el índice parcial.
         */
      expect(result, isNull);

      expect(page0Requests, 1);
      expect(page1Requests, 1);
    });

    test(
      'SIL-9 - después de un error de carga debe poder reintentarse',
      () async {
        var page0Requests = 0;
        var page1Requests = 0;
        var successfulLoad = false;

        final client = MockClient((request) async {
          final url = request.url.toString();

          if (url == '${_indexUrlBase}0') {
            page0Requests++;

            return http.Response(
              _indexPage(
                registrationNumber: 21,
                name: 'Rosalita Capital SIL S.A.',
                nif: 'A12345678',
              ),
              200,
            );
          }

          if (url == '${_indexUrlBase}1') {
            page1Requests++;

            if (!successfulLoad) {
              return http.Response('Internal Server Error', 500);
            }

            return http.Response(_emptyIndexPage(), 200);
          }

          if (url == '${_societyUrlBase}A12345678') {
            return http.Response(_societyPage(isin: 'ES0000000010'), 200);
          }

          throw StateError('URL inesperada: ${request.url}');
        });

        final provider = CnmvSilProvider(client: client);

        final firstResult = await provider.resolve(
          ticker: 'SL021.MC',
          fundName: 'Test Fund',
        );

        expect(firstResult, isNull);

        successfulLoad = true;

        final secondResult = await provider.resolve(
          ticker: 'SL021.MC',
          fundName: 'Test Fund',
        );

        expect(secondResult, isNotNull);
        expect(secondResult!.isin, 'ES0000000010');

        /*
         * El índice tuvo que cargarse nuevamente.
         */
        expect(page0Requests, 2);
        expect(page1Requests, 2);
      },
    );

    test(
      'SIL-10 - una vez cargado correctamente el índice se reutiliza la cache',
      () async {
        var indexRequestCount = 0;
        var societyRequestCount = 0;

        final client = MockClient((request) async {
          final url = request.url.toString();

          if (url == '${_indexUrlBase}0') {
            indexRequestCount++;

            return http.Response(
              _indexPage(
                registrationNumber: 21,
                name: 'Rosalita Capital SIL S.A.',
                nif: 'A12345678',
              ),
              200,
            );
          }

          if (url == '${_indexUrlBase}1') {
            indexRequestCount++;

            return http.Response(_emptyIndexPage(), 200);
          }

          if (url == '${_societyUrlBase}A12345678') {
            societyRequestCount++;

            return http.Response(_societyPage(isin: 'ES0000000010'), 200);
          }

          throw StateError('URL inesperada: ${request.url}');
        });

        final provider = CnmvSilProvider(client: client);

        final firstResult = await provider.resolve(
          ticker: 'SL021.MC',
          fundName: 'Test Fund',
        );

        final secondResult = await provider.resolve(
          ticker: 'SL021.MC',
          fundName: 'Test Fund',
        );

        expect(firstResult, isNotNull);
        expect(secondResult, isNotNull);

        expect(firstResult!.isin, 'ES0000000010');
        expect(secondResult!.isin, 'ES0000000010');

        /*
         * Dos páginas para cargar el índice, una sola vez.
         */
        expect(indexRequestCount, 2);

        /*
         * La sociedad sí se consulta en cada resolve.
         */
        expect(societyRequestCount, 2);
      },
    );

    // -----------------------------------------------------------------------------
    // SIL-11 — Excepción al consultar la sociedad
    // -----------------------------------------------------------------------------
    //
    // El índice se carga correctamente, pero la consulta de la sociedad lanza
    // una excepción. El provider debe absorberla y devolver null.
    //

    test('SIL-11: exception while loading society returns null', () async {
      var indexRequestCount = 0;
      var societyRequestCount = 0;

      final client = MockClient((request) async {
        final uri = request.url;

        if (uri.toString().startsWith(_indexUrlBase)) {
          indexRequestCount++;

          if (uri.queryParameters['page'] == '0') {
            return http.Response(
              _indexPage(
                registrationNumber: 21,
                name: 'Test SIL 21',
                nif: 'A12345678',
              ),
              200,
            );
          }

          return http.Response(_emptyIndexPage(), 200);
        }

        if (uri.toString() ==
            '$_societyUrlBase'
                'A12345678') {
          societyRequestCount++;
          throw StateError('Simulated society failure');
        }

        fail('Unexpected request: $uri');
      });

      final provider = CnmvSilProvider(client: client);

      final result = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(result, isNull);
      expect(indexRequestCount, 2);
      expect(societyRequestCount, 1);
    });

    // -----------------------------------------------------------------------------
    // SIL-12 — Recuperación después de HTTP 503 en sociedad
    // -----------------------------------------------------------------------------
    //
    // La primera consulta de la sociedad devuelve 503.
    // La segunda funciona.
    //
    // El índice debe permanecer cacheado: no se vuelven a descargar sus páginas.
    //

    test('SIL-12: society HTTP error can recover on next resolve', () async {
      var indexRequestCount = 0;
      var societyRequestCount = 0;

      final client = MockClient((request) async {
        final uri = request.url;

        if (uri.toString().startsWith(_indexUrlBase)) {
          indexRequestCount++;

          if (uri.queryParameters['page'] == '0') {
            return http.Response(
              _indexPage(
                registrationNumber: 21,
                name: 'Test SIL 21',
                nif: 'A12345678',
              ),
              200,
            );
          }

          return http.Response(_emptyIndexPage(), 200);
        }

        if (uri.toString() ==
            '$_societyUrlBase'
                'A12345678') {
          societyRequestCount++;

          if (societyRequestCount == 1) {
            return http.Response('Service unavailable', 503);
          }

          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        fail('Unexpected request: $uri');
      });

      final provider = CnmvSilProvider(client: client);

      final firstResult = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(firstResult, isNull);

      final secondResult = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(secondResult, isNotNull);
      expect(secondResult!.isin, 'ES0000000010');
      expect(secondResult.source, 'CNMV/SIL');
      expect(secondResult.officialName, 'Test SIL 21');
      expect(secondResult.cnmvRegistration, 21);
      expect(secondResult.cnmvNif, 'A12345678');

      // El índice solo se descargó una vez: página 0 + página vacía.
      expect(indexRequestCount, 2);

      // La sociedad se consultó dos veces: 503 + éxito.
      expect(societyRequestCount, 2);
    });

    // -----------------------------------------------------------------------------
    // SIL-13 — Recuperación después de excepción en sociedad
    // -----------------------------------------------------------------------------
    //
    // Igual que SIL-12, pero el primer fallo de la sociedad es una excepción,
    // no una respuesta HTTP.
    //
    // Comprueba que una excepción de la fuente no deja al provider en un estado
    // irrecuperable y que el índice continúa cacheado.
    //

    test('SIL-13: society exception can recover on next resolve', () async {
      var indexRequestCount = 0;
      var societyRequestCount = 0;

      final client = MockClient((request) async {
        final uri = request.url;

        if (uri.toString().startsWith(_indexUrlBase)) {
          indexRequestCount++;

          if (uri.queryParameters['page'] == '0') {
            return http.Response(
              _indexPage(
                registrationNumber: 21,
                name: 'Test SIL 21',
                nif: 'A12345678',
              ),
              200,
            );
          }

          return http.Response(_emptyIndexPage(), 200);
        }

        if (uri.toString() ==
            '$_societyUrlBase'
                'A12345678') {
          societyRequestCount++;

          if (societyRequestCount == 1) {
            throw StateError('Simulated society exception');
          }

          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        fail('Unexpected request: $uri');
      });

      final provider = CnmvSilProvider(client: client);

      final firstResult = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(firstResult, isNull);

      final secondResult = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(secondResult, isNotNull);
      expect(secondResult!.isin, 'ES0000000010');
      expect(secondResult.source, 'CNMV/SIL');
      expect(secondResult.officialName, 'Test SIL 21');
      expect(secondResult.cnmvRegistration, 21);
      expect(secondResult.cnmvNif, 'A12345678');

      // El índice sigue cacheado después de la excepción de la sociedad.
      expect(indexRequestCount, 2);

      // Una consulta falló y la siguiente tuvo éxito.
      expect(societyRequestCount, 2);
    });

    // -----------------------------------------------------------------------------
    // SIL-14 — Fallo de una sociedad no contamina el índice cacheado
    // -----------------------------------------------------------------------------
    //
    // Se cargan dos sociedades en el mismo índice.
    //
    // 1. SL021 falla al consultar su sociedad.
    // 2. SL022 se consulta después y funciona.
    //
    // El segundo resolve debe poder utilizar el mismo índice cacheado. Así
    // comprobamos explícitamente que un fallo en una sociedad no invalida ni
    // contamina el índice ya cargado.
    //

    test('SIL-14: society failure does not contaminate cached index', () async {
      var indexRequestCount = 0;
      var societyRequestCount = 0;

      final client = MockClient((request) async {
        final uri = request.url;

        if (uri.toString().startsWith(_indexUrlBase)) {
          indexRequestCount++;

          if (uri.queryParameters['page'] == '0') {
            return http.Response(
              _indexPage(
                    registrationNumber: 21,
                    name: 'Test SIL 21',
                    nif: 'A12345678',
                  ) +
                  _indexPage(
                    registrationNumber: 22,
                    name: 'Test SIL 22',
                    nif: 'B87654321',
                  ),
              200,
            );
          }

          return http.Response(_emptyIndexPage(), 200);
        }

        if (uri.toString() ==
            '$_societyUrlBase'
                'A12345678') {
          societyRequestCount++;
          return http.Response('Service unavailable', 503);
        }

        if (uri.toString() ==
            '$_societyUrlBase'
                'B87654321') {
          societyRequestCount++;

          return http.Response(_societyPage(isin: 'ES0000000010'), 200);
        }

        fail('Unexpected request: $uri');
      });

      final provider = CnmvSilProvider(client: client);

      // Primera sociedad: falla.
      final firstResult = await provider.resolve(
        ticker: 'SL021.MC',
        fundName: 'Test SIL 21',
      );

      expect(firstResult, isNull);

      // Segunda sociedad: debe poder resolverse utilizando el mismo índice.
      final secondResult = await provider.resolve(
        ticker: 'SL022.MC',
        fundName: 'Test SIL 22',
      );

      expect(secondResult, isNotNull);
      expect(secondResult!.isin, 'ES0000000010');
      expect(secondResult.source, 'CNMV/SIL');
      expect(secondResult.officialName, 'Test SIL 22');
      expect(secondResult.cnmvRegistration, 22);
      expect(secondResult.cnmvNif, 'B87654321');

      // El índice se descargó una sola vez: página 0 + página vacía.
      expect(indexRequestCount, 2);

      // Una consulta para SL021 y otra para SL022.
      expect(societyRequestCount, 2);
    });
  });
}
