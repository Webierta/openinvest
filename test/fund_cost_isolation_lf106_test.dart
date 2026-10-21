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

  const isinA = 'IE00LF1060011';
  const isinB = 'IE00LF1060029';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf106_test_');

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
    required DateTime date,
    double amount = 12.50,
  }) {
    return FundCostCharge(
      uid: uid,
      concept: FundCostConcept.performance,
      date: date,
      amount: amount,
      description: uid,
      performancePeriodUid: periodUid,
      settledThrough: date.subtract(const Duration(days: 1)),
    );
  }

  FundData createFund({
    required String isin,
    required String symbol,
    required String name,
    required double lastValue,
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

  FundData fundA({
    String symbol = 'FUND-A',
    String name = 'Fondo A',
    double lastValue = 100,
    List<FundCostPeriod>? periods,
    List<FundCostCharge>? charges,
  }) {
    final defaultPeriod = createPeriod('lf106-a-period');
    return createFund(
      isin: isinA,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      periods: periods ?? [defaultPeriod],
      charges:
          charges ??
          [
            createCharge(
              uid: 'lf106-a-charge',
              periodUid: defaultPeriod.uid,
              date: DateTime(2026, 6, 15),
              amount: 10,
            ),
          ],
    );
  }

  FundData fundB({
    String symbol = 'FUND-B',
    String name = 'Fondo B',
    double lastValue = 200,
    List<FundCostPeriod>? periods,
    List<FundCostCharge>? charges,
  }) {
    final defaultPeriod = createPeriod('lf106-b-period');
    return createFund(
      isin: isinB,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      periods: periods ?? [defaultPeriod],
      charges:
          charges ??
          [
            createCharge(
              uid: 'lf106-b-charge',
              periodUid: defaultPeriod.uid,
              date: DateTime(2026, 10, 20),
              amount: 20,
            ),
          ],
    );
  }

  Future<void> expectFundCosts({
    required String isin,
    required List<String> periodUids,
    required List<String> chargeUids,
    required Map<String, String?> references,
    required Map<String, double> amounts,
  }) async {
    final restored = await DatabaseService.getFund(isin);

    expect(restored, isNotNull);
    expect(restored!.costPeriods, hasLength(periodUids.length));
    expect(
      restored.costPeriods.map((period) => period.uid).toSet(),
      periodUids.toSet(),
    );

    expect(restored.costCharges, hasLength(chargeUids.length));
    expect(
      restored.costCharges.map((charge) => charge.uid).toSet(),
      chargeUids.toSet(),
    );

    for (final charge in restored.costCharges) {
      expect(charge.performancePeriodUid, references[charge.uid]);
      expect(charge.amount, amounts[charge.uid]);
    }
  }

  Future<void> saveBothFunds() async {
    await DatabaseService.saveFund(fundA());
    await DatabaseService.saveFund(fundB());
  }

  test('LF-106.1: dos fondos mantienen sus costes independientes', () async {
    await saveBothFunds();

    await expectFundCosts(
      isin: isinA,
      periodUids: ['lf106-a-period'],
      chargeUids: ['lf106-a-charge'],
      references: {'lf106-a-charge': 'lf106-a-period'},
      amounts: {'lf106-a-charge': 10},
    );

    await expectFundCosts(
      isin: isinB,
      periodUids: ['lf106-b-period'],
      chargeUids: ['lf106-b-charge'],
      references: {'lf106-b-charge': 'lf106-b-period'},
      amounts: {'lf106-b-charge': 20},
    );
  });

  test('LF-106.2: actualizar los costes de A no altera los de B', () async {
    await saveBothFunds();

    final updatedPeriod = createPeriod('lf106-a-updated-period');

    await DatabaseService.saveFund(
      fundA(
        symbol: 'FUND-A-UPDATED',
        name: 'Fondo A actualizado',
        lastValue: 110,
        periods: [updatedPeriod],
        charges: [
          createCharge(
            uid: 'lf106-a-updated-charge',
            periodUid: updatedPeriod.uid,
            date: DateTime(2026, 10, 20),
            amount: 35,
          ),
        ],
      ),
    );

    final restoredA = await DatabaseService.getFund(isinA);
    expect(restoredA, isNotNull);
    expect(restoredA!.symbol, 'FUND-A-UPDATED');
    expect(restoredA.lastValue, 110);

    await expectFundCosts(
      isin: isinA,
      periodUids: ['lf106-a-updated-period'],
      chargeUids: ['lf106-a-updated-charge'],
      references: {'lf106-a-updated-charge': 'lf106-a-updated-period'},
      amounts: {'lf106-a-updated-charge': 35},
    );

    final restoredB = await DatabaseService.getFund(isinB);
    expect(restoredB, isNotNull);
    expect(restoredB!.symbol, 'FUND-B');
    expect(restoredB.lastValue, 200);

    await expectFundCosts(
      isin: isinB,
      periodUids: ['lf106-b-period'],
      chargeUids: ['lf106-b-charge'],
      references: {'lf106-b-charge': 'lf106-b-period'},
      amounts: {'lf106-b-charge': 20},
    );
  });

  test('LF-106.3: eliminar los costes de A no elimina los de B', () async {
    await saveBothFunds();

    await DatabaseService.saveFund(
      fundA(
        symbol: 'FUND-A-EMPTY',
        name: 'Fondo A sin costes',
        lastValue: 101,
        periods: [],
        charges: [],
      ),
    );

    final restoredA = await DatabaseService.getFund(isinA);
    expect(restoredA, isNotNull);
    expect(restoredA!.costPeriods, isEmpty);
    expect(restoredA.costCharges, isEmpty);

    await expectFundCosts(
      isin: isinB,
      periodUids: ['lf106-b-period'],
      chargeUids: ['lf106-b-charge'],
      references: {'lf106-b-charge': 'lf106-b-period'},
      amounts: {'lf106-b-charge': 20},
    );
  });

  test('LF-106.4: una actualización inválida de A conserva los datos de ambos fondos', () async {
    await saveBothFunds();

    final invalidPeriod = createPeriod('lf106-a-invalid-period');

    final invalidFund = fundA(
      symbol: 'FUND-A-INVALID',
      name: 'Fondo A inválido',
      lastValue: 999,
      periods: [invalidPeriod],
      charges: [
        createCharge(
          uid: 'lf106-a-invalid-charge',
          periodUid: 'lf106-period-missing',
          date: DateTime(2026, 10, 20),
          amount: 99,
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final restoredA = await DatabaseService.getFund(isinA);
    expect(restoredA, isNotNull);
    expect(restoredA!.symbol, 'FUND-A');
    expect(restoredA.name, 'Fondo A');
    expect(restoredA.lastValue, 100);

    await expectFundCosts(
      isin: isinA,
      periodUids: ['lf106-a-period'],
      chargeUids: ['lf106-a-charge'],
      references: {'lf106-a-charge': 'lf106-a-period'},
      amounts: {'lf106-a-charge': 10},
    );

    final restoredB = await DatabaseService.getFund(isinB);
    expect(restoredB, isNotNull);
    expect(restoredB!.symbol, 'FUND-B');
    expect(restoredB.name, 'Fondo B');
    expect(restoredB.lastValue, 200);

    await expectFundCosts(
      isin: isinB,
      periodUids: ['lf106-b-period'],
      chargeUids: ['lf106-b-charge'],
      references: {'lf106-b-charge': 'lf106-b-period'},
      amounts: {'lf106-b-charge': 20},
    );
  });
}
