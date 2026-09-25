/*
import 'dart:convert';

import 'package:http/http.dart' as http;

void main() async {
  final client = http.Client();

  final tests = <_FundTest>[
    const _FundTest(
      name: 'Carmignac Patrimoine A EUR Acc',
      expectedIsin: 'FR0010135103',
    ),
    const _FundTest(
      name: 'Fidelity Funds - Iberia Fund A-Acc-EUR',
      expectedIsin: 'LU0261948904',
    ),
    const _FundTest(
      name: 'Vontobel Fund - US Dollar Money B USD',
      expectedIsin: 'LU0120690226',
    ),
  ];

  var passed = 0;
  var failed = 0;

  print('');
  print('=' * 80);
  print('TEST DE API IBERFUNDS');
  print('=' * 80);

  try {
    for (final test in tests) {
      print('');
      print('-' * 80);
      print('TEST: ${test.name}');
      print('-' * 80);
      print('ISIN esperado: ${test.expectedIsin}');

      try {
        final result = await _searchFund(client: client, name: test.name);

        print('');
        print('RESULTADO API:');

        if (result == null) {
          print('  null');
          print('');
          print('✗ ERROR: Iberfunds no devolvió resultados.');
          failed++;
          continue;
        }

        print(const JsonEncoder.withIndent('  ').convert(result));

        final foundIsin = _findIsin(result);

        print('');
        print('ISIN detectado: $foundIsin');

        if (foundIsin == test.expectedIsin) {
          print('');
          print('✓ CORRECTO');
          passed++;
        } else {
          print('');
          print('✗ ERROR');

          if (foundIsin == null) {
            print('  No se encontró ningún ISIN en la respuesta.');
          } else {
            print('  Esperado: ${test.expectedIsin}');
            print('  Obtenido: $foundIsin');
          }

          failed++;
        }
      } catch (e, stackTrace) {
        print('');
        print('✗ EXCEPCIÓN:');
        print('  $e');
        print('');
        print('Stack trace:');
        print(stackTrace);

        failed++;
      }
    }
  } finally {
    client.close();
  }

  print('');
  print('=' * 80);
  print('RESUMEN');
  print('=' * 80);
  print('Tests ejecutados: ${tests.length}');
  print('Correctos:        $passed');
  print('Fallidos:         $failed');
  print('=' * 80);
}

Future<dynamic> _searchFund({
  required http.Client client,
  required String name,
}) async {
  final uri = Uri.parse('https://www.iberfunds.com/api/search/funds')
      .replace(queryParameters: {'q': name});

  print('');
  print('URL: $uri');

  final response = await client.get(
    uri,
    headers: const {
      'Accept': 'application/json',
      'User-Agent': 'OpenInvest/1.0',
    },
  );

  print('HTTP: ${response.statusCode}');
  print('Bytes: ${response.body.length}');

  print('');
  print('RESPUESTA RAW:');
  print(response.body);

  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode}: ${response.body}');
  }

  if (response.body.trim().isEmpty) {
    return null;
  }

  try {
    return jsonDecode(response.body);
  } catch (e) {
    throw Exception('La respuesta no es JSON válido: $e');
  }
}

/// Busca recursivamente cualquier campo llamado "isin"
/// dentro de la respuesta JSON.
///
/// No asumimos todavía la estructura exacta de Iberfunds.
/// Esto nos permite descubrirla con la primera ejecución.
String? _findIsin(dynamic value) {
  if (value is Map) {
    for (final entry in value.entries) {
      final key = entry.key.toString().toLowerCase();

      if (key == 'isin') {
        final candidate = entry.value?.toString().trim();

        if (candidate != null &&
            candidate.isNotEmpty &&
            _isValidIsin(candidate)) {
          return candidate.toUpperCase();
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
  final normalized = isin.toUpperCase();

  if (!RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(normalized)) {
    return false;
  }

  var sum = 0;
  var position = 0;

  // Convertimos las letras a números y aplicamos
  // el algoritmo de checksum ISO 6166.
  final expanded = StringBuffer();

  for (final char in normalized.split('')) {
    if (RegExp(r'[A-Z]').hasMatch(char)) {
      expanded.write(char.codeUnitAt(0) - 55);
    } else {
      expanded.write(char);
    }
  }

  final digits = expanded.toString();

  for (var i = digits.length - 1; i >= 0; i--) {
    var digit = int.parse(digits[i]);

    if ((position % 2) == 0) {
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

class _FundTest {
  final String name;
  final String expectedIsin;

  const _FundTest({required this.name, required this.expectedIsin});
}
*/
