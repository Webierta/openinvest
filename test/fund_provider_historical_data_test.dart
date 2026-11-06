import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/providers/fund_provider.dart';
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
      'fund_provider_historical_test_',
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
    'LF-139.1: loadPortfolio carga inversiones y operaciones históricas',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-001',
        name: 'Inversión histórica',
      );

      final operation = HistoricalOperation(
        uid: 'operation-001',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      await DatabaseService.saveHistoricalInvestment(investment);
      await DatabaseService.saveHistoricalOperation(operation);

      final provider = FundProvider();

      await provider.loadPortfolio();

      expect(provider.historicalInvestments, hasLength(1));
      expect(provider.historicalInvestments.single.uid, investment.uid);

      expect(provider.historicalOperations, hasLength(1));
      expect(provider.historicalOperations.single.uid, operation.uid);
      expect(
        provider.historicalOperations.single.investmentUid,
        investment.uid,
      );
    },
  );

  test(
    'LF-139.2: loadPortfolio actualiza los datos históricos sin duplicarlos',
    () async {
      final firstInvestment = HistoricalInvestment(
        uid: 'historical-001',
        name: 'Primera inversión',
      );

      await DatabaseService.saveHistoricalInvestment(firstInvestment);
      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'operation-001',
          investmentUid: firstInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      );

      final provider = FundProvider();

      await provider.loadPortfolio();

      expect(provider.historicalInvestments, hasLength(1));
      expect(provider.historicalOperations, hasLength(1));

      final secondInvestment = HistoricalInvestment(
        uid: 'historical-002',
        name: 'Segunda inversión',
      );

      await DatabaseService.saveHistoricalInvestment(secondInvestment);
      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'operation-002',
          investmentUid: secondInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
      );

      await provider.loadPortfolio();

      expect(provider.historicalInvestments, hasLength(2));
      expect(provider.historicalOperations, hasLength(2));

      expect(
        provider.historicalInvestments.map((investment) => investment.uid),
        containsAll(['historical-001', 'historical-002']),
      );

      expect(
        provider.historicalOperations.map((operation) => operation.uid),
        containsAll(['operation-001', 'operation-002']),
      );
    },
  );

  test(
    'LF-139.3: loadPortfolio carga inversiones aunque no tengan operaciones',
    () async {
      final investment = HistoricalInvestment(
        uid: 'historical-empty',
        name: 'Inversión sin operaciones',
      );

      await DatabaseService.saveHistoricalInvestment(investment);

      final provider = FundProvider();

      await provider.loadPortfolio();

      expect(provider.historicalInvestments, hasLength(1));
      expect(provider.historicalInvestments.single.uid, investment.uid);
      expect(provider.historicalOperations, isEmpty);
    },
  );

  test(
    'LF-139.4: loadPortfolio mantiene separadas las operaciones por inversión',
    () async {
      final firstInvestment = HistoricalInvestment(
        uid: 'historical-A',
        name: 'Inversión A',
      );
      final secondInvestment = HistoricalInvestment(
        uid: 'historical-B',
        name: 'Inversión B',
      );

      await DatabaseService.saveHistoricalInvestment(firstInvestment);
      await DatabaseService.saveHistoricalInvestment(secondInvestment);

      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'operation-A',
          investmentUid: firstInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      );

      await DatabaseService.saveHistoricalOperation(
        HistoricalOperation(
          uid: 'operation-B',
          investmentUid: secondInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
      );

      final provider = FundProvider();

      await provider.loadPortfolio();

      expect(provider.historicalInvestments, hasLength(2));
      expect(provider.historicalOperations, hasLength(2));

      final investmentUids = provider.historicalOperations
          .map((operation) => operation.investmentUid)
          .toSet();

      expect(investmentUids, {'historical-A', 'historical-B'});

      final operationA = provider.historicalOperations.singleWhere(
        (operation) => operation.uid == 'operation-A',
      );
      final operationB = provider.historicalOperations.singleWhere(
        (operation) => operation.uid == 'operation-B',
      );

      expect(operationA.investmentUid, firstInvestment.uid);
      expect(operationB.investmentUid, secondInvestment.uid);
    },
  );

  test('LF-139.5: loadPortfolio refleja la eliminación de inversiones y operaciones', () async {
    final investment = HistoricalInvestment(
      uid: 'historical-delete',
      name: 'Inversión eliminable',
    );

    await DatabaseService.saveHistoricalInvestment(investment);
    await DatabaseService.saveHistoricalOperation(
      HistoricalOperation(
        uid: 'operation-delete',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      ),
    );

    final provider = FundProvider();

    await provider.loadPortfolio();

    expect(provider.historicalInvestments, hasLength(1));
    expect(provider.historicalOperations, hasLength(1));

    await DatabaseService.deleteHistoricalInvestment(investment.uid);
    await provider.loadPortfolio();

    expect(provider.historicalInvestments, isEmpty);
    expect(provider.historicalOperations, isEmpty);
  });
}
