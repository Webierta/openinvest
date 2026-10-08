import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:investing/services/database_service.dart';
import 'package:investing/models/fund_cost.dart';

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
}
