import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';
import 'package:investing/utils/isin_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EcbIfsProvider provider;

  setUp(() {
    provider = EcbIfsProvider();
  });

  group('LF-20.7 EcbIfsProvider', () {
    test('LF-20.7.1 - resolves a known ECB record', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0190056004');
    });

    test('LF-20.7.2 - resolve returns the first ECB result', () async {
      final all = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final result = await provider.resolve(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(result, isNotNull);
      expect(result!.isin, all.first.isin);
    });

    test('LF-20.7.3 - returns no result for an unknown exact name', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'THIS FUND DOES NOT EXIST IN ECB IFS',
      );

      expect(results, isEmpty);
    });

    test('LF-20.7.4 - resolve returns null for an unknown name', () async {
      final result = await provider.resolve(
        ticker: 'ANY',
        fundName: 'THIS FUND DOES NOT EXIST IN ECB IFS',
      );

      expect(result, isNull);
    });

    test('LF-20.7.5 - normalizes case', () async {
      final canonical = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final normalized = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4founders capital fund iii, f.c.r.e.',
      );

      expect(
        normalized.map((result) => result.isin).toList(),
        canonical.map((result) => result.isin).toList(),
      );
    });

    test('LF-20.7.6 - normalizes punctuation and spacing', () async {
      final canonical = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final normalized = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '  4founders   capital fund iii f c r e  ',
      );

      expect(
        normalized.map((result) => result.isin).toList(),
        canonical.map((result) => result.isin).toList(),
      );
    });

    test('LF-20.7.7 - ticker does not affect name-based lookup', () async {
      final results1 = await provider.resolveAll(
        ticker: 'SL1234.MC',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final results2 = await provider.resolveAll(
        ticker: 'XYZ.TEST',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final results3 = await provider.resolveAll(
        ticker: '',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(
        results2.map((result) => result.isin).toList(),
        results1.map((result) => result.isin).toList(),
      );

      expect(
        results3.map((result) => result.isin).toList(),
        results1.map((result) => result.isin).toList(),
      );
    });

    test('LF-20.7.8 - supports one name mapped to multiple ISINs', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'GLOBAL EQUITY FUND',
      );

      expect(results, hasLength(4));
    });

    test('LF-20.7.9 - preserves all distinct ISINs for a 1:N name', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'GLOBAL EQUITY FUND',
      );

      final isins = results.map((result) => result.isin).toList();

      expect(isins.toSet(), hasLength(4));
      expect(isins, hasLength(4));
    });

    test('LF-20.7.10 - preserves stable source order', () async {
      final first = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'GLOBAL EQUITY FUND',
      );

      final second = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'GLOBAL EQUITY FUND',
      );

      expect(
        second.map((result) => result.isin).toList(),
        first.map((result) => result.isin).toList(),
      );
    });

    test('LF-20.7.11 - returns valid ISINs', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'GLOBAL EQUITY FUND',
      );

      for (final result in results) {
        expect(IsinValidator.isValid(result.isin), isTrue);
      }
    });

    test('LF-20.7.12 - identifies the source as ECB/IFS', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(results.map((result) => result.source).toSet(), {'ECB/IFS'});
    });

    test('LF-20.7.13 - preserves the official ECB name', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(
        results.single.officialName,
        '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );
    });

    test('LF-20.7.14 - resolves Yosemite ECB class', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName: 'YOSEMITE HEDGE FUND, FIL',
      );

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0131446033');
    });

    test('LF-20.7.15 - resolves Gestión Boutique VI ECB class', () async {
      final results = await provider.resolveAll(
        ticker: 'ANY',
        fundName:
            'GESTION BOUTIQUE VI, FI/GESTION BOUTIQUE VI / GESTIVALUE CAPITAL',
      );

      expect(results, hasLength(1));
      expect(results.single.isin, 'ES0110407154');
    });

    test(
      'LF-20.7.16 - resolves CaixaBank Bonos Subordinados ECB class',
      () async {
        final results = await provider.resolveAll(
          ticker: 'ANY',
          fundName: 'CAIXABANK BONOS SUBORDINADOS, FI',
        );

        expect(results, hasLength(1));
        expect(results.single.isin, 'ES0145883031');
      },
    );

    test(
      'LF-20.7.17 - resolves CaixaBank Selección Futuro Sostenible ECB class',
      () async {
        final results = await provider.resolveAll(
          ticker: 'ANY',
          fundName: 'CAIXABANK SELECCION FUTURO SOSTENIBLE, FI',
        );

        expect(results, hasLength(1));
        expect(results.single.isin, 'ES0184922047');
      },
    );
  });
}
