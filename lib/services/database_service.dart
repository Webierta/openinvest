import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/fund_cost.dart';
import '../models/fund_data.dart';

class DatabaseService {
  static Database? _database;
  static String? _databasePathOverride;

  static Future<void> useDatabasePathForTesting(String path) async {
    await close();
    _databasePathOverride = path;
  }

  static Future<void> resetDatabasePathForTesting() async {
    await close();
    _databasePathOverride = null;
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String databasesPath = await getDatabasesPath();
    String oldPath = join(databasesPath, 'investi_scrap.db');
    String newPath =
        _databasePathOverride ?? join(databasesPath, 'open_invest.db');

    // Migración de nombre de archivo de base de datos
    if (_databasePathOverride == null &&
        await databaseExists(oldPath) &&
        !await databaseExists(newPath)) {
      final File oldFile = File(oldPath);
      await oldFile.copy(newPath);
      // Opcionalmente borrar el antiguo, pero mejor dejarlo por seguridad un tiempo
    }

    return await openDatabase(
      newPath,
      version: 11,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE funds (
            isin TEXT PRIMARY KEY,
            symbol TEXT,
            name TEXT,
            currency TEXT,
            last_value REAL,
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
        await _createCostTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE operations (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              isin TEXT,
              date TEXT,
              type TEXT,
              units REAL,
              price REAL
            )
          ''');
        }
        if (oldVersion < 3) {
          try {
            await db.execute('ALTER TABLE operations ADD COLUMN amount REAL');
          } catch (e) {
            // La columna puede existir en bases de datos parcialmente migradas.
          }
          await db.execute(
            'UPDATE operations SET amount = units * price WHERE amount IS NULL',
          );
        }
        if (oldVersion < 4) {
          try {
            await db.execute('ALTER TABLE funds ADD COLUMN alert_min REAL');
            await db.execute('ALTER TABLE funds ADD COLUMN alert_max REAL');
          } catch (e) {
            // Las columnas pueden existir en bases de datos parcialmente migradas.
          }
        }
        if (oldVersion < 5) {
          try {
            await db.execute('ALTER TABLE funds ADD COLUMN ter REAL');
          } catch (e) {
            // La columna puede existir en bases de datos parcialmente migradas.
          }
        }
        if (oldVersion < 6) {
          // Aseguramos que la columna ter existe si por algún motivo la migración 5 falló o se saltó
          try {
            final columns = await db.rawQuery('PRAGMA table_info(funds)');
            final hasTer = columns.any((c) => c['name'] == 'ter');
            if (!hasTer) {
              await db.execute('ALTER TABLE funds ADD COLUMN ter REAL');
            }
          } catch (e) {
            // Ignorar errores si la columna ya existe
          }
        }
        if (oldVersion < 7) {
          try {
            await db.execute(
              'ALTER TABLE funds ADD COLUMN performance_fee REAL',
            );
          } catch (e) {
            // Ignored
          }
        }
        if (oldVersion < 8) {
          await db.execute(
            'ALTER TABLE funds ADD COLUMN morningstar_rating INTEGER',
          );
          await db.execute(
            'ALTER TABLE funds ADD COLUMN morningstar_checked_at TEXT',
          );
          await db.execute(
            'ALTER TABLE funds ADD COLUMN morningstar_last_attempt_at TEXT',
          );
        }
        if (oldVersion < 9) {
          await _createCostTables(db);
          await db.execute('''
            INSERT INTO fund_cost_periods
              (isin, concept, rate_percent, basis, treatment,
               valid_from, valid_to, description)
            SELECT isin, 'ter', ter, 'annualBalance', 'includedInNav',
                   NULL, NULL, NULL
            FROM funds WHERE ter IS NOT NULL
          ''');
          await db.execute('''
            INSERT INTO fund_cost_periods
              (isin, concept, rate_percent, basis, treatment,
               valid_from, valid_to, description)
            SELECT isin, 'performance', performance_fee, 'positiveProfit',
                   'unknown', NULL, NULL,
                   NULL
            FROM funds WHERE performance_fee IS NOT NULL
          ''');
        }
        if (oldVersion < 10) {
          final columns = await db.rawQuery(
            'PRAGMA table_info(fund_cost_charges)',
          );
          final columnNames = columns.map((column) => column['name']).toSet();
          if (!columnNames.contains('performance_period_uid')) {
            await db.execute(
              'ALTER TABLE fund_cost_charges ADD COLUMN performance_period_uid TEXT',
            );
          }
          if (!columnNames.contains('settled_through')) {
            await db.execute(
              'ALTER TABLE fund_cost_charges ADD COLUMN settled_through TEXT',
            );
          }
        }
        if (oldVersion < 11) {
          try {
            await db.execute('ALTER TABLE funds ADD COLUMN source TEXT');
          } catch (_) {
            // La columna puede existir en bases parcialmente migradas.
          }

          try {
            await db.execute(
              'ALTER TABLE funds ADD COLUMN valuation_source TEXT',
            );
          } catch (_) {
            // La columna puede existir en bases parcialmente migradas.
          }
        }
      },
    );
  }

  static Future<void> _createCostTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fund_cost_periods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        isin TEXT NOT NULL,
        concept TEXT NOT NULL,
        rate_percent REAL NOT NULL,
        basis TEXT NOT NULL,
        treatment TEXT NOT NULL,
        valid_from TEXT,
        valid_to TEXT,
        description TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fund_cost_charges (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        isin TEXT NOT NULL,
        concept TEXT NOT NULL,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        performance_period_uid TEXT,
        settled_through TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cost_periods_isin ON fund_cost_periods(isin)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cost_charges_isin_date ON fund_cost_charges(isin, date)',
    );
  }

  static Future<void> _replaceFundCosts(
    DatabaseExecutor executor,
    FundData fund,
  ) async {
    _validateFundCosts(fund);
    await executor.delete(
      'fund_cost_periods',
      where: 'isin = ?',
      whereArgs: [fund.isin],
    );
    await executor.delete(
      'fund_cost_charges',
      where: 'isin = ?',
      whereArgs: [fund.isin],
    );
    for (final period in fund.costPeriods) {
      await executor.insert('fund_cost_periods', {
        'uid': period.uid,
        'isin': fund.isin,
        'concept': period.concept.name,
        'rate_percent': period.ratePercent,
        'basis': period.basis.name,
        'treatment': period.treatment.name,
        'valid_from': period.validFrom?.toIso8601String(),
        'valid_to': period.validTo?.toIso8601String(),
        'description': period.description,
      });
    }
    for (final charge in fund.costCharges) {
      await executor.insert('fund_cost_charges', {
        'uid': charge.uid,
        'isin': fund.isin,
        'concept': charge.concept.name,
        'date': charge.date.toIso8601String(),
        'amount': charge.amount,
        'description': charge.description,
        'performance_period_uid': charge.performancePeriodUid,
        'settled_through': charge.settledThrough?.toIso8601String(),
      });
    }
  }

  static void _validateFundCosts(FundData fund) {
    final periodUids = <String>{};
    for (var index = 0; index < fund.costPeriods.length; index++) {
      final period = fund.costPeriods[index];
      if (!period.ratePercent.isFinite || period.ratePercent < 0) {
        throw ArgumentError('La tasa de coste debe ser finita y no negativa.');
      }
      if (!periodUids.add(period.uid)) {
        throw ArgumentError('Identificador de periodo de coste duplicado.');
      }
      if (period.validFrom == null &&
          (period.validTo != null ||
              period.treatment == FundCostTreatment.chargedSeparately)) {
        throw ArgumentError('El periodo de coste requiere una fecha inicial.');
      }
      if (period.validFrom != null &&
          period.validTo != null &&
          period.validTo!.isBefore(period.validFrom!)) {
        throw ArgumentError('El periodo de coste tiene fechas invertidas.');
      }
      final isOneOffConcept = {
        FundCostConcept.subscription,
        FundCostConcept.redemption,
        FundCostConcept.transfer,
        FundCostConcept.tax,
      }.contains(period.concept);
      if (isOneOffConcept ||
          (period.concept == FundCostConcept.performance &&
              period.basis != FundCostRateBasis.positiveProfit) ||
          (period.concept != FundCostConcept.performance &&
              period.basis != FundCostRateBasis.annualBalance)) {
        throw ArgumentError('La base no corresponde al concepto del coste.');
      }

      for (
        var otherIndex = index + 1;
        otherIndex < fund.costPeriods.length;
        otherIndex++
      ) {
        final other = fund.costPeriods[otherIndex];
        if (period.concept != other.concept) continue;
        final periodStart = period.validFrom ?? DateTime(1);
        final otherStart = other.validFrom ?? DateTime(1);
        final periodEnd = period.validTo ?? DateTime(9999);
        final otherEnd = other.validTo ?? DateTime(9999);
        if (!periodStart.isAfter(otherEnd) && !otherStart.isAfter(periodEnd)) {
          throw ArgumentError('Los periodos del mismo concepto se solapan.');
        }
      }
    }

    final chargeUids = <String>{};
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final firstPurchase = fund.operations
        .where((operation) => operation.type == OperationType.buy)
        .map((operation) => operation.date)
        .fold<DateTime?>(
          null,
          (earliest, date) =>
              earliest == null || date.isBefore(earliest) ? date : earliest,
        );
    for (final charge in fund.costCharges) {
      if (!charge.amount.isFinite || charge.amount <= 0) {
        throw ArgumentError('El importe del cargo debe ser finito y positivo.');
      }
      if (!chargeUids.add(charge.uid)) {
        throw ArgumentError('Identificador de cargo duplicado.');
      }
      if (charge.settledThrough != null &&
          charge.settledThrough!.isAfter(charge.date)) {
        throw ArgumentError(
          'La fecha liquidada no puede ser posterior al cargo.',
        );
      }
      final chargeDate = DateTime(
        charge.date.year,
        charge.date.month,
        charge.date.day,
      );
      final firstPurchaseDate = firstPurchase == null
          ? null
          : DateTime(
              firstPurchase.year,
              firstPurchase.month,
              firstPurchase.day,
            );
      if (chargeDate.isAfter(todayDate) ||
          (firstPurchaseDate != null &&
              chargeDate.isBefore(firstPurchaseDate))) {
        throw ArgumentError(
          'El cargo debe estar dentro del periodo invertido.',
        );
      }
    }
  }

  static FundCostPeriod _periodFromMap(Map<String, dynamic> map) =>
      FundCostPeriod(
        id: map['id'] as int?,
        uid: map['uid'] as String?,
        concept: FundCostConcept.values.firstWhere(
          (value) => value.name == map['concept'],
          orElse: () => FundCostConcept.other,
        ),
        ratePercent: (map['rate_percent'] as num).toDouble(),
        basis: FundCostRateBasis.values.firstWhere(
          (value) => value.name == map['basis'],
          orElse: () => FundCostRateBasis.annualBalance,
        ),
        treatment: FundCostTreatment.values.firstWhere(
          (value) => value.name == map['treatment'],
          orElse: () => FundCostTreatment.unknown,
        ),
        validFrom: DateTime.tryParse(map['valid_from'] as String? ?? ''),
        validTo: DateTime.tryParse(map['valid_to'] as String? ?? ''),
        description: map['description'] as String?,
      );

  static FundCostCharge _chargeFromMap(Map<String, dynamic> map) =>
      FundCostCharge(
        id: map['id'] as int?,
        uid: map['uid'] as String?,
        concept: FundCostConcept.values.firstWhere(
          (value) => value.name == map['concept'],
          orElse: () => FundCostConcept.other,
        ),
        date: DateTime.parse(map['date'] as String),
        amount: (map['amount'] as num).toDouble(),
        description: map['description'] as String?,
        performancePeriodUid: map['performance_period_uid'] as String?,
        settledThrough: DateTime.tryParse(
          map['settled_through'] as String? ?? '',
        ),
      );

  static Future<void> saveFund(FundData fund) async {
    final db = await database;
    final String normalizedDate = DateTime(
      fund.date.year,
      fund.date.month,
      fund.date.day,
    ).toIso8601String();

    await db.transaction((txn) async {
      final existingFund = await txn.query(
        'funds',
        columns: ['isin'],
        where: 'isin = ?',
        whereArgs: [fund.isin],
        limit: 1,
      );
      await txn.insert('funds', {
        'isin': fund.isin,
        'symbol': fund.symbol,
        'name': fund.name,
        'currency': fund.currency,
        'last_value': fund.lastValue,
        'last_update': normalizedDate,
        'alert_min': fund.alertMin,
        'alert_max': fund.alertMax,
        'ter': fund.ter,
        'performance_fee': fund.performanceFee,
        'morningstar_rating': fund.morningstarRating,
        'morningstar_checked_at': fund.morningstarCheckedAt?.toIso8601String(),
        'morningstar_last_attempt_at': fund.morningstarLastAttemptAt
            ?.toIso8601String(),
        'source': fund.source?.name,
        'valuation_source': fund.valuationSource?.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final batch = txn.batch();
      for (final point in fund.history) {
        final pDate = DateTime(
          point.date.year,
          point.date.month,
          point.date.day,
        ).toIso8601String();
        batch.insert('prices', {
          'isin': fund.isin,
          'date': pDate,
          'price': point.price,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      if (fund.lastValue > 0) {
        batch.insert('prices', {
          'isin': fund.isin,
          'date': normalizedDate,
          'price': fund.lastValue,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (existingFund.isEmpty) {
        for (final operation in fund.operations) {
          batch.insert('operations', {
            'isin': operation.isin,
            'date': operation.date.toIso8601String(),
            'type': operation.type.name,
            'units': operation.units,
            'price': operation.price,
            'amount': operation.amount,
          });
        }
      }
      await _replaceFundCosts(txn, fund);
      await batch.commit(noResult: true);
    });
  }

  static Future<void> saveOperation(FundOperation op) async {
    final db = await database;
    if (op.id != null) {
      // Update existing operation
      await db.update(
        'operations',
        {
          'date': op.date.toIso8601String(),
          'type': op.type.name,
          'units': op.units,
          'price': op.price,
          'amount': op.amount,
        },
        where: 'id = ?',
        whereArgs: [op.id],
      );
    } else {
      // Insert new operation
      await db.insert('operations', {
        'isin': op.isin,
        'date': op.date.toIso8601String(),
        'type': op.type.name,
        'units': op.units,
        'price': op.price,
        'amount': op.amount,
      });
    }
  }

  static Future<void> replaceFund(FundData fund) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('funds', where: 'isin = ?', whereArgs: [fund.isin]);
      await txn.delete('prices', where: 'isin = ?', whereArgs: [fund.isin]);
      await txn.delete('operations', where: 'isin = ?', whereArgs: [fund.isin]);

      final normalizedDate = DateTime(
        fund.date.year,
        fund.date.month,
        fund.date.day,
      ).toIso8601String();
      await txn.insert('funds', {
        'isin': fund.isin,
        'symbol': fund.symbol,
        'name': fund.name,
        'currency': fund.currency,
        'last_value': fund.lastValue,
        'last_update': normalizedDate,
        'alert_min': fund.alertMin,
        'alert_max': fund.alertMax,
        'ter': fund.ter,
        'performance_fee': fund.performanceFee,
        'morningstar_rating': fund.morningstarRating,
        'morningstar_checked_at': fund.morningstarCheckedAt?.toIso8601String(),
        'morningstar_last_attempt_at': fund.morningstarLastAttemptAt
            ?.toIso8601String(),
        'source': fund.source?.name,
        'valuation_source': fund.valuationSource?.name,
      });

      final batch = txn.batch();
      for (final point in fund.history) {
        final date = DateTime(
          point.date.year,
          point.date.month,
          point.date.day,
        ).toIso8601String();
        batch.insert('prices', {
          'isin': fund.isin,
          'date': date,
          'price': point.price,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (fund.lastValue > 0) {
        batch.insert('prices', {
          'isin': fund.isin,
          'date': normalizedDate,
          'price': fund.lastValue,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final operation in fund.operations) {
        batch.insert('operations', {
          'isin': operation.isin,
          'date': operation.date.toIso8601String(),
          'type': operation.type.name,
          'units': operation.units,
          'price': operation.price,
          'amount': operation.amount,
        });
      }
      await _replaceFundCosts(txn, fund);
      await batch.commit(noResult: true);
    });
  }

  static Future<void> restoreOperation(FundOperation operation) async {
    final db = await database;
    if (operation.id == null) {
      throw ArgumentError('No se puede restaurar una operación sin id.');
    }
    await db.insert('operations', {
      'id': operation.id,
      'isin': operation.isin,
      'date': operation.date.toIso8601String(),
      'type': operation.type.name,
      'units': operation.units,
      'price': operation.price,
      'amount': operation.amount,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<void> deletePricePoint(String isin, DateTime date) async {
    final db = await database;
    final String pDate = DateTime(
      date.year,
      date.month,
      date.day,
    ).toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'prices',
        where: 'isin = ? AND date = ?',
        whereArgs: [isin, pDate],
      );

      final remaining = await txn.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date DESC',
        limit: 1,
      );

      if (remaining.isEmpty) {
        await txn.update(
          'funds',
          {'last_value': 0.0},
          where: 'isin = ?',
          whereArgs: [isin],
        );
      } else {
        await txn.update(
          'funds',
          {
            'last_value': remaining.first['price'],
            'last_update': remaining.first['date'],
          },
          where: 'isin = ?',
          whereArgs: [isin],
        );
      }
    });
  }

  static Future<void> restorePricePoint(String isin, PricePoint point) async {
    final db = await database;
    final String pDate = DateTime(
      point.date.year,
      point.date.month,
      point.date.day,
    ).toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('prices', {
        'isin': isin,
        'date': pDate,
        'price': point.price,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final latest = await txn.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date DESC',
        limit: 1,
      );
      if (latest.isNotEmpty) {
        await txn.update(
          'funds',
          {
            'last_value': latest.first['price'],
            'last_update': latest.first['date'],
          },
          where: 'isin = ?',
          whereArgs: [isin],
        );
      }
    });
  }

  static Future<List<FundData>> getPortfolio() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('funds');

    List<FundData> funds = [];
    for (var m in maps) {
      final String isin = m['isin'];

      // Get all prices for this fund
      final List<Map<String, dynamic>> priceMaps = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date ASC',
      );

      // Usamos un Map para evitar duplicados por día si hubiera inconsistencias de hora
      final Map<String, PricePoint> historyMap = {};
      for (var pm in priceMaps) {
        final date = DateTime.parse(pm['date']);
        final normalizedDate = DateTime(date.year, date.month, date.day);
        final key = normalizedDate.toIso8601String();
        historyMap[key] = PricePoint(normalizedDate, pm['price']);
      }
      final history = historyMap.values.toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      // Get all operations for this fund
      final List<Map<String, dynamic>> opMaps = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date DESC',
      );

      final operations = opMaps
          .map(
            (om) => FundOperation(
              id: om['id'],
              isin: isin,
              date: DateTime.parse(om['date']),
              type: om['type'] == 'buy'
                  ? OperationType.buy
                  : OperationType.sell,
              units: om['units'],
              price: om['price'],
              amount: om['amount'] ?? (om['units'] * om['price']),
            ),
          )
          .toList();

      final costPeriodMaps = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'valid_from ASC, id ASC',
      );
      final costChargeMaps = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date DESC, id DESC',
      );

      funds.add(
        FundData(
          isin: isin,
          symbol: m['symbol'],
          name: m['name'],
          lastValue: m['last_value'],
          currency: m['currency'],
          date: DateTime.parse(m['last_update']),
          history: history,
          operations: operations,
          alertMin: m['alert_min'],
          alertMax: m['alert_max'],
          ter: m['ter'],
          performanceFee: m['performance_fee'],
          costPeriods: costPeriodMaps.map(_periodFromMap).toList(),
          costCharges: costChargeMaps.map(_chargeFromMap).toList(),
          morningstarRating: m['morningstar_rating'] as int?,
          morningstarCheckedAt: m['morningstar_checked_at'] == null
              ? null
              : DateTime.parse(m['morningstar_checked_at']),
          morningstarLastAttemptAt: m['morningstar_last_attempt_at'] == null
              ? null
              : DateTime.parse(m['morningstar_last_attempt_at']),
          source: _fundSourceFromDatabase(m['source'] as String?),
          valuationSource: _fundSourceFromDatabase(
            m['valuation_source'] as String?,
          ),
        ),
      );
    }
    return funds;
  }

  static FundSource? _fundSourceFromDatabase(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final source in FundSource.values) {
      if (source.name == value) return source;
    }
    return null;
  }

  static Future<FundData?> getFund(String isin) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'funds',
      where: 'isin = ?',
      whereArgs: [isin],
    );

    if (maps.isEmpty) return null;

    final m = maps.first;

    final List<Map<String, dynamic>> priceMaps = await db.query(
      'prices',
      where: 'isin = ?',
      whereArgs: [isin],
      orderBy: 'date ASC',
    );

    final Map<String, PricePoint> historyMap = {};
    for (var pm in priceMaps) {
      final date = DateTime.parse(pm['date']);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final key = normalizedDate.toIso8601String();
      historyMap[key] = PricePoint(normalizedDate, pm['price']);
    }
    final history = historyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final List<Map<String, dynamic>> opMaps = await db.query(
      'operations',
      where: 'isin = ?',
      whereArgs: [isin],
      orderBy: 'date DESC',
    );

    final operations = opMaps
        .map(
          (om) => FundOperation(
            id: om['id'],
            isin: isin,
            date: DateTime.parse(om['date']),
            type: om['type'] == 'buy' ? OperationType.buy : OperationType.sell,
            units: om['units'],
            price: om['price'],
            amount: om['amount'] ?? (om['units'] * om['price']),
          ),
        )
        .toList();

    final costPeriodMaps = await db.query(
      'fund_cost_periods',
      where: 'isin = ?',
      whereArgs: [isin],
      orderBy: 'valid_from ASC, id ASC',
    );
    final costChargeMaps = await db.query(
      'fund_cost_charges',
      where: 'isin = ?',
      whereArgs: [isin],
      orderBy: 'date DESC, id DESC',
    );

    return FundData(
      isin: isin,
      symbol: m['symbol'],
      name: m['name'],
      lastValue: m['last_value'],
      currency: m['currency'],
      date: DateTime.parse(m['last_update']),
      history: history,
      operations: operations,
      alertMin: m['alert_min'],
      alertMax: m['alert_max'],
      ter: m['ter'],
      performanceFee: m['performance_fee'],
      costPeriods: costPeriodMaps.map(_periodFromMap).toList(),
      costCharges: costChargeMaps.map(_chargeFromMap).toList(),
      morningstarRating: m['morningstar_rating'] as int?,
      morningstarCheckedAt: m['morningstar_checked_at'] == null
          ? null
          : DateTime.parse(m['morningstar_checked_at']),
      morningstarLastAttemptAt: m['morningstar_last_attempt_at'] == null
          ? null
          : DateTime.parse(m['morningstar_last_attempt_at']),
      source: _fundSourceFromDatabase(m['source'] as String?),
      valuationSource: _fundSourceFromDatabase(
        m['valuation_source'] as String?,
      ),
    );
  }

  static Future<void> updateMorningstarAttempt(
    String isin,
    DateTime attemptedAt,
  ) async {
    final db = await database;
    await db.update(
      'funds',
      {'morningstar_last_attempt_at': attemptedAt.toIso8601String()},
      where: 'isin = ?',
      whereArgs: [isin],
    );
  }

  static Future<void> updateMorningstarRating(
    String isin, {
    required int? rating,
    required DateTime checkedAt,
  }) async {
    final db = await database;
    final values = <String, Object?>{
      'morningstar_checked_at': checkedAt.toIso8601String(),
    };
    if (rating != null) values['morningstar_rating'] = rating;
    await db.update('funds', values, where: 'isin = ?', whereArgs: [isin]);
  }

  static Future<void> deleteFund(String isin) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('funds', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('prices', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('operations', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
      );
      await txn.delete(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
      );
    });
  }

  static Future<void> clearAllData(String isin) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('prices', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('operations', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
      );
      await txn.update(
        'funds',
        {'last_value': 0.0},
        where: 'isin = ?',
        whereArgs: [isin],
      );
    });
  }

  static Future<void> clearPortfolio() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('funds');
      await txn.delete('prices');
      await txn.delete('operations');
      await txn.delete('fund_cost_periods');
      await txn.delete('fund_cost_charges');
    });
  }

  static Future<void> deleteOperation(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('operations', where: 'id = ?', whereArgs: [id]);
    });
  }

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
