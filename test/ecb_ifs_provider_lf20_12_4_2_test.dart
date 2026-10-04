import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LF-20.12.4.2 — ECB/IFS exact-name resolution', () {
    test('MAPFRE PRIVATE EQUITY I FCR resolves to ES0160483014', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolve(
        ticker: '',
        fundName: 'MAPFRE PRIVATE EQUITY I FCR',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0160483014');
      expect(result.source, 'ECB/IFS');
      expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
    });
  });
}
