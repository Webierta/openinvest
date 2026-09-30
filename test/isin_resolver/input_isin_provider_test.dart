import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_providers/input_isin_provider.dart';
import 'package:investing/services/isin_resolver.dart';

void runInputIsinProviderTests() {
  group('InputIsinProvider - I1..I6', () {
    test('I1 - extractor devuelve ISIN -> IsinResult INPUT', () async {
      final provider = InputIsinProvider(
        extractEmbeddedIsin: (_) => 'LU0297942194',
      );

      final result = await provider.resolve(
        ticker: 'ABC-LU0297942194-USD.LU',
        fundName: 'Fondo de prueba',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'LU0297942194');
      expect(result.source, 'INPUT');
      expect(result.officialName, 'Fondo de prueba');
    });

    test('I2 - extractor devuelve null -> null', () async {
      final provider = InputIsinProvider(extractEmbeddedIsin: (_) => null);

      final result = await provider.resolve(
        ticker: 'SIN-ISIN',
        fundName: 'Fondo de prueba',
      );

      expect(result, isNull);
    });

    test('I3 - el ticker llega exactamente al extractor', () async {
      String? receivedTicker;

      final provider = InputIsinProvider(
        extractEmbeddedIsin: (value) {
          receivedTicker = value;
          return null;
        },
      );

      const ticker = 'AbC-Lu0297942194-Usd.Lu';

      await provider.resolve(ticker: ticker, fundName: 'Fondo de prueba');

      expect(receivedTicker, ticker);
    });

    test('I4 - fundName se conserva exactamente en officialName', () async {
      final provider = InputIsinProvider(
        extractEmbeddedIsin: (_) => 'LU0297942194',
      );

      const fundName = '  Fondo  con  espacios  y MAYÚSCULAS  ';

      final result = await provider.resolve(
        ticker: 'TICKER',
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.officialName, fundName);
    });

    test('I5 - StateError del extractor se propaga', () async {
      final provider = InputIsinProvider(
        extractEmbeddedIsin: (_) {
          throw StateError('error de prueba');
        },
      );

      expect(
        () => provider.resolve(ticker: 'TICKER', fundName: 'Fondo'),
        throwsA(isA<StateError>()),
      );
    });

    test('I6 - Error del extractor se propaga', () async {
      final provider = InputIsinProvider(
        extractEmbeddedIsin: (_) {
          throw AssertionError('error de prueba');
        },
      );

      expect(
        () => provider.resolve(ticker: 'TICKER', fundName: 'Fondo'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('E - _extractEmbeddedIsin', () {
    test('E1 - candidato con formato incorrecto -> no resuelve', () async {
      final resolver = IsinResolver();

      final result = await resolver.resolve(
        ticker: 'ABC-LU029794219-USD.LU',
        fundName: 'Fondo de prueba',
      );

      expect(result, isNull);

      resolver.dispose();
    });

    test('E2 - candidato ISIN con checksum inválido -> no resuelve', () async {
      final resolver = IsinResolver();

      final result = await resolver.resolve(
        ticker: 'ABC-LU0297942195-USD.LU',
        fundName: 'Fondo de prueba',
      );

      expect(result, isNull);

      resolver.dispose();
    });

    test(
      'E3 - candidato inválido seguido de válido -> devuelve el válido',
      () async {
        final resolver = IsinResolver();

        final result = await resolver.resolve(
          ticker: 'ABC-LU0297942195-IE00B8K7V925-USD.LU',
          fundName: 'Fondo de prueba',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'IE00B8K7V925');
        expect(result.source, 'INPUT');

        resolver.dispose();
      },
    );

    test(
      'E4 - varios candidatos con checksum inválido -> no resuelve',
      () async {
        final resolver = IsinResolver();

        final result = await resolver.resolve(
          ticker: 'ABC-LU0297942195-IE00B8K7V924-XYZ',
          fundName: 'Fondo de prueba',
        );

        expect(result, isNull);

        resolver.dispose();
      },
    );

    test(
      'E5 - ISIN válido incrustado en cadena alfanumérica -> lo encuentra',
      () async {
        final resolver = IsinResolver();

        final result = await resolver.resolve(
          ticker: 'XXXLU0297942194YYY',
          fundName: 'Fondo de prueba',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'LU0297942194');
        expect(result.source, 'INPUT');

        resolver.dispose();
      },
    );
  });
}
