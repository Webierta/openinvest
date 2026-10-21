import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00LF1030001';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf103_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  Map<String, dynamic> createCollectionJson({
    bool duplicatePeriodUid = false,
    bool duplicateChargeUid = false,
  }) {
    final firstPeriod = FundCostPeriod(
      uid: 'lf103-performance-1',
      concept: FundCostConcept.performance,
      ratePercent: 8.5,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 6, 30),
      description: 'Primer periodo',
    );

    final secondPeriod = FundCostPeriod(
      uid: duplicatePeriodUid ? firstPeriod.uid : 'lf103-performance-2',
      concept: FundCostConcept.performance,
      ratePercent: 9.0,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 7, 1),
      validTo: DateTime(2026, 12, 31),
      description: 'Segundo periodo',
    );

    final firstCharge = FundCostCharge(
      uid: 'lf103-charge-1',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 6, 15),
      amount: 12.50,
      description: 'Primer cargo',
      performancePeriodUid: firstPeriod.uid,
      settledThrough: DateTime(2026, 6, 14),
    );

    final secondCharge = FundCostCharge(
      uid: duplicateChargeUid ? firstCharge.uid : 'lf103-charge-2',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 15.75,
      description: 'Segundo cargo',
      performancePeriodUid: secondPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    return jsonDecode(
      jsonEncode({
        'periods': [firstPeriod.toJson(), secondPeriod.toJson()],
        'charges': [firstCharge.toJson(), secondCharge.toJson()],
      }),
    ) as Map<String, dynamic>;
  }

  FundData fundFromJson(Map<String, dynamic> json) {
    final periods = (json['periods'] as List)
        .map(
          (item) =>
              FundCostPeriod.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final charges = (json['charges'] as List)
        .map(
          (item) =>
              FundCostCharge.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return FundData(
      isin: isin,
      symbol: 'LF103',
      name: 'Fondo de prueba LF-103',
      lastValue: 105,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [
        PricePoint(DateTime(2026, 10, 19), 100),
        PricePoint(DateTime(2026, 10, 20), 105),
      ],
      costPeriods: periods,
      costCharges: charges,
    );
  }

  Map<String, dynamic> collectionToJson(FundData fund) {
    return jsonDecode(
      jsonEncode({
        'periods': fund.costPeriods.map((period) => period.toJson()).toList(),
        'charges': fund.costCharges.map((charge) => charge.toJson()).toList(),
      }),
    ) as Map<String, dynamic>;
  }

  test(
    'LF-103.1: rechaza UID duplicados entre periodos de la colección JSON',
    () async {
      final fund = fundFromJson(createCollectionJson(duplicatePeriodUid: true));

      await expectLater(DatabaseService.saveFund(fund), throwsArgumentError);

      expect(await DatabaseService.getFund(isin), isNull);
    },
  );

  test(
    'LF-103.2: rechaza UID duplicados entre cargos de la colección JSON',
    () async {
      final fund = fundFromJson(createCollectionJson(duplicateChargeUid: true));

      await expectLater(DatabaseService.saveFund(fund), throwsArgumentError);

      expect(await DatabaseService.getFund(isin), isNull);
    },
  );

  test(
    'LF-103.3: conserva UID y referencias tras JSON, SQLite y JSON',
    () async {
      final originalJson = createCollectionJson();
      final originalFund = fundFromJson(originalJson);

      await DatabaseService.saveFund(originalFund);

      final restoredFund = await DatabaseService.getFund(isin);
      expect(restoredFund, isNotNull);

      final restoredJson = collectionToJson(restoredFund!);
      final restoredAgain = fundFromJson(restoredJson);

      expect(restoredAgain.costPeriods.map((period) => period.uid).toList(), [
        'lf103-performance-1',
        'lf103-performance-2',
      ]);

      expect(restoredAgain.costCharges.map((charge) => charge.uid).toSet(), {
        'lf103-charge-1',
        'lf103-charge-2',
      });

      expect(
        restoredAgain.costCharges
            .map((charge) => charge.performancePeriodUid)
            .toSet(),
        {'lf103-performance-1', 'lf103-performance-2'},
      );

      await DatabaseService.saveFund(restoredAgain);

      final finalFund = await DatabaseService.getFund(isin);
      expect(finalFund, isNotNull);
      expect(finalFund!.costPeriods, hasLength(2));
      expect(finalFund.costCharges, hasLength(2));

      expect(finalFund.costPeriods.map((period) => period.uid).toSet(), {
        'lf103-performance-1',
        'lf103-performance-2',
      });

      expect(finalFund.costCharges.map((charge) => charge.uid).toSet(), {
        'lf103-charge-1',
        'lf103-charge-2',
      });

      expect(
        finalFund.costCharges
            .map((charge) => charge.performancePeriodUid)
            .toSet(),
        {'lf103-performance-1', 'lf103-performance-2'},
      );
    },
  );
}
