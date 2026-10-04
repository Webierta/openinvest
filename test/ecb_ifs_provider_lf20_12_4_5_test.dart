import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.5 — ECB/IFS resolución por ISIN', () {
    test('ES0160483014 devuelve la identidad ECB/IFS correcta', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolveByIsin('ES0160483014');

      expect(result, isNotNull);
      expect(result!.isin, 'ES0160483014');
      expect(result.source, 'ECB/IFS');
      expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
    });

    test(
      'la resolución por ISIN es insensible a espacios y mayúsculas',
      () async {
        final provider = EcbIfsProvider();

        final result = await provider.resolveByIsin('  es0160483014  ');

        expect(result, isNotNull);
        expect(result!.isin, 'ES0160483014');
        expect(result.source, 'ECB/IFS');
        expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
      },
    );

    test('un ISIN válido pero inexistente devuelve null', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolveByIsin('ES0000000000');

      expect(result, isNull);
    });

    test('un ISIN inválido devuelve null', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolveByIsin('NO-ES-UN-ISIN');

      expect(result, isNull);
    });
  });
}
