import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.12.4.4 — ECB/IFS caracterización por ISIN', () {
    test('ES0160483014 existe una sola vez y corresponde a MAPFRE PRIVATE EQUITY I FCR', () async {
      const assetPath = 'assets/files/ECB_IFS_2024.json';
      const targetIsin = 'ES0160483014';

      final jsonString = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(jsonString);

      expect(decoded, isA<List<dynamic>>());

      final records = (decoded as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .where((item) {
            final isin = item['ISIN'];
            return isin is String && isin.trim().toUpperCase() == targetIsin;
          })
          .toList();

      expect(
        records,
        hasLength(1),
        reason: 'El ISIN debe identificar un único registro ECB/IFS.',
      );

      final record = records.single;

      expect(record['ISIN'], isA<String>());
      expect((record['ISIN'] as String).trim().toUpperCase(), targetIsin);

      expect(record['Name'], isA<String>());
      expect((record['Name'] as String).trim(), 'MAPFRE PRIVATE EQUITY I FCR');
    });
  });
}
