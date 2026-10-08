import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  FundData fundData({
    FundSource? source,
    FundSource? valuationSource,
    String isin = 'ES0000000001',
    String symbol = 'TEST',
    String name = 'Test Fund',
    double lastValue = 100.0,
    String currency = 'EUR',
    DateTime? date,
    List<PricePoint> history = const [],
  }) {
    final effectiveDate = date ?? DateTime(2026, 1, 1);

    return FundData(
      isin: isin,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      currency: currency,
      date: effectiveDate,
      history: history,
      source: source,
      valuationSource: valuationSource,
    );
  }

  group('LF-20.13 — identidad vs valoración', () {
    test('CNMV + Yahoo conserva ambas procedencias', () {
      final fund = fundData(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.yahoo);
    });

    test('LOCAL + Yahoo', () {
      final fund = fundData(
        source: FundSource.local,
        valuationSource: FundSource.yahoo,
      );

      expect(fund.source, FundSource.local);
      expect(fund.valuationSource, FundSource.yahoo);
    });

    test('CNMV + QueFondos', () {
      final fund = fundData(
        source: FundSource.cnmv,
        valuationSource: FundSource.queFondos,
      );

      expect(fund.source, FundSource.cnmv);
      expect(fund.valuationSource, FundSource.queFondos);
    });

    test('ECB + Financial Times', () {
      final fund = fundData(
        source: FundSource.ecb,
        valuationSource: FundSource.financialTimes,
      );

      expect(fund.source, FundSource.ecb);
      expect(fund.valuationSource, FundSource.financialTimes);
    });

    test('FT puede ser identidad y valoración', () {
      final fund = fundData(
        source: FundSource.financialTimes,
        valuationSource: FundSource.financialTimes,
      );

      expect(fund.source, FundSource.financialTimes);
      expect(fund.valuationSource, FundSource.financialTimes);
    });

    test('ECB sin valoración mantiene valuationSource null', () {
      final fund = fundData(source: FundSource.ecb);

      expect(fund.source, FundSource.ecb);
      expect(fund.valuationSource, isNull);
    });
  });
  test('FundData conserva source y valuationSource en JSON', () {
    final original = fundData(
      source: FundSource.cnmv,
      valuationSource: FundSource.financialTimes,
    );

    final restored = FundData.fromJson(original.toJson());

    expect(restored.source, FundSource.cnmv);
    expect(restored.valuationSource, FundSource.financialTimes);
  });
}
