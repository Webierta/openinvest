/*
import 'package:http/http.dart' as http;

import '../lib/services/ft_isin_provider.dart';

class TestCase {
  final String ticker;
  final String name;
  final String expectedIsin;

  const TestCase(this.ticker, this.name, this.expectedIsin);
}

Future<void> main() async {
  print('=' * 80);
  print('TEST MULTIPLE DE FtIsinProvider - FT MARKETS');
  print('=' * 80);

  const cases = <TestCase>[
    TestCase(
      '0P00017461',
      'Premier Miton European Opportunities Fund B Accumulation',
      'GB00BZ2K2M84',
    ),
    TestCase(
      '0P0000X83M',
      'PIMCO GIS Income Fund E Class USD Income',
      'IE00B8K7V925',
    ),
    TestCase('0P00000ZJQ', 'JPMorgan Korea (acc) - USD', 'HK0000055712'),
  ];

  final client = http.Client();
  final provider = FtIsinProvider(client: client, pageSize: 200, debug: true);

  var passed = 0;

  try {
    for (final test in cases) {
      print('');
      print('-' * 80);
      print('TEST: ${test.name}');
      print('Ticker:       ${test.ticker}');
      print('ISIN esperado: ${test.expectedIsin}');
      print('-' * 80);

      String? isin;
      try {
        isin = await provider.resolve(
          ticker: test.ticker,
          fundName: test.name,
          yahooSymbol: test.ticker,
          yahooName: test.name,
        );
      } catch (e, st) {
        print('ERROR: $e');
        print(st);
      }

      print('ISIN obtenido: ${isin ?? '(null)'}');

      if (isin == test.expectedIsin) {
        print('✓ TEST CORRECTO');
        passed++;
      } else {
        print('✗ TEST FALLIDO');
      }
    }
  } finally {
    provider.dispose();
  }

  print('');
  print('=' * 80);
  print('RESULTADO FINAL: $passed / ${cases.length}');
  print('=' * 80);
}
*/
