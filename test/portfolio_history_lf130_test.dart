import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/portfolio_history.dart';

void main() {
  group('LF-130: PortfolioHistory', () {
    test(
      'LF-130.1: construye un registro válido y calcula la rentabilidad',
      () {
        final history = PortfolioHistory(
          uid: 'history-001',
          fundName: 'Fondo de prueba',
          isin: 'ES0000000001',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
          initialValue: 1000,
          finalValue: 1250,
          createdAt: DateTime(2026, 1, 1),
        );

        expect(history.uid, 'history-001');
        expect(history.fundName, 'Fondo de prueba');
        expect(history.isin, 'ES0000000001');
        expect(history.initialValue, 1000);
        expect(history.finalValue, 1250);

        expect(history.returnAmount, 250);
        expect(history.returnPercent, 25);
      },
    );

    test('LF-130.2: rechaza un UID vacío', () {
      expect(
        () => PortfolioHistory(
          uid: '   ',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
          initialValue: 1000,
          finalValue: 1250,
        ),
        throwsArgumentError,
      );
    });
    test('LF-130.3: rechaza un valor inicial no positivo o no finito', () {
      PortfolioHistory createHistory(double initialValue) {
        return PortfolioHistory(
          uid: 'history-001',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
          initialValue: initialValue,
          finalValue: 1250,
        );
      }

      expect(() => createHistory(0), throwsArgumentError);
      expect(() => createHistory(-100), throwsArgumentError);
      expect(() => createHistory(double.nan), throwsArgumentError);
      expect(() => createHistory(double.infinity), throwsArgumentError);
    });

    test('LF-130.4: rechaza un valor final negativo o no finito', () {
      PortfolioHistory createHistory(double finalValue) {
        return PortfolioHistory(
          uid: 'history-001',
          startDate: DateTime(2025, 1, 1),
          endDate: DateTime(2025, 12, 31),
          initialValue: 1000,
          finalValue: finalValue,
        );
      }

      expect(() => createHistory(-1), throwsArgumentError);
      expect(() => createHistory(double.nan), throwsArgumentError);
      expect(() => createHistory(double.infinity), throwsArgumentError);
    });

    test('LF-130.5: rechaza una fecha final anterior a la inicial', () {
      expect(
        () => PortfolioHistory(
          uid: 'history-001',
          startDate: DateTime(2025, 12, 31),
          endDate: DateTime(2025, 1, 1),
          initialValue: 1000,
          finalValue: 1250,
        ),
        throwsArgumentError,
      );
    });

    test('LF-130.6: copyWith conserva los campos no modificados y actualiza los indicados', () {
      final original = PortfolioHistory(
        uid: 'history-001',
        fundName: 'Fondo original',
        isin: 'ES0000000001',
        startDate: DateTime(2025, 1, 1),
        endDate: DateTime(2025, 12, 31),
        initialValue: 1000,
        finalValue: 1250,
        createdAt: DateTime(2026, 1, 1),
      );

      final updated = original.copyWith(
        fundName: 'Fondo actualizado',
        finalValue: 1500,
      );

      // Campos modificados.
      expect(updated.fundName, 'Fondo actualizado');
      expect(updated.finalValue, 1500);

      // Campos que deben conservarse.
      expect(updated.id, original.id);
      expect(updated.uid, original.uid);
      expect(updated.isin, original.isin);
      expect(updated.startDate, original.startDate);
      expect(updated.endDate, original.endDate);
      expect(updated.initialValue, original.initialValue);
      expect(updated.createdAt, original.createdAt);

      // Los cálculos deben reflejar los nuevos valores.
      expect(updated.returnAmount, 500);
      expect(updated.returnPercent, 50);

      // La copia no debe modificar el original.
      expect(original.fundName, 'Fondo original');
      expect(original.finalValue, 1250);
    });
  });
}
