import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('Historical transfer counterparts', () {
    test('LF-143.11.1: resuelve la contraparte de un traspaso '
        'desde ambos extremos', () {
      const transferUid = 'transfer-lf143-11-1';

      final transferOut = HistoricalOperation(
        uid: 'operation-out',
        investmentUid: 'investment-source',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferOut,
        amount: 1234.56,
        transferUid: transferUid,
      );

      final transferIn = HistoricalOperation(
        uid: 'operation-in',
        investmentUid: 'investment-destination',
        date: DateTime(2025, 3, 17),
        type: HistoricalOperationType.transferIn,
        amount: 1234.56,
        transferUid: transferUid,
      );

      final counterparts =
          FinancialCalculator.resolveHistoricalTransferCounterparts(
            [transferOut, transferIn],
            {'investment-source', 'investment-destination'},
          );

      expect(counterparts, hasLength(2));
      expect(counterparts[transferOut.uid], same(transferIn));
      expect(counterparts[transferIn.uid], same(transferOut));
    });
  });
}
