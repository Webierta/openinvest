import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  group('LF-20.11.4 — regresión FundSource en UI', () {
    test('todas las fuentes actuales de FundSource están disponibles', () {
      expect(
        FundSource.values,
        containsAll(<FundSource>[
          FundSource.cnmv,
          FundSource.local,
          FundSource.ecb,
          FundSource.morningstar,
          FundSource.yahoo,
        ]),
      );
    });

    test('ECB es una fuente distinta e independiente del catálogo local', () {
      expect(FundSource.ecb, isNot(FundSource.local));
      expect(FundSource.ecb, isNot(FundSource.cnmv));
      expect(FundSource.ecb, isNot(FundSource.morningstar));
      expect(FundSource.ecb, isNot(FundSource.yahoo));
    });
  });
}
