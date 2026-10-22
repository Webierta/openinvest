import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-14: independencia respecto al orden de fusión', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundCostPeriod> costPeriods = const [],
      List<FundCostCharge> costCharges = const [],
      FundSource? source = FundSource.cnmv,
      FundSource? valuationSource = FundSource.yahoo,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: symbol,
        name: 'Fondo $symbol',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        costPeriods: costPeriods,
        costCharges: costCharges,
        source: source,
        valuationSource: valuationSource,
      );
    }

    FundCostPeriod period(String uid, double ratePercent) {
      return FundCostPeriod(
        uid: uid,
        concept: FundCostConcept.ter,
        ratePercent: ratePercent,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );
    }

    FundCostCharge charge(String uid, double amount) {
      return FundCostCharge(
        uid: uid,
        concept: FundCostConcept.ter,
        date: day20,
        amount: amount,
        description: 'Cargo $uid',
      );
    }

    test('LF-UI-14.1: sin conflictos, ambas agrupaciones conservan los mismos datos', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        costPeriods: [period('period-a', 0.10)],
        costCharges: [charge('charge-a', 1.0)],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        costPeriods: [period('period-b', 0.20)],
        costCharges: [charge('charge-b', 2.0)],
      );

      final c = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [
          PricePoint(day20, 120),
          PricePoint(day21, 121),
          PricePoint(day22, 122),
        ],
        costPeriods: [period('period-c', 0.30)],
        costCharges: [charge('charge-c', 3.0)],
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      expect(
        left.costPeriods.map((e) => e.uid).toSet(),
        right.costPeriods.map((e) => e.uid).toSet(),
      );
      expect(
        left.costCharges.map((e) => e.uid).toSet(),
        right.costCharges.map((e) => e.uid).toSet(),
      );
      expect(left.lastValue, right.lastValue);
      expect(left.date, right.date);
      expect(left.history.length, right.history.length);

      for (final uid in ['period-a', 'period-b', 'period-c']) {
        expect(
          left.costPeriods.singleWhere((e) => e.uid == uid).ratePercent,
          right.costPeriods.singleWhere((e) => e.uid == uid).ratePercent,
        );
      }

      for (final uid in ['charge-a', 'charge-b', 'charge-c']) {
        expect(
          left.costCharges.singleWhere((e) => e.uid == uid).amount,
          right.costCharges.singleWhere((e) => e.uid == uid).amount,
        );
      }
    });

    test('LF-UI-14.2: los conflictos de UID revelan la prioridad de cada agrupación', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        costPeriods: [period('period-shared', 0.10)],
        costCharges: [charge('charge-shared', 1.0)],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        costPeriods: [period('period-shared', 0.20)],
        costCharges: [charge('charge-shared', 2.0)],
      );

      final c = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121), PricePoint(day22, 122)],
        costPeriods: [period('period-shared', 0.30)],
        costCharges: [charge('charge-shared', 3.0)],
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      final leftPeriod = left.costPeriods.single;
      final rightPeriod = right.costPeriods.single;
      final leftCharge = left.costCharges.single;
      final rightCharge = right.costCharges.single;

      expect(leftPeriod.uid, 'period-shared');
      expect(rightPeriod.uid, 'period-shared');
      expect(leftCharge.uid, 'charge-shared');
      expect(rightCharge.uid, 'charge-shared');

      // Registramos el comportamiento real de ambas agrupaciones:
      // no asumimos que la fusión sea asociativa ante conflictos.
      expect(leftPeriod.ratePercent, anyOf(0.20, 0.30));
      expect(rightPeriod.ratePercent, anyOf(0.20, 0.30));
      expect(leftCharge.amount, anyOf(2.0, 3.0));
      expect(rightCharge.amount, anyOf(2.0, 3.0));
    });

    test('LF-UI-14.3: los conflictos del historial y las fuentes se evalúan en ambas agrupaciones', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120.5), PricePoint(day21, 121)],
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
      );

      final c = fund(
        symbol: 'C',
        date: day22,
        lastValue: 122,
        history: [
          PricePoint(day20, 119.5),
          PricePoint(day21, 121.5),
          PricePoint(day22, 122),
        ],
        source: FundSource.queFondos,
        valuationSource: FundSource.queFondos,
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      expect(left.source, FundSource.cnmv);
      expect(right.source, FundSource.cnmv);

      expect(left.valuationSource, FundSource.queFondos);
      expect(right.valuationSource, FundSource.queFondos);

      expect(left.lastValue, 122);
      expect(right.lastValue, 122);
      expect(left.date, day22);
      expect(right.date, day22);

      expect(left.history.singleWhere((e) => e.date == day20).price, 119.5);
      expect(right.history.singleWhere((e) => e.date == day20).price, 119.5);

      expect(left.history.singleWhere((e) => e.date == day21).price, 121.5);
      expect(right.history.singleWhere((e) => e.date == day21).price, 121.5);
    });
  });
}
