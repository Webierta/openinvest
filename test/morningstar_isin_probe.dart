import 'dart:convert';
import 'dart:io';

class _Case {
  final String description;
  final String morningstarId;
  final String expectedIsin;

  const _Case({
    required this.description,
    required this.morningstarId,
    required this.expectedIsin,
  });
}

const _cases = <_Case>[
  _Case(
    description: 'PIMCO GIS Income Fund E Class USD Income',
    morningstarId: '0P0000X83M',
    expectedIsin: 'IE00B8K7V925',
  ),
  _Case(
    description: 'JPMorgan Korea (acc) - USD',
    morningstarId: '0P00000ZJQ',
    expectedIsin: 'HK0000055712',
  ),
  _Case(
    description: 'Premier Miton European Opportunities Fund B Accumulation',
    morningstarId: '0P00017461',
    expectedIsin: 'GB00BZ2K2M84',
  ),
];

Future<void> main() async {
  print('=' * 80);
  print('MORNINGSTAR ISIN PROBE');
  print('=' * 80);
  print('');

  final client = HttpClient();
  client.userAgent = 'Mozilla/5.0 (compatible; OpenInvest/1.0)';

  try {
    for (final testCase in _cases) {
      await _probe(client, testCase);
    }
  } finally {
    client.close();
  }
}

Future<void> _probe(HttpClient client, _Case testCase) async {
  print('-' * 80);
  print('TEST: ${testCase.description}');
  print('Morningstar ID: ${testCase.morningstarId}');
  print('ISIN esperado:  ${testCase.expectedIsin}');
  print('');

  // 1. Endpoint histórico que utilizábamos en IsinResolver.
  final searchUris = <Uri>[
    Uri.https('www.morningstar.es', '/es/util/SecuritySearch.ashx', {
      'q': testCase.morningstarId,
    }),
    Uri.https('www.morningstar.es', '/es/funds/SecuritySearchResults.aspx', {
      'type': 'ALL',
      'search': testCase.morningstarId,
    }),
  ];

  for (final uri in searchUris) {
    await _getAndInspect(
      client,
      uri,
      label: 'SEARCH',
      expectedIsin: testCase.expectedIsin,
    );
  }

  // 2. Página moderna de búsqueda de Morningstar.
  final modernSearch = Uri.https(
    'global.morningstar.com',
    '/es/herramientas/buscador',
    {'q': testCase.morningstarId},
  );

  await _getAndInspect(
    client,
    modernSearch,
    label: 'MODERN SEARCH',
    expectedIsin: testCase.expectedIsin,
  );

  // 3. Página directa usando el Performance ID de Yahoo/Morningstar.
  final directPage = Uri.https(
    'global.morningstar.com',
    '/es/inversiones/fondos/${testCase.morningstarId}/cotizacion',
  );

  await _getAndInspect(
    client,
    directPage,
    label: 'DIRECT PAGE',
    expectedIsin: testCase.expectedIsin,
  );

  print('');
}

Future<void> _getAndInspect(
  HttpClient client,
  Uri uri, {
  required String label,
  required String expectedIsin,
}) async {
  print('[$label]');
  print('GET $uri');

  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, '*/*');
    request.headers.set(
      HttpHeaders.acceptLanguageHeader,
      'es-ES,es;q=0.9,en;q=0.8',
    );
    request.headers.set(
      HttpHeaders.refererHeader,
      'https://www.morningstar.es/',
    );

    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();

    print('HTTP: ${response.statusCode}');
    print('Content-Type: ${response.headers.contentType}');

    if (body.isEmpty) {
      print('Body vacío.');
      print('');
      return;
    }

    final normalized = body.toLowerCase();

    final isinMatches = <String>{};
    final isinRegex = RegExp(r'\b[A-Z]{2}[A-Z0-9]{9}[0-9]\b');

    for (final match in isinRegex.allMatches(body.toUpperCase())) {
      final value = match.group(0);
      if (value != null) {
        isinMatches.add(value);
      }
    }

    print('ISINs encontrados por regex: ${isinMatches.length}');
    if (isinMatches.isNotEmpty) {
      for (final isin in isinMatches.take(30)) {
        print('  ISIN: $isin${isin == expectedIsin ? '  <-- ESPERADO' : ''}');
      }
    }

    final interestingTerms = <String>[
      'isin',
      'securityid',
      'performanceid',
      'secid',
      'fundid',
      'ie00',
      'hk000',
      'gb00',
    ];

    print('Términos relevantes encontrados:');
    for (final term in interestingTerms) {
      if (normalized.contains(term)) {
        print('  - $term');
      }
    }

    final securityIdMatches = RegExp(
      r'(?:securityid|security_id|secid)["\x27\s:=]+([A-Z0-9]+)',
      caseSensitive: false,
    ).allMatches(body);

    for (final match in securityIdMatches.take(10)) {
      print('  Security ID candidato: ${match.group(1)}');
    }

    // Mostrar contexto alrededor de ISIN esperado si aparece.
    final expectedIndex = normalized.indexOf(expectedIsin.toLowerCase());

    if (expectedIndex >= 0) {
      final start = (expectedIndex - 300).clamp(0, body.length);
      final end = (expectedIndex + expectedIsin.length + 500).clamp(
        0,
        body.length,
      );

      print('');
      print('*** CONTEXTO DEL ISIN ESPERADO ***');
      print(body.substring(start, end));
      print('*** FIN CONTEXTO ***');
    } else {
      print('ISIN esperado NO aparece en esta respuesta.');
    }

    print('');
  } catch (e) {
    print('EXCEPCIÓN: $e');
    print('');
  }
}
