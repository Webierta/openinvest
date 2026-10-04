import 'package:flutter_test/flutter_test.dart';

import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/services/isin_providers/ecb_ifs_provider.dart';
import 'package:investing/utils/app_error.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const funds = <Map<String, String>>[
    {'isin': 'ES0160483014', 'name': 'MAPFRE PRIVATE EQUITY I FCR'},
    {'isin': 'ES0165272008', 'name': 'NARA HEALTH CAPITAL, FCR'},
    {'isin': 'ES0182124026', 'name': 'ACP MULTIACTIVO I FCR'},
    {'isin': 'ES0164719009', 'name': 'FONDO AXON INNOVATION GROWTH FCR'},
    {
      'isin': 'ES0157103070',
      'name': 'ALTAMAR X GLOBAL PRIVATE EQUITY PROGRAM, FCR',
    },
  ];

  group('LF-20.12.4.6.3 — Cobertura de fondos ECB exclusivos', () {
    test(
      'los cinco fondos ECB exclusivos están presentes en ECB/IFS',
      () async {
        final provider = EcbIfsProvider();

        for (final fund in funds) {
          final result = await provider.resolveByIsin(fund['isin']!);

          expect(
            result,
            isNotNull,
            reason: 'No se encontró ${fund['isin']} en ECB/IFS',
          );

          expect(result!.isin, fund['isin']);
          expect(result.source, 'ECB/IFS');
          expect(result.officialName, fund['name']);
        }
      },
    );

    test(
      'FundProvider recupera los cinco fondos mediante el fallback ECB/IFS',
      () async {
        for (final fund in funds) {
          final provider = FundProvider(
            fundIsinFetcher: (_) async =>
                ScrapeResult(error: AppError.notFound('ISIN no encontrado.')),
          );

          final result = await provider.fetchFundOnly(fund['isin']!);

          expect(
            result.error,
            isNull,
            reason: 'Error resolviendo ${fund['isin']}',
          );
          expect(result.data, isNotNull);

          final data = result.data!;

          expect(data.isin, fund['isin']);
          expect(data.name, fund['name']);

          expect(
            data.symbol,
            isEmpty,
            reason: '${fund['isin']} no debería tener símbolo Yahoo',
          );
          expect(
            data.lastValue,
            0,
            reason: '${fund['isin']} no debería tener cotización',
          );
          expect(
            data.history,
            isEmpty,
            reason: '${fund['isin']} no debería tener histórico',
          );

          expect(result.isResolved, isTrue);
          expect(result.source, FundSource.ecb);
        }
      },
    );
  });
}
