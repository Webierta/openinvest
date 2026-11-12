import 'package:flutter_test/flutter_test.dart';
import 'package:investing/utils/historical_transfer_uid.dart';

void main() {
  group('HistoricalTransferUid', () {
    test(
      'LF-143.10.1: genera un UID legible con nombre normalizado y fecha',
      () {
        // La implementación se incorporará después de comprobar que falla.
        final uid = HistoricalTransferUid.generate(
          investmentName: 'Fonditel Renta Fija',
          date: DateTime(2010, 4, 14),
          uniqueSuffix: 'k8m2',
        );

        expect(uid, 'transfer_fonditel_renta_fija_20100414_k8m2');
      },
    );
  });
}
