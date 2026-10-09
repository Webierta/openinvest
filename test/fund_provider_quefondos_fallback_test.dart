import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/scraper_result.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:investing/utils/app_error.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'fund_provider_quefondos_test_',
    );
    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  test(
    'fetchFundMatch usa el NAV posterior de QueFondos al dar de alta',
    () async {
      const reportedIsin = 'ES0146722014';
      const match = FundSearchMatch(
        isin: reportedIsin,
        symbol: 'ES0146722014',
        name: 'IB Impact Direct Debt',
        source: FundSource.yahoo,
      );
      final primaryFund = FundData(
        isin: reportedIsin,
        symbol: match.symbol,
        name: match.name,
        lastValue: 0.000009,
        currency: 'EUR',
        date: DateTime(2024, 6, 18),
        history: const [],
      );
      final provider = FundProvider(
        fundSearchFetcher: (_) async =>
            ScrapeResult(data: primaryFund, source: FundSource.yahoo),
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'IB IMPACT DIRECT DEBT, FIL B',
          valorLiquidativo: '0,000010',
          fecha: '20/06/2024',
          divisa: 'EUR',
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.data, isNotNull);
      expect(result.data!.lastValue, 0.000010);
      expect(result.data!.date, DateTime(2024, 6, 20));
    },
  );

  test(
    'consulta QueFondos aunque Yahoo coincida con el valor de cartera',
    () async {
      final existing = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo existente',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 4),
        history: const [],
      );
      await DatabaseService.saveFund(existing);

      var queFondosCalls = 0;
      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(data: existing),
        queFondosFetcher: (_) async {
          queFondosCalls++;
          return const ScraperResult(
            nombre: 'Nombre oficial',
            valorLiquidativo: '102,75',
            fecha: '06/10/2026',
            divisa: 'EUR',
          );
        },
      )..portfolio = [existing];

      await provider.updateAllPortfolio();

      final updated = await DatabaseService.getFund(isin);
      expect(queFondosCalls, 1);
      expect(updated, isNotNull);
      expect(updated!.lastValue, 102.75);
      expect(updated.date, DateTime(2026, 10, 6));
    },
  );

  test(
    'fetchFundOnly usa QueFondos si la consulta principal no trae NAV',
    () async {
      const reportedIsin = 'ES0146722014';
      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(),
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'IB IMPACT DIRECT DEBT, FIL B',
          valorLiquidativo: '0,000010',
          fecha: '20/06/2024',
          divisa: 'EUR',
        ),
      );

      final result = await provider.fetchFundOnly(reportedIsin);

      expect(result.data, isNotNull);
      expect(result.data!.lastValue, 0.000010);
      expect(result.data!.date, DateTime(2024, 6, 20));
    },
  );

  test('usa FT si QueFondos devuelve un resultado incompleto', () async {
    var ftCalls = 0;
    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      queFondosFetcher: (_) async =>
          const ScraperResult(nombre: 'Fondo sin cotización'),
      ftFetcher: (_) async {
        ftCalls++;
        return const ScraperResult(
          nombre: 'Fondo recuperado por FT',
          valorLiquidativo: '12.34',
          fecha: '06/10/2026',
          divisa: 'EUR',
        );
      },
    );

    final result = await provider.fetchFundOnly(isin);

    expect(ftCalls, 1);
    expect(result.data, isNotNull);
    expect(result.data!.lastValue, 12.34);
    expect(result.data!.date, DateTime(2026, 10, 6));
  });

  test('no reintenta FT si el fallback lanza una excepción', () async {
    var ftCalls = 0;
    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async {
        ftCalls++;
        throw Exception('FT no disponible');
      },
    );

    final result = await provider.fetchFundOnly(isin);

    expect(ftCalls, 1);
    expect(result.data, isNull);
    expect(result.error, isNotNull);
  });

  test('fetchFundMatch usa QueFondos si el fetch principal falla', () async {
    const reportedIsin = 'ES0146722014';
    const match = FundSearchMatch(
      isin: reportedIsin,
      symbol: 'ES0146722014',
      name: 'IB Impact Direct Debt',
      source: FundSource.yahoo,
    );
    final provider = FundProvider(
      fundSearchFetcher: (_) async =>
          ScrapeResult(error: AppError.notFound('ISIN no encontrado.')),
      queFondosFetcher: (_) async => const ScraperResult(
        nombre: 'IB IMPACT DIRECT DEBT, FIL B',
        valorLiquidativo: '0,000010',
        fecha: '20/06/2024',
        divisa: 'EUR',
      ),
    );

    final result = await provider.fetchFundMatch(match);

    expect(result.data, isNotNull);
    expect(result.data!.isin, reportedIsin);
    expect(result.data!.lastValue, 0.000010);
    expect(result.data!.date, DateTime(2024, 6, 20));
    expect(result.error, isNull);
  });

  test('usa QueFondos si Yahoo devuelve una valoración más antigua', () async {
    final existing = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo existente',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 4),
      history: [PricePoint(DateTime(2026, 10, 3), 99)],
      alertMin: 80,
    );
    await DatabaseService.saveFund(existing);

    final staleFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo anterior',
      lastValue: 98,
      currency: 'EUR',
      date: DateTime(2026, 10, 2),
      history: [PricePoint(DateTime(2026, 10, 2), 98)],
    );
    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: staleFund),
      queFondosFetcher: (_) async => const ScraperResult(
        nombre: 'Nombre oficial',
        valorLiquidativo: '102,75',
        fecha: '06/10/2026',
        divisa: 'EUR',
      ),
    )..portfolio = [existing];

    await provider.updateAllPortfolio();

    final updated = await DatabaseService.getFund(isin);
    expect(updated, isNotNull);
    expect(updated!.lastValue, 102.75);
    expect(updated.date, DateTime(2026, 10, 6));
    expect(updated.name, 'Nombre oficial');
    expect(updated.alertMin, 80);
    expect(
      updated.history.map((point) => point.date),
      contains(DateTime(2026, 10, 3)),
    );
    expect(
      updated.history.map((point) => point.date),
      contains(DateTime(2026, 10, 6)),
    );
  });

  test(
    'usa QueFondos cuando la consulta principal no devuelve datos',
    () async {
      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(),
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'Fondo recuperado',
          valorLiquidativo: '1.234,56',
          fecha: '06/10/2026',
          divisa: 'EUR',
        ),
      );

      expect(await provider.searchFund(isin), isTrue);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.lastValue, 1234.56);
      expect(saved.date, DateTime(2026, 10, 6));
    },
  );

  test('persiste el NAV fraccionario de ES0146722014', () async {
    const reportedIsin = 'ES0146722014';
    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      queFondosFetcher: (_) async => const ScraperResult(
        nombre: 'IB IMPACT DIRECT DEBT, FIL B',
        valorLiquidativo: '0,000010',
        fecha: '20/06/2024',
        divisa: 'EUR',
      ),
    );

    expect(await provider.searchFund(reportedIsin), isTrue);

    final saved = await DatabaseService.getFund(reportedIsin);
    expect(saved, isNotNull);
    expect(saved!.lastValue, 0.000010);
    expect(saved.date, DateTime(2024, 6, 20));
  });

  test(
    'no reemplaza el valor si QueFondos no aporta una fecha posterior',
    () async {
      final existing = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo existente',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 5),
        history: const [],
      );
      await DatabaseService.saveFund(existing);

      final staleFund = FundData(
        isin: isin,
        symbol: 'TEST',
        name: 'Fondo anterior',
        lastValue: 98,
        currency: 'EUR',
        date: DateTime(2026, 10, 2),
        history: [PricePoint(DateTime(2026, 10, 2), 98)],
      );
      final provider = FundProvider(
        fundIsinFetcher: (_) async => ScrapeResult(data: staleFund),
        queFondosFetcher: (_) async => const ScraperResult(
          nombre: 'Valor desfasado',
          valorLiquidativo: '110,00',
          fecha: '05/10/2026',
          divisa: 'EUR',
        ),
      )..portfolio = [existing];

      await provider.updateAllPortfolio();

      final unchanged = await DatabaseService.getFund(isin);
      expect(unchanged, isNotNull);
      expect(unchanged!.lastValue, 100);
      expect(unchanged.date, DateTime(2026, 10, 5));
    },
  );

  test('no muestra “ya actualizado” si el fondo sigue sin NAV', () async {
    final existing = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Fondo sin datos',
      lastValue: 0,
      currency: 'EUR',
      date: DateTime(2026, 10, 5),
      history: const [],
    );
    await DatabaseService.saveFund(existing);

    final provider = FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
    );

    expect(await provider.searchFund(isin), isFalse);
    expect(provider.info, isNull);
    expect(
      provider.error,
      'QueFondos y Financial Times no devolvieron una valoración válida.',
    );
  });
}
