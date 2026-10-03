import 'package:flutter_test/flutter_test.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/isin_providers/fondos_json_provider.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-19.3 IsinResolver + FondosJsonProvider', () {
    test('LF-19.3.1 - FondosJsonProvider can be injected explicitly', () async {
      final resolver = IsinResolver(providers: [FondosJsonProvider()]);

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(resolution.candidates, hasLength(2));

      expect(
        resolution.candidates.map((candidate) => candidate.isin).toList(),
        ['ES0124526007', 'ES0124526015'],
      );

      resolver.dispose();
    });

    test(
      'LF-19.3.2 - all three Fondos JSON ISINs survive aggregation',
      () async {
        final resolver = IsinResolver(providers: [FondosJsonProvider()]);

        final resolution = await resolver.resolveAll(
          ticker: 'ANY',
          fundName: 'A&P LIFESCIENCE FUND, FI',
        );

        expect(resolution.candidates, hasLength(3));

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toList(),
          ['ES0162957007', 'ES0162957015', 'ES0162957023'],
        );

        resolver.dispose();
      },
    );

    test(
      'LF-19.3.3 - Fondos JSON evidence is retained in each candidate',
      () async {
        final resolver = IsinResolver(providers: [FondosJsonProvider()]);

        final resolution = await resolver.resolveAll(
          ticker: 'ANY',
          fundName: 'ABACO RENTA FIJA, FI',
        );

        for (final candidate in resolution.candidates) {
          expect(candidate.evidence, hasLength(1));
          expect(candidate.evidence.single.source, 'fondos.json');
          expect(
            candidate.evidence.single.officialName,
            'ABACO RENTA FIJA, FI',
          );
        }

        resolver.dispose();
      },
    );

    test('LF-19.3.4 - Fondos JSON and another source produce separate '
        'candidates for different ISINs', () async {
      final otherIsin = 'LU0123456789';

      final fakeProvider = _FakeProvider(
        results: [
          IsinResult(
            isin: otherIsin,
            source: 'FAKE',
            officialName: 'ABACO RENTA FIJA, FI',
          ),
        ],
      );

      final resolver = IsinResolver(
        providers: [FondosJsonProvider(), fakeProvider],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(resolution.candidates, hasLength(3));

      expect(
        resolution.candidates.map((candidate) => candidate.isin).toList(),
        ['ES0124526007', 'ES0124526015', otherIsin],
      );

      resolver.dispose();
    });

    test('LF-19.3.5 - same ISIN from Fondos JSON and another source is '
        'merged into one candidate', () async {
      const sharedIsin = 'ES0124526007';

      final fakeProvider = _FakeProvider(
        results: [
          IsinResult(
            isin: sharedIsin,
            source: 'FAKE',
            officialName: 'ABACO RENTA FIJA, FI',
            cnmvRegistration: 1234,
          ),
        ],
      );

      final resolver = IsinResolver(
        providers: [FondosJsonProvider(), fakeProvider],
      );

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(resolution.candidates, hasLength(2));

      final sharedCandidate = resolution.candidates.firstWhere(
        (candidate) => candidate.isin == sharedIsin,
      );

      expect(sharedCandidate.evidence, hasLength(2));

      expect(
        sharedCandidate.evidence.map((evidence) => evidence.source).toList(),
        ['fondos.json', 'FAKE'],
      );

      expect(
        sharedCandidate.evidence
            .map((evidence) => evidence.cnmvRegistration)
            .toList(),
        [null, 1234],
      );

      resolver.dispose();
    });

    test(
      'LF-19.3.6 - candidate order follows first source appearance',
      () async {
        final fakeProvider = _FakeProvider(
          results: [
            const IsinResult(
              isin: 'ES0124526015',
              source: 'FAKE',
              officialName: 'ABACO RENTA FIJA, FI',
            ),
            const IsinResult(
              isin: 'ES9999999999',
              source: 'FAKE',
              officialName: 'ABACO RENTA FIJA, FI',
            ),
          ],
        );

        final resolver = IsinResolver(
          providers: [fakeProvider, FondosJsonProvider()],
        );

        final resolution = await resolver.resolveAll(
          ticker: 'ANY',
          fundName: 'ABACO RENTA FIJA, FI',
        );

        expect(
          resolution.candidates.map((candidate) => candidate.isin).toList(),
          ['ES0124526015', 'ES9999999999', 'ES0124526007'],
        );

        resolver.dispose();
      },
    );

    test('LF-19.3.7 - default resolver includes Fondos JSON results', () async {
      final resolver = IsinResolver();

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'A&P LIFESCIENCE FUND, FI',
      );

      final isins = resolution.candidates
          .map((candidate) => candidate.isin)
          .toSet();

      expect(
        isins,
        containsAll(['ES0162957007', 'ES0162957015', 'ES0162957023']),
      );

      resolver.dispose();
    });

    test('LF-19.3.8 - resolve remains first-hit-wins with explicit '
        'Fondos JSON provider', () async {
      final resolver = IsinResolver(providers: [FondosJsonProvider()]);

      final result = await resolver.resolve(
        ticker: 'ANY',
        fundName: 'ABACO RENTA FIJA, FI',
      );

      expect(result, isNotNull);
      expect(result!.isin, 'ES0124526007');

      resolver.dispose();
    });
  });
}

class _FakeProvider implements IsinSourceProvider {
  final List<IsinResult> results;

  const _FakeProvider({required this.results});

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    return results.isEmpty ? null : results.first;
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    return results;
  }
}
