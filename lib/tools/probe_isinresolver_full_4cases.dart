import 'package:http/http.dart' as http;
import 'package:investing/services/isin_resolver.dart';

//import '../lib/services/isin_resolver_morningstar_lt.dart';

class _TestCase {
  final String ticker;
  final String name;
  final String expected;

  const _TestCase({
    required this.ticker,
    required this.name,
    required this.expected,
  });
}

Future<void> main() async {
  const tests = <_TestCase>[
    _TestCase(
      ticker: '0P0000X83M',
      name: 'PIMCO GIS Income Fund E USD Inc',
      expected: 'IE00B8K7V925',
    ),
    _TestCase(
      ticker: '0P00000FB4.F',
      name: 'Carmignac Patrimoine A EUR Acc',
      expected: 'FR0010135103',
    ),
    _TestCase(
      ticker: '0P00006DAB.F',
      name: 'Fidelity Iberia A-Acc-EUR',
      expected: 'LU0261948904',
    ),
    _TestCase(
      ticker: '0P00000Z1Y.F',
      name: 'JPM Europe Strategic Val C acc EUR',
      expected: 'LU0129445192',
    ),
  ];

  print('=' * 90);
  print('TEST INTEGRAL - IsinResolver REAL');
  print('Yahoo -> ranking -> Foreign providers -> Morningstar');
  print('NO modifica ninguna lógica de producción');
  print('=' * 90);

  final client = http.Client();
  final resolver = IsinResolver(client: client);

  var okCount = 0;

  try {
    for (final test in tests) {
      print('');
      print('-' * 90);
      print('Ticker   : ${test.ticker}');
      print('Nombre   : ${test.name}');
      print('Esperado : ${test.expected}');
      print('-' * 90);

      final result = await resolver.resolve(
        ticker: test.ticker,
        fundName: test.name,
      );

      final actual = result?.isin;
      final status = actual == test.expected ? 'OK' : 'FALLO';

      if (status == 'OK') {
        okCount++;
      }

      print('');
      print('RESULTADO IsinResolver.resolve(): ${actual ?? 'null'}');
      print('SOURCE                       : ${result?.source ?? 'null'}');
      print('NOMBRE OFICIAL               : ${result?.officialName ?? 'null'}');
      print('ESPERADO                     : ${test.expected}');
      print('RESULTADO FINAL              : $status');
    }
  } finally {
    resolver.dispose();
    client.close();
  }

  print('');
  print('=' * 90);
  print('RESUMEN');
  print('$okCount/${tests.length} casos correctos');
  print(
    okCount == tests.length
        ? 'RESULTADO GLOBAL: OK'
        : 'RESULTADO GLOBAL: HAY CASOS QUE REVISAR',
  );
  print('=' * 90);
}
