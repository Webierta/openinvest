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
      concept: FundCostConcept.performance,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      //concept: FundCostConcept.management,
      ratePercent: 0.65,
      //basis: FundCostRateBasis.annualBalance,
      //treatment: FundCostTreatment.includedInNav,
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
      performancePeriodUid: costPeriod.uid,
      settledThrough: DateTime(2025, 12, 31),
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

  void expectStructuredCostsPreserved(FundData fund) {
    expect(fund.lastValue, 112);
    expect(fund.date, DateTime(2026, 10, 4));
    expect(fund.ter, 0.50);
    expect(fund.performanceFee, 10);

    expect(fund.costPeriods, hasLength(1));
    final savedPeriod = fund.costPeriods.single;

    expect(savedPeriod.uid, 'lf68-period-001');
    expect(savedPeriod.concept, FundCostConcept.performance);
    expect(savedPeriod.ratePercent, 0.65);
    expect(savedPeriod.basis, FundCostRateBasis.positiveProfit);
    expect(savedPeriod.treatment, FundCostTreatment.chargedSeparately);
    expect(savedPeriod.validFrom, DateTime(2025, 1, 1));
    expect(savedPeriod.validTo, DateTime(2025, 12, 31));
    expect(savedPeriod.description, 'Coste de gestión LF-68');

    expect(fund.costCharges, hasLength(1));
    final savedCharge = fund.costCharges.single;

    expect(savedCharge.uid, 'lf68-charge-001');
    expect(savedCharge.concept, FundCostConcept.performance);
    expect(savedCharge.date, DateTime(2025, 12, 31));
    expect(savedCharge.amount, 12.75);
    expect(savedCharge.description, 'Cargo de prueba LF-68');
    expect(savedCharge.performancePeriodUid, savedPeriod.uid);
    expect(savedCharge.settledThrough, DateTime(2025, 12, 31));
  }

  test('LF-68.1: searchFund conserva costPeriods y costCharges al actualizar valoración y TER', () async {
    await DatabaseService.saveFund(existingFund);
    final provider = createProvider();

    await provider.searchFund(isin);

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expectStructuredCostsPreserved(savedFund!);
  });

  test('LF-68.2: updateAllPortfolio conserva costPeriods y costCharges al actualizar valoración y TER', () async {
    await DatabaseService.saveFund(existingFund);
    final provider = createProvider()..portfolio = [existingFund];

    await provider.updateAllPortfolio();

    final savedFund = await DatabaseService.getFund(isin);

    expect(savedFund, isNotNull);
    expectStructuredCostsPreserved(savedFund!);
  });

  test('FundData distingue los periodos TER heredados de los explícitos', () {
    final inherited = FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [PricePoint(DateTime(2026, 10, 3), 110)],
      ter: 0.50,
    );

    final explicitEmpty = FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [PricePoint(DateTime(2026, 10, 3), 110)],
      ter: 0.50,
      costPeriods: const [],
    );

    final explicitStructured = FundData(
      isin: 'IE00B4L5Y983',
      symbol: 'TEST',
      name: 'Test Fund',
      lastValue: 110,
      currency: 'EUR',
      date: DateTime(2026, 10, 3),
      history: [PricePoint(DateTime(2026, 10, 3), 110)],
      ter: 0.50,
      costPeriods: [
        FundCostPeriod(
          uid: 'explicit-ter',
          concept: FundCostConcept.ter,
          ratePercent: 0.50,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
      ],
    );

    // Sustituiremos estas expectativas por la propiedad de procedencia
    // cuando la añadamos al modelo.
    expect(inherited.costPeriods, isNotEmpty);
    expect(explicitEmpty.costPeriods, isEmpty);
    expect(explicitStructured.costPeriods, hasLength(1));
  });
}
