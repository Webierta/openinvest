import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-20.12.4.1 — ECB/IFS direct ISIN resolution', () {
    test('ES0160483014 is resolved when supplied as ticker', () async {
      final resolver = IsinResolver(providers: [EcbIfsProvider()]);

      try {
        final result = await resolver.resolve(
          ticker: 'ES0160483014',
          fundName: '',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0160483014');
        expect(result.source, 'ECB/IFS');
      } finally {
        resolver.dispose();
      }
    });
  });
}
