import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00LF1050001';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf105_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundCostPeriod createPeriod(String uid) {
    return FundCostPeriod(
      uid: uid,
      concept: FundCostConcept.performance,
      ratePercent: 8.5,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
      description: uid,
    );
  }

  FundCostCharge createCharge({
    required String uid,
    required String periodUid,
    double amount = 12.50,
    DateTime? date,
  }) {
    final chargeDate = date ?? DateTime(2026, 10, 20);

    return FundCostCharge(
      uid: uid,
      concept: FundCostConcept.performance,
      date: chargeDate,
      amount: amount,
      description: uid,
      performancePeriodUid: periodUid,
      settledThrough: chargeDate.subtract(const Duration(days: 1)),
    );
  }

  FundData createFund({
    String symbol = 'LF105',
    String name = 'Fondo LF-105',
    double lastValue = 100,
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) {
    return FundData(
      isin: isin,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [
        PricePoint(DateTime(2026, 10, 19), 95),
        PricePoint(DateTime(2026, 10, 20), lastValue),
      ],
      costPeriods: periods,
      costCharges: charges,
    );
  }

  Future<void> saveInitialFund() async {
    final firstPeriod = createPeriod('lf105-initial-period');

    await DatabaseService.saveFund(
      createFund(
        symbol: 'INITIAL',
        name: 'Fondo inicial LF-105',
        lastValue: 100,
        periods: [firstPeriod],
        charges: [
          createCharge(
            uid: 'lf105-initial-charge',
            periodUid: firstPeriod.uid,
            amount: 10,
          ),
        ],
      ),
    );
  }

  Future<void> expectCosts({
    required List<String> periodUids,
    required List<String> chargeUids,
    required Map<String, String?> references,
    required Map<String, double> amounts,
  }) async {
    final restored = await DatabaseService.getFund(isin);

    expect(restored, isNotNull);

    expect(
      restored!.costPeriods.map((item) => item.uid).toSet(),
      periodUids.toSet(),
    );
    expect(restored.costPeriods, hasLength(periodUids.length));

    expect(
      restored.costCharges.map((item) => item.uid).toSet(),
      chargeUids.toSet(),
    );
    expect(restored.costCharges, hasLength(chargeUids.length));

    for (final charge in restored.costCharges) {
      expect(
        charge.performancePeriodUid,
        references[charge.uid],
        reason: 'Referencia incorrecta para ${charge.uid}',
      );
      expect(
        charge.amount,
        amounts[charge.uid],
        reason: 'Importe incorrecto para ${charge.uid}',
      );
    }
  }

  test(
    'LF-105.1: la actualización sustituye los costes sin duplicarlos',
    () async {
      await saveInitialFund();

      final newPeriod1 = FundCostPeriod(
        uid: 'lf105-updated-period-1',
        concept: FundCostConcept.performance,
        ratePercent: 8.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
        validTo: DateTime(2026, 6, 30),
        description: 'Primer periodo actualizado',
      );

      final newPeriod2 = FundCostPeriod(
        uid: 'lf105-updated-period-2',
        concept: FundCostConcept.performance,
        ratePercent: 9.0,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 7, 1),
        validTo: DateTime(2026, 12, 31),
        description: 'Segundo periodo actualizado',
      );

      await DatabaseService.saveFund(
        createFund(
          symbol: 'UPDATED',
          name: 'Fondo actualizado LF-105',
          lastValue: 110,
          periods: [newPeriod1, newPeriod2],
          charges: [
            createCharge(
              uid: 'lf105-updated-charge-1',
              periodUid: newPeriod1.uid,
              amount: 15,
              date: DateTime(2026, 6, 15),
            ),
            createCharge(
              uid: 'lf105-updated-charge-2',
              periodUid: newPeriod2.uid,
              amount: 20,
              date: DateTime(2026, 10, 20),
            ),
          ],
        ),
      );

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, 'UPDATED');
      expect(restored.name, 'Fondo actualizado LF-105');
      expect(restored.lastValue, 110);

      await expectCosts(
        periodUids: ['lf105-updated-period-1', 'lf105-updated-period-2'],
        chargeUids: ['lf105-updated-charge-1', 'lf105-updated-charge-2'],
        references: {
          'lf105-updated-charge-1': 'lf105-updated-period-1',
          'lf105-updated-charge-2': 'lf105-updated-period-2',
        },
        amounts: {'lf105-updated-charge-1': 15, 'lf105-updated-charge-2': 20},
      );
    },
  );

  test(
    'LF-105.2: una colección vacía elimina todos los costes persistidos',
    () async {
      await saveInitialFund();

      await DatabaseService.saveFund(
        createFund(
          symbol: 'NO-COSTS',
          name: 'Fondo sin costes LF-105',
          lastValue: 101,
          periods: [],
          charges: [],
        ),
      );

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, 'NO-COSTS');
      expect(restored.costPeriods, isEmpty);
      expect(restored.costCharges, isEmpty);

      // Volver a cargar no debe recuperar los costes antiguos.
      final reloaded = await DatabaseService.getFund(isin);

      expect(reloaded, isNotNull);
      expect(reloaded!.costPeriods, isEmpty);
      expect(reloaded.costCharges, isEmpty);
    },
  );

  test(
    'LF-105.3: guardar dos veces la misma actualización es idempotente',
    () async {
      await saveInitialFund();

      final updatedPeriod = createPeriod('lf105-idempotent-period');
      final updatedCharge = createCharge(
        uid: 'lf105-idempotent-charge',
        periodUid: updatedPeriod.uid,
        amount: 18.75,
      );

      final updatedFund = createFund(
        symbol: 'IDEMPOTENT',
        name: 'Fondo idempotente LF-105',
        lastValue: 120,
        periods: [updatedPeriod],
        charges: [updatedCharge],
      );

      await DatabaseService.saveFund(updatedFund);
      await DatabaseService.saveFund(updatedFund);

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, 'IDEMPOTENT');
      expect(restored.lastValue, 120);

      await expectCosts(
        periodUids: ['lf105-idempotent-period'],
        chargeUids: ['lf105-idempotent-charge'],
        references: {'lf105-idempotent-charge': 'lf105-idempotent-period'},
        amounts: {'lf105-idempotent-charge': 18.75},
      );
    },
  );

  test(
    'LF-105.4: una actualización inválida conserva la última versión válida',
    () async {
      await saveInitialFund();

      final validPeriod = createPeriod('lf105-valid-period');
      final validFund = createFund(
        symbol: 'LAST-VALID',
        name: 'Última versión válida LF-105',
        lastValue: 115,
        periods: [validPeriod],
        charges: [
          createCharge(
            uid: 'lf105-valid-charge',
            periodUid: validPeriod.uid,
            amount: 22.50,
          ),
        ],
      );

      await DatabaseService.saveFund(validFund);

      final invalidPeriod = createPeriod('lf105-invalid-period');
      final invalidFund = createFund(
        symbol: 'INVALID',
        name: 'Actualización inválida LF-105',
        lastValue: 999,
        periods: [invalidPeriod],
        charges: [
          createCharge(
            uid: 'lf105-invalid-charge',
            periodUid: 'lf105-missing-period',
            amount: 50,
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final restored = await DatabaseService.getFund(isin);

      expect(restored, isNotNull);
      expect(restored!.symbol, 'LAST-VALID');
      expect(restored.name, 'Última versión válida LF-105');
      expect(restored.lastValue, 115);

      await expectCosts(
        periodUids: ['lf105-valid-period'],
        chargeUids: ['lf105-valid-charge'],
        references: {'lf105-valid-charge': 'lf105-valid-period'},
        amounts: {'lf105-valid-charge': 22.50},
      );
    },
  );
}
