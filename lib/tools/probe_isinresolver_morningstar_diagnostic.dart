import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:investing/services/isin_resolver.dart';

//import 'package:investing/services/isin_resolver.dart';

//import '../lib/services/isin_resolver_morningstar_lt.dart';

Future<void> main() async {
  const tests = <Map<String, String>>[
    {
      'ticker': '0P0000X83M',
      'name': 'PIMCO GIS Income Fund E USD Inc',
      'expected': 'IE00B8K7V925',
    },
    {
      'ticker': '0P00000FB4.F',
      'name': 'Carmignac Patrimoine A EUR Acc',
      'expected': 'FR0010135103',
    },
    {
      'ticker': '0P00006DAB.F',
      'name': 'Fidelity Iberia A-Acc-EUR',
      'expected': 'LU0261948904',
    },
    {
      'ticker': '0P00000Z1Y.F',
      'name': 'JPM Europe Strategic Val C acc EUR',
      'expected': 'LU0129445192',
    },
  ];

  print('=' * 90);
  print('DIAGNÓSTICO MÍNIMO - IsinResolver REAL');
  print('NO modifica ninguna lógica de producción');
  print('=' * 90);

  final client = http.Client();

  try {
    for (final test in tests) {
      print('\n' + '-' * 90);
      print('Ticker   : ${test['ticker']}');
      print('Nombre   : ${test['name']}');
      print('Esperado : ${test['expected']}');

      final provider = MorningstarLtForeignIsinProvider(client: client);

      // Ejecutamos exactamente el provider real.
      final result = await provider.resolve(
        ticker: test['ticker']!,
        fundName: test['name']!,
        yahooSymbol: test['ticker']!,
        yahooName: test['name']!,
      );

      print('RESULTADO provider.resolve(): ${result ?? 'NULL'}');
      print('ESPERADO                 : ${test['expected']}');
      print(
        'RESULTADO FINAL          : '
        '${result == test['expected'] ? 'OK' : 'ERROR'}',
      );
    }
  } finally {
    client.close();
  }

  print('\n' + '=' * 90);
  print('FIN DEL DIAGNÓSTICO');
  print('=' * 90);
}
