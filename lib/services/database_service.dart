import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'fund_scraper.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    String databasesPath = await getDatabasesPath();
    String oldPath = join(databasesPath, 'investi_scrap.db');
    String newPath = join(databasesPath, 'open_invest.db');

    // Migración de nombre de archivo de base de datos
    if (await databaseExists(oldPath) && !await databaseExists(newPath)) {
      final File oldFile = File(oldPath);
      await oldFile.copy(newPath);
      // Opcionalmente borrar el antiguo, pero mejor dejarlo por seguridad un tiempo
    }

    return await openDatabase(
      newPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE funds (
            isin TEXT PRIMARY KEY,
            symbol TEXT,
            name TEXT,
            currency TEXT,
            last_value REAL,
            last_update TEXT
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
            // Column might already exist if versioning was messy
          }
          await db.execute('UPDATE operations SET amount = units * price WHERE amount IS NULL');
        }
      },
    );
  }

  static Future<void> saveFund(FundData fund) async {
    final db = await database;
    final String normalizedDate = DateTime(fund.date.year, fund.date.month, fund.date.day).toIso8601String();
    
    // Save fund info
    await db.insert(
      'funds',
      {
        'isin': fund.isin,
        'symbol': fund.symbol,
        'name': fund.name,
        'currency': fund.currency,
        'last_value': fund.lastValue,
        'last_update': normalizedDate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Save historical prices
    Batch batch = db.batch();
    
    if (fund.history.isNotEmpty) {
      for (var point in fund.history) {
        final String pDate = DateTime(point.date.year, point.date.month, point.date.day).toIso8601String();
        batch.insert(
          'prices',
          {
            'isin': fund.isin,
            'date': pDate,
            'price': point.price,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Force current lastValue to be the record for its day
    batch.insert(
      'prices',
      {
        'isin': fund.isin,
        'date': normalizedDate,
        'price': fund.lastValue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await batch.commit(noResult: true);
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

  static Future<void> deleteOperation(int id) async {
    final db = await database;
    await db.delete('operations', where: 'id = ?', whereArgs: [id]);
  }

  static Future<void> deletePricePoint(String isin, DateTime date) async {
    final db = await database;
    final String pDate = DateTime(date.year, date.month, date.day).toIso8601String();
    await db.delete('prices', where: 'isin = ? AND date = ?', whereArgs: [isin, pDate]);
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
      final history = historyMap.values.toList()..sort((a, b) => a.date.compareTo(b.date));

      // Get all operations for this fund
      final List<Map<String, dynamic>> opMaps = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'date DESC',
      );

      final operations = opMaps.map((om) => FundOperation(
        id: om['id'],
        isin: isin,
        date: DateTime.parse(om['date']),
        type: om['type'] == 'buy' ? OperationType.buy : OperationType.sell,
        units: om['units'],
        price: om['price'],
        amount: om['amount'] ?? (om['units'] * om['price']),
      )).toList();

      funds.add(FundData(
        isin: isin,
        symbol: m['symbol'],
        name: m['name'],
        lastValue: m['last_value'],
        currency: m['currency'],
        date: DateTime.parse(m['last_update']),
        history: history,
        operations: operations,
      ));
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
    final history = historyMap.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    final List<Map<String, dynamic>> opMaps = await db.query(
      'operations',
      where: 'isin = ?',
      whereArgs: [isin],
      orderBy: 'date DESC',
    );

    final operations = opMaps.map((om) => FundOperation(
      id: om['id'],
      isin: isin,
      date: DateTime.parse(om['date']),
      type: om['type'] == 'buy' ? OperationType.buy : OperationType.sell,
      units: om['units'],
      price: om['price'],
      amount: om['amount'] ?? (om['units'] * om['price']),
    )).toList();

    return FundData(
      isin: isin,
      symbol: m['symbol'],
      name: m['name'],
      lastValue: m['last_value'],
      currency: m['currency'],
      date: DateTime.parse(m['last_update']),
      history: history,
      operations: operations,
    );
  }

  static Future<void> deleteFund(String isin) async {
    final db = await database;
    await db.delete('funds', where: 'isin = ?', whereArgs: [isin]);
    await db.delete('prices', where: 'isin = ?', whereArgs: [isin]);
    await db.delete('operations', where: 'isin = ?', whereArgs: [isin]);
  }

  static Future<void> clearAllData(String isin) async {
    final db = await database;
    await db.delete('prices', where: 'isin = ?', whereArgs: [isin]);
    await db.delete('operations', where: 'isin = ?', whereArgs: [isin]);
    await db.update('funds', {'last_value': 0.0}, where: 'isin = ?', whereArgs: [isin]);
  }

  static Future<void> clearPortfolio() async {
    final db = await database;
    await db.delete('funds');
    await db.delete('prices');
    await db.delete('operations');
  }
}
