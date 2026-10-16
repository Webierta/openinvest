import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:investing/services/ine_ipc_service.dart';

void main() {
  group('IneIpcService (Real API Integration Tests)', () {
    late IneIpcService service;
    setUp(() {
      service = IneIpcService(client: http.Client());
    });

    test(
      'debe obtener una lista no vacía de datos históricos del IPC',
      () async {
        final history = await service.getAllIpcHistory();
        expect(
          history,
          isNotEmpty,
          reason: 'La API del INE debería devolver datos históricos del IPC.',
        );
      },
    );

    test('los datos deben estar ordenados cronológicamente de más reciente a más antiguo', () async {
      final history = await service.getAllIpcHistory();
      expect(history, isNotEmpty);
      for (int i = 0; i < history.length - 1; i++) {
        expect(
          history[i].date.isAfter(history[i + 1].date),
          isTrue,
          reason:
              'El elemento en la posición $i debe ser posterior al elemento ${i + 1}',
        );
      }
    });

    test('los valores del IPC deben ser coherentes internamente (respetando cambios de base)', () async {
      final history = await service.getAllIpcHistory();

      expect(history, isNotEmpty);

      // 1. Regla absoluta: Todos los valores deben ser positivos
      for (final point in history) {
        expect(
          point.value,
          greaterThan(0),
          reason:
              'El valor del IPC no puede ser negativo o cero. Fecha: ${point.year}-${point.month}',
        );
      }

      // 2. El dato más reciente debe estar razonablemente cerca de la base 100 (Base 2021)
      final latestPoint = history.first;
      expect(
        latestPoint.value,
        inInclusiveRange(80.0, 150.0),
        reason:
            'El IPC más reciente (${latestPoint.year}-${latestPoint.month}) debería estar cerca de la base 100, pero fue: ${latestPoint.value}',
      );

      // 3. Comprobación de variaciones mensuales (con tolerancia a cambios de base históricos)
      for (int i = 0; i < history.length - 1; i++) {
        final current = history[i].value;
        final previous = history[i + 1].value;
        final monthlyVariation = ((current - previous) / previous).abs();

        // Umbral elevado a 1.0 (100%) para permitir el "escalón" del cambio de base de 2001/2002 (~57%),
        // pero lo suficientemente bajo para detectar un error de parsing real (ej. 58.72 -> 5872, que sería 9900%).
        expect(
          monthlyVariation,
          lessThan(1.0),
          reason:
              'Variación mensual sospechosa (posible error de parsing) entre ${history[i].year}-${history[i].month} '
              '(${previous.toStringAsFixed(2)} -> ${current.toStringAsFixed(2)}): '
              '${(monthlyVariation * 100).toStringAsFixed(2)}%',
        );
      }

      // 4. La serie debe contener datos históricos suficientes (coherencia de la API)
      final yearsCovered = history.map((p) => p.year).toSet();
      expect(
        yearsCovered.length,
        greaterThanOrEqualTo(5),
        reason:
            'Deberíamos tener al menos 5 años de datos históricos, pero solo hay: ${yearsCovered.length}',
      );
    });

    test('las propiedades de fecha (year, month, date) deben ser consistentes entre sí', () async {
      final history = await service.getAllIpcHistory();
      expect(history, isNotEmpty);

      final firstPoint = history.first;
      expect(
        firstPoint.month,
        inInclusiveRange(1, 12),
        reason: 'El mes debe estar entre 1 y 12',
      );
      expect(
        firstPoint.year,
        greaterThanOrEqualTo(2020),
        reason: 'Deberíamos tener datos al menos desde 2020',
      );

      // Verificar que el objeto DateTime coincide con los campos year y month
      expect(firstPoint.date.year, equals(firstPoint.year));
      expect(firstPoint.date.month, equals(firstPoint.month));
    });

    test('el dato más reciente debe ser actual (de los últimos 2 años)', () async {
      final history = await service.getAllIpcHistory();
      expect(history, isNotEmpty);

      final latestPoint = history.first;
      final currentYear = DateTime.now().year;
      final minExpectedYear = currentYear - 2;
      expect(
        latestPoint.year,
        greaterThanOrEqualTo(minExpectedYear),
        reason:
            'El dato más reciente del IPC debería ser del año $minExpectedYear o posterior, pero fue: ${latestPoint.year}',
      );
    });

    test('debe manejar correctamente la búsqueda de un mes específico (simulación de uso real)', () async {
      final history = await service.getAllIpcHistory();
      expect(history, isNotEmpty);

      // Tomamos una fecha que sabemos que existe (ej. el primer dato que nos devuelve, que suele ser el más reciente)
      final knownPoint = history.first;

      // Simulamos la lógica que usa el FundProvider para buscar un mes concreto
      final foundPoint = history.firstWhere(
        (data) =>
            data.year == knownPoint.year && data.month == knownPoint.month,
        orElse: () =>
            IpcDataPoint(year: 0, month: 0, value: 0, date: DateTime.now()),
      );
      expect(foundPoint.year, equals(knownPoint.year));
      expect(foundPoint.month, equals(knownPoint.month));
      expect(foundPoint.value, equals(knownPoint.value));
    });

    test('la serie histórica debe cubrir múltiples años incluyendo años recientes', () async {
      final history = await service.getAllIpcHistory();
      expect(history, isNotEmpty);

      final oldestYear = history.last.year;
      final newestYear = history.first.year;
      final currentYear = DateTime.now().year;

      // Debería tener datos de al menos 5 años atrás
      expect(
        oldestYear,
        lessThanOrEqualTo(currentYear - 5),
        reason:
            'El dato más antiguo es de $oldestYear, debería ser de al menos ${currentYear - 5}',
      );

      // Y datos del año actual o el anterior (el INE publica con desfase)
      expect(
        newestYear,
        greaterThanOrEqualTo(currentYear - 1),
        reason:
            'El dato más reciente es de $newestYear, debería ser de $currentYear o ${currentYear - 1}',
      );
    });
  });
}
