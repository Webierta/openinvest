import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'fund_scraper.dart';

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
      version: 4,
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
            alert_max REAL
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
      },
    );
  }

  static Future<void> saveFund(FundData fund) async {
    final db = await database;
    final String normalizedDate = DateTime(
      fund.date.year,
      fund.date.month,
      fund.date.day,
    ).toIso8601String();

    await db.transaction((txn) async {
      await txn.insert('funds', {
        'isin': fund.isin,
        'symbol': fund.symbol,
        'name': fund.name,
        'currency': fund.currency,
        'last_value': fund.lastValue,
        'last_update': normalizedDate,
        'alert_min': fund.alertMin,
        'alert_max': fund.alertMax,
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
        ),
      );
    }
    return funds;
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
    );
  }

  static Future<void> deleteFund(String isin) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('funds', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('prices', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('operations', where: 'isin = ?', whereArgs: [isin]);
    });
  }

  static Future<void> clearAllData(String isin) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('prices', where: 'isin = ?', whereArgs: [isin]);
      await txn.delete('operations', where: 'isin = ?', whereArgs: [isin]);
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
