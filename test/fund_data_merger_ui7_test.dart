import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-7: integridad de valoración al importar', () {
    final day20 = DateTime(2026, 10, 20);
    final day21 = DateTime(2026, 10, 21);
    final day22 = DateTime(2026, 10, 22);

    FundData fund({
      required double lastValue,
      required DateTime date,
      required List<PricePoint> history,
    }) {
      return FundData(
        isin: 'ES0123456789',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        currency: 'EUR',
        lastValue: lastValue,
        date: date,
        history: history,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
    }

    test('LF-UI-7.1: una importación antigua no degrada la valoración', () {
      final existing = fund(
        lastValue: 120,
        date: day22,
        history: [
          PricePoint(day20, 100),
          PricePoint(day21, 110),
          PricePoint(day22, 120),
        ],
      );

      final incoming = fund(
        lastValue: 105,
        date: day21,
        history: [PricePoint(day20, 100), PricePoint(day21, 105)],
      );

      final merged = FundDataMerger.merge(existing, incoming);

      expect(merged.date, day22);
      expect(merged.lastValue, 120);
    });

    test(
      'LF-UI-7.2: conserva el historial de ambas versiones sin duplicar fechas',
      () {
        final existing = fund(
          lastValue: 120,
          date: day22,
          history: [PricePoint(day20, 100), PricePoint(day22, 120)],
        );

        final incoming = fund(
          lastValue: 110,
          date: day21,
          history: [PricePoint(day20, 99), PricePoint(day21, 110)],
        );

        final merged = FundDataMerger.merge(existing, incoming);

        final pointsByDate = <String, List<PricePoint>>{};
        for (final point in merged.history) {
          final key =
              '${point.date.year}-${point.date.month}-${point.date.day}';
          pointsByDate.putIfAbsent(key, () => []).add(point);
        }

        expect(merged.history.map((point) => point.date).toList(), [
          day20,
          day21,
          day22,
        ]);
        expect(
          pointsByDate.values.every((points) => points.length == 1),
          isTrue,
        );
        expect(
          merged.history.firstWhere((point) => point.date == day21).price,
          110,
        );
      },
    );

    test(
      'LF-UI-7.3: una valoración más reciente amplía el historial previo',
      () {
        final existing = fund(
          lastValue: 100,
          date: day20,
          history: [PricePoint(day20, 100)],
        );

        final incoming = fund(
          lastValue: 120,
          date: day22,
          history: [PricePoint(day21, 110), PricePoint(day22, 120)],
        );

        final merged = FundDataMerger.merge(existing, incoming);

        expect(merged.date, day22);
        expect(merged.lastValue, 120);
        expect(merged.history.map((point) => point.date).toList(), [
          day20,
          day21,
          day22,
        ]);
        expect(merged.history.map((point) => point.price).toList(), [
          100,
          110,
          120,
        ]);
      },
    );
  });
}
