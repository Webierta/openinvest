import 'package:flutter_test/flutter_test.dart';

import 'package:investing/models/fund_cost.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/services/isin_providers/isin_source_provider.dart';
import 'package:investing/services/isin_resolver.dart';

void main() {
  group('LF-20.10.6 - procedencia y preservación tras resolución', () {
    const match = FundSearchMatch(
      isin: null,
      symbol: 'TEST',
      name: 'Test Fund',
      source: FundSource.yahoo,
    );

    Future<ScrapeResult> runWithResolution(String source) async {
      final provider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          data: _makeFund(),
          isResolved: false,
          source: FundSource.yahoo,
        ),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(
              result: IsinResult(isin: 'ES0123456789', source: source),
            ),
          ],
        ),
      );

      return provider.fetchFundMatch(match);
    }

    test('1. CNMV/SIL → FundSource.cnmv', () async {
      final result = await runWithResolution('CNMV/SIL');

      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.cnmv);
      expect(result.isResolved, isTrue);
    });

    test('2. CNMV/FI → FundSource.cnmv', () async {
      final result = await runWithResolution('CNMV/FI');

      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.cnmv);
      expect(result.isResolved, isTrue);
    });

    test('3. Yahoo/... → FundSource.yahoo', () async {
      final result = await runWithResolution('Yahoo/search');

      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.yahoo);
      expect(result.isResolved, isTrue);
    });

    test('4. Morningstar/... → FundSource.morningstar', () async {
      final result = await runWithResolution('Morningstar/HoldingIsin');

      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.morningstar);
      expect(result.isResolved, isTrue);
    });

    test('5. fondos_armonizados.json → FundSource.local', () async {
      final result = await runWithResolution('fondos_armonizados.json');

      expect(result.data, isNotNull);
      expect(result.data!.isin, 'ES0123456789');
      expect(result.source, FundSource.local);
      expect(result.isResolved, isTrue);
    });

    test('6. isResolved solo es true cuando existe resolución', () async {
      final resolvedProvider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          data: _makeFund(),
          isResolved: false,
          source: FundSource.yahoo,
        ),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(
              result: IsinResult(isin: 'ES0123456789', source: 'ECB/IFS'),
            ),
          ],
        ),
      );

      final resolved = await resolvedProvider.fetchFundMatch(match);

      expect(resolved.isResolved, isTrue);
      expect(resolved.data!.isin, 'ES0123456789');
      expect(resolved.source, FundSource.ecb);

      final unresolvedProvider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          data: _makeFund(),
          isResolved: false,
          source: FundSource.yahoo,
        ),
        isinResolverFactory: () =>
            IsinResolver(providers: [_FakeIsinProvider()]),
      );

      final unresolved = await unresolvedProvider.fetchFundMatch(match);

      expect(unresolved.isResolved, isFalse);
      expect(unresolved.data!.isin, 'INVALID');
      expect(unresolved.source, FundSource.yahoo);
    });

    test('7. La resolución conserva todos los datos del FundData', () async {
      final original = _makeFund();

      final originalHistory = original.history;
      final originalOperation = original.operations.single;
      final originalCostPeriod = original.costPeriods.single;
      final originalCostCharge = original.costCharges.single;

      final provider = FundProvider(
        fundSearchFetcher: (_) async => ScrapeResult(
          data: original,
          isResolved: false,
          source: FundSource.yahoo,
        ),
        isinResolverFactory: () => IsinResolver(
          providers: [
            _FakeIsinProvider(
              result: IsinResult(isin: 'ES0123456789', source: 'ECB/IFS'),
            ),
          ],
        ),
      );

      final result = await provider.fetchFundMatch(match);

      expect(result.data, isNotNull);

      final fund = result.data!;

      // El ISIN debe sustituirse.
      expect(fund.isin, 'ES0123456789');

      // Identidad del fondo.
      expect(fund.symbol, original.symbol);
      expect(fund.name, original.name);

      // Datos de cotización.
      expect(fund.lastValue, original.lastValue);
      expect(fund.currency, original.currency);
      expect(fund.date, original.date);

      expect(fund.history, hasLength(originalHistory.length));
      expect(fund.history.first.date, originalHistory.first.date);
      expect(fund.history.first.price, originalHistory.first.price);

      // Operaciones.
      expect(fund.operations, hasLength(1));
      expect(fund.operations.single.isin, originalOperation.isin);
      expect(fund.operations.single.date, originalOperation.date);
      expect(fund.operations.single.type, originalOperation.type);
      expect(fund.operations.single.units, originalOperation.units);
      expect(fund.operations.single.price, originalOperation.price);
      expect(fund.operations.single.amount, originalOperation.amount);

      // Alertas.
      expect(fund.alertMin, original.alertMin);
      expect(fund.alertMax, original.alertMax);

      // Costes legacy/expuestos.
      expect(fund.ter, original.ter);
      expect(fund.performanceFee, original.performanceFee);

      // Periodos de costes.
      expect(fund.costPeriods, hasLength(1));
      expect(fund.costPeriods.single.uid, originalCostPeriod.uid);
      expect(fund.costPeriods.single.concept, originalCostPeriod.concept);
      expect(
        fund.costPeriods.single.ratePercent,
        originalCostPeriod.ratePercent,
      );
      expect(fund.costPeriods.single.basis, originalCostPeriod.basis);
      expect(fund.costPeriods.single.treatment, originalCostPeriod.treatment);
      expect(fund.costPeriods.single.validFrom, originalCostPeriod.validFrom);
      expect(fund.costPeriods.single.validTo, originalCostPeriod.validTo);
      expect(
        fund.costPeriods.single.description,
        originalCostPeriod.description,
      );

      // Cargos de costes.
      expect(fund.costCharges, hasLength(1));
      expect(fund.costCharges.single.uid, originalCostCharge.uid);
      expect(fund.costCharges.single.concept, originalCostCharge.concept);
      expect(fund.costCharges.single.date, originalCostCharge.date);
      expect(fund.costCharges.single.amount, originalCostCharge.amount);
      expect(
        fund.costCharges.single.description,
        originalCostCharge.description,
      );
      expect(
        fund.costCharges.single.performancePeriodUid,
        originalCostCharge.performancePeriodUid,
      );
      expect(
        fund.costCharges.single.settledThrough,
        originalCostCharge.settledThrough,
      );

      // Metadatos Morningstar.
      expect(fund.morningstarRating, original.morningstarRating);
      expect(fund.morningstarCheckedAt, original.morningstarCheckedAt);
      expect(fund.morningstarLastAttemptAt, original.morningstarLastAttemptAt);

      expect(result.source, FundSource.ecb);
      expect(result.isResolved, isTrue);
    });
  });
}

