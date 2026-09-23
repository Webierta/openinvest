import 'package:http/http.dart' as http;

import '../lib/services/ft_isin_provider.dart';

Future<void> main() async {
  print('=' * 80);
  print('TEST DE FtIsinProvider');
  print('=' * 80);

  final client = http.Client();
  final provider = FtIsinProvider(client: client, pageSize: 200, debug: true);

  try {
    final isin = await provider.resolve(
      ticker: '0P00017461',
      fundName: 'Premier Miton European Opportunities Fund B Accumulation',
      yahooSymbol: '0P00017461',
      yahooName: 'Premier Miton European Opportunities Fund B Accumulation',
    );

    print('');
    print('ISIN obtenido: ${isin ?? '(null)'}');
    print('ISIN esperado: GB00BZ2K2M84');
    print(isin == 'GB00BZ2K2M84' ? '✓ TEST CORRECTO' : '✗ TEST FALLIDO');
  } finally {
    provider.dispose();
  }
}
