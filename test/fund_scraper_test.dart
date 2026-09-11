import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  const basePayload = {
    'chart': {
      'result': [
        {
          'meta': {
            'regularMarketPrice': 12.5,
            'currency': 'EUR',
            'regularMarketTime': 1788307200,
          },
          'timestamp': [1788220800, 1788307200],
          'indicators': {
            'quote': [
              {
                'close': [12.0, 12.5],
              },
            ],
          },
        },
      ],
    },
  };

  ScrapeResult parse(Map<String, dynamic> payload) =>
      FundScraper.parseChartPayload(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        payload: jsonDecode(jsonEncode(payload)) as Map<String, dynamic>,
      );

  test('rechaza historiales con longitudes diferentes', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': [1788220800],
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
    expect(result.error?.message, contains('incompleto'));
  });

  test('rechaza timestamps o precios con tipos inválidos', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': ['invalid', 1788307200],
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
    expect(result.error?.message, contains('inválidos'));
  });

  test('acepta un precio actual cuando no hay historial', () {
    final payload = {
      'chart': {
        'result': [
          {
            'meta': {'regularMarketPrice': 12.5, 'currency': 'EUR'},
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.error, isNull);
    expect(result.data?.lastValue, 12.5);
    expect(result.data?.history, isNotEmpty);
  });

  test('ignora cierres nulos manteniendo el historial válido', () {
    final payload = {
      ...basePayload,
      'chart': {
        'result': [
          {
            ...((basePayload['chart'] as Map)['result'] as List).first as Map,
            'timestamp': [1788220800, 1788307200],
            'indicators': {
              'quote': [
                {
                  'close': [null, 12.5],
                },
              ],
            },
          },
        ],
      },
    };

    final result = parse(payload);

    expect(result.error, isNull);
    expect(result.data?.history, hasLength(1));
    expect(result.data?.history.single.price, 12.5);
  });

  test('rechaza una respuesta sin estructura chart', () {
    final result = parse({'unexpected': true});

    expect(result.data, isNull);
    expect(result.error?.type, AppErrorType.data);
  });
}
