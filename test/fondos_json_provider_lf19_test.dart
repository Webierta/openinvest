import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_providers/fondos_json_provider.dart';
import 'package:investing/utils/isin_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FondosJsonProvider provider;

  setUp(() {
    provider = FondosJsonProvider();
  });

  group('LF-19.1 FondosJsonProvider', () {
    test('LF-19.1.1 - resolves a single ISIN', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '1948 INVERSIONS, SICAV S.A.',
      );

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0109642035');
    });

    test('LF-19.1.2 - resolves all ISINs for ABACO RENTA FIJA', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(results.map((result) => result.isin).toList(), [
        'ES0124526007',
        'ES0124526015',
      ]);
    });

    test(
      'LF-19.1.3 - resolves all three ISINs for A&P LIFESCIENCE FUND',
      () async {
        final results = await provider.resolveAll(
          ticker: 'ANY',
          fundName: 'A&P LIFESCIENCE FUND, FI',
        );

        expect(results.map((result) => result.isin).toList(), [
          'ES0162957007',
          'ES0162957015',
          'ES0162957023',
        ]);
      },
    );

    test('LF-19.1.4 - returns one IsinResult per ISIN', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      expect(results, hasLength(3));
      expect(results.map((result) => result.isin).toSet(), hasLength(3));
    });

    test('LF-19.1.5 - preserves source order', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(results[0].isin, 'ES0124526007');
      expect(results[1].isin, 'ES0124526015');
    });

    test('LF-19.1.6 - preserves official source name', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(results.map((result) => result.officialName).toSet(), {
        'ABACO RENTA FIJA, FI',
      });
    });

    test('LF-19.1.7 - identifies source as fondos.json', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(results.map((result) => result.source).toSet(), {'fondos.json'});
    });

    test('LF-19.1.8 - normalizes case', () async {
      final canonical = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      final normalized = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'abaco renta fija, fi',
      );

      expect(
        normalized.map((result) => result.isin).toList(),
        canonical.map((result) => result.isin).toList(),
      );
    });

    test('LF-19.1.9 - normalizes punctuation and spacing', () async {
      final canonical = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      final normalized = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '  a+p   lifescience   fund fi  ',
      );

      expect(
        normalized.map((result) => result.isin).toList(),
        canonical.map((result) => result.isin).toList(),
      );
    });

    test('LF-19.1.10 - returns no result for an unknown exact name', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'THIS FUND DOES NOT EXIST IN FONDOS JSON',
      );

      expect(results, isEmpty);
    });

    test('LF-19.1.11 - does not use fuzzy matching', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA',
      );

      expect(results, isEmpty);
    });

    test('LF-19.1.12 - ticker does not affect name-based lookup', () async {
      final withTicker = await provider.resolveAll(
        ticker: 'ABCD',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      final withoutRelevantTicker = await provider.resolveAll(
        ticker: 'XYZ',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(
        withTicker.map((result) => result.isin).toList(),
        withoutRelevantTicker.map((result) => result.isin).toList(),
      );
    });

    test('LF-19.1.13 - all returned ISINs are valid', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      for (final result in results) {
        expect(IsinValidator.isValid(result.isin), isTrue);
      }
    });

    test('LF-19.1.14 - repeated lookup is stable', () async {
      final first = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      final second = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      expect(
        second.map((result) => result.isin).toList(),
        first.map((result) => result.isin).toList(),
      );

      expect(
        second.map((result) => result.officialName).toList(),
        first.map((result) => result.officialName).toList(),
      );
    });
  });
}
