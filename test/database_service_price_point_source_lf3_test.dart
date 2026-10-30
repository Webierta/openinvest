import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'investing_price_source_test_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  group('LF-3: persistencia del origen de precios', () {
    test(
      'LF-3.1: saveFund y getFund conservan el origen de cada precio',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);
        final date3 = DateTime(2026, 10, 22);

        final fund = FundData(
          isin: 'LF3TEST',
          symbol: 'LF3',
          name: 'Fund Source Test',
          lastValue: 120.0,
          currency: 'EUR',
          date: date3,
          history: [
            PricePoint(date1, 100.0, source: PricePointSource.yahoo),
            PricePoint(date2, 110.0, source: PricePointSource.manual),
            PricePoint(date3, 120.0, source: PricePointSource.cnmv),
          ],
        );

        await DatabaseService.saveFund(fund);

        final restored = await DatabaseService.getFund('LF3TEST');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(3));

        expect(restored.history[0].price, 100.0);
        expect(restored.history[0].source, PricePointSource.yahoo);

        expect(restored.history[1].price, 110.0);
        expect(restored.history[1].source, PricePointSource.manual);

        expect(restored.history[2].price, 120.0);
        expect(restored.history[2].source, PricePointSource.cnmv);
      },
    );

    test('LF-3.2: getPortfolio conserva el origen de cada precio', () async {
      final date1 = DateTime(2026, 10, 20);
      final date2 = DateTime(2026, 10, 21);

      final fund = FundData(
        isin: 'LF3PORTFOLIO',
        symbol: 'LF3P',
        name: 'Portfolio Source Test',
        lastValue: 110.0,
        currency: 'EUR',
        date: date2,
        history: [
          PricePoint(date1, 100.0, source: PricePointSource.yahoo),
          PricePoint(date2, 110.0, source: PricePointSource.manual),
        ],
      );

      await DatabaseService.saveFund(fund);

      final portfolio = await DatabaseService.getPortfolio();

      final restored = portfolio.firstWhere(
        (item) => item.isin == 'LF3PORTFOLIO',
      );

      expect(restored.history, hasLength(2));
      expect(restored.history[0].source, PricePointSource.yahoo);
      expect(restored.history[1].source, PricePointSource.manual);
    });

    test('LF-3.3: los precios antiguos conservan sus datos y tienen origen null tras migrar', () async {
      final oldDbPath = path.join(temporaryDirectory.path, 'legacy_v11.db');

      final oldDb = await databaseFactoryFfi.openDatabase(
        oldDbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE funds (
              isin TEXT PRIMARY KEY,
              symbol TEXT,
              name TEXT,
              last_value REAL,
              currency TEXT,
              last_update TEXT,
              alert_min REAL,
              alert_max REAL,
              ter REAL,
              performance_fee REAL,
              morningstar_rating INTEGER,
              morningstar_checked_at TEXT,
              morningstar_last_attempt_at TEXT,
              source TEXT,
              valuation_source TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE prices (
              isin TEXT,
              date TEXT,
              price REAL,
              PRIMARY KEY (isin, date)
            )
          ''');

            await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              date TEXT,
              type TEXT,
              units REAL,
              price REAL,
              amount REAL
            )
          ''');

            await db.execute('''
            CREATE TABLE fund_cost_periods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              uid TEXT,
              concept TEXT,
              rate_percent REAL,
              basis TEXT,
              treatment TEXT,
              valid_from TEXT,
              valid_to TEXT,
              description TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE fund_cost_charges (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              uid TEXT,
              concept TEXT,
              date TEXT,
              amount REAL,
              description TEXT,
              performance_period_uid TEXT,
              settled_through TEXT
            )
          ''');
          },
        ),
      );

      final legacyDate = DateTime(2026, 10, 20);

      await oldDb.insert('funds', {
        'isin': 'LF3LEGACY',
        'symbol': 'LF3L',
        'name': 'Legacy Fund',
        'last_value': 100.0,
        'currency': 'EUR',
        //'date': legacyDate.toIso8601String(),
        'last_update': legacyDate.toIso8601String(),
      });

      await oldDb.insert('prices', {
        'isin': 'LF3LEGACY',
        'date': legacyDate.toIso8601String(),
        'price': 100.0,
      });

      await oldDb.close();

      await DatabaseService.useDatabasePathForTesting(oldDbPath);

      final restored = await DatabaseService.getFund('LF3LEGACY');

      expect(restored, isNotNull);
      expect(restored!.history, hasLength(1));
      expect(restored.history.first.price, 100.0);
      expect(restored.history.first.source, isNull);
    });

    test(
      'LF-3.4: savePricePoint conserva el origen del precio individual',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3SINGLE',
          symbol: 'LF3S',
          name: 'Single Price Source Test',
          lastValue: 100.0,
          currency: 'EUR',
          date: date1,
          history: [PricePoint(date1, 100.0)],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.savePricePoint(
          'LF3SINGLE',
          PricePoint(date2, 125.0, source: PricePointSource.morningstar),
        );

        final restored = await DatabaseService.getFund('LF3SINGLE');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(2));

        final savedPoint = restored.history.firstWhere(
          (point) => point.date.year == 2026 && point.date.day == 21,
        );

        expect(savedPoint.price, 125.0);
        expect(savedPoint.source, PricePointSource.morningstar);
      },
    );

    test(
      'LF-3.5.1: restorePricePoint conserva el origen del precio restaurado',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3RESTORE',
          symbol: 'LF3R',
          name: 'Restore Price Source Test',
          lastValue: 100.0,
          currency: 'EUR',
          date: date1,
          history: [PricePoint(date1, 100.0)],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.restorePricePoint(
          'LF3RESTORE',
          PricePoint(date2, 125.0, source: PricePointSource.financialTimes),
        );

        final restored = await DatabaseService.getFund('LF3RESTORE');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(2));

        final savedPoint = restored.history.firstWhere(
          (point) => point.date.day == 21,
        );

        expect(savedPoint.price, 125.0);
        expect(savedPoint.source, PricePointSource.financialTimes);
      },
    );

    test(
      'LF-3.5.2: restorePricePoints conserva los orígenes de varios precios',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);
        final date3 = DateTime(2026, 10, 22);

        final fund = FundData(
          isin: 'LF3RESTOREMULTI',
          symbol: 'LF3RM',
          name: 'Restore Multiple Price Sources Test',
          lastValue: 100.0,
          currency: 'EUR',
          date: date1,
          history: [PricePoint(date1, 100.0)],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.restorePricePoints('LF3RESTOREMULTI', [
          PricePoint(date2, 110.0, source: PricePointSource.yahoo),
          PricePoint(date3, 120.0, source: PricePointSource.financialTimes),
        ]);

        final restored = await DatabaseService.getFund('LF3RESTOREMULTI');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(3));

        final yahooPoint = restored.history.firstWhere(
          (point) => point.date.day == 21,
        );
        final financialTimesPoint = restored.history.firstWhere(
          (point) => point.date.day == 22,
        );

        expect(yahooPoint.price, 110.0);
        expect(yahooPoint.source, PricePointSource.yahoo);

        expect(financialTimesPoint.price, 120.0);
        expect(financialTimesPoint.source, PricePointSource.financialTimes);
      },
    );

    test(
      'LF-3.6.1: restaurar un precio existente sustituye también su origen',
      () async {
        final date = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3REPLACE',
          symbol: 'LF3RP',
          name: 'Replace Price Source Test',
          lastValue: 100.0,
          currency: 'EUR',
          date: date,
          history: [PricePoint(date, 100.0, source: PricePointSource.yahoo)],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.restorePricePoint(
          'LF3REPLACE',
          PricePoint(date, 125.0, source: PricePointSource.financialTimes),
        );

        final restored = await DatabaseService.getFund('LF3REPLACE');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(1));
        expect(restored.history.single.price, 125.0);
        expect(restored.history.single.source, PricePointSource.financialTimes);
      },
    );

    test('LF-3.7.1: restaurar precios en A no modifica el historial ni el origen de B', () async {
      final date1 = DateTime(2026, 10, 20);
      final date2 = DateTime(2026, 10, 21);

      final fundA = FundData(
        isin: 'LF3ISOLATIONA',
        symbol: 'LF3A',
        name: 'Isolation Fund A',
        lastValue: 100.0,
        currency: 'EUR',
        date: date1,
        history: [PricePoint(date1, 100.0)],
      );

      final fundB = FundData(
        isin: 'LF3ISOLATIONB',
        symbol: 'LF3B',
        name: 'Isolation Fund B',
        lastValue: 200.0,
        currency: 'EUR',
        date: date1,
        history: [
          PricePoint(date1, 200.0, source: PricePointSource.morningstar),
        ],
      );

      await DatabaseService.saveFund(fundA);
      await DatabaseService.saveFund(fundB);

      await DatabaseService.restorePricePoint(
        'LF3ISOLATIONA',
        PricePoint(date2, 125.0, source: PricePointSource.financialTimes),
      );

      final restoredA = await DatabaseService.getFund('LF3ISOLATIONA');
      final restoredB = await DatabaseService.getFund('LF3ISOLATIONB');

      expect(restoredA, isNotNull);
      expect(restoredA!.history, hasLength(2));
      expect(restoredA.history.last.price, 125.0);
      expect(restoredA.history.last.source, PricePointSource.financialTimes);

      expect(restoredB, isNotNull);
      expect(restoredB!.history, hasLength(1));
      expect(restoredB.history.single.price, 200.0);
      expect(restoredB.history.single.source, PricePointSource.morningstar);
      expect(restoredB.lastValue, 200.0);
    });

    test(
      'LF-3.8.1: restaurar un precio sin origen elimina el origen anterior',
      () async {
        final date = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3NULLSOURCE',
          symbol: 'LF3NS',
          name: 'Null Price Source Test',
          lastValue: 100.0,
          currency: 'EUR',
          date: date,
          history: [PricePoint(date, 100.0, source: PricePointSource.yahoo)],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.restorePricePoint(
          'LF3NULLSOURCE',
          PricePoint(date, 125.0),
        );

        final restored = await DatabaseService.getFund('LF3NULLSOURCE');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(1));
        expect(restored.history.single.price, 125.0);
        expect(restored.history.single.source, isNull);
      },
    );

    test('LF-3.9.1: getPortfolio conserva los orígenes de precios de varios fondos', () async {
      final date1 = DateTime(2026, 10, 20);
      final date2 = DateTime(2026, 10, 21);

      final fundA = FundData(
        isin: 'LF3PORTFOLIOA',
        symbol: 'LF3PA',
        name: 'Portfolio Fund A',
        lastValue: 110.0,
        currency: 'EUR',
        date: date2,
        history: [
          PricePoint(date1, 100.0),
          PricePoint(date2, 110.0, source: PricePointSource.yahoo),
        ],
      );

      final fundB = FundData(
        isin: 'LF3PORTFOLIOB',
        symbol: 'LF3PB',
        name: 'Portfolio Fund B',
        lastValue: 220.0,
        currency: 'EUR',
        date: date2,
        history: [
          PricePoint(date1, 200.0, source: PricePointSource.morningstar),
          PricePoint(date2, 220.0, source: PricePointSource.financialTimes),
        ],
      );

      await DatabaseService.saveFund(fundA);
      await DatabaseService.saveFund(fundB);

      final portfolio = await DatabaseService.getPortfolio();

      final restoredA = portfolio.firstWhere(
        (fund) => fund.isin == 'LF3PORTFOLIOA',
      );
      final restoredB = portfolio.firstWhere(
        (fund) => fund.isin == 'LF3PORTFOLIOB',
      );

      expect(restoredA.history, hasLength(2));
      expect(restoredA.history[0].source, isNull);
      expect(restoredA.history[1].source, PricePointSource.yahoo);

      expect(restoredB.history, hasLength(2));
      expect(restoredB.history[0].source, PricePointSource.morningstar);
      expect(restoredB.history[1].source, PricePointSource.financialTimes);
    });

    test(
      'LF-3.10.1: los orígenes sobreviven al cerrar y reabrir la base de datos',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3REOPEN',
          symbol: 'LF3RO',
          name: 'Database Reopen Test',
          lastValue: 120.0,
          currency: 'EUR',
          date: date2,
          history: [
            PricePoint(date1, 100.0),
            PricePoint(date2, 120.0, source: PricePointSource.yahoo),
          ],
        );

        await DatabaseService.saveFund(fund);

        // Cerramos la conexión SQLite, pero conservamos el archivo.
        await DatabaseService.close();

        // Recuperamos el fondo mediante una nueva conexión.
        final restored = await DatabaseService.getFund('LF3REOPEN');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(2));
        expect(restored.history[0].source, isNull);
        expect(restored.history[1].source, PricePointSource.yahoo);
        expect(restored.history[0].price, 100.0);
        expect(restored.history[1].price, 120.0);
      },
    );

    test('LF-3.11.1: la migración conserva los historiales de varios fondos y deja sus orígenes en null', () async {
      final oldDbPath = path.join(temporaryDirectory.path, 'legacy_v11.db');

      final oldDb = await databaseFactoryFfi.openDatabase(
        oldDbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE funds (
              isin TEXT PRIMARY KEY,
              symbol TEXT,
              name TEXT,
              last_value REAL,
              currency TEXT,
              last_update TEXT,
              alert_min REAL,
              alert_max REAL,
              ter REAL,
              performance_fee REAL,
              morningstar_rating INTEGER,
              morningstar_checked_at TEXT,
              morningstar_last_attempt_at TEXT,
              source TEXT,
              valuation_source TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE prices (
              isin TEXT,
              date TEXT,
              price REAL,
              PRIMARY KEY (isin, date)
            )
          ''');

            await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              date TEXT,
              type TEXT,
              units REAL,
              price REAL,
              amount REAL
            )
          ''');

            await db.execute('''
            CREATE TABLE fund_cost_periods (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              uid TEXT,
              concept TEXT,
              rate_percent REAL,
              basis TEXT,
              treatment TEXT,
              valid_from TEXT,
              valid_to TEXT,
              description TEXT
            )
          ''');

            await db.execute('''
            CREATE TABLE fund_cost_charges (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              uid TEXT,
              concept TEXT,
              date TEXT,
              amount REAL,
              description TEXT,
              performance_period_uid TEXT,
              settled_through TEXT
            )
          ''');
          },
        ),
      );

      final dates = [DateTime(2026, 10, 19), DateTime(2026, 10, 20)];

      final legacyFunds = [
        {
          'isin': 'LF3LEGACY_A',
          'symbol': 'LF3LA',
          'name': 'Legacy Fund A',
          'last_value': 110.0,
          'currency': 'EUR',
        },
        {
          'isin': 'LF3LEGACY_B',
          'symbol': 'LF3LB',
          'name': 'Legacy Fund B',
          'last_value': 220.0,
          'currency': 'EUR',
        },
      ];

      for (final fund in legacyFunds) {
        await oldDb.insert('funds', {
          ...fund,
          'last_update': dates.last.toIso8601String(),
        });
      }

      final legacyPrices = [
        ('LF3LEGACY_A', dates[0], 100.0),
        ('LF3LEGACY_A', dates[1], 110.0),
        ('LF3LEGACY_B', dates[0], 200.0),
        ('LF3LEGACY_B', dates[1], 220.0),
      ];

      for (final entry in legacyPrices) {
        await oldDb.insert('prices', {
          'isin': entry.$1,
          'date': entry.$2.toIso8601String(),
          'price': entry.$3,
        });
      }

      await oldDb.close();

      await DatabaseService.useDatabasePathForTesting(oldDbPath);

      final restoredA = await DatabaseService.getFund('LF3LEGACY_A');
      final restoredB = await DatabaseService.getFund('LF3LEGACY_B');

      expect(restoredA, isNotNull);
      expect(restoredB, isNotNull);

      expect(restoredA!.history, hasLength(2));
      expect(restoredB!.history, hasLength(2));

      expect(restoredA.history.map((point) => point.price).toList(), [
        100.0,
        110.0,
      ]);
      expect(restoredB.history.map((point) => point.price).toList(), [
        200.0,
        220.0,
      ]);

      expect(restoredA.history.every((point) => point.source == null), isTrue);
      expect(restoredB.history.every((point) => point.source == null), isTrue);
    });

    test(
      'LF-3.12.1: reabrir una base de datos v12 conserva precios y orígenes',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);

        final fund = FundData(
          isin: 'LF3IDEMPOTENT',
          symbol: 'LF3ID',
          name: 'Migration Idempotence Test',
          lastValue: 120.0,
          currency: 'EUR',
          date: date2,
          history: [
            PricePoint(date1, 100.0, source: PricePointSource.yahoo),
            PricePoint(date2, 120.0, source: PricePointSource.financialTimes),
          ],
        );

        await DatabaseService.saveFund(fund);

        // Primera reapertura.
        await DatabaseService.close();

        final firstRestore = await DatabaseService.getFund('LF3IDEMPOTENT');

        expect(firstRestore, isNotNull);
        expect(firstRestore!.history, hasLength(2));
        expect(firstRestore.history[0].source, PricePointSource.yahoo);
        expect(firstRestore.history[1].source, PricePointSource.financialTimes);

        // Segunda reapertura de la misma base de datos.
        await DatabaseService.close();

        final secondRestore = await DatabaseService.getFund('LF3IDEMPOTENT');

        expect(secondRestore, isNotNull);
        expect(secondRestore!.history, hasLength(2));
        expect(secondRestore.history[0].source, PricePointSource.yahoo);
        expect(
          secondRestore.history[1].source,
          PricePointSource.financialTimes,
        );

        expect(secondRestore.history.map((point) => point.price).toList(), [
          100.0,
          120.0,
        ]);
      },
    );

    test(
      'LF-3.13.1: eliminar un fondo borra sus precios sin afectar a los demás',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);

        final fundA = FundData(
          isin: 'LF3DELETEA',
          symbol: 'LF3DA',
          name: 'Delete Fund A',
          lastValue: 110.0,
          currency: 'EUR',
          date: date2,
          history: [
            PricePoint(date1, 100.0, source: PricePointSource.yahoo),
            PricePoint(date2, 110.0, source: PricePointSource.financialTimes),
          ],
        );

        final fundB = FundData(
          isin: 'LF3DELETEB',
          symbol: 'LF3DB',
          name: 'Delete Fund B',
          lastValue: 220.0,
          currency: 'EUR',
          date: date2,
          history: [
            PricePoint(date1, 200.0, source: PricePointSource.morningstar),
            PricePoint(date2, 220.0, source: PricePointSource.yahoo),
          ],
        );

        await DatabaseService.saveFund(fundA);
        await DatabaseService.saveFund(fundB);

        await DatabaseService.deleteFund('LF3DELETEA');

        final deletedFund = await DatabaseService.getFund('LF3DELETEA');
        final remainingFund = await DatabaseService.getFund('LF3DELETEB');

        expect(deletedFund, isNull);

        expect(remainingFund, isNotNull);
        expect(remainingFund!.history, hasLength(2));

        expect(remainingFund.history.map((point) => point.price).toList(), [
          200.0,
          220.0,
        ]);

        expect(remainingFund.history.map((point) => point.source).toList(), [
          PricePointSource.morningstar,
          PricePointSource.yahoo,
        ]);
      },
    );

    test(
      'LF-3.14.1: eliminar un precio elimina su origen y conserva los demás',
      () async {
        final date1 = DateTime(2026, 10, 20);
        final date2 = DateTime(2026, 10, 21);
        final date3 = DateTime(2026, 10, 22);

        final fund = FundData(
          isin: 'LF3DELETEPRICE',
          symbol: 'LF3DP',
          name: 'Delete Price Source Test',
          lastValue: 120.0,
          currency: 'EUR',
          date: date3,
          history: [
            PricePoint(date1, 100.0, source: PricePointSource.yahoo),
            PricePoint(date2, 110.0, source: PricePointSource.morningstar),
            PricePoint(date3, 120.0, source: PricePointSource.financialTimes),
          ],
        );

        await DatabaseService.saveFund(fund);

        await DatabaseService.deletePricePoint('LF3DELETEPRICE', date2);

        final restored = await DatabaseService.getFund('LF3DELETEPRICE');

        expect(restored, isNotNull);
        expect(restored!.history, hasLength(2));

        expect(restored.history.map((point) => point.price).toList(), [
          100.0,
          120.0,
        ]);

        expect(restored.history.map((point) => point.source).toList(), [
          PricePointSource.yahoo,
          PricePointSource.financialTimes,
        ]);

        expect(restored.lastValue, 120.0);
      },
    );

    test('LF-3.14.2: eliminar varios precios elimina sus orígenes y conserva los demás', () async {
      final dates = [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
      ];

      final fund = FundData(
        isin: 'LF3DELETEPRICE_MULTI',
        symbol: 'LF3DPM',
        name: 'Delete Multiple Prices Test',
        lastValue: 130.0,
        currency: 'EUR',
        date: dates[3],
        history: [
          PricePoint(dates[0], 100.0, source: PricePointSource.yahoo),
          PricePoint(dates[1], 110.0, source: PricePointSource.morningstar),
          PricePoint(dates[2], 120.0, source: PricePointSource.financialTimes),
          PricePoint(dates[3], 130.0, source: PricePointSource.cnmv),
        ],
      );

      await DatabaseService.saveFund(fund);

      await DatabaseService.deletePricePoints('LF3DELETEPRICE_MULTI', [
        dates[1],
        dates[2],
      ]);

      final restored = await DatabaseService.getFund('LF3DELETEPRICE_MULTI');

      expect(restored, isNotNull);
      expect(restored!.history, hasLength(2));

      expect(restored.history.map((point) => point.price).toList(), [
        100.0,
        130.0,
      ]);

      expect(restored.history.map((point) => point.source).toList(), [
        PricePointSource.yahoo,
        PricePointSource.cnmv,
      ]);

      expect(restored.lastValue, 130.0);
    });
  });

  test(
    'LF-4.1: replaceFund conserva el origen de cada precio histórico',
    () async {
      final date1 = DateTime(2026, 10, 20);
      final date2 = DateTime(2026, 10, 21);

      final fund = FundData(
        isin: 'ES0000000001',
        symbol: 'TEST',
        name: 'Fondo original',
        lastValue: 110.0,
        currency: 'EUR',
        date: date2,
        history: [
          PricePoint(date1, 100.0, source: PricePointSource.yahoo),
          PricePoint(date2, 110.0, source: PricePointSource.cnmv),
        ],
      );

      await DatabaseService.saveFund(fund);

      final replacement = FundData(
        isin: fund.isin,
        symbol: 'TEST',
        name: 'Fondo reemplazado',
        lastValue: 120.0,
        currency: 'EUR',
        date: date2,
        history: [
          PricePoint(date1, 105.0, source: PricePointSource.morningstar),
          PricePoint(date2, 120.0, source: PricePointSource.financialTimes),
        ],
      );

      await DatabaseService.replaceFund(replacement);

      final recovered = await DatabaseService.getFund(fund.isin);

      expect(recovered, isNotNull);
      expect(recovered!.name, 'Fondo reemplazado');
      expect(recovered.history, hasLength(2));

      expect(recovered.history[0].price, 105.0);
      expect(recovered.history[0].source, PricePointSource.morningstar);

      expect(recovered.history[1].price, 120.0);
      expect(recovered.history[1].source, PricePointSource.financialTimes);
    },
  );
}
