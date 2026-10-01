import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/services/fund_scraper.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('FinancialCalculator Tests', () {
    final baseDate = DateTime(2023, 1, 1);

    group('calculateFundMetrics - Basic Operations', () {
      test(
        'should correctly calculate units, value, and profit with buy and sell',
        () {
          final mockHistory = [
            PricePoint(baseDate, 10.0),
            PricePoint(baseDate.add(const Duration(days: 30)), 12.0),
          ];

          final fund = FundData(
            isin: 'TEST123',
            symbol: 'TST',
            name: 'Test Fund',
            lastValue: 12.0,
            currency: 'EUR',
            date: baseDate.add(const Duration(days: 30)),
            history: mockHistory,
            operations: [
              FundOperation(
                isin: 'TEST123',
                date: baseDate,
                type: OperationType.buy,
                units: 10,
                price: 10,
                amount: 100,
              ),
              FundOperation(
                isin: 'TEST123',
                date: baseDate.add(const Duration(days: 10)),
                type: OperationType.sell,
                units: 2,
                price: 11,
                amount: 22,
              ),
            ],
          );

          final metrics = FinancialCalculator.calculateFundMetrics(fund);

          // Unidades: 10 (compra) - 2 (venta) = 8
          expect(metrics.totalUnits, 8.0);
          // Valor actual: 8 unidades * 12.0 (lastValue) = 96.0
          expect(metrics.currentValue, 96.0);
          // Invertido: 100 (compra) - 22 (venta) = 78.0
          expect(metrics.totalInvested, 78.0);
          // Beneficio absoluto: 96.0 - 78.0 = 18.0
          expect(metrics.profitAbs, 18.0);
        },
      );

      test('should handle no investment correctly', () {
        final fund = FundData(
          isin: 'TEST',
          symbol: 'TST',
          name: 'Test Fund',
          lastValue: 12.0,
          currency: 'EUR',
          date: baseDate,
          history: [],
          operations: [],
        );

        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        expect(metrics.tae, 0.0);
        expect(metrics.currentValue, 0.0);
        expect(metrics.totalUnits, 0.0);
        expect(metrics.mwrAnnualized, isNull);
      });

      test('la antigüedad empieza en la primera suscripción, no reembolso', () {
        final firstBuy = DateTime(2023, 1, 5);
        final earlierSell = DateTime(2023, 1, 2);
        final fund = FundData(
          isin: 'DATES',
          symbol: 'DTS',
          name: 'Date Test Fund',
          lastValue: 10,
          currency: 'EUR',
          date: DateTime(2023, 2, 4),
          history: [PricePoint(firstBuy, 10)],
          operations: [
            FundOperation(
              isin: 'DATES',
              date: earlierSell,
              type: OperationType.sell,
              units: 0.5,
              price: 10,
              amount: 5,
            ),
            FundOperation(
              isin: 'DATES',
              date: firstBuy,
              type: OperationType.buy,
              units: 2,
              price: 10,
              amount: 20,
            ),
          ],
        );

        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        expect(metrics.firstOpDate, firstBuy);
      });

      test('el neto resta cargos externos reales, no tarifas', () {
        final date = DateTime(2023, 1, 1);
        final fund = FundData(
          isin: 'COSTS',
          symbol: 'CST',
          name: 'Cost Test Fund',
          lastValue: 12,
          currency: 'EUR',
          date: date.add(const Duration(days: 365)),
          history: [PricePoint(date, 10)],
          operations: [
            FundOperation(
              isin: 'COSTS',
              date: date,
              type: OperationType.buy,
              units: 10,
              price: 10,
              amount: 100,
            ),
          ],
          costPeriods: [
            FundCostPeriod(
              concept: FundCostConcept.ter,
              ratePercent: 1,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.includedInNav,
              validFrom: date,
            ),
          ],
          costCharges: [
            FundCostCharge(
              concept: FundCostConcept.subscription,
              date: date,
              amount: 3,
            ),
            FundCostCharge(
              concept: FundCostConcept.other,
              date: date.subtract(const Duration(days: 1)),
              amount: 50,
            ),
            FundCostCharge(
              concept: FundCostConcept.other,
              date: DateTime.now().add(const Duration(days: 1)),
              amount: 70,
            ),
            FundCostCharge(
              concept: FundCostConcept.performance,
              date: DateTime.now(),
              amount: 6,
            ),
          ],
        );

        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        expect(metrics.profitAbs, 20);
        expect(metrics.recordedExternalCosts, 9);
        expect(metrics.netProfit, 11);
      });
    });

    group('FinancialCalculator - MWR (IRR) Accuracy', () {
      test('should reflect positive MWR when buying the dip (Dollar Cost Averaging)', () {
        // Escenario: Invierto 1000€. El fondo cae un 50%. Invierto otros 1000€.
        // El fondo se recupera a su valor original. El MWR debe ser muy positivo.
        final startDate = DateTime(2023, 1, 1);
        final midDate = DateTime(2023, 7, 1); // ~6 meses después
        final endDate = DateTime(2024, 1, 1); // ~1 año después

        final fund = FundData(
          isin: 'DCA123',
          symbol: 'DCA',
          name: 'DCA Test Fund',
          lastValue: 20.0, // Se recuperó al precio inicial
          currency: 'EUR',
          date: endDate,
          history: [
            PricePoint(startDate, 20.0),
            PricePoint(midDate, 10.0), // Caída del 50%
            PricePoint(endDate, 20.0), // Recuperación
          ],
          operations: [
            FundOperation(
              isin: 'DCA123',
              date: startDate,
              type: OperationType.buy,
              units: 50, // 1000€ / 20€
              price: 20.0,
              amount: 1000.0,
            ),
            FundOperation(
              isin: 'DCA123',
              date: midDate,
              type: OperationType.buy,
              units: 100, // 1000€ / 10€ (compramos el doble de unidades)
              price: 10.0,
              amount: 1000.0,
            ),
          ],
        );

        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        // Valor actual: 150 unidades * 20€ = 3000€
        expect(metrics.currentValue, 3000.0);
        expect(metrics.totalInvested, 2000.0);

        // El MWR anualizado debe ser positivo y significativo (~41-42%)
        // porque el inversor puso más dinero cuando estaba barato.
        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized, greaterThan(0.40)); // > 40%
      });
    });

    group('FinancialCalculator - Edge Cases', () {
      test(
        'should avoid division by zero when totalInvested is 0 but units > 0',
        () {
          // Caso raro: usuario importa una cartera con unidades pero sin historial de coste
          final fund = FundData(
            isin: 'EDGE',
            symbol: 'EDG',
            name: 'Edge Case Fund',
            lastValue: 15.0,
            currency: 'EUR',
            date: baseDate,
            history: [PricePoint(baseDate, 15.0)],
            operations: [], // Sin operaciones registradas
          );

          final metrics = FinancialCalculator.calculateFundMetrics(fund);

          expect(metrics.totalInvested, 0.0);
          expect(metrics.avgPurchasePrice, 0.0);
          expect(metrics.moic, 0.0);
          expect(metrics.tae, 0.0);
        },
      );
    });
  });

  group('FinancialCalculator - Current Cost Estimates', () {
    test(
      'estima tarifas externas activas sin duplicar TER ni tocar el neto',
      () {
        final date = DateTime(2026, 1, 1);
        final settledThrough = date.subtract(const Duration(days: 1));
        final performancePeriod = FundCostPeriod(
          concept: FundCostConcept.performance,
          ratePercent: 10,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: date.subtract(const Duration(days: 10)),
        );
        final fund = FundData(
          isin: 'ESTIMATE',
          symbol: 'EST',
          name: 'Estimate Fund',
          lastValue: 12,
          currency: 'EUR',
          date: date,
          history: [PricePoint(settledThrough, 11), PricePoint(date, 12)],
          operations: [
            FundOperation(
              isin: 'ESTIMATE',
              date: date.subtract(const Duration(days: 30)),
              type: OperationType.buy,
              units: 10,
              price: 10,
              amount: 100,
            ),
          ],
          costPeriods: [
            FundCostPeriod(
              concept: FundCostConcept.ter,
              ratePercent: 1,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.chargedSeparately,
              validFrom: date.subtract(const Duration(days: 10)),
            ),
            FundCostPeriod(
              concept: FundCostConcept.management,
              ratePercent: 0.25,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.chargedSeparately,
              validFrom: date.subtract(const Duration(days: 10)),
            ),
            FundCostPeriod(
              concept: FundCostConcept.operating,
              ratePercent: 0.2,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.includedInNav,
              validFrom: date.subtract(const Duration(days: 10)),
            ),
            FundCostPeriod(
              concept: FundCostConcept.other,
              ratePercent: 0.5,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.chargedSeparately,
              validFrom: date.subtract(const Duration(days: 10)),
            ),
            performancePeriod,
            FundCostPeriod(
              concept: FundCostConcept.other,
              ratePercent: 5,
              basis: FundCostRateBasis.annualBalance,
              treatment: FundCostTreatment.chargedSeparately,
              validFrom: date.add(const Duration(days: 1)),
            ),
          ],
          costCharges: [
            FundCostCharge(
              concept: FundCostConcept.performance,
              date: date,
              amount: 3,
              performancePeriodUid: performancePeriod.uid,
              settledThrough: settledThrough,
            ),
          ],
        );

        final estimate = FinancialCalculator.estimateCurrentFundCosts(
          fund,
          asOf: date,
        );
        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        expect(estimate.annualRecurringCost, closeTo(1.8, 1e-10));
        expect(estimate.potentialPerformanceFee, closeTo(1, 1e-10));
        expect(estimate.hasAnnualRates, isTrue);
        expect(estimate.hasPerformanceRate, isTrue);
        expect(metrics.profitAbs, 20);
        expect(metrics.netProfit, 17);
      },
    );

    test('oculta comisión potencial si no hay liquidación vinculada', () {
      final date = DateTime(2026, 1, 1);
      final fund = FundData(
        isin: 'NOSETTLEMENT',
        symbol: 'NS',
        name: 'No Settlement Fund',
        lastValue: 12,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 12)],
        operations: [
          FundOperation(
            isin: 'NOSETTLEMENT',
            date: date.subtract(const Duration(days: 30)),
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
        costPeriods: [
          FundCostPeriod(
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: date.subtract(const Duration(days: 10)),
          ),
        ],
      );

      final estimate = FinancialCalculator.estimateCurrentFundCosts(
        fund,
        asOf: date,
      );

      expect(estimate.hasPerformanceRate, isFalse);
      expect(estimate.potentialPerformanceFee, 0);
    });
  });

  group('FinancialCalculator - TWR Accuracy', () {
    test('TWR should isolate fund performance from investor cash flows', () {
      // Escenario: El fondo sube un 10%, luego el inversor deposita dinero,
      // luego el fondo cae un 10%.
      // El TWR debe ser negativo: (1.10 * 0.90) - 1 = -1%
      // (Aunque el MWR podría ser diferente dependiendo de cuándo se depositó).

      final startDate = DateTime(2023, 1, 1);
      final midDate = DateTime(2023, 6, 1);
      final endDate = DateTime(2023, 12, 31);

      final fund = FundData(
        isin: 'TWR123',
        symbol: 'TWR',
        name: 'TWR Test Fund',
        lastValue: 9.9, // 10 * 1.10 * 0.90 = 9.9
        currency: 'EUR',
        date: endDate,
        history: [
          PricePoint(startDate, 10.0),
          PricePoint(midDate, 11.0), // +10%
          PricePoint(endDate, 9.9), // -10% desde 11.0
        ],
        operations: [
          FundOperation(
            isin: 'TWR123',
            date: startDate,
            type: OperationType.buy,
            units: 100,
            price: 10.0,
            amount: 1000.0,
          ),
          FundOperation(
            isin: 'TWR123',
            date: midDate,
            type: OperationType.buy,
            units: 90.909, // 1000€ / 11.0€
            price: 11.0,
            amount: 1000.0,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateFundMetrics(fund);

      // El TWR debe reflejar la caída del 1% del activo, independientemente de los depósitos
      expect(metrics.twrTotal, closeTo(-0.01, 0.001)); // -1%
      expect(metrics.twrAnnualized, lessThan(0)); // Debe ser negativo
    });
  });

  /* group('FinancialCalculator Tests', () {
    final baseDate = DateTime(2023, 1, 1);
    final mockHistory = [
      PricePoint(baseDate, 10.0),
      PricePoint(baseDate.add(const Duration(days: 30)), 12.0),
    ];

    test('calculateFundMetrics should correctly calculate units and value', () {
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 12.0,
        currency: 'EUR',
        date: baseDate.add(const Duration(days: 30)),
        history: mockHistory,
        operations: [
          FundOperation(
            isin: 'TEST',
            date: baseDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
          FundOperation(
            isin: 'TEST',
            date: baseDate.add(const Duration(days: 10)),
            type: OperationType.sell,
            units: 2,
            price: 11,
            amount: 22,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateFundMetrics(fund);
      // (10 - 2) * 12 = 8 * 12 = 96
      expect(metrics.currentValue, 96.0);
      expect(metrics.totalUnits, 8.0);
    });

    test('calculateFundMetrics should handle no investment correctly', () {
      final fund = FundData(
        isin: 'TEST',
        symbol: 'TST',
        name: 'Test Fund',
        lastValue: 12.0,
        currency: 'EUR',
        date: baseDate,
        history: mockHistory,
        operations: [],
      );

      final metrics = FinancialCalculator.calculateFundMetrics(fund);
      expect(metrics.tae, 0);
      expect(metrics.currentValue, 0);
    });
  }); */
}