FundData _makeFund() {
  final operation = FundOperation(
    isin: 'INVALID',
    date: DateTime(2026, 1, 2),
    type: OperationType.buy,
    units: 10.0,
    price: 95.0,
    amount: 950.0,
  );

  final costPeriod = FundCostPeriod(
    concept: FundCostConcept.ter,
    ratePercent: 1.25,
    basis: FundCostRateBasis.annualBalance,
    treatment: FundCostTreatment.includedInNav,
    validFrom: DateTime(2026, 1, 1),
    validTo: DateTime(2026, 12, 31),
    description: 'TER anual',
  );

  final costCharge = FundCostCharge(
    concept: FundCostConcept.subscription,
    date: DateTime(2026, 1, 3),
    amount: 10.0,
    description: 'Comisión de suscripción',
    performancePeriodUid: null,
    settledThrough: DateTime(2026, 1, 4),
  );

  return FundData(
    isin: 'INVALID',
    symbol: 'TEST',
    name: 'Test Fund',
    lastValue: 100.0,
    currency: 'EUR',
    date: DateTime(2026, 1, 1),
    history: [
      PricePoint(DateTime(2026, 1, 1), 100.0),
      PricePoint(DateTime(2025, 12, 31), 99.0),
    ],
    operations: [operation],
    alertMin: 80.0,
    alertMax: 120.0,
    ter: 1.25,
    performanceFee: 10.0,
    costPeriods: [costPeriod],
    costCharges: [costCharge],
    morningstarRating: 4,
    morningstarCheckedAt: DateTime(2026, 2, 1),
    morningstarLastAttemptAt: DateTime(2026, 2, 2),
  );
}

class _FakeIsinProvider implements IsinSourceProvider {
  final IsinResult? result;

  _FakeIsinProvider({this.result});

  @override
  Future<IsinResult?> resolve({
    required String ticker,
    required String fundName,
  }) async {
    return result;
  }

  @override
  Future<List<IsinResult>> resolveAll({
    required String ticker,
    required String fundName,
  }) async {
    return result == null ? [] : [result!];
  }
}
