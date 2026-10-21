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

  FundCostPeriod makePerformancePeriod(String uid) => FundCostPeriod(
    uid: uid,
    concept: FundCostConcept.performance,
    ratePercent: 10,
    basis: FundCostRateBasis.positiveProfit,
    treatment: FundCostTreatment.chargedSeparately,
    validFrom: DateTime(2026, 1, 1),
    description: 'Periodo $uid',
  );

  FundCostCharge makePerformanceCharge(String uid, String periodUid) =>
      FundCostCharge(
        uid: uid,
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 12.50,
        description: 'Cargo $uid',
        performancePeriodUid: periodUid,
        settledThrough: DateTime(2026, 10, 19),
      );

  FundData makeFund({
    required String fundIsin,
    required String symbol,
    List<FundCostPeriod> costPeriods = const [],
    List<FundCostCharge> costCharges = const [],
  }) => FundData(
    isin: fundIsin,
    symbol: symbol,
    name: 'Fondo $symbol',
    lastValue: 100,
    currency: 'EUR',
    date: DateTime(2026, 10, 20),
    history: [PricePoint(DateTime(2026, 10, 20), 100)],
    costPeriods: costPeriods,
    costCharges: costCharges,
  );

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

  test('LF-79.1: saveFund rechaza cargos vinculados a periodos que no son de comisión de éxito', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf79-original-performance',
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      description: 'Comisión de éxito original',
    );

    final originalCharge = FundCostCharge(
      uid: 'lf79-original-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 10,
      performancePeriodUid: originalPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF79',
        name: 'Fondo original LF-79',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    // El periodo existe, pero es de gestión, no de comisión de éxito.
    final managementPeriod = FundCostPeriod(
      uid: 'lf79-management-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      description: 'Comisión de gestión',
    );

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF79-MOD',
      name: 'Fondo modificado LF-79',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [managementPeriod],
      costCharges: [
        FundCostCharge(
          uid: 'lf79-invalid-charge',
          concept: FundCostConcept.performance,
          date: DateTime(2026, 10, 20),
          amount: 20,
          description: 'Cargo vinculado al periodo equivocado',
          performancePeriodUid: managementPeriod.uid,
          settledThrough: DateTime(2026, 10, 19),
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    // El rechazo debe preservar el fondo y sus costes originales.
    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'LF79');
    expect(savedFund.name, 'Fondo original LF-79');
    expect(savedFund.lastValue, 100);
    expect(savedFund.history, hasLength(1));

    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf79-original-performance');
    expect(savedFund.costPeriods.single.concept, FundCostConcept.performance);

    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.uid, 'lf79-original-charge');
    expect(
      savedFund.costCharges.single.performancePeriodUid,
      'lf79-original-performance',
    );
  });

  test('LF-80.1: saveFund rechaza cargos que no son de comisión de éxito pero enlazan un periodo de éxito', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf80-original-performance',
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
    );

    final originalCharge = FundCostCharge(
      uid: 'lf80-original-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 10,
      performancePeriodUid: originalPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF80',
        name: 'Fondo original LF-80',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF80-MOD',
      name: 'Fondo modificado LF-80',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [originalPeriod],
      costCharges: [
        FundCostCharge(
          uid: 'lf80-invalid-charge',
          concept: FundCostConcept.management,
          date: DateTime(2026, 10, 20),
          amount: 20,
          description: 'Cargo de gestión con enlace incompatible',
          performancePeriodUid: originalPeriod.uid,
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
    expect(savedFund!.symbol, 'LF80');
    expect(savedFund.name, 'Fondo original LF-80');
    expect(savedFund.lastValue, 100);

    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf80-original-performance');

    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.uid, 'lf80-original-charge');
    expect(
      savedFund.costCharges.single.performancePeriodUid,
      'lf80-original-performance',
    );
  });

  test(
    'LF-81.1: saveFund rechaza una tasa de coste negativa y conserva el fondo',
    () async {
      final originalFund = FundData(
        isin: isin,
        symbol: 'LF81',
        name: 'Fondo original LF-81',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf81-original-period',
            concept: FundCostConcept.management,
            ratePercent: 0.65,
            basis: FundCostRateBasis.annualBalance,
            treatment: FundCostTreatment.includedInNav,
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF81-MOD',
        name: 'Fondo modificado LF-81',
        lastValue: 200,
        currency: 'EUR',
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 20), 100),
          PricePoint(DateTime(2026, 10, 21), 200),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf81-invalid-period',
            concept: FundCostConcept.management,
            ratePercent: -0.01,
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
      expect(savedFund!.symbol, 'LF81');
      expect(savedFund.name, 'Fondo original LF-81');
      expect(savedFund.lastValue, 100);
      expect(savedFund.costPeriods, hasLength(1));
      expect(savedFund.costPeriods.single.uid, 'lf81-original-period');
      expect(savedFund.costPeriods.single.ratePercent, 0.65);
    },
  );

  test(
    'LF-81.2: saveFund rechaza tasas no finitas y conserva el fondo',
    () async {
      final originalFund = FundData(
        isin: isin,
        symbol: 'LF812',
        name: 'Fondo original LF-81.2',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
      );

      await DatabaseService.saveFund(originalFund);

      for (final rate in [
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        final invalidFund = FundData(
          isin: isin,
          symbol: 'LF812-MOD',
          name: 'Fondo modificado LF-81.2',
          lastValue: 200,
          currency: 'EUR',
          date: DateTime(2026, 10, 21),
          history: [
            PricePoint(DateTime(2026, 10, 20), 100),
            PricePoint(DateTime(2026, 10, 21), 200),
          ],
          costPeriods: [
            FundCostPeriod(
              uid: 'lf812-invalid-${rate.toString()}',
              concept: FundCostConcept.management,
              ratePercent: rate,
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
        expect(savedFund!.symbol, 'LF812');
        expect(savedFund.name, 'Fondo original LF-81.2');
        expect(savedFund.lastValue, 100);
        expect(savedFund.costPeriods, isEmpty);
        expect(savedFund.costCharges, isEmpty);
      }
    },
  );

  test('LF-81.3: saveFund rechaza cargos no positivos o no finitos y conserva los originales', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf813-original-period',
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
    );

    final originalCharge = FundCostCharge(
      uid: 'lf813-original-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 10,
      performancePeriodUid: originalPeriod.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF813',
        name: 'Fondo original LF-81.3',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    for (final amount in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF813-MOD',
        name: 'Fondo modificado LF-81.3',
        lastValue: 200,
        currency: 'EUR',
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 20), 100),
          PricePoint(DateTime(2026, 10, 21), 200),
        ],
        costPeriods: [originalPeriod],
        costCharges: [
          FundCostCharge(
            uid: 'lf813-invalid-${amount.toString()}',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 20),
            amount: amount,
            performancePeriodUid: originalPeriod.uid,
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
      expect(savedFund!.symbol, 'LF813');
      expect(savedFund.name, 'Fondo original LF-81.3');
      expect(savedFund.lastValue, 100);
      expect(savedFund.costPeriods, hasLength(1));
      expect(savedFund.costPeriods.single.uid, 'lf813-original-period');
      expect(savedFund.costCharges, hasLength(1));
      expect(savedFund.costCharges.single.uid, 'lf813-original-charge');
      expect(savedFund.costCharges.single.amount, 10);
      expect(
        savedFund.costCharges.single.performancePeriodUid,
        'lf813-original-period',
      );
    }
  });

  test(
    'LF-82.1: rechaza un periodo con fecha final pero sin fecha inicial',
    () async {
      await DatabaseService.saveFund(
        FundData(
          isin: isin,
          symbol: 'LF821',
          name: 'Fondo original LF-82.1',
          lastValue: 100,
          currency: 'EUR',
          date: DateTime(2026, 10, 20),
          history: [PricePoint(DateTime(2026, 10, 20), 100)],
        ),
      );

      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF821-MOD',
        name: 'Fondo modificado LF-82.1',
        lastValue: 200,
        currency: 'EUR',
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 20), 100),
          PricePoint(DateTime(2026, 10, 21), 200),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf821-invalid-period',
            concept: FundCostConcept.management,
            ratePercent: 0.65,
            basis: FundCostRateBasis.annualBalance,
            treatment: FundCostTreatment.includedInNav,
            validTo: DateTime(2026, 9, 30),
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'LF821');
      expect(savedFund.name, 'Fondo original LF-82.1');
      expect(savedFund.lastValue, 100);
      expect(savedFund.costPeriods, isEmpty);
    },
  );

  test('LF-82.2: rechaza un periodo con fechas invertidas', () async {
    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF822',
        name: 'Fondo original LF-82.2',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
      ),
    );

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF822-MOD',
      name: 'Fondo modificado LF-82.2',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf822-inverted-period',
          concept: FundCostConcept.management,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 10, 1),
          validTo: DateTime(2026, 9, 30),
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'LF822');
    expect(savedFund.name, 'Fondo original LF-82.2');
    expect(savedFund.lastValue, 100);
    expect(savedFund.costPeriods, isEmpty);
  });

  test('LF-82.3: rechaza periodos del mismo concepto con fechas solapadas y conserva el original', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf823-original-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 6, 30),
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF823',
        name: 'Fondo original LF-82.3',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
      ),
    );

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF823-MOD',
      name: 'Fondo modificado LF-82.3',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf823-period-a',
          concept: FundCostConcept.management,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 1, 1),
          validTo: DateTime(2026, 6, 30),
        ),
        FundCostPeriod(
          uid: 'lf823-period-b',
          concept: FundCostConcept.management,
          ratePercent: 0.70,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 6, 15),
          validTo: DateTime(2026, 12, 31),
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'LF823');
    expect(savedFund.name, 'Fondo original LF-82.3');
    expect(savedFund.lastValue, 100);
    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf823-original-period');
    expect(savedFund.costPeriods.single.ratePercent, 0.65);
    expect(savedFund.costPeriods.single.validFrom, DateTime(2026, 1, 1));
    expect(savedFund.costPeriods.single.validTo, DateTime(2026, 6, 30));
  });

  test(
    'LF-82.4: permite periodos del mismo concepto sin solapamiento',
    () async {
      final firstPeriod = FundCostPeriod(
        uid: 'lf824-period-a',
        concept: FundCostConcept.management,
        ratePercent: 0.65,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: DateTime(2026, 1, 1),
        validTo: DateTime(2026, 6, 30),
      );

      final secondPeriod = FundCostPeriod(
        uid: 'lf824-period-b',
        concept: FundCostConcept.management,
        ratePercent: 0.70,
        basis: FundCostRateBasis.annualBalance,
        treatment: FundCostTreatment.includedInNav,
        validFrom: DateTime(2026, 7, 1),
        validTo: DateTime(2026, 12, 31),
      );

      await DatabaseService.saveFund(
        FundData(
          isin: isin,
          symbol: 'LF824',
          name: 'Fondo LF-82.4',
          lastValue: 100,
          currency: 'EUR',
          date: DateTime(2026, 10, 20),
          history: [PricePoint(DateTime(2026, 10, 20), 100)],
          costPeriods: [firstPeriod, secondPeriod],
        ),
      );

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'LF824');
      expect(savedFund.costPeriods, hasLength(2));
      expect(savedFund.costPeriods.map((period) => period.uid).toSet(), {
        'lf824-period-a',
        'lf824-period-b',
      });
    },
  );

  test(
    'LF-82.5: exige fecha inicial para periodos con cargos separados',
    () async {
      await DatabaseService.saveFund(
        FundData(
          isin: isin,
          symbol: 'LF825',
          name: 'Fondo original LF-82.5',
          lastValue: 100,
          currency: 'EUR',
          date: DateTime(2026, 10, 20),
          history: [PricePoint(DateTime(2026, 10, 20), 100)],
        ),
      );

      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF825-MOD',
        name: 'Fondo modificado LF-82.5',
        lastValue: 200,
        currency: 'EUR',
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 20), 100),
          PricePoint(DateTime(2026, 10, 21), 200),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf825-invalid-period',
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'LF825');
      expect(savedFund.name, 'Fondo original LF-82.5');
      expect(savedFund.lastValue, 100);
      expect(savedFund.costPeriods, isEmpty);
    },
  );

  test('LF-83.1: rechaza periodos del mismo concepto que comparten una fecha límite', () async {
    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF831',
      name: 'Fondo LF-83.1',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [PricePoint(DateTime(2026, 10, 20), 100)],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf831-period-a',
          concept: FundCostConcept.management,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 1, 1),
          validTo: DateTime(2026, 6, 30),
        ),
        FundCostPeriod(
          uid: 'lf831-period-b',
          concept: FundCostConcept.management,
          ratePercent: 0.70,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 6, 30),
          validTo: DateTime(2026, 12, 31),
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    expect(await DatabaseService.getFund(isin), isNull);
  });

  test(
    'LF-83.2: permite periodos de conceptos distintos con fechas coincidentes',
    () async {
      final fund = FundData(
        isin: isin,
        symbol: 'LF832',
        name: 'Fondo LF-83.2',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [
          FundCostPeriod(
            uid: 'lf832-management',
            concept: FundCostConcept.management,
            ratePercent: 0.65,
            basis: FundCostRateBasis.annualBalance,
            treatment: FundCostTreatment.includedInNav,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 12, 31),
          ),
          FundCostPeriod(
            uid: 'lf832-depositary',
            concept: FundCostConcept.depositary,
            ratePercent: 0.10,
            basis: FundCostRateBasis.annualBalance,
            treatment: FundCostTreatment.includedInNav,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
      );

      await DatabaseService.saveFund(fund);

      final savedFund = await DatabaseService.getFund(isin);
      expect(savedFund, isNotNull);
      expect(savedFund!.costPeriods, hasLength(2));
      expect(savedFund.costPeriods.map((period) => period.uid).toSet(), {
        'lf832-management',
        'lf832-depositary',
      });
    },
  );

  test('LF-83.3: un periodo sin límites explícitos se solapa con otro del mismo concepto', () async {
    final fund = FundData(
      isin: isin,
      symbol: 'LF833',
      name: 'Fondo LF-83.3',
      lastValue: 100,
      currency: 'EUR',
      date: DateTime(2026, 10, 20),
      history: [PricePoint(DateTime(2026, 10, 20), 100)],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf833-unbounded',
          concept: FundCostConcept.management,
          ratePercent: 0.65,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
        FundCostPeriod(
          uid: 'lf833-bounded',
          concept: FundCostConcept.management,
          ratePercent: 0.70,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 1, 1),
          validTo: DateTime(2026, 12, 31),
        ),
      ],
    );

    await expectLater(DatabaseService.saveFund(fund), throwsArgumentError);

    expect(await DatabaseService.getFund(isin), isNull);
  });

  test('LF-83.4: un solapamiento inválido conserva el fondo y los costes originales', () async {
    final originalPeriod = FundCostPeriod(
      uid: 'lf834-original-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 6, 30),
    );

    final originalCharge = FundCostCharge(
      uid: 'lf834-original-charge',
      concept: FundCostConcept.management,
      date: DateTime(2026, 10, 20),
      amount: 5,
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF834',
        name: 'Fondo original LF-83.4',
        lastValue: 100,
        currency: 'EUR',
        date: DateTime(2026, 10, 20),
        history: [PricePoint(DateTime(2026, 10, 20), 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF834-MOD',
      name: 'Fondo modificado LF-83.4',
      lastValue: 200,
      currency: 'EUR',
      date: DateTime(2026, 10, 21),
      history: [
        PricePoint(DateTime(2026, 10, 20), 100),
        PricePoint(DateTime(2026, 10, 21), 200),
      ],
      costPeriods: [
        originalPeriod,
        FundCostPeriod(
          uid: 'lf834-overlapping-period',
          concept: FundCostConcept.management,
          ratePercent: 0.70,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 6, 30),
          validTo: DateTime(2026, 12, 31),
        ),
      ],
      costCharges: [originalCharge],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'LF834');
    expect(savedFund.name, 'Fondo original LF-83.4');
    expect(savedFund.lastValue, 100);
    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf834-original-period');
    expect(savedFund.costPeriods.single.ratePercent, 0.65);
    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.uid, 'lf834-original-charge');
    expect(savedFund.costCharges.single.amount, 5);
  });

  test('LF-84.1: acepta un cargo de comisión de éxito dentro del periodo referenciado', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf841-performance-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF841',
      name: 'Fondo LF-84.1',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf841-performance-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
          settledThrough: today,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);
    expect(savedFund!.costPeriods, hasLength(1));
    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.performancePeriodUid, periodUid);
  });

  test('LF-84.2: rechaza un cargo fechado fuera de la vigencia del periodo referenciado', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf842-performance-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF842',
      name: 'Fondo LF-84.2',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.subtract(const Duration(days: 1)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf842-performance-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await expectLater(DatabaseService.saveFund(fund), throwsArgumentError);

    expect(await DatabaseService.getFund(isin), isNull);
  });

  test('LF-84.3: rechaza settledThrough anterior al inicio del periodo referenciado', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf843-performance-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF843',
      name: 'Fondo LF-84.3',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 1)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf843-performance-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
          settledThrough: today.subtract(const Duration(days: 2)),
        ),
      ],
    );

    await expectLater(DatabaseService.saveFund(fund), throwsArgumentError);

    expect(await DatabaseService.getFund(isin), isNull);
  });

  test('LF-84.4: un cargo temporalmente inválido conserva el fondo y sus costes originales', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final originalPeriod = FundCostPeriod(
      uid: 'lf844-original-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
    );
    final originalCharge = FundCostCharge(
      uid: 'lf844-original-charge',
      concept: FundCostConcept.management,
      date: today,
      amount: 5,
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF844',
        name: 'Fondo original LF-84.4',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    final periodUid = 'lf844-invalid-performance-period';
    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF844-MOD',
      name: 'Fondo modificado LF-84.4',
      lastValue: 200,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 200)],
      costPeriods: [
        originalPeriod,
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.subtract(const Duration(days: 1)),
        ),
      ],
      costCharges: [
        originalCharge,
        FundCostCharge(
          uid: 'lf844-invalid-performance-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 10,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final savedFund = await DatabaseService.getFund(isin);
    expect(savedFund, isNotNull);
    expect(savedFund!.symbol, 'LF844');
    expect(savedFund.name, 'Fondo original LF-84.4');
    expect(savedFund.lastValue, 100);
    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.uid, 'lf844-original-period');
    expect(savedFund.costCharges, hasLength(1));
    expect(savedFund.costCharges.single.uid, 'lf844-original-charge');
  });

  test('LF-85.1: acepta un cargo exactamente en validFrom', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf851-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF851',
      name: 'Fondo LF-85.1',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today,
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf851-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costCharges, hasLength(1));
    expect(saved.costCharges.single.performancePeriodUid, periodUid);
  });

  test('LF-85.2: acepta un cargo exactamente en validTo', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf852-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF852',
      name: 'Fondo LF-85.2',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today,
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf852-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costCharges, hasLength(1));
    expect(saved.costCharges.single.performancePeriodUid, periodUid);
  });

  test(
    'LF-85.3: permite cargos en un periodo con ambos límites abiertos',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final periodUid = 'lf853-period';

      final fund = FundData(
        isin: isin,
        symbol: 'LF853',
        name: 'Fondo LF-85.3',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [
          FundCostPeriod(
            uid: periodUid,
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.includedInNav,
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'lf853-charge',
            concept: FundCostConcept.performance,
            date: today,
            amount: 5,
            performancePeriodUid: periodUid,
          ),
        ],
      );

      await DatabaseService.saveFund(fund);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.costPeriods.single.validFrom, isNull);
      expect(saved.costPeriods.single.validTo, isNull);
      expect(saved.costCharges, hasLength(1));
    },
  );

  test('LF-85.4: un cargo fuera de vigencia conserva los costes originales aunque haya otros cargos válidos', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final originalPeriod = FundCostPeriod(
      uid: 'lf854-original-period',
      concept: FundCostConcept.management,
      ratePercent: 0.65,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
    );

    final originalCharge = FundCostCharge(
      uid: 'lf854-original-charge',
      concept: FundCostConcept.management,
      date: today,
      amount: 5,
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF854',
        name: 'Fondo original LF-85.4',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    final performancePeriodUid = 'lf854-performance-period';
    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF854-MOD',
      name: 'Fondo modificado LF-85.4',
      lastValue: 200,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 200)],
      costPeriods: [
        originalPeriod,
        FundCostPeriod(
          uid: performancePeriodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.subtract(const Duration(days: 1)),
        ),
      ],
      costCharges: [
        originalCharge,
        FundCostCharge(
          uid: 'lf854-invalid-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 10,
          performancePeriodUid: performancePeriodUid,
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.symbol, 'LF854');
    expect(saved.name, 'Fondo original LF-85.4');
    expect(saved.lastValue, 100);
    expect(saved.costPeriods, hasLength(1));
    expect(saved.costPeriods.single.uid, 'lf854-original-period');
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.uid, 'lf854-original-charge');
    expect(saved.costCharges.single.amount, 5);
  });

  test(
    'LF-86.1: permite varios cargos válidos referenciando el mismo periodo',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final periodUid = 'lf861-performance-period';

      final fund = FundData(
        isin: isin,
        symbol: 'LF861',
        name: 'Fondo LF-86.1',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [
          FundCostPeriod(
            uid: periodUid,
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: today.subtract(const Duration(days: 30)),
            validTo: today.add(const Duration(days: 30)),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'lf861-charge-a',
            concept: FundCostConcept.performance,
            date: today.subtract(const Duration(days: 1)),
            amount: 5,
            performancePeriodUid: periodUid,
          ),
          FundCostCharge(
            uid: 'lf861-charge-b',
            concept: FundCostConcept.performance,
            date: today,
            amount: 7,
            performancePeriodUid: periodUid,
          ),
        ],
      );

      await DatabaseService.saveFund(fund);

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));
      expect(saved.costCharges, hasLength(2));
      expect(
        saved.costCharges.map((charge) => charge.performancePeriodUid),
        everyElement(periodUid),
      );
    },
  );

  test(
    'LF-86.2: rechaza eliminar un periodo que sigue referenciado por un cargo',
    () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final periodUid = 'lf862-performance-period';

      final originalFund = FundData(
        isin: isin,
        symbol: 'LF862',
        name: 'Fondo original LF-86.2',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [
          FundCostPeriod(
            uid: periodUid,
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: today.subtract(const Duration(days: 30)),
            validTo: today.add(const Duration(days: 30)),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'lf862-charge',
            concept: FundCostConcept.performance,
            date: today,
            amount: 5,
            performancePeriodUid: periodUid,
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final invalidFund = FundData(
        isin: isin,
        symbol: 'LF862-MOD',
        name: 'Fondo modificado LF-86.2',
        lastValue: 200,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 200)],
        costPeriods: [],
        costCharges: originalFund.costCharges,
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsArgumentError,
      );

      final saved = await DatabaseService.getFund(isin);
      expect(saved, isNotNull);
      expect(saved!.symbol, 'LF862');
      expect(saved.name, 'Fondo original LF-86.2');
      expect(saved.lastValue, 100);
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, periodUid);
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.performancePeriodUid, periodUid);
    },
  );

  test('LF-86.3: rechaza cambiar el UID de un periodo sin actualizar la referencia del cargo', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final originalPeriodUid = 'lf863-original-period';

    final originalFund = FundData(
      isin: isin,
      symbol: 'LF863',
      name: 'Fondo original LF-86.3',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: originalPeriodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf863-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: originalPeriodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(originalFund);

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF863-MOD',
      name: 'Fondo modificado LF-86.3',
      lastValue: 200,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 200)],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf863-new-period',
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: originalFund.costCharges,
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.symbol, 'LF863');
    expect(saved.costPeriods.single.uid, originalPeriodUid);
    expect(saved.costCharges.single.performancePeriodUid, originalPeriodUid);
  });

  test('LF-86.4: un fallo al modificar la relación conserva el periodo y el cargo originales', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final periodUid = 'lf864-performance-period';

    final originalFund = FundData(
      isin: isin,
      symbol: 'LF864',
      name: 'Fondo original LF-86.4',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf864-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(originalFund);

    final invalidFund = FundData(
      isin: isin,
      symbol: 'LF864-MOD',
      name: 'Fondo modificado LF-86.4',
      lastValue: 250,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 250)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf864-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: 'lf864-missing-period',
        ),
      ],
    );

    await expectLater(
      DatabaseService.saveFund(invalidFund),
      throwsArgumentError,
    );

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.symbol, 'LF864');
    expect(saved.name, 'Fondo original LF-86.4');
    expect(saved.lastValue, 100);
    expect(saved.costPeriods, hasLength(1));
    expect(saved.costPeriods.single.uid, periodUid);
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.uid, 'lf864-charge');
    expect(saved.costCharges.single.performancePeriodUid, periodUid);
    expect(saved.costCharges.single.amount, 5);
  });

  test('LF-87.1: permite cambiar el UID del periodo y actualizar su referencia conjuntamente', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const oldUid = 'lf871-old-period';
    const newUid = 'lf871-new-period';

    FundCostPeriod makePeriod(String uid) => FundCostPeriod(
      uid: uid,
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: today.subtract(const Duration(days: 30)),
      validTo: today.add(const Duration(days: 30)),
    );

    FundCostCharge makeCharge(String periodUid) => FundCostCharge(
      uid: 'lf871-charge',
      concept: FundCostConcept.performance,
      date: today,
      amount: 5,
      performancePeriodUid: periodUid,
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF871',
        name: 'Fondo LF-87.1',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [makePeriod(oldUid)],
        costCharges: [makeCharge(oldUid)],
      ),
    );

    await DatabaseService.saveFund(
      FundData(
        isin: isin,
        symbol: 'LF871',
        name: 'Fondo LF-87.1',
        lastValue: 100,
        currency: 'EUR',
        date: today,
        history: [PricePoint(today, 100)],
        costPeriods: [makePeriod(newUid)],
        costCharges: [makeCharge(newUid)],
      ),
    );

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costPeriods, hasLength(1));
    expect(saved.costPeriods.single.uid, newUid);
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.performancePeriodUid, newUid);
  });

  test('LF-87.2: permite eliminar conjuntamente un periodo y los cargos que lo referencian', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const periodUid = 'lf872-period';

    final originalFund = FundData(
      isin: isin,
      symbol: 'LF872',
      name: 'Fondo LF-87.2',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf872-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(originalFund);

    final updatedFund = FundData(
      isin: isin,
      symbol: 'LF872',
      name: 'Fondo LF-87.2',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [],
      costCharges: [],
    );

    await DatabaseService.saveFund(updatedFund);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costPeriods, isEmpty);
    expect(saved.costCharges, isEmpty);
  });

  test('LF-87.3: permite reasignar un cargo a otro periodo válido', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const firstUid = 'lf873-period-a';
    const secondUid = 'lf873-period-b';

    FundCostPeriod makePeriod(
      String uid,
      double rate,
      DateTime validFrom,
      DateTime validTo,
    ) => FundCostPeriod(
      uid: uid,
      concept: FundCostConcept.performance,
      ratePercent: rate,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: validFrom,
      validTo: validTo,
    );

    final originalFund = FundData(
      isin: isin,
      symbol: 'LF873',
      name: 'Fondo LF-87.3',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        makePeriod(
          firstUid,
          10,
          today.subtract(const Duration(days: 30)),
          today.subtract(const Duration(days: 1)),
        ),
        makePeriod(secondUid, 12, today, today.add(const Duration(days: 30))),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf873-charge',
          concept: FundCostConcept.performance,
          //date: today,
          date: today.subtract(const Duration(days: 1)),
          amount: 5,
          performancePeriodUid: firstUid,
        ),
      ],
    );

    await DatabaseService.saveFund(originalFund);

    final updatedFund = FundData(
      isin: isin,
      symbol: 'LF873',
      name: 'Fondo LF-87.3',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: originalFund.costPeriods,
      costCharges: [
        FundCostCharge(
          uid: 'lf873-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: secondUid,
        ),
      ],
    );

    await DatabaseService.saveFund(updatedFund);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costPeriods, hasLength(2));
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.performancePeriodUid, secondUid);
  });

  test('LF-87.4: guardar dos veces la misma actualización de relaciones no duplica costes', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const periodUid = 'lf874-period';

    final fund = FundData(
      isin: isin,
      symbol: 'LF874',
      name: 'Fondo LF-87.4',
      lastValue: 100,
      currency: 'EUR',
      date: today,
      history: [PricePoint(today, 100)],
      costPeriods: [
        FundCostPeriod(
          uid: periodUid,
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: today.subtract(const Duration(days: 30)),
          validTo: today.add(const Duration(days: 30)),
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf874-charge',
          concept: FundCostConcept.performance,
          date: today,
          amount: 5,
          performancePeriodUid: periodUid,
        ),
      ],
    );

    await DatabaseService.saveFund(fund);
    await DatabaseService.saveFund(fund);

    final saved = await DatabaseService.getFund(isin);
    expect(saved, isNotNull);
    expect(saved!.costPeriods, hasLength(1));
    expect(saved.costPeriods.single.uid, periodUid);
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.uid, 'lf874-charge');
    expect(saved.costCharges.single.performancePeriodUid, periodUid);
  });

  test('LF-88.1: persiste y recupera performancePeriodUid', () async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final periodUid = 'lf88-1-performance-period';
    final chargeUid = 'lf88-1-performance-charge';

    final period = FundCostPeriod(
      uid: periodUid,
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: todayDate.subtract(const Duration(days: 30)),
      validTo: todayDate,
      description: 'Periodo LF-88.1',
    );

    final charge = FundCostCharge(
      uid: chargeUid,
      concept: FundCostConcept.performance,
      date: todayDate.subtract(const Duration(days: 1)),
      amount: 15.25,
      description: 'Cargo LF-88.1',
      performancePeriodUid: periodUid,
      settledThrough: todayDate.subtract(const Duration(days: 2)),
    );

    final fund = FundData(
      isin: isin,
      symbol: 'LF88',
      name: 'Fondo LF-88.1',
      lastValue: 100,
      currency: 'EUR',
      date: todayDate,
      history: [PricePoint(todayDate, 100)],
      costPeriods: [period],
      costCharges: [charge],
    );

    await DatabaseService.saveFund(fund);
    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.costPeriods, hasLength(1));
    expect(savedFund.costCharges, hasLength(1));

    final savedPeriod = savedFund.costPeriods.single;
    final savedCharge = savedFund.costCharges.single;

    expect(savedPeriod.uid, periodUid);
    expect(savedPeriod.validFrom, period.validFrom);
    expect(savedPeriod.validTo, period.validTo);

    expect(savedCharge.uid, chargeUid);
    expect(savedCharge.concept, FundCostConcept.performance);
    expect(savedCharge.date, charge.date);
    expect(savedCharge.amount, 15.25);
    expect(savedCharge.description, 'Cargo LF-88.1');
    expect(savedCharge.performancePeriodUid, savedPeriod.uid);
    expect(savedCharge.settledThrough, charge.settledThrough);
  });

  test('LF-88.2: recupera varios cargos vinculados al mismo periodo', () async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final periodUid = 'lf88-2-performance-period';

    final period = FundCostPeriod(
      uid: periodUid,
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: todayDate.subtract(const Duration(days: 30)),
      validTo: todayDate,
      description: 'Periodo compartido LF-88.2',
    );

    final charge1 = FundCostCharge(
      uid: 'lf88-2-charge-a',
      concept: FundCostConcept.performance,
      date: todayDate.subtract(const Duration(days: 2)),
      amount: 10,
      description: 'Primer cargo',
      performancePeriodUid: periodUid,
      settledThrough: todayDate.subtract(const Duration(days: 3)),
    );

    final charge2 = FundCostCharge(
      uid: 'lf88-2-charge-b',
      concept: FundCostConcept.performance,
      date: todayDate.subtract(const Duration(days: 1)),
      amount: 20,
      description: 'Segundo cargo',
      performancePeriodUid: periodUid,
      settledThrough: todayDate.subtract(const Duration(days: 2)),
    );

    final fund = FundData(
      isin: isin,
      symbol: 'LF88',
      name: 'Fondo LF-88.2',
      lastValue: 100,
      currency: 'EUR',
      date: todayDate,
      history: [PricePoint(todayDate, 100)],
      costPeriods: [period],
      costCharges: [charge1, charge2],
    );

    await DatabaseService.saveFund(fund);
    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expect(savedFund!.costPeriods, hasLength(1));
    expect(savedFund.costCharges, hasLength(2));

    final chargesByUid = {
      for (final charge in savedFund.costCharges) charge.uid: charge,
    };

    expect(
      chargesByUid.keys,
      containsAll(['lf88-2-charge-a', 'lf88-2-charge-b']),
    );
    expect(chargesByUid['lf88-2-charge-a']!.amount, 10);
    expect(chargesByUid['lf88-2-charge-b']!.amount, 20);
    expect(chargesByUid['lf88-2-charge-a']!.performancePeriodUid, periodUid);
    expect(chargesByUid['lf88-2-charge-b']!.performancePeriodUid, periodUid);
    expect(
      savedFund.costCharges.map((charge) => charge.uid).toSet(),
      hasLength(2),
    );
  });

  test(
    'LF-88.3: recupera periodos no solapados y sus cargos correspondientes',
    () async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final firstFrom = todayDate.subtract(const Duration(days: 60));
      final firstTo = todayDate.subtract(const Duration(days: 31));
      final secondFrom = todayDate.subtract(const Duration(days: 30));
      final secondTo = todayDate;

      final firstUid = 'lf88-3-performance-first';
      final secondUid = 'lf88-3-performance-second';

      final firstPeriod = FundCostPeriod(
        uid: firstUid,
        concept: FundCostConcept.performance,
        ratePercent: 8,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: firstFrom,
        validTo: firstTo,
        description: 'Primer periodo LF-88.3',
      );

      final secondPeriod = FundCostPeriod(
        uid: secondUid,
        concept: FundCostConcept.performance,
        ratePercent: 12,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: secondFrom,
        validTo: secondTo,
        description: 'Segundo periodo LF-88.3',
      );

      final firstCharge = FundCostCharge(
        uid: 'lf88-3-charge-first',
        concept: FundCostConcept.performance,
        date: firstTo,
        amount: 8,
        description: 'Cargo del primer periodo',
        performancePeriodUid: firstUid,
        settledThrough: firstTo.subtract(const Duration(days: 1)),
      );

      final secondCharge = FundCostCharge(
        uid: 'lf88-3-charge-second',
        concept: FundCostConcept.performance,
        date: todayDate.subtract(const Duration(days: 1)),
        amount: 12,
        description: 'Cargo del segundo periodo',
        performancePeriodUid: secondUid,
        settledThrough: todayDate.subtract(const Duration(days: 2)),
      );

      final fund = FundData(
        isin: isin,
        symbol: 'LF88',
        name: 'Fondo LF-88.3',
        lastValue: 100,
        currency: 'EUR',
        date: todayDate,
        history: [PricePoint(todayDate, 100)],
        costPeriods: [firstPeriod, secondPeriod],
        costCharges: [firstCharge, secondCharge],
      );

      await DatabaseService.saveFund(fund);
      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.costPeriods, hasLength(2));
      expect(savedFund.costCharges, hasLength(2));

      final periodsByUid = {
        for (final period in savedFund.costPeriods) period.uid: period,
      };
      final chargesByUid = {
        for (final charge in savedFund.costCharges) charge.uid: charge,
      };

      expect(periodsByUid.keys, containsAll([firstUid, secondUid]));
      expect(periodsByUid[firstUid]!.validFrom, firstFrom);
      expect(periodsByUid[firstUid]!.validTo, firstTo);
      expect(periodsByUid[firstUid]!.ratePercent, 8);
      expect(periodsByUid[secondUid]!.validFrom, secondFrom);
      expect(periodsByUid[secondUid]!.validTo, secondTo);
      expect(periodsByUid[secondUid]!.ratePercent, 12);

      expect(
        chargesByUid['lf88-3-charge-first']!.performancePeriodUid,
        firstUid,
      );
      expect(
        chargesByUid['lf88-3-charge-second']!.performancePeriodUid,
        secondUid,
      );
    },
  );

  test(
    'LF-88.4: al actualizar un cargo persiste solo la nueva relación',
    () async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      final firstFrom = todayDate.subtract(const Duration(days: 60));
      final firstTo = todayDate.subtract(const Duration(days: 31));
      final secondFrom = todayDate.subtract(const Duration(days: 30));

      const firstUid = 'lf88-4-performance-first';
      const secondUid = 'lf88-4-performance-second';
      const chargeUid = 'lf88-4-performance-charge';

      final firstPeriod = FundCostPeriod(
        uid: firstUid,
        concept: FundCostConcept.performance,
        ratePercent: 8,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: firstFrom,
        validTo: firstTo,
      );

      final secondPeriod = FundCostPeriod(
        uid: secondUid,
        concept: FundCostConcept.performance,
        ratePercent: 12,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: secondFrom,
        validTo: todayDate,
      );

      final originalCharge = FundCostCharge(
        uid: chargeUid,
        concept: FundCostConcept.performance,
        date: firstTo,
        amount: 15,
        description: 'Cargo reasignado',
        performancePeriodUid: firstUid,
        settledThrough: firstTo.subtract(const Duration(days: 1)),
      );

      final originalFund = FundData(
        isin: isin,
        symbol: 'LF88',
        name: 'Fondo LF-88.4',
        lastValue: 100,
        currency: 'EUR',
        date: todayDate,
        history: [PricePoint(todayDate, 100)],
        costPeriods: [firstPeriod, secondPeriod],
        costCharges: [originalCharge],
      );

      await DatabaseService.saveFund(originalFund);

      final updatedCharge = FundCostCharge(
        uid: chargeUid,
        concept: FundCostConcept.performance,
        date: todayDate.subtract(const Duration(days: 1)),
        amount: 15,
        description: 'Cargo reasignado',
        performancePeriodUid: secondUid,
        settledThrough: todayDate.subtract(const Duration(days: 2)),
      );

      final updatedFund = FundData(
        isin: isin,
        symbol: 'LF88',
        name: 'Fondo LF-88.4',
        lastValue: 100,
        currency: 'EUR',
        date: todayDate,
        history: [PricePoint(todayDate, 100)],
        costPeriods: [firstPeriod, secondPeriod],
        costCharges: [updatedCharge],
      );

      await DatabaseService.saveFund(updatedFund);
      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.costPeriods, hasLength(2));
      expect(savedFund.costCharges, hasLength(1));

      final savedCharge = savedFund.costCharges.single;
      expect(savedCharge.uid, chargeUid);
      expect(savedCharge.performancePeriodUid, secondUid);
      expect(savedCharge.performancePeriodUid, isNot(firstUid));
      expect(savedCharge.date, updatedCharge.date);

      expect(
        savedFund.costPeriods.any(
          (period) => period.uid == savedCharge.performancePeriodUid,
        ),
        isTrue,
      );
    },
  );

  test(
    'LF-88.5: guardar, recuperar y volver a guardar es idempotente',
    () async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      const periodUid = 'lf88-5-performance-period';

      final period = FundCostPeriod(
        uid: periodUid,
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: todayDate.subtract(const Duration(days: 30)),
        validTo: todayDate,
        description: 'Periodo LF-88.5',
      );

      final charge1 = FundCostCharge(
        uid: 'lf88-5-charge-a',
        concept: FundCostConcept.performance,
        date: todayDate.subtract(const Duration(days: 2)),
        amount: 10,
        description: 'Primer cargo LF-88.5',
        performancePeriodUid: periodUid,
        settledThrough: todayDate.subtract(const Duration(days: 3)),
      );

      final charge2 = FundCostCharge(
        uid: 'lf88-5-charge-b',
        concept: FundCostConcept.performance,
        date: todayDate.subtract(const Duration(days: 1)),
        amount: 20,
        description: 'Segundo cargo LF-88.5',
        performancePeriodUid: periodUid,
        settledThrough: todayDate.subtract(const Duration(days: 2)),
      );

      final fund = FundData(
        isin: isin,
        symbol: 'LF88',
        name: 'Fondo LF-88.5',
        lastValue: 100,
        currency: 'EUR',
        date: todayDate,
        history: [PricePoint(todayDate, 100)],
        costPeriods: [period],
        costCharges: [charge1, charge2],
      );

      await DatabaseService.saveFund(fund);

      final firstRead = await DatabaseService.getFund(isin);
      expect(firstRead, isNotNull);

      await DatabaseService.saveFund(firstRead!);

      final secondRead = await DatabaseService.getFund(isin);

      expect(secondRead, isNotNull);
      expect(secondRead!.costPeriods, hasLength(1));
      expect(secondRead.costCharges, hasLength(2));

      final savedPeriod = secondRead.costPeriods.single;
      final chargesByUid = {
        for (final charge in secondRead.costCharges) charge.uid: charge,
      };

      expect(savedPeriod.uid, periodUid);
      expect(savedPeriod.ratePercent, 10);
      expect(savedPeriod.validFrom, period.validFrom);
      expect(savedPeriod.validTo, period.validTo);

      expect(
        chargesByUid.keys,
        containsAll(['lf88-5-charge-a', 'lf88-5-charge-b']),
      );
      expect(chargesByUid.keys.toSet(), hasLength(2));
      expect(chargesByUid['lf88-5-charge-a']!.performancePeriodUid, periodUid);
      expect(chargesByUid['lf88-5-charge-b']!.performancePeriodUid, periodUid);

      expect(
        secondRead.costPeriods.map((item) => item.uid).toSet(),
        hasLength(secondRead.costPeriods.length),
      );
      expect(
        secondRead.costCharges.map((item) => item.uid).toSet(),
        hasLength(secondRead.costCharges.length),
      );
    },
  );

  test(
    'LF-89.1: deleteFund elimina el fondo y todos sus costes asociados',
    () async {
      final period = makePerformancePeriod('lf89-1-period');
      final charge = makePerformanceCharge('lf89-1-charge', period.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF89-1',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      await DatabaseService.deleteFund(isin);

      expect(await DatabaseService.getFund(isin), isNull);

      final db = await DatabaseService.database;

      expect(
        await db.query('funds', where: 'isin = ?', whereArgs: [isin]),
        isEmpty,
      );
      expect(
        await db.query('prices', where: 'isin = ?', whereArgs: [isin]),
        isEmpty,
      );
      expect(
        await db.query('operations', where: 'isin = ?', whereArgs: [isin]),
        isEmpty,
      );
      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [isin],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [isin],
        ),
        isEmpty,
      );
    },
  );

  test(
    'LF-89.2: deleteFund no deja registros ni relaciones huérfanas',
    () async {
      final period = makePerformancePeriod('lf89-2-period');
      final charge = makePerformanceCharge('lf89-2-charge', period.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF89-2',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      await DatabaseService.deleteFund(isin);

      final db = await DatabaseService.database;

      final orphanCharges = await db.rawQuery(
        '''
    SELECT c.uid
    FROM fund_cost_charges c
    LEFT JOIN fund_cost_periods p
      ON p.uid = c.performance_period_uid
     AND p.isin = c.isin
    WHERE c.isin = ?
      AND c.performance_period_uid IS NOT NULL
      AND p.uid IS NULL
  ''',
        [isin],
      );

      expect(orphanCharges, isEmpty);

      final remainingPeriods = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
      );
      final remainingCharges = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
      );

      expect(remainingPeriods, isEmpty);
      expect(remainingCharges, isEmpty);
    },
  );

  test('LF-89.3: deleteFund no modifica los costes de otros fondos', () async {
    const otherIsin = 'IE00B4L5Y983-OTHER';

    final firstPeriod = makePerformancePeriod('lf89-3-first-period');
    final firstCharge = makePerformanceCharge(
      'lf89-3-first-charge',
      firstPeriod.uid,
    );

    final otherPeriod = makePerformancePeriod('lf89-3-other-period');
    final otherCharge = makePerformanceCharge(
      'lf89-3-other-charge',
      otherPeriod.uid,
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF89-3-A',
        costPeriods: [firstPeriod],
        costCharges: [firstCharge],
      ),
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: otherIsin,
        symbol: 'LF89-3-B',
        costPeriods: [otherPeriod],
        costCharges: [otherCharge],
      ),
    );

    await DatabaseService.deleteFund(isin);

    expect(await DatabaseService.getFund(isin), isNull);

    final otherFund = await DatabaseService.getFund(otherIsin);

    expect(otherFund, isNotNull);
    expect(otherFund!.costPeriods, hasLength(1));
    expect(otherFund.costPeriods.single.uid, otherPeriod.uid);
    expect(otherFund.costCharges, hasLength(1));
    expect(otherFund.costCharges.single.uid, otherCharge.uid);
    expect(otherFund.costCharges.single.performancePeriodUid, otherPeriod.uid);
  });

  test(
    'LF-89.4: deleteFund revierte todos los cambios si falla la eliminación',
    () async {
      final period = makePerformancePeriod('lf89-4-period');
      final charge = makePerformanceCharge('lf89-4-charge', period.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF89-4',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      final db = await DatabaseService.database;

      await db.execute('''
    CREATE TRIGGER lf89_force_price_delete_failure
    BEFORE DELETE ON prices
    BEGIN
      SELECT RAISE(ABORT, 'LF-89 forced deletion failure');
    END;
  ''');

      await expectLater(DatabaseService.deleteFund(isin), throwsA(anything));

      // El fondo y todos sus datos deben permanecer intactos.
      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.symbol, 'LF89-4');
      expect(savedFund.costPeriods, hasLength(1));
      expect(savedFund.costPeriods.single.uid, period.uid);
      expect(savedFund.costCharges, hasLength(1));
      expect(savedFund.costCharges.single.uid, charge.uid);
      expect(savedFund.costCharges.single.performancePeriodUid, period.uid);

      expect(
        await db.query('funds', where: 'isin = ?', whereArgs: [isin]),
        hasLength(1),
      );
      expect(
        await db.query('prices', where: 'isin = ?', whereArgs: [isin]),
        isNotEmpty,
      );
      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [isin],
        ),
        hasLength(1),
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [isin],
        ),
        hasLength(1),
      );
    },
  );

  test('LF-89.5: eliminar dos veces el mismo fondo no produce errores', () async {
    final period = makePerformancePeriod('lf89-5-period');
    final charge = makePerformanceCharge('lf89-5-charge', period.uid);

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF89-5',
        costPeriods: [period],
        costCharges: [charge],
      ),
    );

    await DatabaseService.deleteFund(isin);
    await DatabaseService.deleteFund(isin);

    expect(await DatabaseService.getFund(isin), isNull);

    final db = await DatabaseService.database;

    for (final table in [
      'funds',
      'prices',
      'operations',
      'fund_cost_periods',
      'fund_cost_charges',
    ]) {
      expect(
        await db.query(table, where: 'isin = ?', whereArgs: [isin]),
        isEmpty,
        reason:
            'La tabla $table no debe conservar registros del fondo eliminado.',
      );
    }
  });

  test(
    'LF-90.1: la última actualización conserva los costes más recientes',
    () async {
      final firstPeriod = makePerformancePeriod('lf90-1-first-period');
      final firstCharge = makePerformanceCharge(
        'lf90-1-first-charge',
        firstPeriod.uid,
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF90-1',
          costPeriods: [firstPeriod],
          costCharges: [firstCharge],
        ),
      );

      final secondPeriod = makePerformancePeriod('lf90-1-second-period');
      final secondCharge = makePerformanceCharge(
        'lf90-1-second-charge',
        secondPeriod.uid,
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF90-1',
          costPeriods: [secondPeriod],
          costCharges: [secondCharge],
        ),
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, secondPeriod.uid);
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, secondCharge.uid);
      expect(saved.costCharges.single.performancePeriodUid, secondPeriod.uid);
    },
  );

  test('LF-90.2: guardar dos fondos concurrentemente conserva ambos', () async {
    const otherIsin = 'LU0000000002';

    final periodA = makePerformancePeriod('lf90-2-period-a');
    final chargeA = makePerformanceCharge('lf90-2-charge-a', periodA.uid);
    final periodB = makePerformancePeriod('lf90-2-period-b');
    final chargeB = makePerformanceCharge('lf90-2-charge-b', periodB.uid);

    await Future.wait([
      DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF90-2-A',
          costPeriods: [periodA],
          costCharges: [chargeA],
        ),
      ),
      DatabaseService.saveFund(
        makeFund(
          fundIsin: otherIsin,
          symbol: 'LF90-2-B',
          costPeriods: [periodB],
          costCharges: [chargeB],
        ),
      ),
    ]);

    final savedA = await DatabaseService.getFund(isin);
    final savedB = await DatabaseService.getFund(otherIsin);

    expect(savedA, isNotNull);
    expect(savedA!.costPeriods.single.uid, periodA.uid);
    expect(savedA.costCharges.single.uid, chargeA.uid);
    expect(savedA.costCharges.single.performancePeriodUid, periodA.uid);

    expect(savedB, isNotNull);
    expect(savedB!.costPeriods.single.uid, periodB.uid);
    expect(savedB.costCharges.single.uid, chargeB.uid);
    expect(savedB.costCharges.single.performancePeriodUid, periodB.uid);
  });

  test(
    'LF-90.3: una escritura inválida no altera los costes válidos persistidos',
    () async {
      final period = makePerformancePeriod('lf90-3-valid-period');
      final charge = makePerformanceCharge('lf90-3-valid-charge', period.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF90-3-VALID',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      final invalidPeriod = FundCostPeriod(
        uid: 'lf90-3-invalid-period',
        concept: FundCostConcept.performance,
        ratePercent: double.nan,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
      );

      await expectLater(
        DatabaseService.saveFund(
          makeFund(
            fundIsin: isin,
            symbol: 'LF90-3-INVALID',
            costPeriods: [invalidPeriod],
          ),
        ),
        throwsArgumentError,
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.symbol, 'LF90-3-VALID');
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, period.uid);
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, charge.uid);
      expect(saved.costCharges.single.performancePeriodUid, period.uid);
    },
  );

  test(
    'LF-90.4: eliminar un fondo no interfiere con la actualización de otro',
    () async {
      const otherIsin = 'LU0000000003';

      final periodA = makePerformancePeriod('lf90-4-period-a');
      final chargeA = makePerformanceCharge('lf90-4-charge-a', periodA.uid);

      final periodB = makePerformancePeriod('lf90-4-period-b');
      final chargeB = makePerformanceCharge('lf90-4-charge-b', periodB.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF90-4-A',
          costPeriods: [periodA],
          costCharges: [chargeA],
        ),
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: otherIsin,
          symbol: 'LF90-4-B',
          costPeriods: [periodB],
          costCharges: [chargeB],
        ),
      );

      final updatedPeriodB = FundCostPeriod(
        uid: 'lf90-4-period-b-updated',
        concept: FundCostConcept.performance,
        ratePercent: 12,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
      );
      final updatedChargeB = makePerformanceCharge(
        'lf90-4-charge-b-updated',
        updatedPeriodB.uid,
      );

      await Future.wait([
        DatabaseService.deleteFund(isin),
        DatabaseService.saveFund(
          makeFund(
            fundIsin: otherIsin,
            symbol: 'LF90-4-B-UPDATED',
            costPeriods: [updatedPeriodB],
            costCharges: [updatedChargeB],
          ),
        ),
      ]);

      expect(await DatabaseService.getFund(isin), isNull);

      final savedB = await DatabaseService.getFund(otherIsin);
      expect(savedB, isNotNull);
      expect(savedB!.symbol, 'LF90-4-B-UPDATED');
      expect(savedB.costPeriods, hasLength(1));
      expect(savedB.costPeriods.single.uid, updatedPeriodB.uid);
      expect(savedB.costCharges, hasLength(1));
      expect(savedB.costCharges.single.uid, updatedChargeB.uid);
      expect(
        savedB.costCharges.single.performancePeriodUid,
        updatedPeriodB.uid,
      );
    },
  );

  test('LF-90.5: guardar, actualizar y eliminar no deja relaciones huérfanas', () async {
    final initialPeriod = makePerformancePeriod('lf90-5-initial-period');
    final initialCharge = makePerformanceCharge(
      'lf90-5-initial-charge',
      initialPeriod.uid,
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF90-5',
        costPeriods: [initialPeriod],
        costCharges: [initialCharge],
      ),
    );

    final updatedPeriod = makePerformancePeriod('lf90-5-updated-period');
    final updatedCharge = makePerformanceCharge(
      'lf90-5-updated-charge',
      updatedPeriod.uid,
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF90-5-UPDATED',
        costPeriods: [updatedPeriod],
        costCharges: [updatedCharge],
      ),
    );

    final updated = await DatabaseService.getFund(isin);
    expect(updated, isNotNull);
    expect(updated!.costPeriods.single.uid, updatedPeriod.uid);
    expect(updated.costCharges.single.performancePeriodUid, updatedPeriod.uid);

    await DatabaseService.deleteFund(isin);

    final db = await DatabaseService.database;
    for (final table in [
      'funds',
      'prices',
      'operations',
      'fund_cost_periods',
      'fund_cost_charges',
    ]) {
      expect(
        await db.query(table, where: 'isin = ?', whereArgs: [isin]),
        isEmpty,
        reason:
            'La tabla $table conserva registros después de eliminar el fondo.',
      );
    }

    final orphans = await db.rawQuery('''
    SELECT c.uid
    FROM fund_cost_charges c
    LEFT JOIN fund_cost_periods p
      ON p.uid = c.performance_period_uid
     AND p.isin = c.isin
    WHERE c.performance_period_uid IS NOT NULL
      AND p.uid IS NULL
  ''');

    expect(orphans, isEmpty);
  });

  test(
    'LF-91.1: recuperar un fondo sin costes devuelve listas vacías',
    () async {
      await DatabaseService.saveFund(
        makeFund(fundIsin: isin, symbol: 'LF91-1'),
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.costPeriods, isEmpty);
      expect(saved.costCharges, isEmpty);
    },
  );

  test(
    'LF-91.2: recuperar un fondo conserva todos los campos de sus periodos',
    () async {
      final period = FundCostPeriod(
        uid: 'lf91-2-period',
        concept: FundCostConcept.performance,
        ratePercent: 12.75,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 15),
        validTo: DateTime(2026, 9, 30),
        description: 'Comisión de éxito del primer periodo',
      );

      await DatabaseService.saveFund(
        makeFund(fundIsin: isin, symbol: 'LF91-2', costPeriods: [period]),
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));

      final recovered = saved.costPeriods.single;
      expect(recovered.uid, period.uid);
      expect(recovered.concept, period.concept);
      expect(recovered.ratePercent, period.ratePercent);
      expect(recovered.basis, period.basis);
      expect(recovered.treatment, period.treatment);
      expect(recovered.validFrom, period.validFrom);
      expect(recovered.validTo, period.validTo);
      expect(recovered.description, period.description);
    },
  );

  test(
    'LF-91.3: recuperar un fondo conserva los campos del cargo y su relación',
    () async {
      final period = makePerformancePeriod('lf91-3-period');
      final charge = FundCostCharge(
        uid: 'lf91-3-charge',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 27.35,
        description: 'Liquidación trimestral',
        performancePeriodUid: period.uid,
        settledThrough: DateTime(2026, 10, 19),
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF91-3',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.costCharges, hasLength(1));

      final recovered = saved.costCharges.single;
      expect(recovered.uid, charge.uid);
      expect(recovered.concept, charge.concept);
      expect(recovered.date, charge.date);
      expect(recovered.amount, charge.amount);
      expect(recovered.description, charge.description);
      expect(recovered.performancePeriodUid, period.uid);
      expect(recovered.settledThrough, charge.settledThrough);
      expect(saved.costPeriods.single.uid, recovered.performancePeriodUid);
    },
  );

  test(
    'LF-91.4: recuperar varios fondos mantiene aislados sus costes',
    () async {
      const otherIsin = 'LU0000000002';

      final periodA = makePerformancePeriod('lf91-4-period-a');
      final chargeA = makePerformanceCharge('lf91-4-charge-a', periodA.uid);

      final periodB = makePerformancePeriod('lf91-4-period-b');
      final chargeB = makePerformanceCharge('lf91-4-charge-b', periodB.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF91-4-A',
          costPeriods: [periodA],
          costCharges: [chargeA],
        ),
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: otherIsin,
          symbol: 'LF91-4-B',
          costPeriods: [periodB],
          costCharges: [chargeB],
        ),
      );

      final savedA = await DatabaseService.getFund(isin);
      final savedB = await DatabaseService.getFund(otherIsin);

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      expect(savedA!.costPeriods.map((p) => p.uid), [periodA.uid]);
      expect(savedA.costCharges.map((c) => c.uid), [chargeA.uid]);
      expect(savedA.costCharges.single.performancePeriodUid, periodA.uid);

      expect(savedB!.costPeriods.map((p) => p.uid), [periodB.uid]);
      expect(savedB.costCharges.map((c) => c.uid), [chargeB.uid]);
      expect(savedB.costCharges.single.performancePeriodUid, periodB.uid);

      expect(
        savedA.costPeriods
            .map((p) => p.uid)
            .toSet()
            .intersection(savedB.costPeriods.map((p) => p.uid).toSet()),
        isEmpty,
      );
    },
  );

  test('LF-91.5: guardar, recuperar y volver a guardar conserva costes y relaciones', () async {
    final period = FundCostPeriod(
      uid: 'lf91-5-period',
      concept: FundCostConcept.performance,
      ratePercent: 8.5,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      description: 'Periodo persistente',
    );

    final charge = FundCostCharge(
      uid: 'lf91-5-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 10, 20),
      amount: 19.40,
      description: 'Cargo persistente',
      performancePeriodUid: period.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF91-5',
        costPeriods: [period],
        costCharges: [charge],
      ),
    );

    final firstRead = await DatabaseService.getFund(isin);
    expect(firstRead, isNotNull);

    await DatabaseService.saveFund(firstRead!);

    final secondRead = await DatabaseService.getFund(isin);

    expect(secondRead, isNotNull);
    expect(secondRead!.costPeriods, hasLength(1));
    expect(secondRead.costCharges, hasLength(1));

    final recoveredPeriod = secondRead.costPeriods.single;
    final recoveredCharge = secondRead.costCharges.single;

    expect(recoveredPeriod.uid, period.uid);
    expect(recoveredPeriod.ratePercent, period.ratePercent);
    expect(recoveredPeriod.description, period.description);

    expect(recoveredCharge.uid, charge.uid);
    expect(recoveredCharge.amount, charge.amount);
    expect(recoveredCharge.description, charge.description);
    expect(recoveredCharge.performancePeriodUid, recoveredPeriod.uid);
    expect(recoveredCharge.settledThrough, charge.settledThrough);
  });

  test(
    'LF-92.1: eliminar un periodo y sus cargos conserva los costes restantes',
    () async {
      final periodA = FundCostPeriod(
        uid: 'lf92-1-period-a',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
        validTo: DateTime(2026, 6, 30),
        description: 'Primer semestre',
      );

      final periodB = FundCostPeriod(
        uid: 'lf92-1-period-b',
        concept: FundCostConcept.performance,
        ratePercent: 10,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 7, 1),
        description: 'Segundo semestre',
      );

      final chargeA = FundCostCharge(
        uid: 'lf92-1-charge-a',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 6, 20),
        amount: 12.50,
        description: 'Cargo del primer semestre',
        performancePeriodUid: periodA.uid,
        settledThrough: DateTime(2026, 6, 19),
      );

      final chargeB = FundCostCharge(
        uid: 'lf92-1-charge-b',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 15.50,
        description: 'Cargo del segundo semestre',
        performancePeriodUid: periodB.uid,
        settledThrough: DateTime(2026, 10, 19),
      );

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF92-1',
          costPeriods: [periodA, periodB],
          costCharges: [chargeA, chargeB],
        ),
      );

      // Eliminar el primer periodo y su cargo conjuntamente.
      await DatabaseService.saveFund(
        makeFund(
          fundIsin: isin,
          symbol: 'LF92-1',
          costPeriods: [periodB],
          costCharges: [chargeB],
        ),
      );

      final saved = await DatabaseService.getFund(isin);

      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, periodB.uid);
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, chargeB.uid);
      expect(saved.costCharges.single.performancePeriodUid, periodB.uid);
    },
  );

  test('LF-92.2: cambiar el UID de un periodo conserva sus referencias tras recargar', () async {
    final originalPeriod = makePerformancePeriod('lf92-2-period-old');
    final originalCharge = makePerformanceCharge(
      'lf92-2-charge',
      originalPeriod.uid,
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF92-2',
        costPeriods: [originalPeriod],
        costCharges: [originalCharge],
      ),
    );

    final updatedPeriod = makePerformancePeriod('lf92-2-period-new');
    final updatedCharge = makePerformanceCharge(
      originalCharge.uid,
      updatedPeriod.uid,
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF92-2',
        costPeriods: [updatedPeriod],
        costCharges: [updatedCharge],
      ),
    );

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.costPeriods, hasLength(1));
    expect(saved.costPeriods.single.uid, updatedPeriod.uid);
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.uid, originalCharge.uid);
    expect(saved.costCharges.single.performancePeriodUid, updatedPeriod.uid);
    expect(saved.costPeriods.any((p) => p.uid == originalPeriod.uid), isFalse);
  });

  test('LF-92.3: reasignar un cargo persiste la nueva relación', () async {
    final periodA = FundCostPeriod(
      uid: 'lf92-3-period-a',
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 6, 30),
      description: 'Primer semestre',
    );

    final periodB = FundCostPeriod(
      uid: 'lf92-3-period-b',
      concept: FundCostConcept.performance,
      ratePercent: 12,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 7, 1),
      description: 'Segundo semestre',
    );

    final originalCharge = FundCostCharge(
      uid: 'lf92-3-charge',
      concept: FundCostConcept.performance,
      date: DateTime(2026, 6, 20),
      amount: 18.50,
      description: 'Cargo reasignado',
      performancePeriodUid: periodA.uid,
      settledThrough: DateTime(2026, 6, 19),
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF92-3',
        costPeriods: [periodA, periodB],
        costCharges: [originalCharge],
      ),
    );

    // Reasignar el mismo cargo al segundo periodo.
    final reassignedCharge = FundCostCharge(
      uid: originalCharge.uid,
      concept: originalCharge.concept,
      date: DateTime(2026, 10, 20),
      amount: originalCharge.amount,
      description: originalCharge.description,
      performancePeriodUid: periodB.uid,
      settledThrough: DateTime(2026, 10, 19),
    );

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF92-3',
        costPeriods: [periodA, periodB],
        costCharges: [reassignedCharge],
      ),
    );

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.costPeriods, hasLength(2));
    expect(saved.costCharges, hasLength(1));
    expect(saved.costCharges.single.uid, originalCharge.uid);
    expect(saved.costCharges.single.performancePeriodUid, periodB.uid);
    expect(saved.costCharges.single.date, DateTime(2026, 10, 20));
    expect(
      saved.costPeriods.any(
        (period) => period.uid == saved.costCharges.single.performancePeriodUid,
      ),
      isTrue,
    );
  });

  test('LF-92.4: recrear un fondo no recupera costes antiguos', () async {
    final oldPeriod = makePerformancePeriod('lf92-4-old-period');
    final oldCharge = makePerformanceCharge('lf92-4-old-charge', oldPeriod.uid);

    await DatabaseService.saveFund(
      makeFund(
        fundIsin: isin,
        symbol: 'LF92-4-OLD',
        costPeriods: [oldPeriod],
        costCharges: [oldCharge],
      ),
    );

    await DatabaseService.deleteFund(isin);

    await DatabaseService.saveFund(
      makeFund(fundIsin: isin, symbol: 'LF92-4-NEW'),
    );

    final saved = await DatabaseService.getFund(isin);

    expect(saved, isNotNull);
    expect(saved!.symbol, 'LF92-4-NEW');
    expect(saved.costPeriods, isEmpty);
    expect(saved.costCharges, isEmpty);
  });

  test(
    'LF-92.5: una escritura inválida no altera los costes de otro fondo',
    () async {
      const otherIsin = 'LU0000000002';

      final period = makePerformancePeriod('lf92-5-period');
      final charge = makePerformanceCharge('lf92-5-charge', period.uid);

      await DatabaseService.saveFund(
        makeFund(
          fundIsin: otherIsin,
          symbol: 'LF92-5-VALID',
          costPeriods: [period],
          costCharges: [charge],
        ),
      );

      final invalidPeriod = FundCostPeriod(
        uid: 'lf92-5-invalid-period',
        concept: FundCostConcept.performance,
        ratePercent: double.nan,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 1, 1),
      );

      await expectLater(
        DatabaseService.saveFund(
          makeFund(
            fundIsin: isin,
            symbol: 'LF92-5-INVALID',
            costPeriods: [invalidPeriod],
          ),
        ),
        throwsArgumentError,
      );

      final saved = await DatabaseService.getFund(otherIsin);

      expect(saved, isNotNull);
      expect(saved!.symbol, 'LF92-5-VALID');
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, period.uid);
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, charge.uid);
      expect(saved.costCharges.single.performancePeriodUid, period.uid);
    },
  );
}
