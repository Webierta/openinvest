import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/utils/fund_data_merger.dart';

void main() {
  group('LF-UI-6: fusión de fuentes del fondo', () {
    final date = DateTime(2026, 10, 21);

    FundData createFund({
      FundSource? source,
      FundSource? valuationSource,
      double lastValue = 100,
      DateTime? valuationDate,
    }) {
      final effectiveDate = valuationDate ?? date;

      return FundData(
        isin: 'ES0123456789',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        currency: 'EUR',
        lastValue: lastValue,
        date: effectiveDate,
        history: [PricePoint(effectiveDate, lastValue)],
        source: source,
        valuationSource: valuationSource,
      );
    }

    test('LF-UI-6.1: la fuente Yahoo entrante no reemplaza el origen CNMV', () {
      final existing = createFund(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
      final incoming = createFund(
        source: FundSource.yahoo,
        valuationSource: FundSource.yahoo,
      );

      final merged = FundDataMerger.merge(existing, incoming);

      expect(merged.source, FundSource.cnmv);
      expect(merged.valuationSource, FundSource.yahoo);
    });

    test(
      'LF-UI-6.2: actualiza la fuente de valoración sin cambiar el origen',
      () {
        final existing = createFund(
          source: FundSource.cnmv,
          valuationSource: FundSource.yahoo,
          lastValue: 100,
          valuationDate: DateTime(2026, 10, 20),
        );
        final incoming = createFund(
          source: FundSource.yahoo,
          valuationSource: FundSource.financialTimes,
          lastValue: 105,
          valuationDate: date,
        );

        final merged = FundDataMerger.merge(existing, incoming);

        expect(merged.source, FundSource.cnmv);
        expect(merged.valuationSource, FundSource.financialTimes);
        expect(merged.lastValue, 105);
        expect(merged.date, date);
      },
    );

    test('LF-UI-6.3: conserva ambas fuentes si las entrantes son nulas', () {
      final existing = createFund(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
      final incoming = createFund();

      final merged = FundDataMerger.merge(existing, incoming);

      expect(merged.source, FundSource.cnmv);
      expect(merged.valuationSource, FundSource.yahoo);
    });
  });
}
