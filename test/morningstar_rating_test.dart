import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:investing/services/morningstar_rating.dart';

class _FakeHttpClient extends http.BaseClient {
  final int statusCode;
  final String body;

  _FakeHttpClient({required this.statusCode, required this.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(body.codeUnits),
      statusCode,
      request: request,
    );
  }
}

void main() {
  group('MorningstarRating', () {
    test('devuelve 5 cuando encuentra cinco estrellas', () async {
      final client = _FakeHttpClient(
        statusCode: 200,
        body: '''
          <html>
            <body>
              <span data-mod-stars-highlighted="true">
                <i></i>
                <i></i>
                <i></i>
                <i></i>
                <i></i>
              </span>
            </body>
          </html>
        ''',
      );

      final service = MorningstarRating('IE00B8K7V925', client: client);

      expect(await service.getRating(), 5);
    });

    test('devuelve 4 cuando encuentra cuatro estrellas', () async {
      final client = _FakeHttpClient(
        statusCode: 200,
        body: '''
          <span data-mod-stars-highlighted="true">
            <i></i>
            <i></i>
            <i></i>
            <i></i>
          </span>
        ''',
      );

      final service = MorningstarRating('IE00B8K7V925', client: client);

      expect(await service.getRating(), 4);
    });

    test('devuelve 0 cuando no encuentra rating', () async {
      final client = _FakeHttpClient(
        statusCode: 200,
        body: '''
          <html>
            <body>
              <span>Sin rating</span>
            </body>
          </html>
        ''',
      );

      final service = MorningstarRating('IE00B8K7V925', client: client);

      expect(await service.getRating(), 0);
    });

    test('devuelve 0 con ISIN vacío', () async {
      final client = _FakeHttpClient(statusCode: 200, body: '<html></html>');

      final service = MorningstarRating('', client: client);

      expect(await service.getRating(), 0);
    });

    test('devuelve 0 cuando HTTP no devuelve 200', () async {
      final client = _FakeHttpClient(statusCode: 404, body: '<html></html>');

      final service = MorningstarRating('IE00B8K7V925', client: client);

      expect(await service.getRating(), 0);
    });

    test(
      'ignora un candidato inválido y encuentra el siguiente válido',
      () async {
        final client = _FakeHttpClient(
          statusCode: 200,
          body: '''
          <html>
            <body>
              <span data-mod-stars-highlighted="true">
                <i></i>
                <i></i>
                <i></i>
                <i></i>
                <i></i>
                <i></i>
              </span>

              <span data-mod-stars-highlighted="true">
                <i></i>
                <i></i>
                <i></i>
                <i></i>
              </span>
            </body>
          </html>
        ''',
        );

        final service = MorningstarRating('IE00B8K7V925', client: client);

        expect(await service.getRating(), 4);
      },
    );
  });
}
