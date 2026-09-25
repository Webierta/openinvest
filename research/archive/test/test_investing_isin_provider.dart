/*
import '../lib/services/investing_isin_provider.dart';

Future<void> main() async {
  print('=' * 80);
  print('TEST DE InvestingIsinProvider');
  print('=' * 80);

  final provider = InvestingIsinProvider(debug: true);

  final tests = [
    {
      'name': 'JPMorgan Korea (acc) - USD',
      'performanceId': '0P00000ZJQ',
      'expected': 'HK0000055712',
    },
    {
      'name': 'Premier Miton European Opportunities Fund B Accumulation',
      'performanceId': '0P00017461',
      'expected': 'GB00BZ2K2M84',
    },
    {
      'name': 'PIMCO GIS Income Fund E Class USD Income',
      'performanceId': '0P0000X83M',
      'expected': 'IE00B8K7V925',
    },
  ];

  var passed = 0;

  for (final test in tests) {
    print('');
    print('-' * 80);
    print('TEST: ${test['name']}');
    print('Performance ID: ${test['performanceId']}');
    print('ISIN esperado: ${test['expected']}');
    print('-' * 80);

    final result = await provider.resolve(
      ticker: test['performanceId']!,
      fundName: test['name']!,
      yahooSymbol: test['performanceId']!,
      yahooName: test['name']!,
    );

    print('ISIN obtenido: ${result ?? '(null)'}');

    if (result == test['expected']) {
      print('✓ TEST CORRECTO');
      passed++;
    } else {
      print('✗ TEST FALLIDO');
    }
  }

  provider.dispose();

  print('');
  print('=' * 80);
  print('RESULTADO FINAL: $passed / ${tests.length}');
  print('=' * 80);
}
*/
