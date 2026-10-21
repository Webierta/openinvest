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

  const isin = 'IE00LF1020001';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf102_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  Map<String, dynamic> createJsonCollection({
    String periodUid = 'lf102-performance-period',
    String chargePeriodUid = 'lf102-performance-period',
    FundCostConcept periodConcept = FundCostConcept.performance,
    DateTime? validFrom,
    DateTime? validTo,
    DateTime? chargeDate,
  }) {
    final period = FundCostPeriod(
      uid: periodUid,
      concept: periodConcept,
      ratePercent: periodConcept == FundCostConcept.performance ? 8.5 : 0.65,
      basis: periodConcept == FundCostConcept.performance
          ? FundCostRateBasis.positiveProfit
          : FundCostRateBasis.annualBalance,
      treatment: periodConcept == FundCostConcept.performance
          ? FundCostTreatment.chargedSeparately
          : FundCostTreatment.includedInNav,
      validFrom: validFrom ?? DateTime(2026, 1, 1),
      validTo: validTo ?? DateTime(2026, 12, 31),
      description: 'Periodo LF-102',
    );

    final charge = FundCostCharge(
      uid: 'lf102-performance-charge',
      concept: FundCostConcept.performance,
      date: chargeDate ?? DateTime(2026, 10, 20),
      amount: 12.50,
      description: 'Cargo LF-102',
      performancePeriodUid: chargePeriodUid,
      settledThrough: DateTime(2026, 10, 19),
    );

    return jsonDecode(
      jsonEncode({
        'periods': [period.toJson()],
        'charges': [charge.toJson()],
      }),
    ) as Map<String, dynamic>;
  }

  FundData fundFromJson(
    Map<String, dynamic> collection, {
    String symbol = 'LF102',
    String name = 'Fondo LF-102',
    double lastValue = 105,
  }) {
    final periods = (collection['periods'] as List)
        .map(
          (item) =>
              FundCostPeriod.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    final charges = (collection['charges'] as List)
        .map(
          (item) =>
              FundCostCharge.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    return FundData(
      isin: isin,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [
        PricePoint(DateTime(2026, 10, 19), 100),
        PricePoint(DateTime(2026, 10, 20), lastValue),
      ],
      costPeriods: periods,
      costCharges: charges,
    );
  }

  Future<void> saveOriginalFund() async {
    await DatabaseService.saveFund(
      fundFromJson(
        createJsonCollection(),
        symbol: 'ORIGINAL',
        name: 'Fondo original LF-102',
        lastValue: 100,
      ),
    );
  }

  Future<void> expectOriginalFundUnchanged() async {
    final restored = await DatabaseService.getFund(isin);

    expect(restored, isNotNull);
    expect(restored!.symbol, 'ORIGINAL');
    expect(restored.name, 'Fondo original LF-102');
    expect(restored.lastValue, 100);

    expect(restored.costPeriods, hasLength(1));
    expect(restored.costPeriods.single.uid, 'lf102-performance-period');
    expect(restored.costPeriods.single.concept, FundCostConcept.performance);

    expect(restored.costCharges, hasLength(1));
    expect(restored.costCharges.single.uid, 'lf102-performance-charge');
    expect(
      restored.costCharges.single.performancePeriodUid,
      'lf102-performance-period',
    );
    expect(restored.costCharges.single.amount, 12.50);
  }

  test('LF-102.1: rechaza referencias JSON a periodos inexistentes', () async {
    await saveOriginalFund();

    final invalidFund = fundFromJson(
      createJsonCollection(chargePeriodUid: 'lf102-period-does-not-exist'),
      symbol: 'INVALID',
      name: 'Fondo con referencia inexistente',
      lastValue: 200,
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    await expectOriginalFundUnchanged();
  });

  test(
    'LF-102.2: rechaza referencias JSON a periodos que no son de éxito',
    () async {
      await saveOriginalFund();

      final invalidFund = fundFromJson(
        createJsonCollection(
          periodUid: 'lf102-management-period',
          chargePeriodUid: 'lf102-management-period',
          periodConcept: FundCostConcept.management,
        ),
        symbol: 'INVALID',
        name: 'Fondo con referencia a gestión',
        lastValue: 200,
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      await expectOriginalFundUnchanged();
    },
  );

  test(
    'LF-102.3: rechaza cargos JSON posteriores al fin del periodo',
    () async {
      await saveOriginalFund();

      final invalidFund = fundFromJson(
        createJsonCollection(
          validFrom: DateTime(2026, 1, 1),
          validTo: DateTime(2026, 10, 1),
          chargeDate: DateTime(2026, 10, 20),
        ),
        symbol: 'INVALID',
        name: 'Fondo con cargo fuera de vigencia',
        lastValue: 200,
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      await expectOriginalFundUnchanged();
    },
  );

  test(
    'LF-102.4: rechaza cargos JSON anteriores al inicio del periodo',
    () async {
      await saveOriginalFund();

      final invalidFund = fundFromJson(
        createJsonCollection(
          validFrom: DateTime(2026, 10, 1),
          validTo: DateTime(2026, 12, 31),
          chargeDate: DateTime(2026, 9, 20),
        ),
        symbol: 'INVALID',
        name: 'Fondo con cargo anterior a vigencia',
        lastValue: 200,
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      await expectOriginalFundUnchanged();
    },
  );
}
