import 'package:flutter_test/flutter_test.dart';

import 'package:investing/services/isin_resolver.dart';
import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';
import 'package:investing/services/isin_providers/fondos_json_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-20.9 IsinResolver + EcbIfsProvider', () {
    test('LF-20.9.1 - EcbIfsProvider can be injected explicitly', () async {
      final resolver = IsinResolver(providers: [EcbIfsProvider()]);

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      expect(resolution.candidates, hasLength(1));
      expect(resolution.candidates.single.isin, 'ES0190056004');

      resolver.dispose();
    });

    test('LF-20.9.2 - default resolver includes ECB/IFS results', () async {
      final resolver = IsinResolver();

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
      );

      final ecbCandidates = resolution.candidates.where(
        (candidate) =>
            candidate.evidence.any((evidence) => evidence.source == 'ECB/IFS'),
      );

      expect(ecbCandidates, hasLength(1));
      expect(ecbCandidates.single.isin, 'ES0190056004');

      resolver.dispose();
    });

    test('LF-20.9.3 - resolve() keeps Fondos JSON ahead of ECB/IFS', () async {
      final resolver = IsinResolver();

      final result = await resolver.resolve(
        ticker: 'ANY',
        fundName: 'CAIXABANK BONOS SUBORDINADOS, FI',
      );

      expect(result, isNotNull);

      // Fondos JSON must remain ahead of ECB/IFS.
      expect(result!.source, 'fondos.json');
      expect(result.isin, 'ES0145883007');

      resolver.dispose();
    });

    test(
      'LF-20.9.4 - resolveAll() aggregates Fondos JSON and ECB/IFS',
      () async {
        final resolver = IsinResolver();

        final resolution = await resolver.resolveAll(
          ticker: 'ANY',
          fundName: 'CAIXABANK BONOS SUBORDINADOS, FI',
        );

        final isins = resolution.candidates
            .map((candidate) => candidate.isin)
            .toList();

        expect(isins, [
          'ES0145883007',
          'ES0145883015',
          'ES0145883023',
          'ES0145883031',
        ]);

        resolver.dispose();
      },
    );

    test('LF-20.9.5 - ECB/IFS evidence is retained in its candidate', () async {
      final resolver = IsinResolver();

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'CAIXABANK BONOS SUBORDINADOS, FI',
      );

      final ecbCandidate = resolution.candidates.firstWhere(
        (candidate) => candidate.isin == 'ES0145883031',
      );

      expect(ecbCandidate.evidence, hasLength(1));
      expect(ecbCandidate.evidence.single.source, 'ECB/IFS');
      expect(
        ecbCandidate.evidence.single.officialName,
        'CAIXABANK BONOS SUBORDINADOS, FI',
      );

      resolver.dispose();
    });

    test('LF-20.9.6 - an ECB-only ISIN survives default aggregation', () async {
      final resolver = IsinResolver();

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'YOSEMITE HEDGE FUND, FIL',
      );

      final isins = resolution.candidates
          .map((candidate) => candidate.isin)
          .toList();

      expect(isins, contains('ES0131446033'));

      final ecbCandidate = resolution.candidates.firstWhere(
        (candidate) => candidate.isin == 'ES0131446033',
      );

      expect(ecbCandidate.evidence, hasLength(1));
      expect(ecbCandidate.evidence.single.source, 'ECB/IFS');

      resolver.dispose();
    });

    test(
      'LF-20.9.7 - explicit provider injection does not add default providers',
      () async {
        final resolver = IsinResolver(providers: [FondosJsonProvider()]);

        final resolution = await resolver.resolveAll(
          ticker: 'ANY',
          fundName: '4FOUNDERS CAPITAL FUND III, F.C.R.E.',
        );

        expect(resolution.candidates, isEmpty);

        resolver.dispose();
      },
    );

    test('LF-20.9.8 - same ECB ISIN is represented by one candidate', () async {
      final resolver = IsinResolver();

      final resolution = await resolver.resolveAll(
        ticker: 'ANY',
        fundName: 'CAIXABANK BONOS SUBORDINADOS, FI',
      );

      final matchingCandidates = resolution.candidates.where(
        (candidate) => candidate.isin == 'ES0145883031',
      );

      expect(matchingCandidates, hasLength(1));

      resolver.dispose();
    });
  });
}
