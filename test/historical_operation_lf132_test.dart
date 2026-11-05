import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_operation.dart';

void main() {
  group('LF-132: HistoricalOperation', () {
    test('LF-132.1: construye una operación histórica válida', () {
      final operation = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500.0,
        units: 10.0,
        price: 150.0,
        description: 'Aportación inicial',
      );

      expect(operation.uid, 'operation-001');
      expect(operation.investmentUid, 'investment-001');
      expect(operation.date, DateTime(2025, 3, 15));
      expect(operation.type, HistoricalOperationType.subscription);
      expect(operation.amount, 1500.0);
      expect(operation.units, 10.0);
      expect(operation.price, 150.0);
      expect(operation.description, 'Aportación inicial');
      expect(operation.transferUid, isNull);
    });
    test('LF-132.2: rechaza un UID vacío', () {
      expect(
        () => HistoricalOperation(
          uid: '   ',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500.0,
        ),
        throwsArgumentError,
      );
    });
    test('LF-132.3: rechaza un investmentUid vacío', () {
      expect(
        () => HistoricalOperation(
          uid: 'operation-001',
          investmentUid: '   ',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500.0,
        ),
        throwsArgumentError,
      );
    });

    test('LF-132.4: rechaza importes negativos o no finitos', () {
      for (final amount in [
        -1.0,
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => HistoricalOperation(
            uid: 'operation-001',
            investmentUid: 'investment-001',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: amount,
          ),
          throwsArgumentError,
          reason: 'Debe rechazar el importe $amount',
        );
      }
    });

    test('LF-132.5: rechaza participaciones negativas o no finitas', () {
      for (final units in [
        -1.0,
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => HistoricalOperation(
            uid: 'operation-001',
            investmentUid: 'investment-001',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: 1500.0,
            units: units,
          ),
          throwsArgumentError,
          reason: 'Debe rechazar las participaciones $units',
        );
      }
    });

    test('LF-132.6: rechaza precios negativos o no finitos', () {
      for (final price in [
        -1.0,
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => HistoricalOperation(
            uid: 'operation-001',
            investmentUid: 'investment-001',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: 1500.0,
            price: price,
          ),
          throwsArgumentError,
          reason: 'Debe rechazar el precio $price',
        );
      }
    });
    test(
      'LF-132.7: calcula el importe a partir de participaciones y precio',
      () {
        final operation = HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          units: 10.0,
          price: 150.0,
        );

        expect(operation.amount, 1500.0);
      },
    );
    test('LF-132.8: rechaza la operación si falta el importe y algún dato de cálculo', () {
      expect(
        () => HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          units: 10.0,
        ),
        throwsArgumentError,
      );

      expect(
        () => HistoricalOperation(
          uid: 'operation-002',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          price: 150.0,
        ),
        throwsArgumentError,
      );
    });

    test('LF-132.9: rechaza un importe que no coincide con participaciones por precio', () {
      expect(
        () => HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1600.0,
          units: 10.0,
          price: 150.0,
        ),
        throwsArgumentError,
      );
    });

    test('LF-132.10: admite diferencias de redondeo de hasta un céntimo', () {
      final operation = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500.01,
        units: 10.0,
        price: 150.0,
      );

      expect(operation.amount, 1500.01);
    });

    test('LF-132.11: rechaza diferencias superiores a un céntimo', () {
      expect(
        () => HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500.02,
          units: 10.0,
          price: 150.0,
        ),
        throwsArgumentError,
      );
    });

    test('LF-132.12: copyWith conserva los campos no modificados', () {
      final original = HistoricalOperation(
        id: 7,
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500.0,
        units: 10.0,
        price: 150.0,
        description: 'Aportación inicial',
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(description: 'Aportación adicional');

      expect(updated.id, 7);
      expect(updated.uid, 'operation-001');
      expect(updated.investmentUid, 'investment-001');
      expect(updated.date, DateTime(2025, 3, 15));
      expect(updated.type, HistoricalOperationType.subscription);
      expect(updated.amount, 1500.0);
      expect(updated.units, 10.0);
      expect(updated.price, 150.0);
      expect(updated.description, 'Aportación adicional');
      expect(updated.transferUid, 'transfer-001');

      expect(original.description, 'Aportación inicial');
    });

    test('LF-132.13: copyWith permite eliminar los campos opcionales', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500.0,
        units: 10.0,
        price: 150.0,
        description: 'Aportación inicial',
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(
        units: null,
        price: null,
        description: null,
        transferUid: null,
      );

      expect(updated.units, isNull);
      expect(updated.price, isNull);
      expect(updated.description, isNull);
      expect(updated.transferUid, isNull);

      expect(updated.amount, 1500.0);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
    });

    test('LF-132.14: copyWith recalcula el importe al cambiar participaciones y precio', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        units: 10.0,
        price: 150.0,
      );

      final updated = original.copyWith(
        units: 12.0,
        price: 160.0,
        amount: null,
      );

      expect(updated.units, 12.0);
      expect(updated.price, 160.0);
      expect(updated.amount, 1920.0);
      expect(original.amount, 1500.0);
    });

    test(
      'LF-132.15: rechaza cambios de participaciones sin recalcular el importe',
      () {
        final original = HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          units: 10.0,
          price: 150.0,
        );

        expect(() => original.copyWith(units: 12.0), throwsArgumentError);

        expect(() => original.copyWith(price: 160.0), throwsArgumentError);
      },
    );
    test('LF-132.16: rechaza un transferUid vacío', () {
      expect(
        () => HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.transferOut,
          amount: 500.0,
          transferUid: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('LF-132.17: copyWith rechaza un transferUid vacío', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferOut,
        amount: 500.0,
        transferUid: 'transfer-001',
      );

      expect(() => original.copyWith(transferUid: '   '), throwsArgumentError);
    });

    test('LF-132.18: copyWith permite cambiar el tipo de operación', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferOut,
        amount: 500.0,
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(
        type: HistoricalOperationType.transferIn,
        investmentUid: 'investment-002',
      );

      expect(updated.type, HistoricalOperationType.transferIn);
      expect(updated.investmentUid, 'investment-002');
      expect(updated.amount, 500.0);
      expect(updated.uid, original.uid);
      expect(updated.date, original.date);
      expect(updated.transferUid, original.transferUid);
    });

    test(
      'LF-132.19: normaliza los identificadores eliminando espacios exteriores',
      () {
        final operation = HistoricalOperation(
          uid: ' operation-001 ',
          investmentUid: ' investment-001 ',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500.0,
          transferUid: ' transfer-001 ',
        );

        expect(operation.uid, 'operation-001');
        expect(operation.investmentUid, 'investment-001');
        expect(operation.transferUid, 'transfer-001');
      },
    );

    test('LF-132.20: copyWith normaliza los identificadores modificados', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500.0,
      );

      final updated = original.copyWith(
        uid: ' operation-002 ',
        investmentUid: ' investment-002 ',
        transferUid: ' transfer-002 ',
      );

      expect(updated.uid, 'operation-002');
      expect(updated.investmentUid, 'investment-002');
      expect(updated.transferUid, 'transfer-002');
    });

    test('LF-132.21: permite operaciones con importe cero', () {
      final direct = HistoricalOperation(
        uid: 'operation-zero-1',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 0,
      );

      final calculated = HistoricalOperation(
        uid: 'operation-zero-2',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        units: 0,
        price: 150,
      );

      expect(direct.amount, 0);
      expect(calculated.amount, 0);
    });

    test(
      'LF-132.22: permite importe positivo sin participaciones ni precio',
      () {
        final operation = HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500,
        );

        expect(operation.amount, 1500);
        expect(operation.units, isNull);
        expect(operation.price, isNull);
      },
    );

    test(
      'LF-132.23: rechaza identificadores vacíos después de normalizarlos',
      () {
        expect(
          () => HistoricalOperation(
            uid: '   ',
            investmentUid: 'investment-001',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: 1500,
          ),
          throwsArgumentError,
        );

        expect(
          () => HistoricalOperation(
            uid: 'operation-001',
            investmentUid: '   ',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: 1500,
          ),
          throwsArgumentError,
        );

        expect(
          () => HistoricalOperation(
            uid: 'operation-001',
            investmentUid: 'investment-001',
            date: DateTime(2025, 3, 15),
            type: HistoricalOperationType.subscription,
            amount: 1500,
            transferUid: '   ',
          ),
          throwsArgumentError,
        );
      },
    );

    test('LF-132.24: copyWith conserva los identificadores no modificados', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(
        description: 'Operación histórica actualizada',
      );

      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.transferUid, original.transferUid);
    });

    test('LF-132.25: copyWith permite cambiar el importe sin participaciones ni precio', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      final updated = original.copyWith(amount: 1750);

      expect(updated.amount, 1750);
      expect(updated.units, isNull);
      expect(updated.price, isNull);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
    });

    test('LF-132.26: copyWith recalcula el importe con valores enteros', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      final updated = original.copyWith(units: 10, price: 200, amount: null);

      expect(updated.amount, 2000);
      expect(updated.units, 10);
      expect(updated.price, 200);
    });

    test('LF-132.27: copyWith rechaza valores numéricos no finitos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      expect(() => original.copyWith(units: double.nan), throwsArgumentError);

      expect(
        () => original.copyWith(price: double.infinity),
        throwsArgumentError,
      );

      expect(() => original.copyWith(amount: double.nan), throwsArgumentError);
    });
  });
}
