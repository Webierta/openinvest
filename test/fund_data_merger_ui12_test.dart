import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-12: idempotencia de la fusión', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required String symbol,
      required DateTime date,
      required double lastValue,
      required List<PricePoint> history,
      List<FundOperation> operations = const [],
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
        operations: operations,
        costPeriods: costPeriods,
        costCharges: costCharges,
        source: source,
        valuationSource: valuationSource,
      );
    }

    FundCostPeriod period({required String uid, required double ratePercent}) {
      return FundCostPeriod(
        uid: uid,
        concept: FundCostConcept.ter,
        ratePercent: ratePercent,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: day20,
      );
    }

    FundCostCharge charge({required String uid, required double amount}) {
      return FundCostCharge(
        uid: uid,
        concept: FundCostConcept.ter,
        date: day20,
        amount: amount,
        description: 'Cargo $uid',
      );
    }

    test('LF-UI-12.1: repetir la fusión no duplica periodos ni cargos', () {
      final existing = fund(
        symbol: 'EXISTING',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        costPeriods: [period(uid: 'period-a', ratePercent: 0.20)],
        costCharges: [charge(uid: 'charge-a', amount: 2.0)],
      );

      final incoming = fund(
        symbol: 'INCOMING',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121), PricePoint(day22, 122)],
        costPeriods: [period(uid: 'period-b', ratePercent: 0.30)],
        costCharges: [charge(uid: 'charge-b', amount: 3.0)],
      );

      final once = FundDataMerger.merge(existing, incoming);
      final twice = FundDataMerger.merge(once, incoming);

      expect(once.costPeriods.map((e) => e.uid).toSet(), {
        'period-a',
        'period-b',
      });
      expect(twice.costPeriods, hasLength(2));
      expect(twice.costPeriods.map((e) => e.uid).toSet(), {
        'period-a',
        'period-b',
      });

      expect(once.costCharges, hasLength(2));
      expect(twice.costCharges, hasLength(2));
      expect(twice.costCharges.map((e) => e.uid).toSet(), {
        'charge-a',
        'charge-b',
      });

      expect(
        twice.history
            .map((e) => e.date.toIso8601String().substring(0, 10))
            .toSet(),
        hasLength(twice.history.length),
      );
    });

    test('LF-UI-12.2: repetir la fusión conserva los ganadores por UID', () {
      final existing = fund(
        symbol: 'EXISTING',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day21, 121)],
        costPeriods: [period(uid: 'period-shared', ratePercent: 0.20)],
        costCharges: [charge(uid: 'charge-shared', amount: 2.0)],
      );

      final incoming = fund(
        symbol: 'INCOMING',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day22, 122)],
        costPeriods: [period(uid: 'period-shared', ratePercent: 0.25)],
        costCharges: [charge(uid: 'charge-shared', amount: 2.5)],
      );

      final once = FundDataMerger.merge(existing, incoming);
      final twice = FundDataMerger.merge(once, incoming);

      expect(
        once.costPeriods
            .singleWhere((e) => e.uid == 'period-shared')
            .ratePercent,
        0.25,
      );
      expect(
        twice.costPeriods
            .singleWhere((e) => e.uid == 'period-shared')
            .ratePercent,
        0.25,
      );

      expect(
        once.costCharges.singleWhere((e) => e.uid == 'charge-shared').amount,
        2.5,
      );
      expect(
        twice.costCharges.singleWhere((e) => e.uid == 'charge-shared').amount,
        2.5,
      );
    });

    test('LF-UI-12.3: las fusiones repetidas conservan operaciones, fuentes e historial', () {
      final existing = fund(
        symbol: 'EXISTING',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120), PricePoint(day21, 121)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      final incoming = fund(
        symbol: 'INCOMING',
        date: day22,
        lastValue: 122,
        history: [PricePoint(day21, 121.5), PricePoint(day22, 122)],
        source: FundSource.queFondos,
        valuationSource: FundSource.queFondos,
      );

      final once = FundDataMerger.merge(existing, incoming);
      final twice = FundDataMerger.merge(once, incoming);

      expect(twice.source, FundSource.cnmv);
      expect(twice.valuationSource, FundSource.queFondos);
      expect(twice.lastValue, 122);
      expect(twice.date, day22);

      expect(twice.history, hasLength(3));
      expect(
        twice.history
            .map((e) => e.date.toIso8601String().substring(0, 10))
            .toSet(),
        hasLength(3),
      );
      expect(twice.history.singleWhere((e) => e.date == day21).price, 121.5);

      expect(twice.operations, hasLength(0));
    });
  });
}
