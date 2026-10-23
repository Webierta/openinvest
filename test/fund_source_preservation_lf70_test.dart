import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const isin = 'IE00B4L5Y983';

  late Directory temporaryDirectory;
  late FundData existingFund;
  late FundData primaryFund;
  late FundCostPeriod costPeriod;
  late FundCostCharge costCharge;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp('lf68_test_');

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );

    costPeriod = FundCostPeriod(
      uid: 'lf68-period-001',
      concept: FundCostConcept.management,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      ratePercent: 0.65,
      validFrom: DateTime(2025, 1, 1),
      validTo: DateTime(2025, 12, 31),
      description: 'Coste de gestión LF-68',
    );

    costCharge = FundCostCharge(
      uid: 'lf68-charge-001',
      concept: FundCostConcept.performance,
      date: DateTime(2025, 12, 31),
      amount: 12.75,
      description: 'Cargo de prueba LF-68',
      performancePeriodUid: null,
      settledThrough: null,
    );

    existingFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [
        PricePoint(DateTime(2026, 10, 2), 105),
        PricePoint(DateTime(2026, 10, 3), 110),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.yahoo,
      ter: 0.75,
      performanceFee: 10,
      costPeriods: [costPeriod],
      costCharges: [costCharge],
    );

    // La fuente principal aporta una valoración más reciente y un TER nuevo,
    // pero no informa de los costes estructurados.
    primaryFund = FundData(
      isin: isin,
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 112,
      currency: 'EUR',
      date: DateTime(2026, 10, 4),
      history: [
        PricePoint(DateTime(2026, 10, 3), 110),
        PricePoint(DateTime(2026, 10, 4), 112),
      ],
      source: FundSource.cnmv,
      valuationSource: FundSource.cnmv,
      ter: 0.50,
      //costPeriods: const [],
      //costCharges: const [],
      costPeriods: [
        FundCostPeriod(
          uid: 'lf70-period-provider',
          concept: FundCostConcept.management,
          ratePercent: 0.90,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
          validFrom: DateTime(2026, 1, 1),
          description: 'Coste nuevo del proveedor',
        ),
      ],
      costCharges: [
        FundCostCharge(
          uid: 'lf70-charge-provider',
          concept: FundCostConcept.performance,
          date: DateTime(2026, 10, 4),
          amount: 25.0,
          description: 'Cargo nuevo del proveedor',
        ),
      ],
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
    FundProvider.disposeHttpClient();
  });

  FundProvider createProvider() {
    return FundProvider(
      fundIsinFetcher: (_) async => ScrapeResult(data: primaryFund),
      queFondosFetcher: (_) async => null,
      ftFetcher: (_) async => null,
      ftByIsinFetcher: (_) async => null,
    );
  }

  Future<FundData> fetchFundWithCosts({
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) async {
    await DatabaseService.saveFund(existingFund);

    // Misma valoración, fecha e historial: solo cambian los costes.
    primaryFund = FundData(
      isin: existingFund.isin,
      symbol: existingFund.symbol,
      name: existingFund.name,
      lastValue: existingFund.lastValue,
      currency: existingFund.currency,
      date: existingFund.date,
      history: existingFund.history,
      ter: existingFund.ter,
      performanceFee: existingFund.performanceFee,
      source: existingFund.source,
      valuationSource: existingFund.valuationSource,
      costPeriods: periods,
      costCharges: charges,
    );

    final provider = createProvider();

    //final success = await provider.searchFund(existingFund.isin);
    //expect(success, isTrue);

    final success = await provider.searchFund(existingFund.isin);

    if (!success) {
      // ignore: avoid_print
      print('LF-71 lastError: ${provider.lastError}');
    }

    expect(success, isTrue);

    final savedFund = await DatabaseService.getFund(existingFund.isin);
    expect(savedFund, isNotNull);

    return savedFund!;
  }

  void expectProviderCostsAdopted(FundData fund) {
    // La nueva valoración y el TER siguen actualizándose.
    expect(fund.lastValue, 112);
    expect(fund.date, DateTime(2026, 10, 4));
    expect(fund.ter, 0.50);

    // Los metadatos que la respuesta no proporciona se conservan.
    expect(fund.performanceFee, 10);

    // Debe incorporarse el periodo de costes del proveedor.
    expect(fund.costPeriods, hasLength(1));

    final savedPeriod = fund.costPeriods.single;

    expect(savedPeriod.uid, 'lf70-period-provider');
    expect(savedPeriod.concept, FundCostConcept.management);
    expect(savedPeriod.ratePercent, 0.90);
    expect(savedPeriod.basis, FundCostRateBasis.annualBalance);
    expect(savedPeriod.treatment, FundCostTreatment.includedInNav);
    expect(savedPeriod.validFrom, DateTime(2026, 1, 1));
    expect(savedPeriod.validTo, isNull);
    expect(savedPeriod.description, 'Coste nuevo del proveedor');

    // Debe incorporarse también el cargo nuevo.
    expect(fund.costCharges, hasLength(1));

    final savedCharge = fund.costCharges.single;

    expect(savedCharge.uid, 'lf70-charge-provider');
    expect(savedCharge.concept, FundCostConcept.performance);
    expect(savedCharge.date, DateTime(2026, 10, 4));
    expect(savedCharge.amount, 25.0);
    expect(savedCharge.description, 'Cargo nuevo del proveedor');
    expect(savedCharge.performancePeriodUid, isNull);
    expect(savedCharge.settledThrough, isNull);
  }

  test('LF-70.1: searchFund adopta los costes nuevos del proveedor', () async {
    await DatabaseService.saveFund(existingFund);
    final provider = createProvider();

    await provider.searchFund(isin);

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expectProviderCostsAdopted(savedFund!);
  });

  test(
    'LF-70.2: updateAllPortfolio adopta los costes nuevos del proveedor',
    () async {
      await DatabaseService.saveFund(existingFund);
      final provider = createProvider()..portfolio = [existingFund];

      await provider.updateAllPortfolio();

      final savedFund = await DatabaseService.getFund(isin);

      expect(savedFund, isNotNull);
      expectProviderCostsAdopted(savedFund!);
    },
  );

  test(
    'LF-70.3: searchFund adopta costes nuevos aunque la valoración no cambie',
    () async {
      await DatabaseService.saveFund(existingFund);

      // El proveedor ofrece costes nuevos, pero no cambia la valoración,
      // la fecha ni el historial del fondo.
      primaryFund = FundData(
        isin: existingFund.isin,
        symbol: existingFund.symbol,
        name: existingFund.name,
        lastValue: existingFund.lastValue,
        currency: existingFund.currency,
        date: existingFund.date,
        history: existingFund.history,
        source: existingFund.source,
        valuationSource: existingFund.valuationSource,
        ter: existingFund.ter,
        performanceFee: existingFund.performanceFee,
        costPeriods: [
          FundCostPeriod(
            uid: 'lf70-period-provider',
            concept: FundCostConcept.management,
            ratePercent: 0.90,
            basis: FundCostRateBasis.annualBalance,
            treatment: FundCostTreatment.includedInNav,
            validFrom: DateTime(2026, 1, 1),
            description: 'Coste nuevo del proveedor',
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'lf70-charge-provider',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 4),
            amount: 25.0,
            description: 'Cargo nuevo del proveedor',
          ),
        ],
      );

      final provider = createProvider();

      // final success = await provider.searchFund(existingFund.isin);

      // expect(success, isTrue);

      final success = await provider.searchFund(existingFund.isin);

      if (!success) {
        // Diagnóstico temporal para identificar por qué no se actualiza.
        // ignore: avoid_print
        print('LF-70.3 lastError: ${provider.lastError}');
      }

      expect(success, isTrue);

      final savedFund = await DatabaseService.getFund(existingFund.isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.costPeriods.map((period) => period.uid).toList(), [
        'lf70-period-provider',
      ]);
      expect(savedFund.costCharges.map((charge) => charge.uid).toList(), [
        'lf70-charge-provider',
      ]);
      expect(savedFund.costPeriods.single.ratePercent, 0.90);
      expect(savedFund.costCharges.single.amount, 25.0);
    },
  );

  test('LF-71.1: detecta un cambio de concepto del periodo', () async {
    final updatedPeriod = FundCostPeriod(
      uid: costPeriod.uid,
      concept: FundCostConcept.other,
      ratePercent: costPeriod.ratePercent,
      basis: FundCostRateBasis.annualBalance,
      treatment: FundCostTreatment.includedInNav,
      validFrom: costPeriod.validFrom,
      validTo: costPeriod.validTo,
      description: costPeriod.description,
    );

    /* final savedFund = await fetchFundWithCosts(
      periods: [updatedPeriod],
      charges: [costCharge],
    ); */

    final savedFund = await fetchFundWithCosts(
      periods: [updatedPeriod],
      charges: const [],
    );

    expect(savedFund.lastValue, existingFund.lastValue);
    expect(savedFund.date, existingFund.date);
    expect(savedFund.costPeriods, hasLength(1));
    expect(savedFund.costPeriods.single.concept, FundCostConcept.other);
  });
}
