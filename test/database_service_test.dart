import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:investing/services/database_service.dart';
import 'package:investing/models/fund_cost.dart';

import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'investing_database_test_',
    );
    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('eliminar el último precio actualiza el valor vigente', () async {
    final firstDate = DateTime(2026, 9, 1);
    final latestDate = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: latestDate,
      history: [PricePoint(firstDate, 10), PricePoint(latestDate, 20)],
    );
    await DatabaseService.saveFund(fund);

    await DatabaseService.deletePricePoint('TEST', latestDate);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.lastValue, 10);
    expect(storedFund.date, firstDate);
    expect(storedFund.history.map((point) => point.date), [firstDate]);
  });

  test(
    'eliminar y restaurar varios precios conserva el valor vigente',
    () async {
      final dates = [
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      ];
      final points = [
        PricePoint(dates[0], 10),
        PricePoint(dates[1], 20),
        PricePoint(dates[2], 30),
      ];
      await DatabaseService.saveFund(
        FundData(
          isin: 'BATCH',
          symbol: 'BAT',
          name: 'Batch Test Fund',
          lastValue: 30,
          currency: 'EUR',
          date: dates.last,
          history: points,
        ),
      );

      await DatabaseService.deletePricePoints('BATCH', dates.sublist(1));

      var storedFund = await DatabaseService.getFund('BATCH');
      expect(storedFund!.history.map((point) => point.date), [dates.first]);
      expect(storedFund.lastValue, 10);

      await DatabaseService.restorePricePoints('BATCH', points.sublist(1));

      storedFund = await DatabaseService.getFund('BATCH');
      expect(storedFund!.history.map((point) => point.date), dates);
      expect(
        storedFund.history.map((point) => point.price),
        points.map((point) => point.price),
      );
      expect(storedFund.lastValue, 30);
    },
  );

  test('guardar un fondo persiste sus operaciones', () async {
    final date = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
      operations: [
        FundOperation(
          isin: 'TEST',
          date: date,
          type: OperationType.buy,
          units: 3,
          price: 20,
          amount: 60,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.operations, hasLength(1));
    expect(storedFund.operations.single.type, OperationType.buy);
    expect(storedFund.operations.single.amount, 60);
  });

  test('persiste el rating Morningstar y sus fechas', () async {
    final date = DateTime(2026, 9, 2);
    final checkedAt = DateTime(2026, 9, 10, 12);
    final attemptedAt = DateTime(2026, 9, 10, 11);
    await DatabaseService.saveFund(
      FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 20,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 20)],
        morningstarRating: 4,
        morningstarCheckedAt: checkedAt,
        morningstarLastAttemptAt: attemptedAt,
      ),
    );

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund!.morningstarRating, 4);
    expect(storedFund.morningstarCheckedAt, checkedAt);
    expect(storedFund.morningstarLastAttemptAt, attemptedAt);
  });

  test('persiste periodos de costes y cargos externos', () async {
    final date = DateTime(2026, 9, 2);
    final performancePeriod = FundCostPeriod(
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2025, 1, 1),
    );
    final fund = FundData(
      isin: 'COST',
      symbol: 'CST',
      name: 'Cost Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
      costPeriods: [
        FundCostPeriod(
          concept: FundCostConcept.ter,
          ratePercent: 0.5,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2025, 1, 1),
          validTo: DateTime(2025, 12, 31),
        ),
        performancePeriod,
      ],
      costCharges: [
        FundCostCharge(
          concept: FundCostConcept.performance,
          date: date,
          amount: 2.5,
          description: 'Broker fee',
          performancePeriodUid: performancePeriod.uid,
          settledThrough: DateTime(2026, 9, 1),
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final stored = await DatabaseService.getFund('COST');
    expect(stored, isNotNull);
    final savedFund = stored!;
    expect(savedFund.costPeriods, hasLength(2));
    final storedTer = savedFund.costPeriods.firstWhere(
      (period) => period.concept == FundCostConcept.ter,
    );
    expect(storedTer.ratePercent, 0.5);
    expect(storedTer.validFrom, DateTime(2025, 1, 1));
    expect(storedTer.treatment, FundCostTreatment.includedInNav);
    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.amount, 2.5);
    expect(savedFund.costCharges.single.description, 'Broker fee');
    expect(
      savedFund.costCharges.single.performancePeriodUid,
      performancePeriod.uid,
    );
    expect(savedFund.costCharges.single.settledThrough, DateTime(2026, 9, 1));
  });

  test('migra v9 preservando cargos sin atribuir liquidación', () async {
    final databasePath = path.join(temporaryDirectory.path, 'test.db');
    final oldDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 9,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE funds (
              isin TEXT PRIMARY KEY, symbol TEXT, name TEXT, currency TEXT,
              last_value REAL, last_update TEXT, alert_min REAL,
              alert_max REAL, ter REAL, performance_fee REAL,
              morningstar_rating INTEGER, morningstar_checked_at TEXT,
              morningstar_last_attempt_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE prices (
              isin TEXT, date TEXT, price REAL, PRIMARY KEY (isin, date)
            )
          ''');
          await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT, isin TEXT, date TEXT,
              type TEXT, units REAL, price REAL, amount REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE fund_cost_periods (
              id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT, isin TEXT NOT NULL,
              concept TEXT NOT NULL, rate_percent REAL NOT NULL,
              basis TEXT NOT NULL, treatment TEXT NOT NULL,
              valid_from TEXT, valid_to TEXT, description TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE fund_cost_charges (
              id INTEGER PRIMARY KEY AUTOINCREMENT, uid TEXT, isin TEXT NOT NULL,
              concept TEXT NOT NULL, date TEXT NOT NULL, amount REAL NOT NULL,
              description TEXT
            )
          ''');
          await db.insert('funds', {
            'isin': 'V9TEST',
            'symbol': 'V9',
            'name': 'Version Nine Fund',
            'currency': 'EUR',
            'last_value': 20.0,
            'last_update': '2026-09-02T00:00:00.000',
          });
          await db.insert('fund_cost_charges', {
            'uid': 'legacy-charge',
            'isin': 'V9TEST',
            'concept': 'performance',
            'date': '2026-09-01T00:00:00.000',
            'amount': 3.0,
            'description': 'Legacy performance fee',
          });
        },
      ),
    );
    await oldDatabase.close();

    final migrated = await DatabaseService.getFund('V9TEST');

    expect(migrated, isNotNull);
    expect(migrated!.costCharges, hasLength(1));
    expect(migrated.costCharges.single.amount, 3);
    expect(migrated.costCharges.single.performancePeriodUid, isNull);
    expect(migrated.costCharges.single.settledThrough, isNull);
  });

  test(
    'acepta un cargo anterior a hoy aunque el último VL sea más antiguo',
    () async {
      final today = DateTime.now();
      final quoteDate = today.subtract(const Duration(days: 1));
      final fund = FundData(
        isin: 'STALEQUOTE',
        symbol: 'STL',
        name: 'Stale Quote Fund',
        lastValue: 20,
        currency: 'EUR',
        date: quoteDate,
        history: [PricePoint(quoteDate, 20)],
        costCharges: [
          FundCostCharge(
            concept: FundCostConcept.performance,
            date: today,
            amount: 4,
          ),
        ],
      );

      await DatabaseService.saveFund(fund);

      final stored = await DatabaseService.getFund('STALEQUOTE');
      expect(stored!.costCharges.single.date, today);
    },
  );

  test('migra v8 sin inferir fechas para las tasas heredadas', () async {
    final databasePath = path.join(temporaryDirectory.path, 'test.db');
    final oldDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE funds (
              isin TEXT PRIMARY KEY, symbol TEXT, name TEXT, currency TEXT,
              last_value REAL, last_update TEXT, alert_min REAL,
              alert_max REAL, ter REAL, performance_fee REAL,
              morningstar_rating INTEGER, morningstar_checked_at TEXT,
              morningstar_last_attempt_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE prices (
              isin TEXT, date TEXT, price REAL, PRIMARY KEY (isin, date)
            )
          ''');
          await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT, isin TEXT, date TEXT,
              type TEXT, units REAL, price REAL, amount REAL
            )
          ''');
          await db.insert('funds', {
            'isin': 'V8TEST',
            'symbol': 'V8',
            'name': 'Version Eight Fund',
            'currency': 'EUR',
            'last_value': 20.0,
            'last_update': '2026-09-02T00:00:00.000',
            'ter': 0.5,
            'performance_fee': 10.0,
          });
        },
      ),
    );
    await oldDatabase.close();

    final migrated = await DatabaseService.getFund('V8TEST');

    expect(migrated, isNotNull);
    expect(migrated!.costPeriods, hasLength(2));
    final ter = migrated.costPeriods.firstWhere(
      (period) => period.concept == FundCostConcept.ter,
    );
    final performance = migrated.costPeriods.firstWhere(
      (period) => period.concept == FundCostConcept.performance,
    );
    expect(ter.validFrom, isNull);
    expect(ter.treatment, FundCostTreatment.includedInNav);
    expect(performance.validFrom, isNull);
    expect(performance.treatment, FundCostTreatment.unknown);
  });

  test('rechaza tarifas solapadas sin borrar el calendario guardado', () async {
    final start = DateTime(2025, 1, 1);
    final date = DateTime(2026, 9, 2);
    final original = FundData(
      isin: 'OVERLAP',
      symbol: 'OVL',
      name: 'Overlap Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
      costPeriods: [
        FundCostPeriod(
          concept: FundCostConcept.management,
          ratePercent: 0.5,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: start,
          validTo: DateTime(2025, 12, 31),
        ),
      ],
    );
    await DatabaseService.saveFund(original);

    final overlapping = FundData(
      isin: original.isin,
      symbol: original.symbol,
      name: original.name,
      lastValue: original.lastValue,
      currency: original.currency,
      date: original.date,
      history: original.history,
      costPeriods: [
        ...original.costPeriods,
        FundCostPeriod(
          concept: FundCostConcept.management,
          ratePercent: 0.7,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: DateTime(2025, 6, 1),
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(overlapping),
      throwsArgumentError,
    );
    final stored = await DatabaseService.getFund(original.isin);
    expect(stored!.costPeriods, hasLength(1));
    expect(stored.costPeriods.single.ratePercent, 0.5);
  });

  test('importa JSON antiguo sin campos Morningstar', () {
    final date = DateTime(2026, 9, 2);
    final legacyJson =
        FundData(
            isin: 'TEST',
            symbol: 'TST',
            name: 'Test Fund',
            lastValue: 20,
            currency: 'EUR',
            date: date,
            history: [PricePoint(date, 20)],
          ).toJson()
          ..remove('morningstarRating')
          ..remove('morningstarCheckedAt')
          ..remove('morningstarLastAttemptAt');

    final importedFund = FundData.fromJson(legacyJson);

    expect(importedFund.morningstarRating, isNull);
    expect(importedFund.morningstarCheckedAt, isNull);
    expect(importedFund.morningstarLastAttemptAt, isNull);
  });

  test('importa tasas de un JSON antiguo sin inventar su vigencia', () {
    final date = DateTime(2026, 9, 2);
    final legacyJson =
        FundData(
            isin: 'TEST',
            symbol: 'TST',
            name: 'Test Fund',
            lastValue: 20,
            currency: 'EUR',
            date: date,
            history: [PricePoint(date, 20)],
            ter: 0.5,
            performanceFee: 10,
          ).toJson()
          ..remove('costPeriods')
          ..remove('costCharges');

    final imported = FundData.fromJson(legacyJson);

    expect(imported.costPeriods, hasLength(2));
    expect(
      imported.costPeriods.every((period) => period.validFrom == null),
      isTrue,
    );
    expect(
      imported.costPeriods
          .firstWhere((period) => period.concept == FundCostConcept.ter)
          .treatment,
      FundCostTreatment.includedInNav,
    );
    expect(
      imported.costPeriods
          .firstWhere((period) => period.concept == FundCostConcept.performance)
          .treatment,
      FundCostTreatment.unknown,
    );
  });

  test('migra una base de datos v7 conservando sus fondos', () async {
    final databasePath = path.join(temporaryDirectory.path, 'test.db');
    final oldDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 7,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE funds (
              isin TEXT PRIMARY KEY, symbol TEXT, name TEXT, currency TEXT,
              last_value REAL, last_update TEXT, alert_min REAL,
              alert_max REAL, ter REAL, performance_fee REAL
            )
          ''');
          await db.execute('''
            CREATE TABLE prices (
              isin TEXT, date TEXT, price REAL, PRIMARY KEY (isin, date)
            )
          ''');
          await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT, isin TEXT, date TEXT,
              type TEXT, units REAL, price REAL, amount REAL
            )
          ''');
          await db.insert('funds', {
            'isin': 'TEST',
            'symbol': 'TST',
            'name': 'Test Fund',
            'currency': 'EUR',
            'last_value': 20.0,
            'last_update': '2026-09-02T00:00:00.000',
          });
        },
      ),
    );
    await oldDatabase.close();

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.lastValue, 20);
    expect(storedFund.morningstarRating, isNull);
    expect(storedFund.morningstarCheckedAt, isNull);
  });

  test('actualizar las alertas no duplica las operaciones', () async {
    final date = DateTime(2026, 9, 2);
    final operation = FundOperation(
      isin: 'TEST',
      date: date,
      type: OperationType.buy,
      units: 3,
      price: 20,
      amount: 60,
    );
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
      operations: [operation],
    );

    await DatabaseService.saveFund(fund);
    await DatabaseService.saveFund(
      FundData(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        lastValue: fund.lastValue,
        currency: fund.currency,
        date: fund.date,
        history: fund.history,
        operations: [operation],
        alertMin: 10,
        alertMax: 30,
      ),
    );

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund!.alertMin, 10);
    expect(storedFund.alertMax, 30);
    expect(storedFund.operations, hasLength(1));
  });

  test('eliminar el único precio deja el historial vacío', () async {
    final date = DateTime(2026, 9, 2);
    final fund = FundData(
      isin: 'TEST',
      symbol: 'TST',
      name: 'Test Fund',
      lastValue: 20,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 20)],
    );
    await DatabaseService.saveFund(fund);

    await DatabaseService.deletePricePoint('TEST', date);

    final storedFund = await DatabaseService.getFund('TEST');
    expect(storedFund, isNotNull);
    expect(storedFund!.lastValue, 0);
    expect(storedFund.history, isEmpty);
  });

  test(
    'restaurar un precio recupera el historial y el valor vigente',
    () async {
      final firstDate = DateTime(2026, 9, 1);
      final latestDate = DateTime(2026, 9, 2);
      final deletedPoint = PricePoint(latestDate, 20);
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: deletedPoint.price,
        currency: 'EUR',
        date: latestDate,
        history: [PricePoint(firstDate, 10), deletedPoint],
      );
      await DatabaseService.saveFund(fund);
      await DatabaseService.deletePricePoint('TEST', latestDate);

      await DatabaseService.restorePricePoint('TEST', deletedPoint);

      final storedFund = await DatabaseService.getFund('TEST');
      expect(storedFund, isNotNull);
      expect(storedFund!.lastValue, 20);
      expect(storedFund.date, latestDate);
      expect(storedFund.history.map((point) => point.date), [
        firstDate,
        latestDate,
      ]);
    },
  );

  test('restaurar una operación recupera sus datos y su id', () async {
    final date = DateTime(2026, 9, 2);
    await DatabaseService.saveFund(
      FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 20,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 20)],
      ),
    );
    await DatabaseService.saveOperation(
      FundOperation(
        isin: 'TEST',
        date: date,
        type: OperationType.buy,
        units: 3,
        price: 20,
        amount: 60,
      ),
    );

    final savedFund = await DatabaseService.getFund('TEST');
    final operation = savedFund!.operations.single;
    expect(operation.id, isNotNull);

    await DatabaseService.deleteOperation(operation.id!);
    expect((await DatabaseService.getFund('TEST'))!.operations, isEmpty);

    await DatabaseService.restoreOperation(operation);

    final restoredFund = await DatabaseService.getFund('TEST');
    expect(restoredFund!.operations, hasLength(1));
    expect(restoredFund.operations.single.id, operation.id);
    expect(restoredFund.operations.single.amount, 60);
  });

  test(
    'reemplazar un fondo elimina sus datos anteriores atómicamente',
    () async {
      final date = DateTime(2026, 9, 2);
      final original = FundData(
        isin: 'TEST',
        symbol: 'OLD',
        name: 'Old Fund',
        lastValue: 10,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 10)],
      );
      await DatabaseService.saveFund(original);
      await DatabaseService.saveOperation(
        FundOperation(
          isin: 'TEST',
          date: date,
          type: OperationType.buy,
          units: 1,
          price: 10,
          amount: 10,
        ),
      );

      final replacement = FundData(
        isin: 'TEST',
        symbol: 'NEW',
        name: 'New Fund',
        lastValue: 25,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 25)],
        operations: [
          FundOperation(
            id: 999,
            isin: 'TEST',
            date: date,
            type: OperationType.sell,
            units: 2,
            price: 25,
            amount: 50,
          ),
        ],
      );
      await DatabaseService.replaceFund(replacement);

      final storedFund = await DatabaseService.getFund('TEST');
      expect(storedFund!.name, 'New Fund');
      expect(storedFund.lastValue, 25);
      expect(storedFund.operations, hasLength(1));
      expect(storedFund.operations.single.type, OperationType.sell);
      expect(storedFund.operations.single.id, isNot(999));
    },
  );

  test('crea las tablas de inversiones y operaciones históricas', () async {
    final db = await DatabaseService.database;

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );

    final tableNames = tables.map((row) => row['name'] as String).toSet();

    expect(tableNames, contains('historical_investments'));
    expect(tableNames, contains('historical_operations'));
  });

  test(
    'migra de v12 a v13 creando las tablas históricas y conservando datos',
    () async {
      final databasePath = path.join(temporaryDirectory.path, 'test.db');

      // Simula una base de datos existente en versión 12.
      final oldDatabase = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, version) async {
            await db.execute('''
          CREATE TABLE legacy_probe (
            id INTEGER PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

            await db.insert('legacy_probe', {
              'id': 1,
              'value': 'dato existente',
            });
          },
        ),
      );

      await oldDatabase.close();

      // Abrir mediante DatabaseService debe ejecutar la migración a v13.
      final db = await DatabaseService.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      );

      final tableNames = tables.map((row) => row['name'] as String).toSet();

      expect(tableNames, contains('historical_investments'));
      expect(tableNames, contains('historical_operations'));

      final preservedRows = await db.query('legacy_probe');
      expect(preservedRows, hasLength(1));
      expect(preservedRows.single['value'], 'dato existente');

      expect(await db.getVersion(), 13);
    },
  );
  test('guarda y recupera una inversión histórica por su UID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-001',
      name: 'Fondo histórico',
      isin: 'ES0123456789',
      description: 'Inversión anterior a OpenInvest',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final stored = await DatabaseService.getHistoricalInvestment(
      'historical-001',
    );

    expect(stored, isNotNull);
    expect(stored!.uid, 'historical-001');
    expect(stored.name, 'Fondo histórico');
    expect(stored.isin, 'ES0123456789');
    expect(stored.description, 'Inversión anterior a OpenInvest');
    expect(stored.id, isNotNull);
  });

  test('guarda inversiones históricas independientes por UID', () async {
    final first = HistoricalInvestment(
      uid: 'historical-A',
      name: 'Primera inversión',
      isin: 'ES0000000001',
    );

    final second = HistoricalInvestment(
      uid: 'historical-B',
      name: 'Segunda inversión',
      isin: 'ES0000000002',
    );

    await DatabaseService.saveHistoricalInvestment(first);
    await DatabaseService.saveHistoricalInvestment(second);

    final storedFirst = await DatabaseService.getHistoricalInvestment(
      'historical-A',
    );
    final storedSecond = await DatabaseService.getHistoricalInvestment(
      'historical-B',
    );

    expect(storedFirst, isNotNull);
    expect(storedSecond, isNotNull);

    expect(storedFirst!.name, 'Primera inversión');
    expect(storedFirst.isin, 'ES0000000001');

    expect(storedSecond!.name, 'Segunda inversión');
    expect(storedSecond.isin, 'ES0000000002');

    expect(storedFirst.id, isNot(storedSecond.id));
  });

  test('rechaza guardar dos inversiones históricas con el mismo UID', () async {
    final first = HistoricalInvestment(
      uid: 'historical-duplicate',
      name: 'Primera inversión',
    );

    final second = HistoricalInvestment(
      uid: 'historical-duplicate',
      name: 'Segunda inversión',
    );

    await DatabaseService.saveHistoricalInvestment(first);

    await expectLater(
      DatabaseService.saveHistoricalInvestment(second),
      throwsA(isA<DatabaseException>()),
    );

    final stored = await DatabaseService.getHistoricalInvestment(
      'historical-duplicate',
    );

    expect(stored, isNotNull);
    expect(stored!.name, 'Primera inversión');
  });

  test('devuelve null al buscar una inversión histórica inexistente', () async {
    final stored = await DatabaseService.getHistoricalInvestment(
      'historical-no-existe',
    );

    expect(stored, isNull);
  });

  test(
    'guarda y recupera una inversión histórica con campos opcionales nulos',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-null-fields',
        name: 'Inversión sin datos adicionales',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final stored = await DatabaseService.getHistoricalInvestment(
        'historical-null-fields',
      );

      expect(stored, isNotNull);
      expect(stored!.uid, 'historical-null-fields');
      expect(stored.name, 'Inversión sin datos adicionales');
      expect(stored.isin, isNull);
      expect(stored.description, isNull);
    },
  );

  test('guarda y recupera una operación histórica por su UID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operation-investment',
      name: 'Inversión histórica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-operation-001',
      investmentUid: 'historical-operation-investment',
      date: DateTime(2020, 5, 15),
      type: HistoricalOperationType.subscription,
      amount: 1500.0,
      units: 100.0,
      price: 15.0,
      description: 'Aportación inicial',
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(
      'historical-operation-001',
    );

    expect(stored, isNotNull);
    expect(stored!.uid, 'historical-operation-001');
    expect(stored.investmentUid, 'historical-operation-investment');
    expect(stored.date, DateTime(2020, 5, 15));
    expect(stored.type, HistoricalOperationType.subscription);
    expect(stored.amount, 1500.0);
    expect(stored.units, 100.0);
    expect(stored.price, 15.0);
    expect(stored.description, 'Aportación inicial');
    expect(stored.id, isNotNull);
  });

  test('guarda operaciones históricas independientes por UID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operations-independent',
      name: 'Inversión histórica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final first = HistoricalOperation(
      uid: 'historical-operation-A',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final second = HistoricalOperation(
      uid: 'historical-operation-B',
      investmentUid: investment.uid,
      date: DateTime(2020, 2, 10),
      type: HistoricalOperationType.redemption,
      amount: 250,
    );

    await DatabaseService.saveHistoricalOperation(first);
    await DatabaseService.saveHistoricalOperation(second);

    final storedFirst = await DatabaseService.getHistoricalOperation(
      'historical-operation-A',
    );
    final storedSecond = await DatabaseService.getHistoricalOperation(
      'historical-operation-B',
    );

    expect(storedFirst, isNotNull);
    expect(storedSecond, isNotNull);

    expect(storedFirst!.amount, 1000);
    expect(storedFirst.type, HistoricalOperationType.subscription);

    expect(storedSecond!.amount, 250);
    expect(storedSecond.type, HistoricalOperationType.redemption);

    expect(storedFirst.id, isNot(storedSecond.id));
  });

  test('rechaza guardar dos operaciones históricas con el mismo UID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operations-duplicate',
      name: 'Inversión histórica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final first = HistoricalOperation(
      uid: 'historical-operation-duplicate',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final second = HistoricalOperation(
      uid: 'historical-operation-duplicate',
      investmentUid: investment.uid,
      date: DateTime(2020, 2, 10),
      type: HistoricalOperationType.redemption,
      amount: 250,
    );

    await DatabaseService.saveHistoricalOperation(first);

    await expectLater(
      DatabaseService.saveHistoricalOperation(second),
      throwsA(isA<DatabaseException>()),
    );

    final stored = await DatabaseService.getHistoricalOperation(
      'historical-operation-duplicate',
    );

    expect(stored, isNotNull);
    expect(stored!.amount, 1000);
    expect(stored.type, HistoricalOperationType.subscription);
  });

  test('devuelve null al buscar una operación histórica inexistente', () async {
    final stored = await DatabaseService.getHistoricalOperation(
      'historical-operation-no-existe',
    );

    expect(stored, isNull);
  });

  test(
    'guarda y recupera una operación histórica con campos opcionales nulos',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-operation-null-fields',
        name: 'Inversión histórica',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation = HistoricalOperation(
        uid: 'historical-operation-null-001',
        investmentUid: investment.uid,
        date: DateTime(2021, 3, 20),
        type: HistoricalOperationType.subscription,
        amount: 500,
      );

      await DatabaseService.saveHistoricalOperation(operation);

      final stored = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      expect(stored, isNotNull);
      expect(stored!.units, isNull);
      expect(stored.price, isNull);
      expect(stored.description, isNull);
      expect(stored.transferUid, isNull);
    },
  );

  test('recupera las operaciones históricas de una inversión', () async {
    final investmentA = HistoricalInvestment(
      uid: 'historical-operations-by-investment-A',
      name: 'Inversión A',
    );

    final investmentB = HistoricalInvestment(
      uid: 'historical-operations-by-investment-B',
      name: 'Inversión B',
    );

    await DatabaseService.saveHistoricalInvestment(investmentA);
    await DatabaseService.saveHistoricalInvestment(investmentB);

    final operationA1 = HistoricalOperation(
      uid: 'historical-operation-A1',
      investmentUid: investmentA.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final operationA2 = HistoricalOperation(
      uid: 'historical-operation-A2',
      investmentUid: investmentA.uid,
      date: DateTime(2020, 2, 10),
      type: HistoricalOperationType.redemption,
      amount: 200,
    );

    final operationB1 = HistoricalOperation(
      uid: 'historical-operation-B1',
      investmentUid: investmentB.uid,
      date: DateTime(2020, 1, 15),
      type: HistoricalOperationType.subscription,
      amount: 500,
    );

    await DatabaseService.saveHistoricalOperation(operationA1);
    await DatabaseService.saveHistoricalOperation(operationA2);
    await DatabaseService.saveHistoricalOperation(operationB1);

    final stored = await DatabaseService.getHistoricalOperations(
      investmentA.uid,
    );

    expect(stored, hasLength(2));
    expect(stored.map((operation) => operation.uid).toSet(), {
      'historical-operation-A1',
      'historical-operation-A2',
    });

    expect(
      stored.every((operation) => operation.investmentUid == investmentA.uid),
      isTrue,
    );
  });

  test('recupera las operaciones históricas en orden cronológico', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operations-chronological',
      name: 'Inversión cronológica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final later = HistoricalOperation(
      uid: 'historical-operation-later',
      investmentUid: investment.uid,
      date: DateTime(2022, 3, 15),
      type: HistoricalOperationType.redemption,
      amount: 300,
    );

    final earlier = HistoricalOperation(
      uid: 'historical-operation-earlier',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final middle = HistoricalOperation(
      uid: 'historical-operation-middle',
      investmentUid: investment.uid,
      date: DateTime(2021, 6, 20),
      type: HistoricalOperationType.subscription,
      amount: 500,
    );

    // Guardamos deliberadamente en un orden distinto al cronológico.
    await DatabaseService.saveHistoricalOperation(later);
    await DatabaseService.saveHistoricalOperation(earlier);
    await DatabaseService.saveHistoricalOperation(middle);

    final stored = await DatabaseService.getHistoricalOperations(
      investment.uid,
    );

    expect(stored.map((operation) => operation.uid).toList(), [
      'historical-operation-earlier',
      'historical-operation-middle',
      'historical-operation-later',
    ]);
  });
  test(
    'devuelve una lista vacía si la inversión no tiene operaciones históricas',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-investment-without-operations',
        name: 'Inversión sin operaciones',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final stored = await DatabaseService.getHistoricalOperations(
        investment.uid,
      );

      expect(stored, isEmpty);
    },
  );
  test(
    'mantiene un orden estable entre operaciones históricas de igual fecha',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-operations-same-date',
        name: 'Inversión con operaciones simultáneas',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final first = HistoricalOperation(
        uid: 'historical-operation-same-date-1',
        investmentUid: investment.uid,
        date: DateTime(2021, 5, 10),
        type: HistoricalOperationType.subscription,
        amount: 100,
      );

      final second = HistoricalOperation(
        uid: 'historical-operation-same-date-2',
        investmentUid: investment.uid,
        date: DateTime(2021, 5, 10),
        type: HistoricalOperationType.redemption,
        amount: 50,
      );

      await DatabaseService.saveHistoricalOperation(first);
      await DatabaseService.saveHistoricalOperation(second);

      final stored = await DatabaseService.getHistoricalOperations(
        investment.uid,
      );

      expect(stored.map((operation) => operation.uid).toList(), [
        'historical-operation-same-date-1',
        'historical-operation-same-date-2',
      ]);
    },
  );
  test(
    'devuelve una lista vacía para una inversión histórica inexistente',
    () async {
      final stored = await DatabaseService.getHistoricalOperations(
        'historical-investment-no-existe',
      );

      expect(stored, isEmpty);
    },
  );

  test('actualiza una operación histórica conservando su identidad', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-update-investment',
      name: 'Inversión para actualización',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final original = HistoricalOperation(
      uid: 'historical-operation-update',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
      description: 'Importe original',
    );

    await DatabaseService.saveHistoricalOperation(original);

    final storedOriginal = await DatabaseService.getHistoricalOperation(
      original.uid,
    );

    final updated = storedOriginal!.copyWith(
      amount: 1500,
      description: 'Importe actualizado',
    );

    await DatabaseService.updateHistoricalOperation(updated);

    final storedUpdated = await DatabaseService.getHistoricalOperation(
      original.uid,
    );

    expect(storedUpdated, isNotNull);
    expect(storedUpdated!.id, storedOriginal.id);
    expect(storedUpdated.uid, original.uid);
    expect(storedUpdated.investmentUid, investment.uid);
    expect(storedUpdated.amount, 1500);
    expect(storedUpdated.description, 'Importe actualizado');
  });

  test('rechaza actualizar una operación histórica sin ID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-no-id-investment',
      name: 'Inversión sin ID',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-operation-no-id',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    expect(
      () => DatabaseService.updateHistoricalOperation(operation),
      throwsArgumentError,
    );

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    expect(stored, isNull);
  });

  test(
    'rechaza actualizar una operación histórica con ID ajeno a su UID',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-mismatched-id-investment',
        name: 'Inversión para comprobar identidad',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final original = HistoricalOperation(
        uid: 'historical-operation-original',
        investmentUid: investment.uid,
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final other = HistoricalOperation(
        uid: 'historical-operation-other',
        investmentUid: investment.uid,
        date: DateTime(2020, 2, 10),
        type: HistoricalOperationType.subscription,
        amount: 2000,
      );

      await DatabaseService.saveHistoricalOperation(original);
      await DatabaseService.saveHistoricalOperation(other);

      final storedOriginal = await DatabaseService.getHistoricalOperation(
        original.uid,
      );
      final storedOther = await DatabaseService.getHistoricalOperation(
        other.uid,
      );

      final invalidUpdate = storedOriginal!.copyWith(
        id: storedOther!.id,
        amount: 3000,
      );

      await expectLater(
        DatabaseService.updateHistoricalOperation(invalidUpdate),
        throwsStateError,
      );

      final unchangedOriginal = await DatabaseService.getHistoricalOperation(
        original.uid,
      );
      final unchangedOther = await DatabaseService.getHistoricalOperation(
        other.uid,
      );

      expect(unchangedOriginal!.amount, 1000);
      expect(unchangedOther!.amount, 2000);
    },
  );

  test('permite limpiar los campos opcionales al actualizar una operación histórica', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-clear-fields-investment',
      name: 'Inversión para limpiar campos',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final original = HistoricalOperation(
      uid: 'historical-operation-clear-fields',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
      units: 10,
      price: 100,
      description: 'Descripción original',
      transferUid: 'historical-transfer-original',
    );

    await DatabaseService.saveHistoricalOperation(original);

    final storedOriginal = await DatabaseService.getHistoricalOperation(
      original.uid,
    );

    final updated = storedOriginal!.copyWith(
      units: null,
      price: null,
      description: null,
      transferUid: null,
    );

    await DatabaseService.updateHistoricalOperation(updated);

    final storedUpdated = await DatabaseService.getHistoricalOperation(
      original.uid,
    );

    expect(storedUpdated, isNotNull);
    expect(storedUpdated!.id, storedOriginal.id);
    expect(storedUpdated.units, isNull);
    expect(storedUpdated.price, isNull);
    expect(storedUpdated.description, isNull);
    expect(storedUpdated.transferUid, isNull);
    expect(storedUpdated.amount, 1000);
  });

  test('elimina una operación histórica conservando las demás', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-delete-investment',
      name: 'Inversión para eliminación',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operationToDelete = HistoricalOperation(
      uid: 'historical-operation-to-delete',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final operationToKeep = HistoricalOperation(
      uid: 'historical-operation-to-keep',
      investmentUid: investment.uid,
      date: DateTime(2020, 2, 10),
      type: HistoricalOperationType.subscription,
      amount: 2000,
    );

    await DatabaseService.saveHistoricalOperation(operationToDelete);
    await DatabaseService.saveHistoricalOperation(operationToKeep);

    final stored = await DatabaseService.getHistoricalOperation(
      operationToDelete.uid,
    );

    await DatabaseService.deleteHistoricalOperation(stored!);

    final deleted = await DatabaseService.getHistoricalOperation(
      operationToDelete.uid,
    );
    final remaining = await DatabaseService.getHistoricalOperation(
      operationToKeep.uid,
    );

    expect(deleted, isNull);
    expect(remaining, isNotNull);
    expect(remaining!.amount, 2000);
  });

  test('rechaza eliminar una operación histórica sin ID', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-delete-no-id-investment',
      name: 'Inversión sin ID',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-delete-no-id',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    await expectLater(
      DatabaseService.deleteHistoricalOperation(operation),
      throwsArgumentError,
    );

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    expect(stored, isNull);
  });

  test(
    'rechaza eliminar una operación histórica con ID ajeno a su UID',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-delete-mismatch-investment',
        name: 'Inversión para comprobar identidad',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final original = HistoricalOperation(
        uid: 'historical-delete-original',
        investmentUid: investment.uid,
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final other = HistoricalOperation(
        uid: 'historical-delete-other',
        investmentUid: investment.uid,
        date: DateTime(2020, 2, 10),
        type: HistoricalOperationType.subscription,
        amount: 2000,
      );

      await DatabaseService.saveHistoricalOperation(original);
      await DatabaseService.saveHistoricalOperation(other);

      final storedOriginal = await DatabaseService.getHistoricalOperation(
        original.uid,
      );
      final storedOther = await DatabaseService.getHistoricalOperation(
        other.uid,
      );

      final invalidDelete = storedOriginal!.copyWith(id: storedOther!.id);

      await expectLater(
        DatabaseService.deleteHistoricalOperation(invalidDelete),
        throwsStateError,
      );

      final unchangedOriginal = await DatabaseService.getHistoricalOperation(
        original.uid,
      );
      final unchangedOther = await DatabaseService.getHistoricalOperation(
        other.uid,
      );

      expect(unchangedOriginal, isNotNull);
      expect(unchangedOriginal!.amount, 1000);
      expect(unchangedOther, isNotNull);
      expect(unchangedOther!.amount, 2000);
    },
  );

  test('elimina una inversión histórica y todas sus operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-delete-parent',
      name: 'Inversión que se eliminará',
    );

    final otherInvestment = HistoricalInvestment(
      uid: 'historical-delete-other-parent',
      name: 'Otra inversión',
    );

    await DatabaseService.saveHistoricalInvestment(investment);
    await DatabaseService.saveHistoricalInvestment(otherInvestment);

    final operation = HistoricalOperation(
      uid: 'historical-delete-parent-operation',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final otherOperation = HistoricalOperation(
      uid: 'historical-delete-other-operation',
      investmentUid: otherInvestment.uid,
      date: DateTime(2020, 2, 10),
      type: HistoricalOperationType.subscription,
      amount: 2000,
    );

    await DatabaseService.saveHistoricalOperation(operation);
    await DatabaseService.saveHistoricalOperation(otherOperation);

    await DatabaseService.deleteHistoricalInvestment(investment.uid);

    expect(
      await DatabaseService.getHistoricalInvestment(investment.uid),
      isNull,
    );

    expect(await DatabaseService.getHistoricalOperation(operation.uid), isNull);

    expect(
      await DatabaseService.getHistoricalInvestment(otherInvestment.uid),
      isNotNull,
    );

    expect(
      await DatabaseService.getHistoricalOperation(otherOperation.uid),
      isNotNull,
    );
  });

  test('rechaza eliminar una inversión histórica con UID vacío', () async {
    await expectLater(
      DatabaseService.deleteHistoricalInvestment('   '),
      throwsArgumentError,
    );
  });

  test('rechaza eliminar una inversión histórica inexistente', () async {
    await expectLater(
      DatabaseService.deleteHistoricalInvestment(
        'historical-investment-does-not-exist',
      ),
      throwsStateError,
    );
  });

  test('revierte la eliminación de una inversión si falla el borrado de sus operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-atomic-delete',
      name: 'Inversión para comprobar atomicidad',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-atomic-delete-operation',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER prevent_historical_operation_delete
    BEFORE DELETE ON historical_operations
    BEGIN
      SELECT RAISE(ABORT, 'Deletion intentionally blocked');
    END
  ''');

    await expectLater(
      DatabaseService.deleteHistoricalInvestment(investment.uid),
      throwsA(isA<Exception>()),
    );

    final storedInvestment = await DatabaseService.getHistoricalInvestment(
      investment.uid,
    );

    final storedOperation = await DatabaseService.getHistoricalOperation(
      operation.uid,
    );

    expect(storedInvestment, isNotNull);
    expect(storedOperation, isNotNull);
  });

  test('recupera una inversión histórica con todas sus operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-complete-investment',
      name: 'Inversión histórica completa',
      isin: 'ES0123456789',
      description: 'Inversión de prueba',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final firstOperation = HistoricalOperation(
      uid: 'historical-complete-operation-1',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    final secondOperation = HistoricalOperation(
      uid: 'historical-complete-operation-2',
      investmentUid: investment.uid,
      date: DateTime(2021, 3, 15),
      type: HistoricalOperationType.redemption,
      amount: 300,
    );

    await DatabaseService.saveHistoricalOperation(firstOperation);
    await DatabaseService.saveHistoricalOperation(secondOperation);

    final recovered =
        await DatabaseService.getHistoricalInvestmentWithOperations(
          investment.uid,
        );

    expect(recovered, isNotNull);
    expect(recovered!.investment.uid, investment.uid);
    expect(recovered.investment.name, investment.name);
    expect(recovered.investment.isin, investment.isin);
    expect(recovered.investment.description, investment.description);

    expect(recovered.operations, hasLength(2));
    expect(recovered.operations[0].uid, firstOperation.uid);
    expect(recovered.operations[1].uid, secondOperation.uid);
  });

  test('recupera una inversión histórica sin operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-empty-investment',
      name: 'Inversión sin operaciones',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final recovered =
        await DatabaseService.getHistoricalInvestmentWithOperations(
          investment.uid,
        );

    expect(recovered, isNotNull);
    expect(recovered!.investment.uid, investment.uid);
    expect(recovered.investment.name, investment.name);
    expect(recovered.operations, isEmpty);
  });

  test(
    'devuelve null al recuperar una inversión histórica inexistente',
    () async {
      final recovered =
          await DatabaseService.getHistoricalInvestmentWithOperations(
            'historical-investment-missing',
          );

      expect(recovered, isNull);
    },
  );

  test(
    'recupera únicamente las operaciones de la inversión solicitada',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-isolation-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-isolation-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      final operationA = HistoricalOperation(
        uid: 'historical-isolation-operation-A',
        investmentUid: investmentA.uid,
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final operationB = HistoricalOperation(
        uid: 'historical-isolation-operation-B',
        investmentUid: investmentB.uid,
        date: DateTime(2020, 2, 10),
        type: HistoricalOperationType.subscription,
        amount: 2000,
      );

      await DatabaseService.saveHistoricalOperation(operationA);
      await DatabaseService.saveHistoricalOperation(operationB);

      final recovered =
          await DatabaseService.getHistoricalInvestmentWithOperations(
            investmentA.uid,
          );

      expect(recovered, isNotNull);
      expect(recovered!.investment.uid, investmentA.uid);
      expect(recovered.operations, hasLength(1));
      expect(recovered.operations.single.uid, operationA.uid);
      expect(
        recovered.operations.any(
          (operation) => operation.uid == operationB.uid,
        ),
        isFalse,
      );
    },
  );

  test(
    'conserva los ID de inversión y operaciones al recuperar el conjunto',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-identity-investment',
        name: 'Inversión con identidad',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation = HistoricalOperation(
        uid: 'historical-identity-operation',
        investmentUid: investment.uid,
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      await DatabaseService.saveHistoricalOperation(operation);

      final storedInvestment = await DatabaseService.getHistoricalInvestment(
        investment.uid,
      );
      final storedOperation = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      final recovered =
          await DatabaseService.getHistoricalInvestmentWithOperations(
            investment.uid,
          );

      expect(recovered, isNotNull);
      expect(recovered!.investment.id, storedInvestment!.id);
      expect(recovered.operations.single.id, storedOperation!.id);
    },
  );

  test(
    'rechaza guardar una operación histórica sin inversión asociada',
    () async {
      final operation = HistoricalOperation(
        uid: 'historical-orphan-operation',
        investmentUid: 'historical-investment-does-not-exist',
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      // await expectLater(
      //   DatabaseService.saveHistoricalOperation(operation),
      //   throwsA(isA<Exception>()),
      // );

      await expectLater(
        DatabaseService.saveHistoricalOperation(operation),
        throwsStateError,
      );

      final stored = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      expect(stored, isNull);
    },
  );

  test('rechaza actualizar una operación histórica hacia una inversión inexistente', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-update-valid-parent',
      name: 'Inversión original',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-update-orphan-operation',
      investmentUid: investment.uid,
      date: DateTime(2020, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    final invalidUpdate = stored!.copyWith(
      investmentUid: 'historical-parent-does-not-exist',
    );

    await expectLater(
      DatabaseService.updateHistoricalOperation(invalidUpdate),
      throwsStateError,
    );

    final unchanged = await DatabaseService.getHistoricalOperation(
      operation.uid,
    );

    expect(unchanged, isNotNull);
    expect(unchanged!.investmentUid, investment.uid);
    expect(unchanged.amount, 1000);
  });

  test(
    'permite cambiar una operación a otra inversión histórica existente',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-parent-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-parent-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      final operation = HistoricalOperation(
        uid: 'historical-transfer-operation',
        investmentUid: investmentA.uid,
        date: DateTime(2020, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      await DatabaseService.saveHistoricalOperation(operation);

      final stored = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      final updated = stored!.copyWith(investmentUid: investmentB.uid);

      await DatabaseService.updateHistoricalOperation(updated);

      final recovered = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      expect(recovered, isNotNull);
      expect(recovered!.id, stored.id);
      expect(recovered.uid, operation.uid);
      expect(recovered.investmentUid, investmentB.uid);
      expect(recovered.amount, 1000);

      expect(
        await DatabaseService.getHistoricalOperations(investmentA.uid),
        isEmpty,
      );

      expect(
        await DatabaseService.getHistoricalOperations(investmentB.uid),
        hasLength(1),
      );
    },
  );

  test(
    'elimina todas las operaciones históricas asociadas a una inversión',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-delete-multiple',
        name: 'Inversión con varios movimientos',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operations = [
        HistoricalOperation(
          uid: 'historical-delete-multiple-1',
          investmentUid: investment.uid,
          date: DateTime(2020, 1, 10),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'historical-delete-multiple-2',
          investmentUid: investment.uid,
          date: DateTime(2021, 1, 10),
          type: HistoricalOperationType.redemption,
          amount: 300,
        ),
        HistoricalOperation(
          uid: 'historical-delete-multiple-3',
          investmentUid: investment.uid,
          date: DateTime(2022, 1, 10),
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
      ];

      for (final operation in operations) {
        await DatabaseService.saveHistoricalOperation(operation);
      }

      expect(
        await DatabaseService.getHistoricalOperations(investment.uid),
        hasLength(3),
      );

      await DatabaseService.deleteHistoricalInvestment(investment.uid);

      expect(
        await DatabaseService.getHistoricalOperations(investment.uid),
        isEmpty,
      );

      for (final operation in operations) {
        expect(
          await DatabaseService.getHistoricalOperation(operation.uid),
          isNull,
        );
      }
    },
  );

  test(
    'guarda y recupera operaciones históricas vinculadas por transferUid',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-link-A',
        name: 'Inversión origen',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-link-B',
        name: 'Inversión destino',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      const transferUid = 'historical-transfer-link-001';

      final transferOut = HistoricalOperation(
        uid: 'historical-transfer-out-001',
        investmentUid: investmentA.uid,
        date: DateTime(2022, 5, 10),
        type: HistoricalOperationType.transferOut,
        amount: 1500,
        transferUid: transferUid,
      );

      final transferIn = HistoricalOperation(
        uid: 'historical-transfer-in-001',
        investmentUid: investmentB.uid,
        date: DateTime(2022, 5, 10),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        transferUid: transferUid,
      );

      await DatabaseService.saveHistoricalOperation(transferOut);
      await DatabaseService.saveHistoricalOperation(transferIn);

      final recoveredOut = await DatabaseService.getHistoricalOperation(
        transferOut.uid,
      );
      final recoveredIn = await DatabaseService.getHistoricalOperation(
        transferIn.uid,
      );

      expect(recoveredOut, isNotNull);
      expect(recoveredIn, isNotNull);

      expect(recoveredOut!.type, HistoricalOperationType.transferOut);
      expect(recoveredIn!.type, HistoricalOperationType.transferIn);

      expect(recoveredOut.transferUid, transferUid);
      expect(recoveredIn.transferUid, transferUid);

      expect(recoveredOut.amount, recoveredIn.amount);
      expect(recoveredOut.investmentUid, investmentA.uid);
      expect(recoveredIn.investmentUid, investmentB.uid);
    },
  );

  test('mantiene independientes varias transferencias históricas', () async {
    final investmentA = HistoricalInvestment(
      uid: 'historical-multiple-transfer-A',
      name: 'Inversión A',
    );

    final investmentB = HistoricalInvestment(
      uid: 'historical-multiple-transfer-B',
      name: 'Inversión B',
    );

    await DatabaseService.saveHistoricalInvestment(investmentA);
    await DatabaseService.saveHistoricalInvestment(investmentB);

    final transfers = [
      (uid: 'historical-transfer-independent-1', amount: 1000.0),
      (uid: 'historical-transfer-independent-2', amount: 2500.0),
    ];

    for (final transfer in transfers) {
      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: '${transfer.uid}-out',
          investmentUid: investmentA.uid,
          date: DateTime(2022, 5, 10),
          type: HistoricalOperationType.transferOut,
          amount: transfer.amount,
          transferUid: transfer.uid,
        ),
      );

      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: '${transfer.uid}-in',
          investmentUid: investmentB.uid,
          date: DateTime(2022, 5, 10),
          type: HistoricalOperationType.transferIn,
          amount: transfer.amount,
          transferUid: transfer.uid,
        ),
      );
    }

    final operationsA = await DatabaseService.getHistoricalOperations(
      investmentA.uid,
    );
    final operationsB = await DatabaseService.getHistoricalOperations(
      investmentB.uid,
    );

    expect(operationsA, hasLength(2));
    expect(operationsB, hasLength(2));

    expect(operationsA.map((operation) => operation.transferUid).toSet(), {
      'historical-transfer-independent-1',
      'historical-transfer-independent-2',
    });

    expect(operationsB.map((operation) => operation.transferUid).toSet(), {
      'historical-transfer-independent-1',
      'historical-transfer-independent-2',
    });
  });

  test(
    'actualiza el transferUid de una operación sin modificar su contrapartida',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-update-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-update-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      final transferOut = HistoricalOperation(
        uid: 'historical-transfer-update-out',
        investmentUid: investmentA.uid,
        date: DateTime(2022, 5, 10),
        type: HistoricalOperationType.transferOut,
        amount: 1500,
        transferUid: 'historical-transfer-original',
      );

      final transferIn = HistoricalOperation(
        uid: 'historical-transfer-update-in',
        investmentUid: investmentB.uid,
        date: DateTime(2022, 5, 10),
        type: HistoricalOperationType.transferIn,
        amount: 1500,
        transferUid: 'historical-transfer-original',
      );

      await DatabaseService.saveHistoricalOperation(transferOut);
      await DatabaseService.saveHistoricalOperation(transferIn);

      final storedOut = await DatabaseService.getHistoricalOperation(
        transferOut.uid,
      );

      final updatedOut = storedOut!.copyWith(
        transferUid: 'historical-transfer-modified',
      );

      await DatabaseService.updateHistoricalOperation(updatedOut);

      final recoveredOut = await DatabaseService.getHistoricalOperation(
        transferOut.uid,
      );

      final recoveredIn = await DatabaseService.getHistoricalOperation(
        transferIn.uid,
      );

      expect(recoveredOut!.transferUid, 'historical-transfer-modified');
      expect(recoveredIn!.transferUid, 'historical-transfer-original');
      expect(recoveredOut.id, storedOut.id);
      expect(recoveredOut.amount, recoveredIn.amount);
    },
  );

  test('permite limpiar el transferUid de una operación sin modificar su contrapartida', () async {
    final investmentA = HistoricalInvestment(
      uid: 'historical-transfer-clear-A',
      name: 'Inversión A',
    );

    final investmentB = HistoricalInvestment(
      uid: 'historical-transfer-clear-B',
      name: 'Inversión B',
    );

    await DatabaseService.saveHistoricalInvestment(investmentA);
    await DatabaseService.saveHistoricalInvestment(investmentB);

    final transferOut = HistoricalOperation(
      uid: 'historical-transfer-clear-out',
      investmentUid: investmentA.uid,
      date: DateTime(2022, 6, 10),
      type: HistoricalOperationType.transferOut,
      amount: 2000,
      transferUid: 'historical-transfer-clear-link',
    );

    final transferIn = HistoricalOperation(
      uid: 'historical-transfer-clear-in',
      investmentUid: investmentB.uid,
      date: DateTime(2022, 6, 10),
      type: HistoricalOperationType.transferIn,
      amount: 2000,
      transferUid: 'historical-transfer-clear-link',
    );

    await DatabaseService.saveHistoricalOperation(transferOut);
    await DatabaseService.saveHistoricalOperation(transferIn);

    final storedOut = await DatabaseService.getHistoricalOperation(
      transferOut.uid,
    );

    final updatedOut = storedOut!.copyWith(transferUid: null);

    await DatabaseService.updateHistoricalOperation(updatedOut);

    final recoveredOut = await DatabaseService.getHistoricalOperation(
      transferOut.uid,
    );

    final recoveredIn = await DatabaseService.getHistoricalOperation(
      transferIn.uid,
    );

    expect(recoveredOut!.transferUid, isNull);
    expect(recoveredIn!.transferUid, 'historical-transfer-clear-link');
    expect(recoveredOut.id, storedOut.id);
    expect(recoveredOut.amount, recoveredIn.amount);
  });

  test(
    'elimina una operación de transferencia sin eliminar su contrapartida',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-delete-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-delete-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      final transferOut = HistoricalOperation(
        uid: 'historical-transfer-delete-out',
        investmentUid: investmentA.uid,
        date: DateTime(2022, 7, 10),
        type: HistoricalOperationType.transferOut,
        amount: 2500,
        transferUid: 'historical-transfer-delete-link',
      );

      final transferIn = HistoricalOperation(
        uid: 'historical-transfer-delete-in',
        investmentUid: investmentB.uid,
        date: DateTime(2022, 7, 10),
        type: HistoricalOperationType.transferIn,
        amount: 2500,
        transferUid: 'historical-transfer-delete-link',
      );

      await DatabaseService.saveHistoricalOperation(transferOut);
      await DatabaseService.saveHistoricalOperation(transferIn);

      final storedOut = await DatabaseService.getHistoricalOperation(
        transferOut.uid,
      );

      await DatabaseService.deleteHistoricalOperation(storedOut!);

      final recoveredOut = await DatabaseService.getHistoricalOperation(
        transferOut.uid,
      );

      final recoveredIn = await DatabaseService.getHistoricalOperation(
        transferIn.uid,
      );

      expect(recoveredOut, isNull);
      expect(recoveredIn, isNotNull);
      expect(recoveredIn!.transferUid, 'historical-transfer-delete-link');
      expect(recoveredIn.amount, 2500);
      expect(recoveredIn.type, HistoricalOperationType.transferIn);
    },
  );

  test(
    'elimina todas las operaciones de una transferencia sin afectar a otras',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-group-delete-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-group-delete-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      final operations = [
        HistoricalOperation(
          uid: 'historical-transfer-group-delete-out-1',
          investmentUid: investmentA.uid,
          date: DateTime(2022, 8, 10),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: 'historical-transfer-group-delete-link-1',
        ),
        HistoricalOperation(
          uid: 'historical-transfer-group-delete-in-1',
          investmentUid: investmentB.uid,
          date: DateTime(2022, 8, 10),
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: 'historical-transfer-group-delete-link-1',
        ),
        HistoricalOperation(
          uid: 'historical-transfer-group-delete-out-2',
          investmentUid: investmentA.uid,
          date: DateTime(2022, 8, 11),
          type: HistoricalOperationType.transferOut,
          amount: 2000,
          transferUid: 'historical-transfer-group-delete-link-2',
        ),
        HistoricalOperation(
          uid: 'historical-transfer-group-delete-in-2',
          investmentUid: investmentB.uid,
          date: DateTime(2022, 8, 11),
          type: HistoricalOperationType.transferIn,
          amount: 2000,
          transferUid: 'historical-transfer-group-delete-link-2',
        ),
      ];

      for (final operation in operations) {
        await DatabaseService.saveHistoricalOperation(operation);
      }

      /* final db = await DatabaseService.database;

      await db.delete(
        'historical_operations',
        where: 'transfer_uid = ?',
        whereArgs: ['historical-transfer-group-delete-link-1'],
      ); */

      await DatabaseService.deleteHistoricalTransfer(
        'historical-transfer-group-delete-link-1',
      );

      final remainingA = await DatabaseService.getHistoricalOperations(
        investmentA.uid,
      );

      final remainingB = await DatabaseService.getHistoricalOperations(
        investmentB.uid,
      );

      expect(remainingA, hasLength(1));
      expect(remainingB, hasLength(1));
      expect(remainingA.single.uid, 'historical-transfer-group-delete-out-2');
      expect(remainingB.single.uid, 'historical-transfer-group-delete-in-2');
      expect(
        remainingA.single.transferUid,
        'historical-transfer-group-delete-link-2',
      );
      expect(
        remainingB.single.transferUid,
        'historical-transfer-group-delete-link-2',
      );
    },
  );

  test('rechaza eliminar una transferencia con transferUid vacío', () async {
    await expectLater(
      DatabaseService.deleteHistoricalTransfer('   '),
      throwsArgumentError,
    );
  });

  test('rechaza eliminar una transferencia inexistente', () async {
    await expectLater(
      DatabaseService.deleteHistoricalTransfer(
        'historical-transfer-does-not-exist',
      ),
      throwsStateError,
    );
  });

  test('elimina una transferencia de forma atómica', () async {
    final investmentA = HistoricalInvestment(
      uid: 'historical-transfer-atomic-A',
      name: 'Inversión A',
    );

    final investmentB = HistoricalInvestment(
      uid: 'historical-transfer-atomic-B',
      name: 'Inversión B',
    );

    await DatabaseService.saveHistoricalInvestment(investmentA);
    await DatabaseService.saveHistoricalInvestment(investmentB);

    final transferOut = HistoricalOperation(
      uid: 'historical-transfer-atomic-out',
      investmentUid: investmentA.uid,
      date: DateTime(2022, 9, 10),
      type: HistoricalOperationType.transferOut,
      amount: 3000,
      transferUid: 'historical-transfer-atomic-link',
    );

    final transferIn = HistoricalOperation(
      uid: 'historical-transfer-atomic-in',
      investmentUid: investmentB.uid,
      date: DateTime(2022, 9, 10),
      type: HistoricalOperationType.transferIn,
      amount: 3000,
      transferUid: 'historical-transfer-atomic-link',
    );

    await DatabaseService.saveHistoricalOperation(transferOut);
    await DatabaseService.saveHistoricalOperation(transferIn);

    final db = await DatabaseService.database;

    await db.execute('''
    CREATE TRIGGER prevent_historical_transfer_delete
    BEFORE DELETE ON historical_operations
    WHEN OLD.uid = 'historical-transfer-atomic-in'
    BEGIN
      SELECT RAISE(ABORT, 'Deletion intentionally blocked');
    END
  ''');

    await expectLater(
      DatabaseService.deleteHistoricalTransfer(
        'historical-transfer-atomic-link',
      ),
      throwsException,
    );

    final recoveredOut = await DatabaseService.getHistoricalOperation(
      transferOut.uid,
    );

    final recoveredIn = await DatabaseService.getHistoricalOperation(
      transferIn.uid,
    );

    expect(recoveredOut, isNotNull);
    expect(recoveredIn, isNotNull);
    expect(recoveredOut!.transferUid, 'historical-transfer-atomic-link');
    expect(recoveredIn!.transferUid, 'historical-transfer-atomic-link');
  });

  test(
    'elimina una transferencia sin eliminar sus inversiones históricas',
    () async {
      final investmentA = HistoricalInvestment(
        uid: 'historical-transfer-preserve-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'historical-transfer-preserve-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(investmentA);
      await DatabaseService.saveHistoricalInvestment(investmentB);

      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'historical-transfer-preserve-out',
          investmentUid: investmentA.uid,
          date: DateTime(2022, 10, 10),
          type: HistoricalOperationType.transferOut,
          amount: 4000,
          transferUid: 'historical-transfer-preserve-link',
        ),
      );

      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'historical-transfer-preserve-in',
          investmentUid: investmentB.uid,
          date: DateTime(2022, 10, 10),
          type: HistoricalOperationType.transferIn,
          amount: 4000,
          transferUid: 'historical-transfer-preserve-link',
        ),
      );

      await DatabaseService.deleteHistoricalTransfer(
        'historical-transfer-preserve-link',
      );

      final recoveredA = await DatabaseService.getHistoricalInvestment(
        investmentA.uid,
      );
      final recoveredB = await DatabaseService.getHistoricalInvestment(
        investmentB.uid,
      );

      final operationsA = await DatabaseService.getHistoricalOperations(
        investmentA.uid,
      );
      final operationsB = await DatabaseService.getHistoricalOperations(
        investmentB.uid,
      );

      expect(recoveredA, isNotNull);
      expect(recoveredB, isNotNull);
      expect(operationsA, isEmpty);
      expect(operationsB, isEmpty);
    },
  );

  test('rechaza cambiar el UID de una operación histórica conservando el registro original', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operation-uid-immutable',
      name: 'Inversión histórica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-operation-original-uid',
      investmentUid: investment.uid,
      date: DateTime(2022, 11, 10),
      type: HistoricalOperationType.subscription,
      amount: 1500,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    final modified = stored!.copyWith(uid: 'historical-operation-modified-uid');

    await expectLater(
      DatabaseService.updateHistoricalOperation(modified),
      throwsStateError,
    );

    final original = await DatabaseService.getHistoricalOperation(
      operation.uid,
    );

    final modifiedLookup = await DatabaseService.getHistoricalOperation(
      'historical-operation-modified-uid',
    );

    expect(original, isNotNull);
    expect(original!.id, stored.id);
    expect(original.uid, operation.uid);
    expect(original.amount, 1500);
    expect(modifiedLookup, isNull);
  });

  test(
    'rechaza actualizar una operación histórica con un ID inexistente',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-operation-missing-id',
        name: 'Inversión histórica',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation = HistoricalOperation(
        id: 999999,
        uid: 'historical-operation-missing-id-op',
        investmentUid: investment.uid,
        date: DateTime(2022, 12, 10),
        type: HistoricalOperationType.subscription,
        amount: 1800,
      );

      await expectLater(
        DatabaseService.updateHistoricalOperation(operation),
        throwsStateError,
      );

      final operations = await DatabaseService.getHistoricalOperations(
        investment.uid,
      );

      expect(operations, isEmpty);
    },
  );

  test(
    'rechaza actualizar una operación histórica con el UID de otra',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-operation-duplicate-uid',
        name: 'Inversión histórica',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final first = HistoricalOperation(
        uid: 'historical-operation-duplicate-first',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final second = HistoricalOperation(
        uid: 'historical-operation-duplicate-second',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 11),
        type: HistoricalOperationType.subscription,
        amount: 2000,
      );

      await DatabaseService.saveHistoricalOperation(first);
      await DatabaseService.saveHistoricalOperation(second);

      final storedFirst = await DatabaseService.getHistoricalOperation(
        first.uid,
      );

      final storedSecond = await DatabaseService.getHistoricalOperation(
        second.uid,
      );

      final modified = storedSecond!.copyWith(uid: first.uid, amount: 2500);

      await expectLater(
        DatabaseService.updateHistoricalOperation(modified),
        throwsStateError,
      );

      final recoveredFirst = await DatabaseService.getHistoricalOperation(
        first.uid,
      );

      final recoveredSecond = await DatabaseService.getHistoricalOperation(
        second.uid,
      );

      expect(recoveredFirst, isNotNull);
      expect(recoveredSecond, isNotNull);
      expect(recoveredFirst!.id, storedFirst!.id);
      expect(recoveredFirst.amount, 1000);
      expect(recoveredSecond!.id, storedSecond.id);
      expect(recoveredSecond.uid, second.uid);
      expect(recoveredSecond.amount, 2000);
    },
  );

  test('conserva la identidad al trasladar una operación histórica entre inversiones', () async {
    final investmentA = HistoricalInvestment(
      uid: 'historical-operation-move-A',
      name: 'Inversión A',
    );

    final investmentB = HistoricalInvestment(
      uid: 'historical-operation-move-B',
      name: 'Inversión B',
    );

    await DatabaseService.saveHistoricalInvestment(investmentA);
    await DatabaseService.saveHistoricalInvestment(investmentB);

    final operation = HistoricalOperation(
      uid: 'historical-operation-move-uid',
      investmentUid: investmentA.uid,
      date: DateTime(2023, 2, 10),
      type: HistoricalOperationType.subscription,
      amount: 2200,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    final modified = stored!.copyWith(investmentUid: investmentB.uid);

    await DatabaseService.updateHistoricalOperation(modified);

    final operationsA = await DatabaseService.getHistoricalOperations(
      investmentA.uid,
    );

    final operationsB = await DatabaseService.getHistoricalOperations(
      investmentB.uid,
    );

    expect(operationsA, isEmpty);
    expect(operationsB, hasLength(1));
    expect(operationsB.single.id, stored.id);
    expect(operationsB.single.uid, operation.uid);
    expect(operationsB.single.investmentUid, investmentB.uid);
    expect(operationsB.single.amount, 2200);
  });

  test('rechaza trasladar una operación histórica a una inversión inexistente sin modificarla', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operation-move-invalid-A',
      name: 'Inversión A',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-operation-move-invalid-op',
      investmentUid: investment.uid,
      date: DateTime(2023, 3, 10),
      type: HistoricalOperationType.subscription,
      amount: 2750,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    final modified = stored!.copyWith(
      investmentUid: 'historical-investment-does-not-exist',
      amount: 3000,
    );

    await expectLater(
      DatabaseService.updateHistoricalOperation(modified),
      throwsStateError,
    );

    final recovered = await DatabaseService.getHistoricalOperation(
      operation.uid,
    );

    final operations = await DatabaseService.getHistoricalOperations(
      investment.uid,
    );

    expect(recovered, isNotNull);
    expect(recovered!.id, stored.id);
    expect(recovered.investmentUid, investment.uid);
    expect(recovered.amount, 2750);
    expect(operations, hasLength(1));
  });

  test(
    'actualiza los datos de una operación histórica conservando su inversión',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-operation-update-parent',
        name: 'Inversión histórica',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation = HistoricalOperation(
        uid: 'historical-operation-update-parent-op',
        investmentUid: investment.uid,
        date: DateTime(2023, 4, 10),
        type: HistoricalOperationType.subscription,
        amount: 1200,
        description: 'Aportación inicial',
      );

      await DatabaseService.saveHistoricalOperation(operation);

      final stored = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      final modified = stored!.copyWith(
        amount: 1800,
        description: 'Aportación actualizada',
      );

      await DatabaseService.updateHistoricalOperation(modified);

      final recovered = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      expect(recovered, isNotNull);
      expect(recovered!.id, stored.id);
      expect(recovered.uid, operation.uid);
      expect(recovered.investmentUid, investment.uid);
      expect(recovered.amount, 1800);
      expect(recovered.description, 'Aportación actualizada');
    },
  );

  test('actualiza una operación histórica conservando fecha y tipo', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-operation-date-type',
      name: 'Inversión histórica',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-operation-date-type-op',
      investmentUid: investment.uid,
      date: DateTime(2023, 5, 15),
      type: HistoricalOperationType.redemption,
      amount: 900,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final stored = await DatabaseService.getHistoricalOperation(operation.uid);

    final modified = stored!.copyWith(amount: 1100);

    await DatabaseService.updateHistoricalOperation(modified);

    final recovered = await DatabaseService.getHistoricalOperation(
      operation.uid,
    );

    expect(recovered, isNotNull);
    expect(recovered!.date, DateTime(2023, 5, 15));
    expect(recovered.type, HistoricalOperationType.redemption);
    expect(recovered.amount, 1100);
    expect(recovered.id, stored.id);
  });

  test(
    'recupera una inversión histórica junto con sus operaciones ordenadas',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-combined-001',
        name: 'Fondo histórico combinado',
        isin: 'ES0000000002',
        description: 'Prueba de recuperación conjunta',
      );

      final redemption = HistoricalOperation(
        uid: 'historical-combined-redemption',
        investmentUid: investment.uid,
        date: DateTime(2025, 12, 31),
        type: HistoricalOperationType.redemption,
        amount: 1250,
      );

      final subscription = HistoricalOperation(
        uid: 'historical-combined-subscription',
        investmentUid: investment.uid,
        date: DateTime(2025, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      await DatabaseService.saveHistoricalInvestment(investment);
      await DatabaseService.saveHistoricalOperation(redemption);
      await DatabaseService.saveHistoricalOperation(subscription);

      final result =
          await DatabaseService.getHistoricalInvestmentWithOperations(
            investment.uid,
          );

      expect(result, isNotNull);
      expect(result!.investment.uid, investment.uid);
      expect(result.investment.name, investment.name);
      expect(result.investment.isin, investment.isin);
      expect(result.investment.description, investment.description);

      expect(result.operations, hasLength(2));
      expect(result.operations.map((operation) => operation.uid).toList(), [
        subscription.uid,
        redemption.uid,
      ]);
    },
  );

  test(
    'recupera todas las inversiones históricas ordenadas por más recientes',
    () async {
      await DatabaseService.saveHistoricalInvestment(
        HistoricalInvestment(
          uid: 'historical-list-A',
          name: 'Primera inversión',
        ),
      );

      await DatabaseService.saveHistoricalInvestment(
        HistoricalInvestment(
          uid: 'historical-list-B',
          name: 'Segunda inversión',
        ),
      );

      await DatabaseService.saveHistoricalInvestment(
        HistoricalInvestment(
          uid: 'historical-list-C',
          name: 'Tercera inversión',
        ),
      );

      final investments = await DatabaseService.getHistoricalInvestments();

      expect(investments.map((investment) => investment.uid).toList(), [
        'historical-list-C',
        'historical-list-B',
        'historical-list-A',
      ]);

      expect(investments, hasLength(3));
      expect(investments.first.name, 'Tercera inversión');
      expect(investments.first.id, isNotNull);
    },
  );

  test(
    'LF-136.1: actualiza una operación histórica conservando su identidad',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-investment-edit-1',
        name: 'Inversión de prueba',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation = HistoricalOperation(
        uid: 'historical-operation-edit-1',
        investmentUid: investment.uid,
        date: DateTime(2025, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
        units: 10,
        price: 100,
        description: 'Suscripción inicial',
      );

      await DatabaseService.saveHistoricalOperation(operation);

      final saved = await DatabaseService.getHistoricalOperation(operation.uid);

      expect(saved, isNotNull);
      expect(saved!.id, isNotNull);

      final updated = saved.copyWith(
        date: DateTime(2025, 2, 10),
        amount: 1500,
        units: 15,
        price: 100,
        description: 'Suscripción actualizada',
      );

      await DatabaseService.updateHistoricalOperation(updated);

      final result = await DatabaseService.getHistoricalOperation(
        operation.uid,
      );

      expect(result, isNotNull);
      expect(result!.id, saved.id);
      expect(result.uid, saved.uid);
      expect(result.investmentUid, investment.uid);
      expect(result.date, DateTime(2025, 2, 10));
      expect(result.amount, 1500);
      expect(result.units, 15);
      expect(result.price, 100);
      expect(result.description, 'Suscripción actualizada');
    },
  );

  test(
    'LF-136.4.1: elimina una operación histórica sin eliminar la inversión',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-investment-delete-1',
        name: 'Inversión de prueba',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final operation1 = HistoricalOperation(
        uid: 'historical-operation-delete-1',
        investmentUid: investment.uid,
        date: DateTime(2025, 1, 10),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final operation2 = HistoricalOperation(
        uid: 'historical-operation-delete-2',
        investmentUid: investment.uid,
        date: DateTime(2025, 2, 10),
        type: HistoricalOperationType.subscription,
        amount: 500,
      );

      await DatabaseService.saveHistoricalOperation(operation1);
      await DatabaseService.saveHistoricalOperation(operation2);

      final saved = await DatabaseService.getHistoricalOperation(
        operation1.uid,
      );

      expect(saved, isNotNull);

      await DatabaseService.deleteHistoricalOperation(saved!);

      final deleted = await DatabaseService.getHistoricalOperation(
        operation1.uid,
      );

      final remaining = await DatabaseService.getHistoricalOperations(
        investment.uid,
      );

      final investmentStillExists =
          await DatabaseService.getHistoricalInvestment(investment.uid);

      expect(deleted, isNull);
      expect(remaining.length, 1);
      expect(remaining.single.uid, operation2.uid);
      expect(investmentStillExists, isNotNull);
    },
  );

  test('LF-136.6.1: actualiza una inversión histórica conservando su identidad y operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-investment-edit-1',
      name: 'Inversión original',
      isin: 'ES0000000001',
      description: 'Descripción original',
    );

    await DatabaseService.saveHistoricalInvestment(investment);

    final operation = HistoricalOperation(
      uid: 'historical-investment-edit-operation-1',
      investmentUid: investment.uid,
      date: DateTime(2025, 1, 10),
      type: HistoricalOperationType.subscription,
      amount: 1000,
    );

    await DatabaseService.saveHistoricalOperation(operation);

    final saved = await DatabaseService.getHistoricalInvestment(investment.uid);

    expect(saved, isNotNull);
    expect(saved!.id, isNotNull);

    final updated = saved.copyWith(
      name: 'Inversión actualizada',
      isin: 'ES0000000002',
      description: 'Nueva descripción',
    );

    await DatabaseService.updateHistoricalInvestment(updated);

    final recovered = await DatabaseService.getHistoricalInvestment(
      investment.uid,
    );

    final operations = await DatabaseService.getHistoricalOperations(
      investment.uid,
    );

    expect(recovered, isNotNull);
    expect(recovered!.id, saved.id);
    expect(recovered.uid, saved.uid);
    expect(recovered.name, 'Inversión actualizada');
    expect(recovered.isin, 'ES0000000002');
    expect(recovered.description, 'Nueva descripción');

    expect(operations, hasLength(1));
    expect(operations.single.uid, operation.uid);
  });

  test(
    'LF-136.6.2: rechaza actualizar una inversión histórica sin ID',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-investment-without-id',
        name: 'Inversión sin ID',
      );

      expect(
        () => DatabaseService.updateHistoricalInvestment(investment),
        throwsArgumentError,
      );
    },
  );

  test(
    'LF-136.6.3: rechaza actualizar una inversión con el ID de otra',
    () async {
      final first = HistoricalInvestment(
        uid: 'historical-investment-identity-1',
        name: 'Primera inversión',
      );
      final second = HistoricalInvestment(
        uid: 'historical-investment-identity-2',
        name: 'Segunda inversión',
      );

      await DatabaseService.saveHistoricalInvestment(first);
      await DatabaseService.saveHistoricalInvestment(second);

      final savedFirst = await DatabaseService.getHistoricalInvestment(
        first.uid,
      );
      final savedSecond = await DatabaseService.getHistoricalInvestment(
        second.uid,
      );

      expect(savedFirst, isNotNull);
      expect(savedSecond, isNotNull);

      final forged = HistoricalInvestment(
        id: savedSecond!.id,
        uid: savedFirst!.uid,
        name: 'Nombre manipulado',
      );

      await expectLater(
        DatabaseService.updateHistoricalInvestment(forged),
        throwsStateError,
      );

      final recoveredFirst = await DatabaseService.getHistoricalInvestment(
        first.uid,
      );
      final recoveredSecond = await DatabaseService.getHistoricalInvestment(
        second.uid,
      );

      expect(recoveredFirst!.name, 'Primera inversión');
      expect(recoveredSecond!.name, 'Segunda inversión');
    },
  );

  test(
    'LF-140.19: rechaza una inversión cuya primera operación es una salida',
    () async {
      final investment = HistoricalInvestment(
        uid: 'investment-lf140-19',
        name: 'Inversión inválida',
      );

      final operation = HistoricalOperation(
        uid: 'operation-lf140-19',
        investmentUid: investment.uid,
        date: DateTime(2025, 1, 1),
        type: HistoricalOperationType.redemption,
        amount: 1000,
      );

      await expectLater(
        DatabaseService.saveHistoricalInvestmentWithOperations(investment, [
          operation,
        ]),
        throwsA(isA<ArgumentError>()),
      );

      final investments = await DatabaseService.getHistoricalInvestments();

      expect(investments, isEmpty);
    },
  );

  test(
    'LF-140.20: guarda una inversión válida y todas sus operaciones',
    () async {
      final investment = HistoricalInvestment(
        uid: 'investment-lf140-20',
        name: 'Inversión válida',
      );

      final operations = [
        HistoricalOperation(
          uid: 'operation-lf140-20-1',
          investmentUid: investment.uid,
          date: DateTime(2025, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'operation-lf140-20-2',
          investmentUid: investment.uid,
          date: DateTime(2025, 6, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      await DatabaseService.saveHistoricalInvestmentWithOperations(
        investment,
        operations,
      );

      final investments = await DatabaseService.getHistoricalInvestments();

      expect(investments, hasLength(1));
      expect(investments.single.uid, investment.uid);

      final db = await DatabaseService.database;
      final savedOperations = await db.query(
        'historical_operations',
        where: 'investment_uid = ?',
        whereArgs: [investment.uid],
        orderBy: 'date ASC',
      );

      expect(savedOperations, hasLength(2));
      expect(savedOperations.map((row) => row['uid']).toList(), [
        'operation-lf140-20-1',
        'operation-lf140-20-2',
      ]);
    },
  );

  test(
    'LF-140.21: revierte toda la transacción si falla una operación',
    () async {
      // Preparamos una inversión y una operación que ya existen.
      final existingInvestment = HistoricalInvestment(
        uid: 'investment-existing-lf140-21',
        name: 'Inversión existente',
      );

      await DatabaseService.saveHistoricalInvestment(existingInvestment);

      final existingOperation = HistoricalOperation(
        uid: 'operation-lf140-21-2',
        investmentUid: existingInvestment.uid,
        date: DateTime(2024, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 500,
      );

      await DatabaseService.saveHistoricalOperation(existingOperation);

      // La segunda operación colisionará con el UID ya existente.
      final investment = HistoricalInvestment(
        uid: 'investment-lf140-21',
        name: 'Inversión con error',
      );

      final operations = [
        HistoricalOperation(
          uid: 'operation-lf140-21-1',
          investmentUid: investment.uid,
          date: DateTime(2025, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'operation-lf140-21-2',
          investmentUid: investment.uid,
          date: DateTime(2025, 6, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      await expectLater(
        DatabaseService.saveHistoricalInvestmentWithOperations(
          investment,
          operations,
        ),
        throwsA(isA<DatabaseException>()),
      );

      final investments = await DatabaseService.getHistoricalInvestments();

      // La inversión inicial permanece, pero la nueva no se guarda.
      expect(investments, hasLength(1));
      expect(investments.single.uid, existingInvestment.uid);

      final db = await DatabaseService.database;

      // No debe quedar la primera operación de la transacción fallida.
      final targetOperations = await db.query(
        'historical_operations',
        where: 'investment_uid = ?',
        whereArgs: [investment.uid],
      );

      expect(targetOperations, isEmpty);

      // La operación que provocó la colisión sigue intacta.
      final existingOperations = await db.query(
        'historical_operations',
        where: 'uid = ?',
        whereArgs: ['operation-lf140-21-2'],
      );

      expect(existingOperations, hasLength(1));
      expect(
        existingOperations.single['investment_uid'],
        existingInvestment.uid,
      );
    },
  );

  test(
    'LF-140.22: rechaza operaciones pertenecientes a otra inversión',
    () async {
      final investment = HistoricalInvestment(
        uid: 'investment-lf140-22',
        name: 'Inversión principal',
      );

      final operations = [
        HistoricalOperation(
          uid: 'operation-lf140-22-1',
          investmentUid: investment.uid,
          date: DateTime(2025, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'operation-lf140-22-2',
          investmentUid: 'investment-other-lf140-22',
          date: DateTime(2025, 6, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      await expectLater(
        DatabaseService.saveHistoricalInvestmentWithOperations(
          investment,
          operations,
        ),
        throwsA(isA<ArgumentError>()),
      );

      final investments = await DatabaseService.getHistoricalInvestments();

      expect(investments, isEmpty);

      final db = await DatabaseService.database;
      final savedOperations = await db.query('historical_operations');

      expect(savedOperations, isEmpty);
    },
  );
}
