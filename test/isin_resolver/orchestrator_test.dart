import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';

class _FakeProvider implements IsinSourceProvider {
  final String name;
  final IsinResult? result;
  final List<String> calls;
  final void Function(String ticker, String fundName)? onResolve;
  final Object? error;

  _FakeProvider({
    required this.name,
    required this.result,
    required this.calls,
    this.onResolve,
    this.error,
  });

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    final result = await resolve(ticker: ticker, fundName: fundName);

    return result == null ? const [] : [result];
  }

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    calls.add(name);
    onResolve?.call(ticker, fundName);

    if (error != null) {
      throw error!;
    }

    return result;
  }
}

void main() {
  group('IsinResolver - Orquestador', () {
    test(
      'O1 - devuelve el resultado del primer provider y detiene la cadena',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(
          name: 'P1',
          result: const IsinResult(isin: 'ES0000000001', source: 'P1'),
          calls: calls,
        );

        final provider2 = _FakeProvider(
          name: 'P2',
          result: const IsinResult(isin: 'ES0000000002', source: 'P2'),
          calls: calls,
        );

        final resolver = IsinResolver(providers: [provider1, provider2]);
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000001');
        expect(result.source, 'P1');
        expect(calls, ['P1']);
      },
    );

    test(
      'O2 - si el primer provider devuelve null, continúa con el siguiente',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(name: 'P1', result: null, calls: calls);

        final provider2 = _FakeProvider(
          name: 'P2',
          result: const IsinResult(isin: 'ES0000000002', source: 'P2'),
          calls: calls,
        );

        final resolver = IsinResolver(providers: [provider1, provider2]);
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000002');
        expect(result.source, 'P2');
        expect(calls, ['P1', 'P2']);
      },
    );

    test(
      'O3 - continúa atravesando varios null hasta encontrar un resultado',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(name: 'P1', result: null, calls: calls);

        final provider2 = _FakeProvider(name: 'P2', result: null, calls: calls);

        final provider3 = _FakeProvider(name: 'P3', result: null, calls: calls);

        final provider4 = _FakeProvider(
          name: 'P4',
          result: const IsinResult(isin: 'ES0000000004', source: 'P4'),
          calls: calls,
        );

        final resolver = IsinResolver(
          providers: [provider1, provider2, provider3, provider4],
        );
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000004');
        expect(result.source, 'P4');
        expect(calls, ['P1', 'P2', 'P3', 'P4']);
      },
    );

    test('O4 - respeta exactamente el orden de los providers', () async {
      final calls = <String>[];

      final providerA = _FakeProvider(name: 'A', result: null, calls: calls);

      final providerB = _FakeProvider(name: 'B', result: null, calls: calls);

      final providerC = _FakeProvider(
        name: 'C',
        result: const IsinResult(isin: 'ES0000000003', source: 'C'),
        calls: calls,
      );

      final resolver = IsinResolver(
        providers: [providerA, providerB, providerC],
      );
      addTearDown(resolver.dispose);

      await resolver.resolve(ticker: 'TEST.MC', fundName: 'Test Fund');

      expect(calls, ['A', 'B', 'C']);
    });

    test(
      'O5 - después de encontrar un resultado no ejecuta providers posteriores',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(
          name: 'P1',
          result: const IsinResult(isin: 'ES0000000001', source: 'P1'),
          calls: calls,
        );

        final provider2 = _FakeProvider(
          name: 'P2',
          result: const IsinResult(isin: 'ES0000000002', source: 'P2'),
          calls: calls,
        );

        final provider3 = _FakeProvider(
          name: 'P3',
          result: const IsinResult(isin: 'ES0000000003', source: 'P3'),
          calls: calls,
        );

        final resolver = IsinResolver(
          providers: [provider1, provider2, provider3],
        );
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result!.source, 'P1');
        expect(calls, ['P1']);
      },
    );

    test(
      'O6 - normaliza ticker pero conserva fundName sin modificar',
      () async {
        final calls = <String>[];
        String? receivedTicker;
        String? receivedFundName;

        final provider = _FakeProvider(
          name: 'P1',
          result: const IsinResult(isin: 'ES0000000001', source: 'P1'),
          calls: calls,
          onResolve: (ticker, fundName) {
            receivedTicker = ticker;
            receivedFundName = fundName;
          },
        );

        final resolver = IsinResolver(providers: [provider]);
        addTearDown(resolver.dispose);

        await resolver.resolve(
          ticker: '  test.mc  ',
          fundName: '  Test Fund  ',
        );

        expect(receivedTicker, 'TEST.MC');
        expect(receivedFundName, '  Test Fund  ');
        expect(calls, ['P1']);
      },
    );

    test(
      'O7 - devuelve null cuando ningún provider resuelve el ISIN',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(name: 'P1', result: null, calls: calls);

        final provider2 = _FakeProvider(name: 'P2', result: null, calls: calls);

        final provider3 = _FakeProvider(name: 'P3', result: null, calls: calls);

        final resolver = IsinResolver(
          providers: [provider1, provider2, provider3],
        );
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNull);
        expect(calls, ['P1', 'P2', 'P3']);
      },
    );

    test(
      'O8 - una excepción de un provider permite continuar con el siguiente',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(
          name: 'P1',
          result: null,
          calls: calls,
          error: StateError('P1 failure'),
        );

        final provider2 = _FakeProvider(
          name: 'P2',
          result: const IsinResult(isin: 'ES0000000002', source: 'P2'),
          calls: calls,
        );

        final resolver = IsinResolver(providers: [provider1, provider2]);
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000002');
        expect(result.source, 'P2');

        expect(calls, ['P1', 'P2']);
      },
    );

    test('O9 - conserva officialName del provider', () async {
      final expected = const IsinResult(
        isin: 'ES0000000009',
        source: 'TEST',
        officialName: 'Nombre oficial del fondo',
      );

      final provider = _FakeProvider(name: 'P1', result: expected, calls: []);

      final resolver = IsinResolver(providers: [provider]);
      addTearDown(resolver.dispose);

      final result = await resolver.resolve(
        ticker: 'TEST.MC',
        fundName: 'Nombre de entrada',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0000000009');
      expect(result.source, 'TEST');
      expect(result.officialName, 'Nombre oficial del fondo');
    });

    test('O10 - conserva cnmvRegistration del provider', () async {
      final expected = const IsinResult(
        isin: 'ES0000000010',
        source: 'TEST',
        officialName: 'Fondo CNMV',
        cnmvRegistration: 12345,
      );

      final provider = _FakeProvider(name: 'P1', result: expected, calls: []);

      final resolver = IsinResolver(providers: [provider]);
      addTearDown(resolver.dispose);

      final result = await resolver.resolve(
        ticker: 'TEST.MC',
        fundName: 'Fondo de entrada',
      );

      expect(result, isNotNull);
      expect(result!.cnmvRegistration, 12345);
    });

    test('O11 - conserva cnmvNif del provider', () async {
      final expected = const IsinResult(
        isin: 'ES0000000011',
        source: 'TEST',
        officialName: 'Fondo CNMV',
        cnmvNif: 'V12345678',
      );

      final provider = _FakeProvider(name: 'P1', result: expected, calls: []);

      final resolver = IsinResolver(providers: [provider]);
      addTearDown(resolver.dispose);

      final result = await resolver.resolve(
        ticker: 'TEST.MC',
        fundName: 'Fondo de entrada',
      );

      expect(result, isNotNull);
      expect(result!.cnmvNif, 'V12345678');
    });

    test('O12 - conserva íntegramente el IsinResult del provider', () async {
      final expected = const IsinResult(
        isin: 'ES0000000012',
        source: 'CNMV/FI local',
        officialName: 'Fondo de inversión completo',
        cnmvRegistration: 54321,
        cnmvNif: 'V87654321',
      );

      final provider = _FakeProvider(name: 'P1', result: expected, calls: []);

      final resolver = IsinResolver(providers: [provider]);
      addTearDown(resolver.dispose);

      final result = await resolver.resolve(
        ticker: 'TEST.MC',
        fundName: 'Nombre de entrada',
      );

      expect(result, isNotNull);

      expect(result!.isin, expected.isin);
      expect(result.source, expected.source);
      expect(result.officialName, expected.officialName);
      expect(result.cnmvRegistration, expected.cnmvRegistration);
      expect(result.cnmvNif, expected.cnmvNif);
    });

    test('O13 - una excepción de un provider intermedio permite ejecutar los siguientes', () async {
      final calls = <String>[];

      final provider1 = _FakeProvider(name: 'P1', result: null, calls: calls);

      final provider2 = _FakeProvider(
        name: 'P2',
        result: null,
        calls: calls,
        error: StateError('CnmvFiProvider failure'),
      );

      final provider3 = _FakeProvider(
        name: 'P3',
        result: const IsinResult(isin: 'ES0000000013', source: 'P3'),
        calls: calls,
      );

      final resolver = IsinResolver(
        providers: [provider1, provider2, provider3],
      );
      addTearDown(resolver.dispose);

      final result = await resolver.resolve(
        ticker: 'TEST.MC',
        fundName: 'Test Fund',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0000000013');
      expect(result.source, 'P3');

      expect(calls, ['P1', 'P2', 'P3']);
    });

    test(
      'O14 - una excepción de CNMV/FI permite continuar hasta Yahoo',
      () async {
        final calls = <String>[];

        final cnmvFiProvider = _FakeProvider(
          name: 'CnmvFiProvider',
          result: null,
          calls: calls,
          error: StateError('CNMV local data failure'),
        );

        final yahooProvider = _FakeProvider(
          name: 'YahooProvider',
          result: const IsinResult(isin: 'IE00TEST0014', source: 'Yahoo'),
          calls: calls,
        );

        final resolver = IsinResolver(
          providers: [cnmvFiProvider, yahooProvider],
        );
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'IE00TEST0014');
        expect(result.source, 'Yahoo');

        expect(calls, ['CnmvFiProvider', 'YahooProvider']);
      },
    );

    /// O15 - una excepción de un provider permite continuar con el siguiente

    test(
      'O15 - una excepción de un provider permite continuar con el siguiente',
      () async {
        final calls = <String>[];

        final provider1 = _FakeProvider(name: 'P1', result: null, calls: calls);

        final provider2 = _FakeProvider(
          name: 'P2',
          result: null,
          calls: calls,
          error: StateError('P2 failure'),
        );

        final provider3 = _FakeProvider(
          name: 'P3',
          result: const IsinResult(
            isin: 'ES0000000015',
            source: 'P3',
            officialName: 'Recovered Fund',
          ),
          calls: calls,
        );

        final resolver = IsinResolver(
          providers: [provider1, provider2, provider3],
        );
        addTearDown(resolver.dispose);

        final result = await resolver.resolve(
          ticker: 'TEST.MC',
          fundName: 'Test Fund',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0000000015');
        expect(result.source, 'P3');
        expect(result.officialName, 'Recovered Fund');

        expect(calls, ['P1', 'P2', 'P3']);
      },
    );
  });
}
