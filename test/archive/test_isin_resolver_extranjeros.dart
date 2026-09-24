/*
//import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
//import 'package:test/test.dart';
import 'package:investing/services/isin_resolver.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = HttpClient(context: context);
    client.badCertificateCallback = (
      X509Certificate cert,
      String host,
      int port,
    ) => true;
    return client;
  }
}

class _Case {
  final String description;
  final String ticker;
  final String fundName;
  final String expectedIsin;

  const _Case({
    required this.description,
    required this.ticker,
    required this.fundName,
    required this.expectedIsin,
  });
}

void main() {
  //TestWidgetsFlutterBinding.ensureInitialized();
  TestWidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = _RealHttpOverrides();

  const cases = <_Case>[
    _Case(
      description: 'PIMCO GIS Income Fund E Class USD Income',
      ticker: '0P0000X83M',
      fundName: 'PIMCO GIS Income Fund E Class USD Income',
      expectedIsin: 'IE00B8K7V925',
    ),
    _Case(
      description: 'JPMorgan Korea (acc) - USD',
      ticker: '0P00000ZJQ',
      fundName: 'JPMorgan Korea (acc) - USD',
      expectedIsin: 'HK0000055712',
    ),
    _Case(
      description: 'Premier Miton European Opportunities Fund B Accumulation',
      ticker: '0P00017461',
      fundName: 'Premier Miton European Opportunities Fund B Accumulation',
      expectedIsin: 'GB00BZ2K2M84',
    ),
  ];

  test('IsinResolver - fondos extranjeros sin ISIN embebido y no presentes en la BD local', () async {
    final resolver = IsinResolver();

    var passed = 0;

    try {
      for (final testCase in cases) {
        print('\n${'-' * 70}');
        print('TEST: ${testCase.description}');
        print('Ticker:   ${testCase.ticker}');
        print('Esperado: ${testCase.expectedIsin}');
        print('');

        final result = await resolver.resolve(
          ticker: testCase.ticker,
          fundName: testCase.fundName,
        );

        print('Obtenido: ${result?.isin}');
        print('Fuente:   ${result?.source}');
        print('Nombre:   ${result?.officialName}');

        expect(
          result?.isin,
          testCase.expectedIsin,
          reason:
              'No se resolvió correctamente ${testCase.ticker}: '
              'obtenido=${result?.isin}, fuente=${result?.source}',
        );

        passed++;
        print('RESULTADO: CORRECTO');
      }
    } finally {
      resolver.dispose();
    }

    print('\n${'=' * 70}');
    print('RESULTADO FINAL: $passed / ${cases.length}');
    print('${'=' * 70}');
  });
}
*/
