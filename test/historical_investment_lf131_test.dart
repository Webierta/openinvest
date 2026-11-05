import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';

void main() {
  group('LF-131: HistoricalInvestment', () {
    test('LF-131.1: construye una inversión válida', () {
      final investment = HistoricalInvestment(
        uid: 'investment-001',
        name: 'Fondo de prueba',
        isin: 'ES0000000001',
        description: 'Inversión histórica de prueba',
      );

      expect(investment.uid, 'investment-001');
      expect(investment.name, 'Fondo de prueba');
      expect(investment.isin, 'ES0000000001');
      expect(investment.description, 'Inversión histórica de prueba');
    });

    test('LF-131.2: utiliza No especificado cuando no se conoce el fondo', () {
      final investment = HistoricalInvestment(uid: 'investment-002');

      expect(investment.name, 'No especificado');
      expect(investment.isin, isNull);
      expect(investment.description, isNull);
    });

    test('LF-131.3: rechaza un UID vacío', () {
      expect(() => HistoricalInvestment(uid: '   '), throwsArgumentError);
    });

    test('LF-131.4: copyWith conserva los campos no modificados', () {
      final original = HistoricalInvestment(
        id: 12,
        uid: 'investment-001',
        name: 'Fondo original',
        isin: 'ES0000000001',
        description: 'Descripción original',
      );

      final updated = original.copyWith(
        name: 'Fondo actualizado',
        description: 'Nueva descripción',
      );

      expect(updated.id, 12);
      expect(updated.uid, 'investment-001');
      expect(updated.name, 'Fondo actualizado');
      expect(updated.isin, 'ES0000000001');
      expect(updated.description, 'Nueva descripción');

      // El original permanece intacto.
      expect(original.name, 'Fondo original');
      expect(original.description, 'Descripción original');
    });

    test('LF-131.5: copyWith permite eliminar ISIN y descripción', () {
      final original = HistoricalInvestment(
        uid: 'investment-001',
        name: 'Fondo original',
        isin: 'ES0000000001',
        description: 'Descripción original',
      );

      final updated = original.copyWith(isin: null, description: null);

      expect(updated.isin, isNull);
      expect(updated.description, isNull);
      expect(updated.uid, original.uid);
      expect(updated.name, original.name);
    });
  });
}
