import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final client = http.Client();

  final tests = <_Test>[
    const _Test(
      description: 'Carmignac',
      ticker: '0P00000FB4',
      expectedIsin: 'FR0010135103',
    ),
    const _Test(
      description: 'Fidelity Iberia',
      ticker: '0P00006DAB',
      expectedIsin: 'LU0261948904',
    ),
    const _Test(
      description: 'Vontobel',
      ticker: '0P00000HZF',
      expectedIsin: 'LU0120690226',
    ),
  ];

  try {
    for (final test in tests) {
      print('');
      print('=' * 80);
      print('TEST: ${test.description}');
      print('=' * 80);

      final uri = Uri.parse('https://api.openfigi.com/v3/mapping');

      final request = [
        {'idType': 'TICKER', 'idValue': test.ticker},
      ];

      print('');
      print('REQUEST:');
      print(const JsonEncoder.withIndent('  ').convert(request));

      try {
        final response = await client.post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'OpenInvest/1.0',
          },
          body: jsonEncode(request),
        );

        print('');
        print('HTTP: ${response.statusCode}');
        print('Bytes: ${response.body.length}');

        print('');
        print('RESPUESTA:');
        print(response.body);

        if (response.statusCode != 200) {
          continue;
        }

        try {
          final json = jsonDecode(response.body);

          print('');
          print('JSON FORMATEADO:');
          print(const JsonEncoder.withIndent('  ').convert(json));

          final isin = _findIsin(json);

          print('');
          print('ISIN DETECTADO: $isin');
          print('ISIN ESPERADO:  ${test.expectedIsin}');

          if (isin == test.expectedIsin) {
            print('');
            print('✓ CORRECTO');
          } else {
            print('');
            print('✗ NO COINCIDE');
          }
        } catch (e) {
          print('Error parseando JSON: $e');
        }
      } catch (e, stackTrace) {
        print('');
        print('EXCEPCIÓN: $e');
        print(stackTrace);
      }
    }
  } finally {
    client.close();
  }
}

String? _findIsin(dynamic value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();

      if (key == 'isin') {
        final valueString = entry.value?.toString().trim().toUpperCase();

        if (valueString != null && _isValidIsin(valueString)) {
          return valueString;
        }
      }

      if (key == 'securityid') {
        final valueString = entry.value?.toString().trim().toUpperCase();

        if (valueString != null && _isValidIsin(valueString)) {
          return valueString;
        }
      }

      final nested = _findIsin(entry.value);

      if (nested != null) {
        return nested;
      }
    }
  }

  if (value is List) {
    for (final item in value) {
      final nested = _findIsin(item);

      if (nested != null) {
        return nested;
      }
    }
  }

  return null;
}

bool _isValidIsin(String isin) {
  if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin)) {
    return false;
  }

  final expanded = StringBuffer();

  for (final char in isin.split('')) {
    if (RegExp(r'[A-Z]').hasMatch(char)) {
      expanded.write(char.codeUnitAt(0) - 55);
    } else {
      expanded.write(char);
    }
  }

  final digits = expanded.toString();

  var sum = 0;
  var position = 0;

  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = int.parse(digits[i]);

    if (position.isEven) {
      digit *= 2;

      if (digit > 9) {
        digit = (digit ~/ 10) + (digit % 10);
      }
    }

    sum += digit;
    position++;
  }

  return sum % 10 == 0;
}

class _Test {
  final String description;
  final String ticker;
  final String expectedIsin;

  const _Test({
    required this.description,
    required this.ticker,
    required this.expectedIsin,
  });
}
