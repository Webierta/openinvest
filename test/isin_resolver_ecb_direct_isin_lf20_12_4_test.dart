import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.1 — ECB/IFS direct ISIN resolution', () {
    test('un ISIN ECB válido suministrado como ticker se resuelve', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolve(
        ticker: 'ES0160483014',
        fundName: '',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0160483014');
      expect(result.source, 'ECB/IFS');
      expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
    });

    test(
      'la resolución directa por ticker tolera espacios y minúsculas',
      () async {
        final provider = EcbIfsProvider();

        final result = await provider.resolve(
          ticker: '  es0160483014  ',
          fundName: '',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0160483014');
        expect(result.source, 'ECB/IFS');
        expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
      },
    );

    test('un ISIN válido pero ausente de ECB/IFS devuelve null', () async {
      final provider = EcbIfsProvider();

      final result = await provider.resolve(
        ticker: 'ES0000000000',
        fundName: '',
      );

      expect(result, isNull);
    });

    test(
      'un ticker que no es ISIN mantiene la resolución por nombre',
      () async {
        final provider = EcbIfsProvider();

        final result = await provider.resolve(
          ticker: 'MAPFRE',
          fundName: 'MAPFRE PRIVATE EQUITY I FCR',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0160483014');
        expect(result.source, 'ECB/IFS');
        expect(result.officialName, 'MAPFRE PRIVATE EQUITY I FCR');
      },
    );
  });
}
