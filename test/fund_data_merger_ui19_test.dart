import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  group('LF-UI-19: Protección de FundData.operations', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    //final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundOperation> operations = const [],
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        operations: operations,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
    }

    FundOperation operation({
      int? id,
      String isin = 'ES0123456789',
      required DateTime date,
      required OperationType type,
      required double units,
      required double price,
      required double amount,
    }) {
      return FundOperation(
        id: id,
        isin: isin,
        date: date,
        type: type,
        units: units,
        price: price,
        amount: amount,
      );
    }

    test(
      'LF-UI-19.1: el constructor aísla las operaciones de la lista recibida',
      () {
        final opA = operation(
          id: 1,
          date: day20,
          type: OperationType.buy,
          units: 2,
          price: 10,
          amount: 20,
        );

        final opB = operation(
          id: 2,
          date: day21,
          type: OperationType.sell,
          units: 1,
          price: 12,
          amount: 12,
        );

        final inputOperations = <FundOperation>[opA];

        final fundData = fund(
          symbol: 'A',
          date: day20,
          lastValue: 120,
          history: [PricePoint(day20, 120)],
          operations: inputOperations,
        );

        expect(fundData.operations, hasLength(1));
        expect(identical(fundData.operations.single, opA), isTrue);

        // Modificar la lista original no debe modificar el fondo.
        inputOperations.clear();

        expect(fundData.operations, hasLength(1));
        expect(identical(fundData.operations.single, opA), isTrue);

        inputOperations.add(opB);

        expect(fundData.operations, hasLength(1));
        expect(fundData.operations.any((op) => identical(op, opB)), isFalse);

        // Los datos de los objetos de operación permanecen intactos.
        expect(opA.id, 1);
        expect(opA.units, 2);
        expect(opA.price, 10);
        expect(opA.amount, 20);
      },
    );
  });
}
