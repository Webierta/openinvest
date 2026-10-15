import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/ine_ipc_service.dart';

void main() {
  group('IpcDataPoint.fromJson', () {
    test('uses year and month when Fecha is null', () {
      final point = IpcDataPoint.fromJson({
        'Anyo': 2024,
        'FK_Periodo': 4,
        'Valor': 3.2,
        'Fecha': null,
      });

      expect(point.year, 2024);
      expect(point.month, 4);
      expect(point.value, 3.2);
      expect(point.date, DateTime(2024, 4));
    });
  });
}
