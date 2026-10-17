import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';
import 'package:investing/services/isin_resolver.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FixedIsinSourceProvider implements IsinSourceProvider {
  _FixedIsinSourceProvider({
    required this.resolvedIsin,
    required this.resolutionSource,
  });

  final String resolvedIsin;
  final String resolutionSource;

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    return IsinResult(
      isin: resolvedIsin,
      source: resolutionSource,
      officialName: fundName,
    );
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    return [
      IsinResult(
        isin: resolvedIsin,
        source: resolutionSource,
        officialName: fundName,
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_source_preservation_lf42_test_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundData fund({
    String fundIsin = '',
    FundSource? source,
    FundSource? valuationSource,
    double value = 100,
    DateTime? date,
  }) {
    final valuationDate = date ?? DateTime(2026, 10, 1);

    return FundData(
      isin: fundIsin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: value,
      currency: 'EUR',
      date: valuationDate,
      history: [PricePoint(valuationDate, value)],
      source: source,
      valuationSource: valuationSource,
    );
  }

  FundProvider providerWithResolution({
    required FundData initialFund,
    required String resolutionSource,
    required Future<ScraperResult?> Function(String) queFondosFetcher,
    required Future<ScraperResult?> Function(String) ftFetcher,
  }) {
    return FundProvider(
      isinResolverFactory: () => IsinResolver(
        providers: [
          _FixedIsinSourceProvider(
            resolvedIsin: isin,
            resolutionSource: resolutionSource,
          ),
        ],
      ),
      fundSearchFetcher: (_) async => ScrapeResult(data: initialFund),
      queFondosFetcher: queFondosFetcher,
      ftFetcher: ftFetcher,
      ftByIsinFetcher: (_) async => null,
    );
  }

  test(
    'LF-42.1: asigna la fuente ECB al resolver un fondo sin origen previo',
    () async {
      final provider = providerWithResolution(
        initialFund: fund(),
        resolutionSource: 'ECB/IFS',
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '110',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(
        FundSearchMatch(isin: null, symbol: 'TEST', name: 'Test Fund'),
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, isin);
      expect(result.data!.source, FundSource.ecb);
      expect(result.data!.valuationSource, FundSource.queFondos);
      expect(result.data!.lastValue, 110);
      expect(result.data!.date, DateTime(2026, 10, 3));
    },
  );

  test(
    'LF-42.2: asigna la fuente Yahoo al resolver un fondo sin origen previo',
    () async {
      final provider = providerWithResolution(
        initialFund: fund(),
        resolutionSource: 'Yahoo',
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '112',
          fecha: '03/10/2026',
          divisa: 'EUR',
        ),
        ftFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(
        FundSearchMatch(isin: null, symbol: 'TEST', name: 'Test Fund'),
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, isin);
      expect(result.data!.source, FundSource.yahoo);
      expect(result.data!.valuationSource, FundSource.queFondos);
      expect(result.data!.lastValue, 112);
      expect(result.data!.date, DateTime(2026, 10, 3));
    },
  );

  test(
    'LF-42.3: conserva el origen previo aunque el resolver indique ECB',
    () async {
      final provider = providerWithResolution(
        initialFund: fund(source: FundSource.cnmv),
        resolutionSource: 'ECB/IFS',
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'Test Fund',
          valorLiquidativo: '115',
          fecha: '04/10/2026',
          divisa: 'EUR',
        ),
        ftFetcher: (_) async => null,
      );

      final result = await provider.fetchFundMatch(
        FundSearchMatch(isin: null, symbol: 'TEST', name: 'Test Fund'),
      );

      expect(result.data, isNotNull);
      expect(result.data!.isin, isin);
      expect(result.data!.source, FundSource.cnmv);
      expect(result.data!.valuationSource, FundSource.queFondos);
      expect(result.data!.lastValue, 115);
      expect(result.data!.date, DateTime(2026, 10, 4));
    },
  );

  test('LF-42.4: conserva la fuente de resolución ECB con valoración de Financial Times', () async {
    final provider = providerWithResolution(
      initialFund: fund(),
      resolutionSource: 'ECB/IFS',
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => const ScraperResult(
        nombre: 'Test Fund',
        valorLiquidativo: '120',
        fecha: '05/10/2026',
        divisa: 'EUR',
      ),
    );

    final result = await provider.fetchFundMatch(
      FundSearchMatch(isin: null, symbol: 'TEST', name: 'Test Fund'),
    );

    expect(result.data, isNotNull);
    expect(result.data!.isin, isin);
    expect(result.data!.source, FundSource.ecb);
    expect(result.data!.valuationSource, FundSource.financialTimes);
    expect(result.data!.lastValue, 120);
    expect(result.data!.date, DateTime(2026, 10, 5));
  });
}
