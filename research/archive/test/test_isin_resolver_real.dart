import 'package:investing/services/isin_resolver.dart';
import 'package:flutter/widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print('');
  print('=' * 100);
  print('TEST REAL - IsinResolver - 15 CASOS EXTRANJEROS');
  print('=' * 100);
  print('Red real: SI');
  print('Yahoo / Morningstar / catálogo local: SI');
  print('');

  final cases = <Map<String, String>>[
    {
      'ticker': '0P0000X83M',
      'name': 'PIMCO GIS Income Fund E USD Inc',
      'isin': 'IE00B8K7V925',
    },
    {
      'ticker': '0P00000FB4.F',
      'name': 'Carmignac Patrimoine A EUR Acc',
      'isin': 'FR0010135103',
    },
    {
      'ticker': '0P00006DAB.F',
      'name': 'Fidelity Iberia A-Acc-EUR',
      'isin': 'LU0261948904',
    },
    {
      'ticker': '0P00000Z1Y.F',
      'name': 'JPM Europe Strategic Val C acc EUR',
      'isin': 'LU0129445192',
    },
    {
      'ticker': 'LU1599125231',
      'name': 'JPM Europe Strategic Value A Acc USD Hedged',
      'isin': 'LU1599125231',
    },
    {
      'ticker': 'LU3284971820',
      'name': 'JPM Europe Strategic Value A Acc SGD Hedged',
      'isin': 'LU3284971820',
    },
    {
      'ticker': '0P00000C1U',
      'name': 'JPM Europe Strategic Value A Dist GBP',
      'isin': 'LU0119092640',
    },
    {
      'ticker': 'LU0997586606',
      'name': 'Fidelity European Growth A Acc USD Hedged',
      'isin': 'LU0997586606',
    },
    {
      'ticker': 'LU0550127509',
      'name': 'Fidelity European Growth A Dist SGD',
      'isin': 'LU0550127509',
    },
    {
      'ticker': 'LU0324710721',
      'name': 'Fidelity European Growth C Dist EUR',
      'isin': 'LU0324710721',
    },
    {
      'ticker': 'LU1642889510',
      'name': 'Fidelity European Growth I Acc EUR',
      'isin': 'LU1642889510',
    },
    {
      'ticker': 'LU1235258925',
      'name': 'Fidelity European Growth SR Acc EUR',
      'isin': 'LU1235258925',
    },
    {
      'ticker': 'LU1235259576',
      'name': 'Fidelity European Growth SR Acc SGD',
      'isin': 'LU1235259576',
    },
    {
      'ticker': 'LU2533724949',
      'name': 'BlackRock Next Generation Technology A10 USD',
      'isin': 'LU2533724949',
    },
    {
      'ticker': 'FR0011269596',
      'name': 'Carmignac Patrimoine A CHF Acc Hdg',
      'isin': 'FR0011269596',
    },
  ];

  final resolver = IsinResolver();

  var ok = 0;
  var failed = 0;

  for (var i = 0; i < cases.length; i++) {
    final testCase = cases[i];

    final ticker = testCase['ticker']!;
    final name = testCase['name']!;
    final expectedIsin = testCase['isin']!;

    print('');
    print('-' * 100);
    print('CASO ${i + 1}/${cases.length}');
    print('-' * 100);
    print('Nombre esperado : $name');
    print('Ticker          : $ticker');
    print('ISIN esperado   : $expectedIsin');

    try {
      final result = await resolver.resolve(ticker: ticker, fundName: name);

      if (result == null) {
        print('RESULTADO       : ❌ NULL');
        print('Fuente          : -');
        print('ISIN obtenido   : -');
        failed++;
        continue;
      }

      print(
        'RESULTADO       : ${result.isin == expectedIsin ? '✅ OK' : '❌ ERROR'}',
      );
      print('ISIN obtenido   : ${result.isin}');
      print('Fuente          : ${result.source}');
      print('Nombre oficial  : ${result.officialName ?? '-'}');

      if (result.isin == expectedIsin) {
        ok++;
      } else {
        failed++;
        print('');
        print('*** ISIN INCORRECTO ***');
        print('Esperado : $expectedIsin');
        print('Obtenido : ${result.isin}');
      }
    } catch (e, stackTrace) {
      print('RESULTADO       : ❌ EXCEPCIÓN');
      print('Error           : $e');
      print('Stack trace     : $stackTrace');
      failed++;
    }
  }

  resolver.dispose();

  print('');
  print('');
  print('=' * 100);
  print('RESUMEN');
  print('=' * 100);
  print('Casos totales   : ${cases.length}');
  print('Correctos       : $ok');
  print('Fallidos        : $failed');
  print('=' * 100);

  if (failed == 0) {
    print('');
    print('🎉 TODOS LOS CASOS HAN RESUELTO EL ISIN CORRECTAMENTE.');
    print('');
  } else {
    print('');
    print('⚠️ HAY CASOS PENDIENTES DE REVISAR.');
    print('');
  }
}
