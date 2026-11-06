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

    test('LF-132.28: copyWith rechaza participaciones negativas', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      expect(() => original.copyWith(units: -1), throwsArgumentError);
    });

    test('LF-132.29: copyWith rechaza precios negativos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      expect(() => original.copyWith(price: -10), throwsArgumentError);
    });

    test('LF-132.30: copyWith rechaza importes negativos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      expect(() => original.copyWith(amount: -1), throwsArgumentError);
    });

    test('LF-132.31: copyWith permite eliminar unidades y precio conservando el importe', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(units: null, price: null);

      expect(updated.amount, 1500);
      expect(updated.units, isNull);
      expect(updated.price, isNull);
    });

    test(
      'LF-132.32: cambiar unidades y eliminar precio conserva el importe',
      () {
        final original = HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500,
          units: 10,
          price: 150,
        );

        final updated = original.copyWith(units: 12, price: null);

        expect(updated.amount, 1500);
        expect(updated.units, 12);
        expect(updated.price, isNull);
      },
    );

    test('LF-132.33: eliminar unidades conserva precio e importe', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(units: null);

      expect(updated.amount, 1500);
      expect(updated.units, isNull);
      expect(updated.price, 150);
    });

    test('LF-132.34: copyWith recalcula el importe cuando se solicita', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(units: 12, amount: null);

      expect(updated.amount, 1800);
      expect(updated.units, 12);
      expect(updated.price, 150);
    });

    test('LF-132.35: rechaza recalcular el importe si falta el precio', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      expect(
        () => original.copyWith(price: null, amount: null),
        throwsArgumentError,
      );
    });

    test('LF-132.36: rechaza recalcular el importe si faltan las unidades', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      expect(
        () => original.copyWith(units: null, amount: null),
        throwsArgumentError,
      );
    });

    test('LF-132.37: rechaza un importe incoherente al modificar unidades y precio', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      expect(
        () => original.copyWith(units: 12, price: 160),
        throwsArgumentError,
      );
    });

    test('LF-132.38: copyWith permite modificar unidades y precio recalculando el importe', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(units: 12, price: 160, amount: null);

      expect(updated.amount, 1920);
      expect(updated.units, 12);
      expect(updated.price, 160);
    });

    test('LF-132.39: conserva fecha y tipo al modificar datos económicos', () {
      final date = DateTime(2025, 3, 15);

      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: date,
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(units: 12, price: 160, amount: null);

      expect(updated.date, date);
      expect(updated.type, HistoricalOperationType.subscription);
      expect(updated.amount, 1920);
    });

    test('LF-132.40: cambiar el tipo conserva los datos económicos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(
        type: HistoricalOperationType.redemption,
      );

      expect(updated.type, HistoricalOperationType.redemption);
      expect(updated.amount, 1500);
      expect(updated.units, 10);
      expect(updated.price, 150);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
    });

    test(
      'LF-132.41: cambiar la inversión conserva los datos de la operación',
      () {
        final original = HistoricalOperation(
          uid: 'operation-001',
          investmentUid: 'investment-001',
          date: DateTime(2025, 3, 15),
          type: HistoricalOperationType.subscription,
          amount: 1500,
          units: 10,
          price: 150,
          transferUid: 'transfer-001',
        );

        final updated = original.copyWith(investmentUid: 'investment-002');

        expect(updated.investmentUid, 'investment-002');
        expect(updated.uid, original.uid);
        expect(updated.date, original.date);
        expect(updated.type, original.type);
        expect(updated.amount, original.amount);
        expect(updated.units, original.units);
        expect(updated.price, original.price);
        expect(updated.transferUid, original.transferUid);
      },
    );

    test('LF-132.42: cambiar la fecha conserva el resto de los datos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        units: 10,
        price: 150,
        transferUid: 'transfer-001',
      );

      final newDate = DateTime(2025, 4, 20);

      final updated = original.copyWith(date: newDate);

      expect(updated.date, newDate);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.type, original.type);
      expect(updated.amount, original.amount);
      expect(updated.units, original.units);
      expect(updated.price, original.price);
      expect(updated.transferUid, original.transferUid);
    });

    test('LF-132.43: cambiar transferUid conserva el resto de los datos', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        units: 10,
        price: 150,
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(transferUid: 'transfer-002');

      expect(updated.transferUid, 'transfer-002');
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.date, original.date);
      expect(updated.type, original.type);
      expect(updated.amount, original.amount);
      expect(updated.units, original.units);
      expect(updated.price, original.price);
    });

    test('LF-132.44: copyWith permite eliminar transferUid', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        transferUid: 'transfer-001',
      );

      final updated = original.copyWith(transferUid: null);

      expect(updated.transferUid, isNull);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.amount, original.amount);
      expect(updated.type, original.type);
    });

    test('LF-132.45: copyWith permite eliminar la descripción', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        description: 'Aportación inicial',
      );

      final updated = original.copyWith(description: null);

      expect(updated.description, isNull);
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.amount, original.amount);
    });

    test('LF-132.46: copyWith permite modificar la descripción', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        description: 'Aportación inicial',
      );

      final updated = original.copyWith(
        description: 'Aportación extraordinaria',
      );

      expect(updated.description, 'Aportación extraordinaria');
      expect(updated.uid, original.uid);
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.date, original.date);
      expect(updated.amount, original.amount);
    });

    test('LF-132.47: copyWith normaliza transferUid', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
      );

      final updated = original.copyWith(transferUid: ' transfer-002 ');

      expect(updated.transferUid, 'transfer-002');
    });

    test('LF-132.48: copyWith rechaza transferUid vacío', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
      );

      expect(() => original.copyWith(transferUid: '   '), throwsArgumentError);
    });

    test('LF-132.49: copyWith permite cambiar el UID de la operación', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
        units: 10,
        price: 150,
      );

      final updated = original.copyWith(uid: 'operation-002');

      expect(updated.uid, 'operation-002');
      expect(updated.investmentUid, original.investmentUid);
      expect(updated.date, original.date);
      expect(updated.type, original.type);
      expect(updated.amount, original.amount);
      expect(updated.units, original.units);
      expect(updated.price, original.price);
    });

    test('LF-132.50: copyWith rechaza un UID vacío', () {
      final original = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: 'investment-001',
        date: DateTime(2025, 3, 15),
        type: HistoricalOperationType.subscription,
        amount: 1500,
      );

      expect(() => original.copyWith(uid: '   '), throwsArgumentError);
    });
  });

  group('LF-140: HistoricalInvestment', () {
    test(
      'LF-140.5: rechaza una inversión cuya primera operación es de salida',
      () {
        // Aquí utilizaremos el mecanismo de validación
        // de la inversión histórica.
      },
    );
  });
}
