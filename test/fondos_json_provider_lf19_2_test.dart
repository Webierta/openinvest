import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_providers/fondos_json_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FondosJsonProvider provider;

  setUp(() {
    provider = FondosJsonProvider();
  });

  group('LF-19.2 FondosJsonProvider.resolve', () {
    test(
      'LF-19.2.1 - returns the only ISIN for a single-result name',
      () async {
        final result = await provider.resolve(
          ticker: 'ANY',
          fundName: '1948 INVERSIONS, SICAV S.A.',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0109642035');
      },
    );

    test(
      'LF-19.2.2 - returns the first ISIN for a multi-result name',
      () async {
        final result = await provider.resolve(
          ticker: 'ANY',
          fundName: 'ABACO RENTA FIJA, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0124526007');
      },
    );

    test(
      'LF-19.2.3 - first ISIN is deterministic for a three-ISIN name',
      () async {
        final result = await provider.resolve(
          ticker: 'ANY',
          fundName: 'A&P LIFESCIENCE FUND, FI',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0162957007');
      },
    );

    test('LF-19.2.4 - returns null when the name is not found', () async {
      final result = await provider.resolve(
        ticker: 'ANY',
        fundName: 'THIS FUND DOES NOT EXIST IN FONDOS JSON',
      );

      expect(result, isNull);
    });

    test(
      'LF-19.2.5 - resolve agrees with the first resolveAll result',
      () async {
        const fundName = 'ABACO RENTA FIJA, FI';

        final result = await provider.resolve(
          ticker: 'ANY',
          fundName: fundName,
        );

        final allResults = await provider.resolveAll(
          ticker: 'ANY',
          fundName: fundName,
        );

        expect(allResults, isNotEmpty);
        expect(result, isNotNull);
        expect(result!.isin, allResults.first.isin);
      },
    );

    test('LF-19.2.6 - resolve returns the first result without discarding '
        'results from resolveAll', () async {
      const fundName = 'A&P LIFESCIENCE FUND, FI';

      final allResultsBefore = await provider.resolveAll(
        ticker: 'ANY',
        fundName: fundName,
      );

      final result = await provider.resolve(ticker: 'ANY', fundName: fundName);

      final allResultsAfter = await provider.resolveAll(
        ticker: 'ANY',
        fundName: fundName,
      );

      expect(result, isNotNull);
      expect(result!.isin, allResultsBefore.first.isin);

      expect(
        allResultsAfter.map((item) => item.isin).toList(),
        allResultsBefore.map((item) => item.isin).toList(),
      );

      expect(allResultsAfter, hasLength(3));
    });

    test(
      'LF-19.2.7 - resolve preserves normalized-name lookup semantics',
      () async {
        final result = await provider.resolve(
          ticker: 'ANY',
          fundName: '  abaco   renta fija fi  ',
        );

        expect(result, isNotNull);
        expect(result!.isin, 'ES0124526007');
      },
    );

    test('LF-19.2.8 - ticker does not affect resolve result', () async {
      final resultA = await provider.resolve(
        ticker: 'ABC',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      final resultB = await provider.resolve(
        ticker: 'XYZ',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(resultA, isNotNull);
      expect(resultB, isNotNull);
      expect(resultA!.isin, resultB!.isin);
    });
  });
}
