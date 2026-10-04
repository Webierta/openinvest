import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.3 — ECB/IFS lookup inverso por ISIN', () {
    test('ES0160483014 devuelve su identidad ECB/IFS', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolveByIsin('ES0160483014');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0160483014');
      expect(result.source, 'ECB/IFS');
      expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
    });

    test('un ISIN no presente en ECB/IFS devuelve null', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolveByIsin('ES0000000000');

      expect(result, isNull);
    });
  });
}
