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

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf75_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  test('LF-75.1: saveFund revierte todos los cambios si falla la validación de costes', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf75-original-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      description: 'Periodo original',
    );

    final originalFund = FundData(
      isin: isin,
      symbol: 'ORIGINAL',
      name: 'Fondo original',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [PricePoint(DateTime(2026, 10, 20), 100)],
      costPeriods: [originalPeriod],
    );

    await DatabaseService.saveFund(originalFund);

    // El mismo UID en dos periodos debe invalidar el fondo.
    final invalidFund = FundData(
      isin: isin,
      symbol: 'MODIFIED',
      name: 'Fondo modificado',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf75-duplicate-period',
          concept: FundCostConcept.management,
          ratePercent: 0.80,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
        FundCostPeriod(
          uid: 'lf75-duplicate-period',
          concept: FundCostConcept.ter,
          ratePercent: 0.20,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'ORIGINAL');
    expect(savedFund.name, 'Fondo original');
    expect(savedFund.lastValue, 100);
    expect(savedFund.date, DateTime(2026, 10, 20));
    expect(savedFund.history, hasLength(1));

    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf75-original-period');
    expect(savedFund.costPeriods.single.ratePercent, 0.65);
  });

  test('LF-75.2: saveFund conserva los cargos y sus relaciones si falla la validación', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf75-2-original-performance',
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      description: 'Comisión de éxito original',
    );

    final originalCharge = FundCostCharge(
      uid: 'lf75-2-original-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 12.50,
      description: 'Cargo original',
      performancePeriodUid: originalPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    final originalFund = FundData(
      isin: isin,
      symbol: 'ORIGINAL',
      name: 'Fondo original',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [PricePoint(DateTime(2026, 10, 20), 100)],
      costPeriods: [originalPeriod],
      costCharges: [originalCharge],
    );

    await DatabaseService.saveFund(originalFund);

    final invalidFund = FundData(
      isin: isin,
      symbol: 'MODIFIED',
      name: 'Fondo modificado',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf75-2-duplicate-period',
          concept: FundCostConcept.management,
          ratePercent: 0.80,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
        FundCostPeriod(
          uid: 'lf75-2-duplicate-period',
          concept: FundCostConcept.ter,
          ratePercent: 0.20,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'ORIGINAL');
    expect(savedFund.name, 'Fondo original');
    expect(savedFund.lastValue, 100);
    expect(savedFund.history, hasLength(1));

    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf75-2-original-performance');
    expect(savedFund.costPeriods.single.ratePercent, 10);

    expect(savedFund.costCharges, hasLength(1));
    final savedCharge = savedFund.costCharges.single;

    expect(savedCharge.uid, 'lf75-2-original-charge');
    expect(savedCharge.concept, FundCostConcept.performance);
    expect(savedCharge.date, DateTime(2026, 10, 20));
    expect(savedCharge.amount, 12.50);
    expect(savedCharge.description, 'Cargo original');
    expect(savedCharge.performancePeriodUid, 'lf75-2-original-performance');
    expect(savedCharge.settledThrough, DateTime(2026, 10, 19));
  });

  test('LF-76.1: saveFund sustituye los costes anteriores por los nuevos sin duplicados', () async {
    final oldPeriod = FundCostPeriod(
      uid: 'lf76-old-performance-period',
      concept: FundCostConcept.performance,
      ratePercent: 8,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      description: 'Comisión de éxito antigua',
    );

    final oldCharge = FundCostCharge(
      uid: 'lf76-old-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 18),
      amount: 8,
      description: 'Cargo antiguo',
      performancePeriodUid: oldPeriod.uid,
      settledThrough: DateTime(2026, 10, 17),
    );

    final originalFund = FundData(
      isin: isin,
      symbol: 'LF76',
      name: 'Fondo LF76',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [PricePoint(DateTime(2026, 10, 20), 100)],
      costPeriods: [oldPeriod],
      costCharges: [oldCharge],
    );

    await DatabaseService.saveFund(originalFund);

    final newPeriod = FundCostPeriod(
      uid: 'lf76-new-performance-period',
      concept: FundCostConcept.performance,
      ratePercent: 12,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      description: 'Comisión de éxito nueva',
    );

    final newCharge = FundCostCharge(
      uid: 'lf76-new-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 12.50,
      description: 'Cargo nuevo',
      performancePeriodUid: newPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    final updatedFund = FundData(
      isin: isin,
      symbol: 'LF76',
      name: 'Fondo LF76 actualizado',
      lastValue: 105,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 105),
      ],
      costPeriods: [newPeriod],
      costCharges: [newCharge],
    );

    await DatabaseService.saveFund(updatedFund);

    // Recargar desde SQLite para verificar la persistencia real.
    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.name, 'Fondo LF76 actualizado');
    expect(savedFund.lastValue, 105);

    // Solo debe quedar el periodo nuevo.
    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf76-new-performance-period');
    expect(savedFund.costPeriods.single.ratePercent, 12);
    expect(
      savedFund.costPeriods.any(
        (period) => period.uid == 'lf76-old-performance-period',
      ),
      isFalse,
    );

    // Solo debe quedar el cargo nuevo.
    expect(savedFund.costCharges, hasLength(1));
    final savedCharge = savedFund.costCharges.single;

    expect(savedCharge.uid, 'lf76-new-charge');
    expect(savedCharge.amount, 12.50);
    expect(savedCharge.description, 'Cargo nuevo');
    expect(savedCharge.performancePeriodUid, 'lf76-new-performance-period');
    expect(
      savedFund.costCharges.any((charge) => charge.uid == 'lf76-old-charge'),
      isFalse,
    );

    // El vínculo del cargo debe apuntar a un periodo existente.
    expect(
      savedFund.costPeriods.any(
        (period) => period.uid == savedCharge.performancePeriodUid,
      ),
      isTrue,
    );
  });

  test(
    'LF-77.1: guardar dos veces los mismos costes no crea duplicados',
    () async {
      final period = FundCostPeriod(
        uid: 'lf77-performance-period',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
        description: 'Comisión de éxito LF-77',
      );

      final charge = FundCostCharge(
        uid: 'lf77-performance-charge',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 15.25,
        description: 'Cargo LF-77',
        performancePeriodUid: period.uid,
        settledThrough: DateTime(2026, 10, 19),
      );

      final fund = FundData(
        isin: isin,
        symbol: 'LF77',
        name: 'Fondo LF77',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [period],
        costCharges: [charge],
      );

      // Primera persistencia.
      await DatabaseService.saveFund(fund);

      // Segunda persistencia del mismo fondo y de los mismos costes.
      await DatabaseService.saveFund(fund);

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.costPeriods, hasLength(1));
      expect(savedFund.costCharges, hasLength(1));

      final savedPeriod = savedFund.costPeriods.single;
      final savedCharge = savedFund.costCharges.single;

      expect(savedPeriod.uid, 'lf77-performance-period');
      expect(savedPeriod.concept, FundCostConcept.performance);
      expect(savedPeriod.ratePercent, 10);
      expect(savedPeriod.basis, FundCostRateBasis.positiveProfit);
      expect(savedPeriod.treatment, FundCostTreatment.chargedSeparately);
      expect(savedPeriod.validFrom, DateTime(2026, 1, 1));
      expect(savedPeriod.description, 'Comisión de éxito LF-77');

      expect(savedCharge.uid, 'lf77-performance-charge');
      expect(savedCharge.concept, FundCostConcept.performance);
      expect(savedCharge.date, DateTime(2026, 10, 20));
      expect(savedCharge.amount, 15.25);
      expect(savedCharge.description, 'Cargo LF-77');
      expect(savedCharge.performancePeriodUid, savedPeriod.uid);
      expect(savedCharge.settledThrough, DateTime(2026, 10, 19));

      // Comprobar que el vínculo no apunta a un periodo inexistente.
      expect(
        savedFund.costPeriods.any(
          (item) => item.uid == savedCharge.performancePeriodUid,
        ),
        isTrue,
      );
    },
  );

  test(
    'LF-78.1: saveFund rechaza cargos que referencian periodos inexistentes',
    () async {
      final originalPeriod = FundCostPeriod(
        uid: 'lf78-original-period',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
        description: 'Periodo original',
      );

      final originalCharge = FundCostCharge(
        uid: 'lf78-original-charge',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 10,
        description: 'Cargo original',
        performancePeriodUid: originalPeriod.uid,
        settledThrough: DateTime(2026, 10, 19),
      );

      final originalFund = FundData(
        isin: isin,
        symbol: 'LF78',
        name: 'Fondo original LF-78',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      );

      await DatabaseService.saveFund(originalFund);

      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF78-MOD',
        name: 'Fondo modificado LF-78',
        lastValue: 200,
        currency: 'EUR',
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 20), 100),
          PricePoint(DateTime(2026, 10, 21), 200),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf78-new-period',
            concept: FundCostConcept.performance,
            ratePercent: 12,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            description: 'Periodo nuevo',
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'lf78-invalid-charge',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 20),
            amount: 20,
            description: 'Cargo con referencia inexistente',
            performancePeriodUid: 'lf78-period-does-not-exist',
            settledThrough: DateTime(2026, 10, 19),
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'LF78');
      expect(savedFund.name, 'Fondo original LF-78');
      expect(savedFund.lastValue, 100);
      expect(savedFund.history, hasLength(1));

      expect(savedFund.costPeriods, hasLength(1));
      expect(savedFund.costPeriods.single.uid, 'lf78-original-period');

      expect(savedFund.costCharges, hasLength(1));
      expect(savedFund.costCharges.single.uid, 'lf78-original-charge');
      expect(
        savedFund.costCharges.single.performancePeriodUid,
        'lf78-original-period',
      );
    },
  );
}
