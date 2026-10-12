import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FundData conserva source y valuationSource al serializarse', () {
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
      source: FundSource.local,
      valuationSource: FundSource.yahoo,
    );

    final serialized = original.toJson();
    final restored = FundData.fromJson(serialized);

    expect(restored.source, FundSource.local);
    expect(restored.valuationSource, FundSource.yahoo);
    expect(restored.isin, original.isin);
    expect(restored.lastValue, original.lastValue);
    expect(restored.history, hasLength(original.history.length));
  });

  test('FundData conserva fuentes diferentes al serializarse', () {
    final original = FundData(
      isin: 'ES0000000011',
      symbol: '',
      name: 'Fondo ECB',
      lastValue: 0.0,
      currency: 'EUR',
      date: DateTime(2026, 10, 2),
      history: const [],
      source: FundSource.ecb,
    );

    final restored = FundData.fromJson(original.toJson());

    expect(restored.source, FundSource.ecb);
    expect(restored.valuationSource, isNull);
  });

  test('FundData admite registros antiguos sin campos de fuente', () {
    final legacyJson = <String, dynamic>{
      'isin': 'ES0000000010',
      'symbol': 'TEST.MC',
      'name': 'Fondo histórico',
      'lastValue': 105.0,
      'currency': 'EUR',
      'date': '2026-10-02T00:00:00.000',
      'history': [
        {'date': '2026-10-02T00:00:00.000', 'price': 105.0},
      ],
      'operations': [],
    };
    final restored = FundData.fromJson(legacyJson);
    expect(restored.isin, 'ES0000000010');
    expect(restored.lastValue, 105.0);
    expect(restored.source, isNull);
    expect(restored.valuationSource, isNull);
  });
  test('FundData no interpreta fuentes desconocidas como Yahoo', () {
    final json = <String, dynamic>{
      'isin': 'ES0000000011',
      'symbol': 'TEST.MC',
      'name': 'Fondo con fuente desconocida',
      'lastValue': 100.0,
      'currency': 'EUR',
      'date': '2026-10-02T00:00:00.000',
      'history': [],
      'source': 'unknownProvider',
      'valuationSource': 'unknownProvider',
    };
    final restored = FundData.fromJson(json);
    expect(restored.source, isNull);
    expect(restored.valuationSource, isNull);
  });
}
