import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('copyWith cambia source y conserva los demás metadatos', () {
    final checkedAt = DateTime(2026, 10, 1);
    final attemptAt = DateTime(2026, 10, 2);

    final period = FundCostPeriod(
      uid: 'period-1',
      concept: FundCostConcept.management,
      ratePercent: 1.25,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      description: 'Comisión de gestión',
    );

    final charge = FundCostCharge(
      uid: 'charge-1',
      concept: FundCostConcept.management,
      date: DateTime(2026, 10, 2),
      amount: 2.5,
      description: 'Coste de prueba',
    );

    final original = FundData(
      isin: 'ES0000000010',
      symbol: 'TEST.MC',
      name: 'Fondo de prueba',
      lastValue: 105.0,
      currency: 'EUR',
      date: DateTime(2026, 10, 2),
      history: [
        PricePoint(DateTime(2026, 10, 1), 100.0),
        PricePoint(DateTime(2026, 10, 2), 105.0),
      ],
      operations: [
        FundOperation(
          isin: 'ES0000000010',
          date: DateTime(2026, 9, 30),
          type: OperationType.buy,
          units: 2,
          price: 50,
          amount: 100,
        ),
      ],
      alertMin: 90,
      alertMax: 120,
      ter: 1.25,
      performanceFee: 10,
      costPeriods: [period],
      costCharges: [charge],
      morningstarRating: 4,
      morningstarCheckedAt: checkedAt,
      morningstarLastAttemptAt: attemptAt,
      source: FundSource.financialTimes,
      valuationSource: FundSource.financialTimes,
    );

    final copied = original.copyWith(source: FundSource.local);

    expect(copied.source, FundSource.local);
    expect(copied.valuationSource, FundSource.financialTimes);

    expect(copied.isin, original.isin);
    expect(copied.symbol, original.symbol);
    expect(copied.name, original.name);
    expect(copied.lastValue, original.lastValue);
    expect(copied.currency, original.currency);
    expect(copied.date, original.date);
    expect(copied.history, hasLength(original.history.length));
    expect(copied.operations, hasLength(1));

    expect(copied.alertMin, 90);
    expect(copied.alertMax, 120);
    expect(copied.ter, 1.25);
    expect(copied.performanceFee, 10);

    expect(copied.costPeriods, hasLength(1));
    expect(copied.costPeriods.single.uid, 'period-1');
    expect(copied.costCharges, hasLength(1));
    expect(copied.costCharges.single.uid, 'charge-1');

    expect(copied.morningstarRating, 4);
    expect(copied.morningstarCheckedAt, checkedAt);
    expect(copied.morningstarLastAttemptAt, attemptAt);
  });
}
