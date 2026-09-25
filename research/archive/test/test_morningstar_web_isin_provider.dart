/*
import 'package:http/http.dart' as http;

import '../lib/services/morningstar_web_isin_provider.dart';

Future<void> main() async {
  print('=' * 80);
  print('TEST DE MorningstarWebIsinProvider');
  print('=' * 80);

  final tests = [
    {
      'name': 'JPMorgan Korea (acc) - USD',
      'id': '0P00000ZJQ',
      'isin': 'HK0000055712',
    },
    {
      'name': 'Premier Miton European Opportunities Fund B Accumulation',
      'id': '0P00017461',
      'isin': 'GB00BZ2K2M84',
    },
    {
      'name': 'PIMCO GIS Income Fund E Class USD Income',
      'id': '0P0000X83M',
      'isin': 'IE00B8K7V925',
    },
  ];

  final client = http.Client();
  final provider = MorningstarWebIsinProvider(client: client, debug: true);

  var passed = 0;
  try {
    for (final test in tests) {
      print('');
      print('-' * 80);
      print('TEST: ${test['name']}');
      print('Performance ID: ${test['id']}');
      print('ISIN esperado: ${test['isin']}');
      print('-' * 80);

      final isin = await provider.resolve(
        ticker: test['id']!,
        fundName: test['name']!,
        yahooSymbol: test['id']!,
        yahooName: test['name']!,
      );

      print('ISIN obtenido: ${isin ?? '(null)'}');
      if (isin == test['isin']) {
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
  print('RESULTADO FINAL: $passed / ${tests.length}');
  print('=' * 80);
}
*/
