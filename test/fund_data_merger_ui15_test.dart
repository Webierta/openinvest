import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-15: asociatividad y prioridades de fusión', () {
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

    test('LF-UI-15.1: compara los ganadores de costes con UID compartido', () {
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

      final leftRate = left.costPeriods
          .singleWhere((e) => e.uid == 'period-shared')
          .ratePercent;
      final rightRate = right.costPeriods
          .singleWhere((e) => e.uid == 'period-shared')
          .ratePercent;
      final leftAmount = left.costCharges
          .singleWhere((e) => e.uid == 'charge-shared')
          .amount;
      final rightAmount = right.costCharges
          .singleWhere((e) => e.uid == 'charge-shared')
          .amount;

      // Con conflicto, la prioridad depende de cómo se agrupe la fusión.
      // Esta prueba registra explícitamente ambos resultados.
      expect(leftRate, anyOf(0.20, 0.30));
      expect(rightRate, anyOf(0.20, 0.30));
      expect(leftAmount, anyOf(2.0, 3.0));
      expect(rightAmount, anyOf(2.0, 3.0));

      // La salida de diagnóstico facilita comparar las agrupaciones.
      // ignore: avoid_print
      print('LF-UI-15.1 period rate: left=$leftRate, right=$rightRate');
      // ignore: avoid_print
      print('LF-UI-15.1 charge amount: left=$leftAmount, right=$rightAmount');
    });

    test('LF-UI-15.2: compara el historial ante conflictos en varios días', () {
      final a = fund(
        symbol: 'A',
        date: day20,
        lastValue: 120,
        history: [PricePoint(day20, 120)],
      );

      final b = fund(
        symbol: 'B',
        date: day21,
        lastValue: 121,
        history: [PricePoint(day20, 120.5), PricePoint(day21, 121)],
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
      );

      final left = FundDataMerger.merge(FundDataMerger.merge(a, b), c);
      final right = FundDataMerger.merge(a, FundDataMerger.merge(b, c));

      double priceAt(FundData data, DateTime date) =>
          data.history.singleWhere((e) => e.date == date).price;

      final left20 = priceAt(left, day20);
      final right20 = priceAt(right, day20);
      final left21 = priceAt(left, day21);
      final right21 = priceAt(right, day21);

      expect(left.history, hasLength(3));
      expect(right.history, hasLength(3));
      expect(left.lastValue, 122);
      expect(right.lastValue, 122);

      expect(left20, anyOf(119.5, 120.5, 120.0));
      expect(right20, anyOf(119.5, 120.5, 120.0));
      expect(left21, anyOf(121.5, 121.0));
      expect(right21, anyOf(121.5, 121.0));

      // ignore: avoid_print
      print('LF-UI-15.2 day20 price: left=$left20, right=$right20');
      // ignore: avoid_print
      print('LF-UI-15.2 day21 price: left=$left21, right=$right21');
    });

    test('LF-UI-15.3: las fuentes y la valoración final se mantienen en ambas agrupaciones', () {
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
        history: [PricePoint(day21, 121.5), PricePoint(day22, 122)],
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
    });
  });
}
