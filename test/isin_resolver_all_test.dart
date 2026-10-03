import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';

void main() {
  group('IsinResolver.resolveAll()', () {
    test('18.1.1 - devuelve resolución vacía si ningún provider encuentra resultado', () async {
      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: const []),
          _FakeProvider(results: const []),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates, isEmpty);

      resolver.dispose();
    });

    test('18.1.2 - conserva un resultado de un provider', () async {
      final result = _result(isin: 'ES0000000001', source: 'provider-a');

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: [result]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates, hasLength(1));
      expect(resolution.candidates.single.isin, 'ES0000000001');
      expect(resolution.candidates.single.evidence, hasLength(1));
      expect(resolution.candidates.single.evidence.single.source, 'provider-a');

      resolver.dispose();
    });

    test(
      '18.1.3 - conserva múltiples resultados de un mismo provider',
      () async {
        final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
        final resultB = _result(isin: 'ES0000000002', source: 'provider-a');
        final resultC = _result(isin: 'ES0000000003', source: 'provider-a');

        final resolver = IsinResolver(
          providers: [
            _FakeProvider(results: [resultA, resultB, resultC]),
          ],
        );

        final resolution = await resolver.resolveAll(
          ticker: 'test',
          fundName: 'Test Fund',
        );

        expect(resolution.candidates, hasLength(3));
        expect(resolution.candidates.map((candidate) => candidate.isin), [
          'ES0000000001',
          'ES0000000002',
          'ES0000000003',
        ]);

        resolver.dispose();
      },
    );

    test('18.1.4 - agrega resultados de todos los providers', () async {
      final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
      final resultB = _result(isin: 'ES0000000002', source: 'provider-b');
      final resultC = _result(isin: 'ES0000000003', source: 'provider-b');

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: [resultA]),
          _FakeProvider(results: [resultB, resultC]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates, hasLength(3));
      expect(resolution.candidates.map((candidate) => candidate.isin), [
        'ES0000000001',
        'ES0000000002',
        'ES0000000003',
      ]);

      resolver.dispose();
    });

    test(
      '18.1.5 - agrupa el mismo ISIN encontrado por varios providers',
      () async {
        final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
        final resultB = _result(isin: 'ES0000000001', source: 'provider-b');
        final resultC = _result(isin: 'ES0000000002', source: 'provider-b');

        final resolver = IsinResolver(
          providers: [
            _FakeProvider(results: [resultA]),
            _FakeProvider(results: [resultB, resultC]),
          ],
        );

        final resolution = await resolver.resolveAll(
          ticker: 'test',
          fundName: 'Test Fund',
        );

        expect(resolution.candidates, hasLength(2));

        final candidateA = resolution.candidates[0];
        final candidateB = resolution.candidates[1];

        expect(candidateA.isin, 'ES0000000001');
        expect(candidateA.evidence, hasLength(2));
        expect(candidateA.evidence.map((evidence) => evidence.source), [
          'provider-a',
          'provider-b',
        ]);

        expect(candidateB.isin, 'ES0000000002');
        expect(candidateB.evidence, hasLength(1));
        expect(candidateB.evidence.single.source, 'provider-b');

        resolver.dispose();
      },
    );

    test('18.1.6 - una excepción de un provider no impide continuar', () async {
      final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
      final resultC = _result(isin: 'ES0000000003', source: 'provider-c');

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(
            results: [resultA],
            exception: StateError('provider failure'),
          ),
          _FakeProvider(results: [resultC]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates, hasLength(1));
      expect(resolution.candidates.single.isin, 'ES0000000003');

      resolver.dispose();
    });

    test('18.1.7 - mantiene el orden de primera aparición del ISIN', () async {
      final resultA = _result(isin: 'ES0000000002', source: 'provider-a');
      final resultB = _result(isin: 'ES0000000001', source: 'provider-a');
      final resultC = _result(isin: 'ES0000000002', source: 'provider-b');
      final resultD = _result(isin: 'ES0000000003', source: 'provider-b');

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: [resultA, resultB]),
          _FakeProvider(results: [resultC, resultD]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates.map((candidate) => candidate.isin), [
        'ES0000000002',
        'ES0000000001',
        'ES0000000003',
      ]);

      resolver.dispose();
    });

    test('18.1.8 - resolve() mantiene first-hit-wins', () async {
      final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
      final resultB = _result(isin: 'ES0000000002', source: 'provider-b');

      final first = _FakeProvider(results: [resultA]);
      final second = _FakeProvider(results: [resultB]);

      final resolver = IsinResolver(providers: [first, second]);

      final result = await resolver.resolve(
        ticker: 'test',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0000000001');
      expect(first.resolveCalls, 1);
      expect(second.resolveCalls, 0);

      resolver.dispose();
    });

    test('18.1.9 - resolveAll() consulta todos los providers', () async {
      final first = _FakeProvider(
        results: [_result(isin: 'ES0000000001', source: 'provider-a')],
      );
      final second = _FakeProvider(
        results: [_result(isin: 'ES0000000002', source: 'provider-b')],
      );

      final resolver = IsinResolver(providers: [first, second]);

      final resolution = await resolver.resolveAll(
        ticker: ' test ',
        fundName: 'Test Fund',
      );

      expect(resolution.candidates, hasLength(2));
      expect(first.resolveAllCalls, 1);
      expect(second.resolveAllCalls, 1);
      expect(first.lastTicker, 'TEST');
      expect(second.lastTicker, 'TEST');

      resolver.dispose();
    });

    test('18.2.1 - preserva toda la metadata de IsinResult', () async {
      final result = IsinResult(
        isin: 'ES0000000001',
        source: 'provider-a',
        officialName: 'Nombre oficial completo',
        cnmvRegistration: 1234,
        cnmvNif: 'A12345678',
      );

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: [result]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'TEST',
        fundName: 'Test Fund',
      );

      final evidence = resolution.candidates.single.evidence.single;

      expect(evidence.isin, 'ES0000000001');
      expect(evidence.source, 'provider-a');
      expect(evidence.officialName, 'Nombre oficial completo');
      expect(evidence.cnmvRegistration, 1234);
      expect(evidence.cnmvNif, 'A12345678');

      resolver.dispose();
    });

    test('18.2.2 - dos ISIN distintos para el mismo nombre permanecen como dos candidatos', () async {
      final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
      final resultB = _result(isin: 'ES0000000002', source: 'provider-a');

      final resolver = IsinResolver(
        providers: [
          _FakeProvider(results: [resultA, resultB]),
        ],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'TEST',
        fundName: 'Mismo Nombre',
      );

      expect(resolution.candidates, hasLength(2));
      expect(resolution.candidates.map((candidate) => candidate.isin), [
        'ES0000000001',
        'ES0000000002',
      ]);

      resolver.dispose();
    });

    test(
      '18.2.3 - mismo ISIN con metadata diferente conserva ambas evidencias',
      () async {
        final resultA = IsinResult(
          isin: 'ES0000000001',
          source: 'provider-a',
          officialName: 'Nombre A',
          cnmvRegistration: 100,
          cnmvNif: 'A11111111',
        );

        final resultB = IsinResult(
          isin: 'ES0000000001',
          source: 'provider-b',
          officialName: 'Nombre B',
          cnmvRegistration: 200,
          cnmvNif: 'B22222222',
        );

        final resolver = IsinResolver(
          providers: [
            _FakeProvider(results: [resultA]),
            _FakeProvider(results: [resultB]),
          ],
        );

        final resolution = await resolver.resolveAll(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(resolution.candidates, hasLength(1));

        final candidate = resolution.candidates.single;

        expect(candidate.isin, 'ES0000000001');
        expect(candidate.evidence, hasLength(2));

        expect(candidate.evidence[0].source, 'provider-a');
        expect(candidate.evidence[0].officialName, 'Nombre A');
        expect(candidate.evidence[0].cnmvRegistration, 100);
        expect(candidate.evidence[0].cnmvNif, 'A11111111');

        expect(candidate.evidence[1].source, 'provider-b');
        expect(candidate.evidence[1].officialName, 'Nombre B');
        expect(candidate.evidence[1].cnmvRegistration, 200);
        expect(candidate.evidence[1].cnmvNif, 'B22222222');

        resolver.dispose();
      },
    );

    test(
      '18.2.4 - un provider vacío no altera los resultados de los demás',
      () async {
        final resultA = _result(isin: 'ES0000000001', source: 'provider-a');
        final resultC = _result(isin: 'ES0000000003', source: 'provider-c');

        final resolver = IsinResolver(
          providers: [
            _FakeProvider(results: [resultA]),
            _FakeProvider(results: const []),
            _FakeProvider(results: [resultC]),
          ],
        );

        final resolution = await resolver.resolveAll(
          ticker: 'TEST',
          fundName: 'Test Fund',
        );

        expect(resolution.candidates, hasLength(2));
        expect(resolution.candidates.map((candidate) => candidate.isin), [
          'ES0000000001',
          'ES0000000003',
        ]);

        resolver.dispose();
      },
    );

    test(
      '18.2.5 - resolveAll normaliza el ticker para todos los providers',
      () async {
        final first = _FakeProvider(
          results: [_result(isin: 'ES0000000001', source: 'provider-a')],
        );

        final second = _FakeProvider(
          results: [_result(isin: 'ES0000000002', source: 'provider-b')],
        );

        final resolver = IsinResolver(providers: [first, second]);

        await resolver.resolveAll(ticker: '  abc.pa ', fundName: 'Test Fund');

        expect(first.lastTicker, 'ABC.PA');
        expect(second.lastTicker, 'ABC.PA');

        resolver.dispose();
      },
    );
  });
}

IsinResult _result({required String isin, required String source}) {
  return IsinResult(isin: isin, source: source, officialName: 'Test Fund');
}

class _FakeProvider implements IsinSourceProvider {
  final List<IsinResult> results;
  final Object? exception;

  int resolveCalls = 0;
  int resolveAllCalls = 0;

  String? lastTicker;
  String? lastFundName;

  _FakeProvider({required this.results, this.exception});

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    resolveCalls++;
    lastTicker = ticker;
    lastFundName = fundName;

    if (exception != null) {
      throw exception!;
    }

    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    resolveAllCalls++;
    lastTicker = ticker;
    lastFundName = fundName;

    if (exception != null) {
      throw exception!;
    }

    return results;
  }
}
