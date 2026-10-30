import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';

void main() {
  group('LF-1: origen de los precios históricos', () {
    final date = DateTime(2026, 10, 21);

    test('LF-1.1: conserva el origen manual al serializar y recuperar', () {
      final point = PricePoint(date, 123.45, source: PricePointSource.manual);

      final restored = PricePoint.fromJson(point.toJson());

      expect(restored.date, date);
      expect(restored.price, 123.45);
      expect(restored.source, PricePointSource.manual);
    });

    test('LF-1.2: conserva el origen de un proveedor', () {
      final point = PricePoint(date, 98.76, source: PricePointSource.yahoo);

      final restored = PricePoint.fromJson(point.toJson());

      expect(restored.source, PricePointSource.yahoo);
    });

    test('LF-1.3: los precios JSON antiguos recuperan origen null', () {
      final legacyJson = {'date': date.toIso8601String(), 'price': 75.50};

      final restored = PricePoint.fromJson(legacyJson);

      expect(restored.date, date);
      expect(restored.price, 75.50);
      expect(restored.source, isNull);
    });

    test('LF-1.4: JSON conserva fecha, precio y origen', () {
      final point = PricePoint(date, 142.80, source: PricePointSource.cnmv);

      final json = point.toJson();

      expect(json['date'], date.toIso8601String());
      expect(json['price'], 142.80);
      expect(json['source'], 'cnmv');

      final restored = PricePoint.fromJson(json);

      expect(restored.date, date);
      expect(restored.price, 142.80);
      expect(restored.source, PricePointSource.cnmv);
    });
  });

  test(
    'LF-2.1: copyWith conserva el origen al actualizar el último precio',
    () {
      final date = DateTime(2026, 10, 21);

      final fund = FundData(
        isin: 'ES0000000001',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 100.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 100.0, source: PricePointSource.yahoo)],
      );

      final updated = fund.copyWith(lastValue: 110.0);

      expect(updated.history, hasLength(1));
      expect(updated.history.first.price, 110.0);
      expect(updated.history.first.source, PricePointSource.yahoo);
    },
  );

  test('LF-2.2: precios iguales conservan sus distintos orígenes', () {
    final date = DateTime(2026, 10, 21);

    final manual = PricePoint(date, 100.0, source: PricePointSource.manual);

    final yahoo = PricePoint(date, 100.0, source: PricePointSource.yahoo);

    expect(manual.date, yahoo.date);
    expect(manual.price, yahoo.price);
    expect(manual.source, PricePointSource.manual);
    expect(yahoo.source, PricePointSource.yahoo);
  });

  test('LF-2.3: sincronizar el historial conserva los orígenes existentes', () {
    final previousDate = DateTime(2026, 10, 20);
    final currentDate = DateTime(2026, 10, 21);

    final fund = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 110.0,
      currency: 'EUR',
      date: currentDate,
      history: [
        PricePoint(previousDate, 100.0, source: PricePointSource.yahoo),
      ],
    );

    expect(fund.history, hasLength(2));

    final previousPoint = fund.history.firstWhere(
      (point) => point.date == previousDate,
    );
    final currentPoint = fund.history.firstWhere(
      (point) => point.date == currentDate,
    );

    expect(previousPoint.price, 100.0);
    expect(previousPoint.source, PricePointSource.yahoo);

    expect(currentPoint.price, 110.0);
  });

  test('LF-2.4: actualizar una fecha existente conserva su origen', () {
    final date = DateTime(2026, 10, 21);

    final fund = FundData(
      isin: 'ES0000000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 100.0,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 100.0, source: PricePointSource.yahoo)],
    );

    final updatedFund = fund.copyWith(lastValue: 110.0);

    expect(updatedFund.history, hasLength(1));
    expect(updatedFund.history.first.price, 110.0);
    expect(updatedFund.history.first.source, PricePointSource.yahoo);
  });

  test('LF-1.5: conserva el precio histórico distinto de lastValue en la misma fecha', () {
    final date = DateTime(2026, 10, 21);

    final fund = FundData(
      isin: 'TEST00000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 113.0,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 112.5, source: PricePointSource.yahoo)],
    );

    expect(fund.lastValue, 113.0);
    expect(fund.history, hasLength(1));
    expect(fund.history.single.price, 112.5);
    expect(fund.history.single.source, PricePointSource.yahoo);
  });
}
