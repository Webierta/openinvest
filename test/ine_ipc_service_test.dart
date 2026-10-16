import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:investing/services/ine_ipc_service.dart';

void main() {
  group('IpcDataPoint.fromJson', () {
    test('uses year and month when Fecha is null', () {
      final point = IpcDataPoint.fromJson({
        'Anyo': 2024,
        'FK_Periodo': 4,
        'Valor': 3.2,
        'Fecha': null,
      });

      expect(point.year, 2024);
      expect(point.month, 4);
      expect(point.value, 3.2);
      expect(point.date, DateTime(2024, 4));
    });
    test('convierte los campos y usa el día 1 si Fecha es null', () {
      final point = IpcDataPoint.fromJson({
        'Anyo': 2024,
        'FK_Periodo': 3,
        'Valor': 115.25,
        'Fecha': null,
      });

      expect(point.year, 2024);
      expect(point.month, 3);
      expect(point.value, 115.25);
      expect(point.date, DateTime(2024, 3));
    });

    test('convierte Fecha desde milisegundos Unix', () {
      final timestamp = DateTime.utc(2024, 3, 15).millisecondsSinceEpoch;

      final point = IpcDataPoint.fromJson({
        'Anyo': 2024,
        'FK_Periodo': 3,
        'Valor': 115,
        'Fecha': timestamp,
      });

      expect(point.date, DateTime.fromMillisecondsSinceEpoch(timestamp));
    });
  });

  group('IneIpcService.getPartIpcHistory', () {
    test('selecciona la serie indicada y ordena los datos de más reciente '
        'a más antiguo', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'COD': 'OTRA_SERIE',
              'Data': [
                {'Anyo': 2030, 'FK_Periodo': 1, 'Valor': 999, 'Fecha': null},
              ],
            },
            {
              'COD': 'IPC290751',
              'Data': [
                {'Anyo': 2023, 'FK_Periodo': 1, 'Valor': 110.0, 'Fecha': null},
                {'Anyo': 2024, 'FK_Periodo': 2, 'Valor': 115.5, 'Fecha': null},
              ],
            },
          ]),
          200,
        );
      });
      final service = IneIpcService(client: client);

      final result = await service.getPartIpcHistory(
        'https://example.test/ipc',
        'IPC290751',
      );

      expect(result, hasLength(2));
      expect(result.map((point) => point.year).toList(), [2024, 2023]);
      expect(result.first.month, 2);
      expect(result.first.value, 115.5);

      client.close();
    });

    test('devuelve una lista vacía cuando no encuentra el código', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'COD': 'COD_DISTINTO', 'Data': []},
          ]),
          200,
        );
      });
      final service = IneIpcService(client: client);

      final result = await service.getPartIpcHistory(
        'https://example.test/ipc',
        'IPC290751',
      );

      expect(result, isEmpty);
      client.close();
    });

    test('devuelve una lista vacía si la serie no contiene Data', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'COD': 'IPC290751'},
          ]),
          200,
        );
      });
      final service = IneIpcService(client: client);

      final result = await service.getPartIpcHistory(
        'https://example.test/ipc',
        'IPC290751',
      );

      expect(result, isEmpty);
      client.close();
    });

    test(
      'devuelve una lista vacía si la API responde con error HTTP',
      () async {
        final client = MockClient((request) async {
          return http.Response('Error del servidor', 500);
        });
        final service = IneIpcService(client: client);

        final result = await service.getPartIpcHistory(
          'https://example.test/ipc',
          'IPC290751',
        );

        expect(result, isEmpty);
        client.close();
      },
    );

    test('devuelve una lista vacía si falla la petición', () async {
      final client = MockClient((request) async {
        throw Exception('Error de red');
      });
      final service = IneIpcService(client: client);
      final result = await service.getPartIpcHistory(
        'https://example.test/ipc',
        'IPC290751',
      );

      expect(result, isEmpty);
      client.close();
    });
  });

  group('IneIpcService.getAllIpcHistory', () {
    test('consulta las dos tablas y concatena sus resultados', () async {
      final requestedUris = <Uri>[];

      final client = MockClient((request) async {
        requestedUris.add(request.url);

        final isPost2002 = request.url.path.endsWith('/76125');
        final code = isPost2002 ? 'IPC290751' : 'IPC2401';
        final year = isPost2002 ? 2024 : 2001;

        return http.Response(
          jsonEncode([
            {
              'COD': code,
              'Data': [
                {'Anyo': year, 'FK_Periodo': 1, 'Valor': 100.0, 'Fecha': null},
              ],
            },
          ]),
          200,
        );
      });
      final service = IneIpcService(client: client);

      final result = await service.getAllIpcHistory();

      expect(requestedUris, hasLength(2));
      expect(requestedUris[0].path, endsWith('/76125'));
      expect(requestedUris[1].path, endsWith('/268'));
      expect(result.map((point) => point.year).toList(), [2024, 2001]);

      client.close();
    });

    test(
      'devuelve los datos disponibles aunque una de las tablas falle',
      () async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/76125')) {
            return http.Response(
              jsonEncode([
                {
                  'COD': 'IPC290751',
                  'Data': [
                    {
                      'Anyo': 2024,
                      'FK_Periodo': 1,
                      'Valor': 100.0,
                      'Fecha': null,
                    },
                  ],
                },
              ]),
              200,
            );
          }

          return http.Response('Error', 500);
        });
        final service = IneIpcService(client: client);

        final result = await service.getAllIpcHistory();

        expect(result, hasLength(1));
        expect(result.single.year, 2024);

        client.close();
      },
    );
  });
}
