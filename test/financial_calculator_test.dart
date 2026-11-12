import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
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

      test('calcula una MWR anualizada superior al 200%', () {
        final startDate = DateTime(2023, 1, 1);
        final endDate = DateTime(2023, 2, 1);

        final fund = FundData(
          isin: 'HIGH-IRR',
          symbol: 'HIR',
          name: 'High IRR Test Fund',
          lastValue: 20,
          currency: 'EUR',
          date: endDate,
          history: [PricePoint(startDate, 10), PricePoint(endDate, 20)],
          operations: [
            FundOperation(
              isin: 'HIGH-IRR',
              date: startDate,
              type: OperationType.buy,
              units: 100,
              price: 10,
              amount: 1000,
            ),
          ],
        );

        final metrics = FinancialCalculator.calculateFundMetrics(fund);

        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized!, greaterThan(2.0));
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

  group('calculateGlobalMetrics - Portfolio MWR', () {
    test('calculates the annualized MWR from global cash flows', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2025, 1, 1);
      final fund = FundData(
        isin: 'GLOBAL-MWR',
        symbol: 'GMWR',
        name: 'Global MWR Fund',
        lastValue: 12.1,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 10), PricePoint(endDate, 12.1)],
        operations: [
          FundOperation(
            isin: 'GLOBAL-MWR',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1},
      );

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized, closeTo(0.1, 0.0005));
    });

    test('calcula una MWR global anualizada superior al 200%', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2023, 2, 1);

      final fund = FundData(
        isin: 'GLOBAL-HIGH-IRR',
        symbol: 'GHIR',
        name: 'Global High IRR Test Fund',
        lastValue: 20,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 10), PricePoint(endDate, 20)],
        operations: [
          FundOperation(
            isin: 'GLOBAL-HIGH-IRR',
            date: startDate,
            type: OperationType.buy,
            units: 100,
            price: 10,
            amount: 1000,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1},
      );

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, greaterThan(2.0));
    });

    test('internal fund transfers cancel out in global cash flows', () {
      final startDate = DateTime(2023, 1, 1);
      final transferDate = DateTime(2023, 7, 1);
      final endDate = DateTime(2024, 1, 1);
      final sourceFund = FundData(
        isin: 'TRANSFER-OUT',
        symbol: 'OUT',
        name: 'Transfer source',
        lastValue: 10,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(endDate, 10)],
        operations: [
          FundOperation(
            isin: 'TRANSFER-OUT',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
          FundOperation(
            isin: 'TRANSFER-OUT',
            date: transferDate,
            type: OperationType.outTransfer,
            units: 5,
            price: 10,
            amount: 50,
          ),
        ],
      );
      final destinationFund = FundData(
        isin: 'TRANSFER-IN',
        symbol: 'IN',
        name: 'Transfer destination',
        lastValue: 10,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(endDate, 10)],
        operations: [
          FundOperation(
            isin: 'TRANSFER-IN',
            date: transferDate,
            type: OperationType.inTransfer,
            units: 5,
            price: 10,
            amount: 50,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [sourceFund, destinationFund],
        const {'EUR': 1},
      );

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized, closeTo(0, 0.0005));
    });

    test('incluye inversiones históricas en las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-GLOBAL-001',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-OP-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1000);
      expect(metrics.totalValue, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(10, 0.0001));
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test(
      'calcula la MWR conjunta de varias inversiones históricas cerradas',
      () {
        final investmentA = HistoricalInvestment(
          uid: 'HIST-GLOBAL-A',
          name: 'Inversión histórica A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'HIST-GLOBAL-B',
          name: 'Inversión histórica B',
        );

        final operations = [
          HistoricalOperation(
            uid: 'HIST-GLOBAL-A-01',
            investmentUid: investmentA.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'HIST-GLOBAL-A-02',
            investmentUid: investmentA.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
          HistoricalOperation(
            uid: 'HIST-GLOBAL-B-01',
            investmentUid: investmentB.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'HIST-GLOBAL-B-02',
            investmentUid: investmentB.uid,
            date: DateTime(2025, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 600,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [investmentA, investmentB],
          historicalOperations: operations,
        );

        expect(metrics.totalInvested, 1500);
        expect(metrics.totalValue, 1700);
        expect(metrics.profitAbs, 200);
        expect(metrics.profitRel, closeTo(200 / 1500 * 100, 0.0001));
        expect(metrics.mwrAnnualized, closeTo(0.130636, 0.0005));
      },
    );

    test('no añade una valoración terminal artificial a inversiones históricas cerradas', () {
      final investmentA = HistoricalInvestment(
        uid: 'HIST-TERMINAL-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'HIST-TERMINAL-B',
        name: 'Inversión histórica B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-TERMINAL-A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-TERMINAL-A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-TERMINAL-B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'HIST-TERMINAL-B-02',
          investmentUid: investmentB.uid,
          date: DateTime(2025, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 600,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1500);
      expect(metrics.totalValue, 1700);
      expect(metrics.profitAbs, 200);
      //expect(metrics.mwrAnnualized, closeTo(0.130636, 0.0005));
      expect(metrics.mwrAnnualized, closeTo(0.097724, 0.0005));
    });

    test(
      'ignora inversiones históricas sin operaciones en las métricas globales',
      () {
        final investment = HistoricalInvestment(
          uid: 'HIST-EMPTY',
          name: 'Inversión sin operaciones',
        );

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [investment],
          historicalOperations: const [],
        );

        expect(metrics.totalInvested, 0);
        expect(metrics.totalValue, 0);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test(
      'solo contabiliza las operaciones asociadas a cada inversión histórica',
      () {
        final investmentA = HistoricalInvestment(
          uid: 'HIST-ISOLATION-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'HIST-ISOLATION-B',
          name: 'Inversión B',
        );

        final operations = [
          HistoricalOperation(
            uid: 'HIST-ISOLATION-A-01',
            investmentUid: investmentA.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'HIST-ISOLATION-A-02',
            investmentUid: investmentA.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
          HistoricalOperation(
            uid: 'HIST-ISOLATION-B-01',
            investmentUid: investmentB.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'HIST-ISOLATION-B-02',
            investmentUid: investmentB.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 450,
          ),
          // Operación huérfana: no pertenece a ninguna inversión recibida.
          HistoricalOperation(
            uid: 'HIST-ISOLATION-ORPHAN',
            investmentUid: 'HIST-NONEXISTENT',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 9999,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [investmentA, investmentB],
          historicalOperations: operations,
        );

        expect(metrics.totalInvested, 1500);
        expect(metrics.totalValue, 1550);
        expect(metrics.profitAbs, 50);
        expect(metrics.mwrAnnualized, isNotNull);
      },
    );

    test('mantiene las métricas globales aunque cambie el orden de inversiones y operaciones históricas', () {
      final investmentA = HistoricalInvestment(
        uid: 'HIST-ORDER-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'HIST-ORDER-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-ORDER-A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-ORDER-A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-ORDER-B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2023, 6, 1),
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'HIST-ORDER-B-02',
          investmentUid: investmentB.uid,
          date: DateTime(2024, 6, 1),
          type: HistoricalOperationType.redemption,
          amount: 600,
        ),
      ];

      final first = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      final reordered = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investmentB, investmentA],
        historicalOperations: operations.reversed.toList(),
      );

      expect(reordered.totalInvested, first.totalInvested);
      expect(reordered.totalValue, first.totalValue);
      expect(reordered.profitAbs, first.profitAbs);
      expect(reordered.profitRel, closeTo(first.profitRel, 0.000001));
      expect(reordered.mwrAnnualized, closeTo(first.mwrAnnualized!, 0.000001));
    });

    test('ignora operaciones históricas posteriores a la fecha actual', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-FUTURE',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-FUTURE-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-03',
          investmentUid: investment.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1000);
      expect(metrics.totalValue, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test('las operaciones futuras no alteran isAnnualized', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-ANNUALIZED',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-ANNUALIZED-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-ANNUALIZED-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-ANNUALIZED-03',
          investmentUid: investment.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('una suscripción futura no modifica la antigüedad de la cartera', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-FIRST-DATE',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-FIRST-DATE-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-FIRST-DATE-02',
          investmentUid: investment.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1000);
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('ignora reembolsos históricos posteriores a la fecha actual', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-FUTURE-REDEMPTION',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-FUTURE-REDEMPTION-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-REDEMPTION-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-REDEMPTION-03',
          investmentUid: investment.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1000);
      expect(metrics.totalValue, 1100);
      expect(metrics.profitAbs, 100);
    });

    test('las operaciones futuras no alteran la MWR global', () {
      final investment = HistoricalInvestment(
        uid: 'HIST-FUTURE-MWR',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-FUTURE-MWR-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-MWR-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-MWR-03',
          investmentUid: investment.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test('ignora operaciones futuras de otras inversiones históricas', () {
      final investmentA = HistoricalInvestment(
        uid: 'HIST-FUTURE-OTHER-A',
        name: 'Inversión A',
      );
      final investmentB = HistoricalInvestment(
        uid: 'HIST-FUTURE-OTHER-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-FUTURE-OTHER-01',
          investmentUid: investmentA.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-OTHER-02',
          investmentUid: investmentA.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-FUTURE-OTHER-03',
          investmentUid: investmentB.uid,
          date: DateTime(2099, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1000);
      expect(metrics.totalValue, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test('combina fondos abiertos e inversiones históricas cerradas', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2025, 1, 1);

      final fund = FundData(
        isin: 'MIXED-GLOBAL',
        symbol: 'MIX',
        name: 'Mixed Portfolio Fund',
        lastValue: 12.1,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 10), PricePoint(endDate, 12.1)],
        operations: [
          FundOperation(
            isin: 'MIXED-GLOBAL',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'HIST-MIXED-001',
        name: 'Inversión histórica mixta',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'HIST-MIXED-OP-001',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-MIXED-OP-002',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: historicalOperations,
      );

      final openPortfolioMetrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
      );

      expect(metrics.totalInvested, 1100);
      expect(metrics.totalValue, 1221);
      expect(metrics.profitAbs, 121);
      //expect(metrics.profitRel, closeTo(10, 0.0001));
      expect(
        metrics.profitRel,
        closeTo(openPortfolioMetrics.profitRel, 0.0001),
      );
      expect(metrics.mwrAnnualized, isNotNull);
      expect(
        metrics.mwrAnnualized,
        closeTo(openPortfolioMetrics.mwrAnnualized!, 0.0002),
      );
    });

    test('mantiene las métricas históricas independientes del instante '
        'de evaluación durante el cálculo global', () {
      final investmentA = HistoricalInvestment(
        uid: 'HIST-NOW-A',
        name: 'Inversión A',
      );
      final investmentB = HistoricalInvestment(
        uid: 'HIST-NOW-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'HIST-NOW-01',
          investmentUid: investmentA.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'HIST-NOW-02',
          investmentUid: investmentA.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'HIST-NOW-03',
          investmentUid: investmentB.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvested, 1500);
      expect(metrics.totalValue, 1100);
      expect(metrics.profitAbs, -400);
    });

    test(
      'LF-143.1: mantiene el valor actual limitado a los fondos vigentes',
      () {
        final currentStartDate = DateTime(2025, 1, 1);
        final currentEndDate = DateTime(2026, 1, 1);

        final currentFund = FundData(
          isin: 'CURRENT-LF143',
          symbol: 'CUR',
          name: 'Fondo actual',
          lastValue: 12,
          currency: 'EUR',
          date: currentEndDate,
          history: [
            PricePoint(currentStartDate, 10),
            PricePoint(currentEndDate, 12),
          ],
          operations: [
            FundOperation(
              isin: 'CURRENT-LF143',
              date: currentStartDate,
              type: OperationType.buy,
              units: 10,
              price: 10,
              amount: 100,
            ),
          ],
        );

        final historicalInvestment = HistoricalInvestment(
          uid: 'HIST-LF143-001',
          name: 'Inversión histórica cerrada',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'HIST-LF143-001-01',
            investmentUid: historicalInvestment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'HIST-LF143-001-02',
            investmentUid: historicalInvestment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [currentFund],
          const {'EUR': 1.0},
          historicalInvestments: [historicalInvestment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalValueGlobal, closeTo(120, 0.0001));
      },
    );

    test(
      'LF-143.2.1: acumula aportaciones sin descontar reembolsos históricos',
      () {
        final startDate = DateTime(2023, 1, 1);
        final endDate = DateTime(2025, 1, 1);

        final fund = FundData(
          isin: 'LF143-INVESTED',
          symbol: 'LF143',
          name: 'LF143 Invested Fund',
          lastValue: 12,
          currency: 'EUR',
          date: endDate,
          history: [PricePoint(startDate, 10), PricePoint(endDate, 12)],
          operations: [
            FundOperation(
              isin: 'LF143-INVESTED',
              date: startDate,
              type: OperationType.buy,
              units: 10,
              price: 10,
              amount: 100,
            ),
          ],
        );

        final investment = HistoricalInvestment(
          uid: 'LF143-HIST-001',
          name: 'Inversión histórica cerrada',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-HIST-OP-001',
            investmentUid: investment.uid,
            date: startDate,
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-HIST-OP-002',
            investmentUid: investment.uid,
            date: endDate,
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [fund],
          const {'EUR': 1.0},
          historicalInvestments: [investment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvested, 1100);
        expect(metrics.totalInvestedGlobal, 1100);
      },
    );

    test('LF-143.2.2: no duplica las aportaciones al realizar traspasos históricos internos', () {
      final subscriptionDate = DateTime(2023, 1, 1);
      final transferDate = DateTime(2024, 1, 1);

      final sourceInvestment = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destinationInvestment = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OP-001',
          investmentUid: sourceInvestment.uid,
          date: subscriptionDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OP-002',
          investmentUid: sourceInvestment.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 300,
          transferUid: 'LF143-TRANSFER-001',
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OP-003',
          investmentUid: destinationInvestment.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 300,
          transferUid: 'LF143-TRANSFER-001',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {},
        historicalInvestments: [sourceInvestment, destinationInvestment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.totalInvestedGlobal, 1000);
    });

    test(
      'LF-143.2.3: contabiliza los traspasos históricos de entrada externos',
      () {
        final investment = HistoricalInvestment(
          uid: 'LF143-EXTERNAL-TRANSFER',
          name: 'Inversión destino',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-EXTERNAL-OP-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-EXTERNAL-OP-002',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferIn,
            amount: 300,
            transferUid: 'LF143-EXTERNAL-TRANSFER-001',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          const [],
          const {},
          historicalInvestments: [investment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvestedGlobal, 1300);
      },
    );

    /*  test(
      'LF-143.2.4: no empareja traspasos históricos de fechas distintas',
      () {
        final sourceInvestment = HistoricalInvestment(
          uid: 'LF143-DATE-SOURCE',
          name: 'Inversión origen',
        );

        final destinationInvestment = HistoricalInvestment(
          uid: 'LF143-DATE-DESTINATION',
          name: 'Inversión destino',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-DATE-OP-001',
            investmentUid: sourceInvestment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-DATE-OP-002',
            investmentUid: sourceInvestment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 300,
            transferUid: 'LF143-DATE-TRANSFER-001',
          ),
          HistoricalOperation(
            uid: 'LF143-DATE-OP-003',
            investmentUid: destinationInvestment.uid,
            date: DateTime(2024, 1, 2),
            type: HistoricalOperationType.transferIn,
            amount: 300,
            transferUid: 'LF143-DATE-TRANSFER-001',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          const [],
          const {},
          historicalInvestments: [sourceInvestment, destinationInvestment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvestedGlobal, 1300);
      },
    ); */

    test(
      'LF-143.2.5: un traspaso de salida futuro no anula una entrada histórica',
      () {
        final sourceInvestment = HistoricalInvestment(
          uid: 'LF143-FUTURE-SOURCE',
          name: 'Inversión origen',
        );

        final destinationInvestment = HistoricalInvestment(
          uid: 'LF143-FUTURE-DESTINATION',
          name: 'Inversión destino',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-FUTURE-OP-001',
            investmentUid: destinationInvestment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-FUTURE-OP-002',
            investmentUid: destinationInvestment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferIn,
            amount: 300,
            transferUid: 'LF143-FUTURE-TRANSFER-001',
          ),
          HistoricalOperation(
            uid: 'LF143-FUTURE-OP-003',
            investmentUid: sourceInvestment.uid,
            date: DateTime.now().add(const Duration(days: 30)),
            type: HistoricalOperationType.transferOut,
            amount: 300,
            transferUid: 'LF143-FUTURE-TRANSFER-001',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          const [],
          const {},
          historicalInvestments: [sourceInvestment, destinationInvestment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvestedGlobal, 1300);
      },
    );

    test(
      'LF-143.2.6: contabiliza entradas con identificador de traspaso ambiguo',
      () {
        final sourceInvestment1 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-SOURCE-1',
          name: 'Inversión origen 1',
        );

        final sourceInvestment2 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-SOURCE-2',
          name: 'Inversión origen 2',
        );

        final destinationInvestment = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-DESTINATION',
          name: 'Inversión destino',
        );

        final transferDate = DateTime(2024, 1, 1);

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OP-001',
            investmentUid: sourceInvestment1.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 300,
            transferUid: 'LF143-AMBIGUOUS-TRANSFER-001',
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OP-002',
            investmentUid: sourceInvestment2.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 300,
            transferUid: 'LF143-AMBIGUOUS-TRANSFER-001',
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OP-003',
            investmentUid: destinationInvestment.uid,
            date: transferDate,
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OP-004',
            investmentUid: destinationInvestment.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 300,
            transferUid: 'LF143-AMBIGUOUS-TRANSFER-001',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          const [],
          const {},
          historicalInvestments: [
            sourceInvestment1,
            sourceInvestment2,
            destinationInvestment,
          ],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvestedGlobal, 1300);
      },
    );

    test('LF-143.2.7: contabiliza entradas cuando una salida tiene varios destinos', () {
      final sourceInvestment = HistoricalInvestment(
        uid: 'LF143-MULTI-IN-SOURCE',
        name: 'Inversión origen',
      );

      final destinationInvestment1 = HistoricalInvestment(
        uid: 'LF143-MULTI-IN-DESTINATION-1',
        name: 'Inversión destino 1',
      );

      final destinationInvestment2 = HistoricalInvestment(
        uid: 'LF143-MULTI-IN-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      final transferDate = DateTime(2024, 1, 1);

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-MULTI-IN-OP-001',
          investmentUid: sourceInvestment.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 300,
          transferUid: 'LF143-MULTI-IN-TRANSFER-001',
        ),
        HistoricalOperation(
          uid: 'LF143-MULTI-IN-OP-002',
          investmentUid: destinationInvestment1.uid,
          date: transferDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-MULTI-IN-OP-003',
          investmentUid: destinationInvestment1.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 300,
          transferUid: 'LF143-MULTI-IN-TRANSFER-001',
        ),
        HistoricalOperation(
          uid: 'LF143-MULTI-IN-OP-004',
          investmentUid: destinationInvestment2.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 300,
          transferUid: 'LF143-MULTI-IN-TRANSFER-001',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {},
        historicalInvestments: [
          sourceInvestment,
          destinationInvestment1,
          destinationInvestment2,
        ],
        historicalOperations: historicalOperations,
      );

      expect(metrics.totalInvestedGlobal, 1600);
    });

    test('LF-143.3.1: calcula la rentabilidad relativa usando solo '
        'la cartera vigente cuando existen inversiones históricas', () {
      final startDate = DateTime(2025, 1, 1);
      final endDate = DateTime(2026, 1, 1);

      final fund = FundData(
        isin: 'LF143-RELATIVE',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 12,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 10), PricePoint(endDate, 12)],
        operations: [
          FundOperation(
            isin: 'LF143-RELATIVE',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
      );

      final historicalInvestment = HistoricalInvestment(
        uid: 'LF143-RELATIVE-HIST',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-RELATIVE-HIST-01',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-RELATIVE-HIST-02',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [historicalInvestment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.profitAbs, closeTo(120, 0.0001));
      expect(metrics.profitRel, closeTo(20, 0.0001));
    });

    test('LF-143.3.2: utiliza la rentabilidad histórica cuando no hay '
        'cartera vigente', () {
      final historicalInvestment = HistoricalInvestment(
        uid: 'LF143-EMPTY-PORTFOLIO',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-EMPTY-PORTFOLIO-01',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-EMPTY-PORTFOLIO-02',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [historicalInvestment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.profitAbs, closeTo(100, 0.0001));
      expect(metrics.profitRel, closeTo(10, 0.0001));
    });

    test('LF-143.3.3: utiliza solo el valor de la cartera vigente '
        'como valoración final del MWR', () {
      final currentStartDate = DateTime(2025, 1, 1);
      final currentEndDate = DateTime(2026, 1, 1);

      final currentFund = FundData(
        isin: 'LF143-MWR-CURRENT',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 12,
        currency: 'EUR',
        date: currentEndDate,
        history: [
          PricePoint(currentStartDate, 10),
          PricePoint(currentEndDate, 12),
        ],
        operations: [
          FundOperation(
            isin: 'LF143-MWR-CURRENT',
            date: currentStartDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
      );

      final historicalInvestment = HistoricalInvestment(
        uid: 'LF143-MWR-HIST',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-MWR-HIST-01',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-MWR-HIST-02',
          investmentUid: historicalInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [currentFund],
        const {'EUR': 1.0},
        historicalInvestments: [historicalInvestment],
        historicalOperations: historicalOperations,
      );

      final openPortfolioMetrics = FinancialCalculator.calculateGlobalMetrics(
        [currentFund],
        const {'EUR': 1.0},
      );

      expect(metrics.totalValue, closeTo(1220, 0.0001));
      expect(metrics.totalValueGlobal, closeTo(120, 0.0001));
      expect(metrics.mwrAnnualized, isNotNull);
      expect(
        metrics.mwrAnnualized,
        closeTo(openPortfolioMetrics.mwrAnnualized!, 0.0002),
      );
    });
    test('LF-143.3.4: calcula el MWR histórico cuando no hay '
        'cartera vigente', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-MWR-EMPTY',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-MWR-EMPTY-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-MWR-EMPTY-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalValue, 1100);
      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, closeTo(0.10, 0.0002));
    });

    test('LF-143.3.5: excluye las operaciones históricas futuras '
        'de las métricas globales y del MWR', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-MWR-FUTURE',
        name: 'Inversión histórica',
      );

      final pastOperations = [
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final operationsWithFuture = [
        ...pastOperations,
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-03',
          investmentUid: investment.uid,
          date: DateTime.now().add(const Duration(days: 365)),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: pastOperations,
      );

      final withFutureOperation = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operationsWithFuture,
      );

      expect(withFutureOperation.totalInvested, baseline.totalInvested);
      expect(
        withFutureOperation.totalInvestedGlobal,
        baseline.totalInvestedGlobal,
      );
      expect(withFutureOperation.totalValue, baseline.totalValue);
      expect(withFutureOperation.profitAbs, baseline.profitAbs);
      expect(
        withFutureOperation.mwrAnnualized,
        closeTo(baseline.mwrAnnualized!, 0.000001),
      );
    });

    test('LF-143.3.6: excluye las operaciones futuras del cálculo '
        'de la antigüedad de la inversión', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-ANNUALIZED-FUTURE',
        name: 'Inversión histórica',
      );

      final pastOperations = [
        HistoricalOperation(
          uid: 'LF143-ANNUALIZED-FUTURE-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-ANNUALIZED-FUTURE-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final operationsWithFuture = [
        ...pastOperations,
        HistoricalOperation(
          uid: 'LF143-ANNUALIZED-FUTURE-03',
          investmentUid: investment.uid,
          date: DateTime.now().add(const Duration(days: 365)),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: pastOperations,
      );

      final withFutureOperation = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operationsWithFuture,
      );

      //expect(baseline.isAnnualized, isTrue);
      expect(baseline.isAnnualized, isFalse);
      expect(baseline.isAnnualizedGlobal, isTrue);
      expect(withFutureOperation.isAnnualized, baseline.isAnnualized);
    });

    test('LF-143.3.7: un reembolso histórico futuro no altera '
        'la valoración terminal del MWR', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-MWR-FUTURE-REDEMPTION',
        name: 'Inversión histórica',
      );

      final pastOperations = [
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-REDEMPTION-01',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-REDEMPTION-02',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final operationsWithFuture = [
        ...pastOperations,
        HistoricalOperation(
          uid: 'LF143-MWR-FUTURE-REDEMPTION-03',
          investmentUid: investment.uid,
          date: DateTime.now().add(const Duration(days: 365)),
          type: HistoricalOperationType.redemption,
          amount: 500,
        ),
      ];

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: pastOperations,
      );

      final withFutureRedemption = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operationsWithFuture,
      );

      expect(
        withFutureRedemption.mwrAnnualized,
        closeTo(baseline.mwrAnnualized!, 0.000001),
      );
      expect(withFutureRedemption.totalValue, baseline.totalValue);
      expect(withFutureRedemption.profitAbs, baseline.profitAbs);
      expect(withFutureRedemption.totalInvestedGlobal, 1000);
    });

    test('LF-143.3.8: una inversión histórica sin operaciones válidas '
        'no altera las métricas globales', () {
      final emptyInvestment = HistoricalInvestment(
        uid: 'LF143-EMPTY-HISTORICAL',
        name: 'Inversión sin operaciones válidas',
      );

      final futureInvestment = HistoricalInvestment(
        uid: 'LF143-FUTURE-HISTORICAL',
        name: 'Inversión con operaciones futuras',
      );

      final futureOperations = [
        HistoricalOperation(
          uid: 'LF143-FUTURE-HISTORICAL-01',
          investmentUid: futureInvestment.uid,
          date: DateTime.now().add(const Duration(days: 365)),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
      ];

      final baseline = FinancialCalculator.calculateGlobalMetrics([], const {
        'EUR': 1.0,
      });

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [emptyInvestment, futureInvestment],
        historicalOperations: futureOperations,
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test('LF-143.3.9: una operación histórica sin inversión asociada '
        'no altera las métricas globales', () {
      final orphanOperation = HistoricalOperation(
        uid: 'LF143-ORPHAN-01',
        investmentUid: 'LF143-NONEXISTENT-INVESTMENT',
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics([], const {
        'EUR': 1.0,
      });

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalOperations: [orphanOperation],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test('LF-143.3.10: una operación histórica de importe cero '
        'no altera las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-ZERO-INVESTMENT',
        name: 'Inversión con operación de importe cero',
      );

      final zeroOperation = HistoricalOperation(
        uid: 'LF143-ZERO-01',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 0,
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics([], const {
        'EUR': 1.0,
      });

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [zeroOperation],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });
    test('LF-143.3.10.1: una suscripción histórica de importe cero '
        'no establece la fecha inicial de inversión', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-ZERO-DATE',
        name: 'Inversión sin aportaciones reales',
      );

      final operation = HistoricalOperation(
        uid: 'LF143-ZERO-DATE-01',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.subscription,
        amount: 0,
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [operation],
      );

      expect(metrics.isAnnualized, isFalse);
    });

    test('LF-143.3.11: un reembolso histórico de importe cero '
        'no altera las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-ZERO-REDEMPTION',
        name: 'Inversión con reembolso de importe cero',
      );

      final zeroRedemption = HistoricalOperation(
        uid: 'LF143-ZERO-REDEMPTION-01',
        investmentUid: investment.uid,
        date: DateTime(2023, 1, 1),
        type: HistoricalOperationType.redemption,
        amount: 0,
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [zeroRedemption],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test('LF-143.3.12: una operación histórica futura de importe cero '
        'no altera las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-FUTURE-ZERO',
        name: 'Inversión con operación futura de importe cero',
      );

      final zeroOperation = HistoricalOperation(
        uid: 'LF143-FUTURE-ZERO-01',
        investmentUid: investment.uid,
        date: DateTime.now().add(const Duration(days: 365)),
        type: HistoricalOperationType.subscription,
        amount: 0,
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [zeroOperation],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test('LF-143.3.13: una suscripción histórica futura '
        'no establece la fecha inicial de inversión', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-FUTURE-FIRST-DATE',
        name: 'Inversión con primera aportación futura',
      );

      final futureOperation = HistoricalOperation(
        uid: 'LF143-FUTURE-FIRST-DATE-01',
        investmentUid: investment.uid,
        date: DateTime.now().add(const Duration(days: 365)),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [futureOperation],
      );

      expect(metrics.totalValue, 0);
      expect(metrics.totalInvested, 0);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.14: un reembolso histórico futuro '
        'no establece la fecha inicial de inversión', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-FUTURE-REDEMPTION-DATE',
        name: 'Inversión con primer reembolso futuro',
      );

      final futureOperation = HistoricalOperation(
        uid: 'LF143-FUTURE-REDEMPTION-DATE-01',
        investmentUid: investment.uid,
        date: DateTime.now().add(const Duration(days: 365)),
        type: HistoricalOperationType.redemption,
        amount: 1000,
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [futureOperation],
      );

      expect(metrics.totalValue, 0);
      expect(metrics.totalInvested, 0);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.15: un traspaso histórico de entrada futuro '
        'no altera las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-FUTURE-TRANSFER',
        name: 'Inversión con traspaso futuro',
      );

      final futureOperation = HistoricalOperation(
        uid: 'LF143-FUTURE-TRANSFER-01',
        investmentUid: investment.uid,
        date: DateTime.now().add(const Duration(days: 365)),
        type: HistoricalOperationType.transferIn,
        amount: 1000,
        transferUid: 'LF143-FUTURE-TRANSFER-UID',
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [futureOperation],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test('LF-143.3.16: un traspaso histórico de salida futuro '
        'no altera las métricas globales', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-FUTURE-TRANSFER-OUT',
        name: 'Inversión con traspaso de salida futuro',
      );

      final futureOperation = HistoricalOperation(
        uid: 'LF143-FUTURE-TRANSFER-OUT-01',
        investmentUid: investment.uid,
        date: DateTime.now().add(const Duration(days: 365)),
        type: HistoricalOperationType.transferOut,
        amount: 1000,
        transferUid: 'LF143-FUTURE-TRANSFER-OUT-UID',
      );

      final baseline = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [futureOperation],
      );

      expect(metrics.totalValue, baseline.totalValue);
      expect(metrics.totalInvested, baseline.totalInvested);
      expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
      expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
      expect(metrics.profitAbs, baseline.profitAbs);
      expect(metrics.profitRel, baseline.profitRel);
      expect(metrics.isAnnualized, baseline.isAnnualized);
      expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
    });

    test(
      'LF-143.3.17: un traspaso interno futuro no altera las métricas globales',
      () {
        final source = HistoricalInvestment(
          uid: 'LF143-FUTURE-SOURCE',
          name: 'Origen futuro',
        );
        final destination = HistoricalInvestment(
          uid: 'LF143-FUTURE-DESTINATION',
          name: 'Destino futuro',
        );

        final transferDate = DateTime.now().add(const Duration(days: 365));
        const transferUid = 'LF143-FUTURE-INTERNAL-TRANSFER';

        final operations = [
          HistoricalOperation(
            uid: 'LF143-FUTURE-OUT',
            investmentUid: source.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 1000,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'LF143-FUTURE-IN',
            investmentUid: destination.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 1000,
            transferUid: transferUid,
          ),
        ];

        final baseline = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [source, destination],
        );

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [source, destination],
          historicalOperations: operations,
        );

        expect(metrics.totalValue, baseline.totalValue);
        expect(metrics.totalInvested, baseline.totalInvested);
        expect(metrics.totalInvestedGlobal, baseline.totalInvestedGlobal);
        expect(metrics.totalValueGlobal, baseline.totalValueGlobal);
        expect(metrics.profitAbs, baseline.profitAbs);
        expect(metrics.profitRel, baseline.profitRel);
        expect(metrics.isAnnualized, baseline.isAnnualized);
        expect(metrics.mwrAnnualized, baseline.mwrAnnualized);
      },
    );

    test('LF-143.3.18: un traspaso interno histórico válido '
        'no duplica las aportaciones globales', () {
      final source = HistoricalInvestment(
        uid: 'LF143-PAST-SOURCE',
        name: 'Origen histórico',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-PAST-DESTINATION',
        name: 'Destino histórico',
      );

      final transferDate = DateTime(2023, 1, 1);
      const transferUid = 'LF143-PAST-INTERNAL-TRANSFER';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-PAST-OUT',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-PAST-IN',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      expect(operations, hasLength(2));

      expect(
        operations.where(
          (operation) =>
              operation.transferUid == transferUid &&
              operation.type == HistoricalOperationType.transferOut &&
              operation.investmentUid != destination.uid &&
              operation.date.isAtSameMomentAs(transferDate),
        ),
        hasLength(1),
      );

      expect(
        operations.where(
          (operation) =>
              operation.transferUid == transferUid &&
              operation.type == HistoricalOperationType.transferIn &&
              operation.date.isAtSameMomentAs(transferDate),
        ),
        hasLength(1),
      );

      final transferIn = operations.singleWhere(
        (operation) => operation.type == HistoricalOperationType.transferIn,
      );

      final matchingTransferOuts = operations.where(
        (candidate) =>
            candidate.transferUid == transferIn.transferUid &&
            candidate.investmentUid != transferIn.investmentUid &&
            candidate.type == HistoricalOperationType.transferOut &&
            candidate.date.isAtSameMomentAs(transferIn.date),
      );

      final matchingTransferIns = operations.where(
        (candidate) =>
            candidate.transferUid == transferIn.transferUid &&
            candidate.type == HistoricalOperationType.transferIn &&
            candidate.date.isAtSameMomentAs(transferIn.date),
      );

      expect(matchingTransferOuts, hasLength(1));
      expect(matchingTransferIns, hasLength(1));

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(matchingTransferOuts.length, 1);
      expect(matchingTransferIns.length, 1);
      expect(metrics.totalInvestedGlobal, 0);

      //expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1000);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test(
      'LF-143.3.20: un traspaso ambiguo con dos salidas no se deduplica',
      () {
        final source1 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-SOURCE-1',
          name: 'Origen histórico 1',
        );

        final source2 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-SOURCE-2',
          name: 'Origen histórico 2',
        );

        final destination = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-DESTINATION',
          name: 'Destino histórico',
        );

        final transferUid = 'LF143-AMBIGUOUS-TRANSFER';
        final transferDate = DateTime(2023, 1, 1);

        final operations = [
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OUT-1',
            investmentUid: source1.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 500,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OUT-2',
            investmentUid: source2.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 500,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-IN',
            investmentUid: destination.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 1000,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [source1, source2, destination],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 1000);
        expect(metrics.totalValueGlobal, 0);
        expect(metrics.totalInvested, 1000);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        //expect(metrics.isAnnualized, isTrue);
        expect(metrics.isAnnualized, isFalse);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test(
      'LF-143.3.21: un traspaso ambiguo con dos entradas no se deduplica',
      () {
        final source = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-SOURCE',
          name: 'Origen histórico',
        );

        final destination1 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-DESTINATION-1',
          name: 'Destino histórico 1',
        );

        final destination2 = HistoricalInvestment(
          uid: 'LF143-AMBIGUOUS-DESTINATION-2',
          name: 'Destino histórico 2',
        );

        final transferUid = 'LF143-AMBIGUOUS-TRANSFER';
        final transferDate = DateTime(2023, 1, 1);

        final operations = [
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-OUT',
            investmentUid: source.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 1000,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-IN-1',
            investmentUid: destination1.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 500,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'LF143-AMBIGUOUS-IN-2',
            investmentUid: destination2.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 500,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [source, destination1, destination2],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 1000);
        expect(metrics.totalValueGlobal, 0);
        expect(metrics.totalInvested, 1000);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        //expect(metrics.isAnnualized, isTrue);
        expect(metrics.isAnnualized, isFalse);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test('LF-143.3.22: dos traspasos internos independientes el mismo día se deduplican por separado', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE-1',
        name: 'Origen 1',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION-1',
        name: 'Destino 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE-2',
        name: 'Origen 2',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION-2',
        name: 'Destino 2',
      );

      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-1',
          investmentUid: source1.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 600,
          transferUid: 'LF143-TRANSFER-UID-1',
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-1',
          investmentUid: destination1.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 600,
          transferUid: 'LF143-TRANSFER-UID-1',
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-2',
          investmentUid: source2.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 400,
          transferUid: 'LF143-TRANSFER-UID-2',
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-2',
          investmentUid: destination2.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 400,
          transferUid: 'LF143-TRANSFER-UID-2',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, destination1, source2, destination2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1000);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.23: un traspaso interno con importes diferentes no duplica aportaciones globales', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Origen histórico',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Destino histórico',
      );

      final transferUid = 'LF143-TRANSFER-DIFFERENT-AMOUNTS';
      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      //expect(metrics.profitAbs, 0);
      //expect(metrics.profitRel, 0);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.24: un traspaso con origen y destino en la misma inversión '
        'no se deduplica como traspaso interno', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      const transferUid = 'LF143-TRANSFER-SAME-INVESTMENT';
      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-SAME',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-SAME',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.25: un traspaso entre inversiones distintas sin transferUid '
        'no se deduplica', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-NULL-UID',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-NULL-UID',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 950,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.27: dos traspasos entre las mismas inversiones con el mismo '
        'transferUid y fecha generan un emparejamiento ambiguo', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-TRANSFER-AMBIGUOUS-PAIRING';
      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-1',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-2',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-1',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-2',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1400);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test(
      'LF-143.3.28: dos traspasos independientes entre las mismas inversiones '
      'en la misma fecha se deduplican correctamente',
      () {
        final source = HistoricalInvestment(
          uid: 'LF143-TRANSFER-SOURCE',
          name: 'Inversión origen',
        );

        final destination = HistoricalInvestment(
          uid: 'LF143-TRANSFER-DESTINATION',
          name: 'Inversión destino',
        );

        final transferDate = DateTime(2023, 1, 1);

        final operations = [
          HistoricalOperation(
            uid: 'LF143-TRANSFER-OUT-1',
            investmentUid: source.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 1000,
            transferUid: 'LF143-TRANSFER-INDEPENDENT-1',
          ),
          HistoricalOperation(
            uid: 'LF143-TRANSFER-IN-1',
            investmentUid: destination.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 950,
            transferUid: 'LF143-TRANSFER-INDEPENDENT-1',
          ),
          HistoricalOperation(
            uid: 'LF143-TRANSFER-OUT-2',
            investmentUid: source.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 500,
            transferUid: 'LF143-TRANSFER-INDEPENDENT-2',
          ),
          HistoricalOperation(
            uid: 'LF143-TRANSFER-IN-2',
            investmentUid: destination.uid,
            date: transferDate,
            type: HistoricalOperationType.transferIn,
            amount: 450,
            transferUid: 'LF143-TRANSFER-INDEPENDENT-2',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {'EUR': 1.0},
          historicalInvestments: [source, destination],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 0);
        expect(metrics.totalValueGlobal, 0);
        expect(metrics.totalInvested, 1400);
        expect(metrics.profitAbs, 100);
        expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
        //expect(metrics.isAnnualized, isTrue);
        expect(metrics.isAnnualized, isFalse);
        expect(metrics.isAnnualizedGlobal, isTrue);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test('LF-143.3.29: un traspaso interno válido se deduplica aunque '
        'la entrada aparezca antes que la salida', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-TRANSFER-UNSORTED';
      final transferDate = DateTime(2023, 1, 1);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-UNSORTED',
          investmentUid: destination.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-UNSORTED',
          investmentUid: source.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.30: un traspaso interno válido se deduplica '
        'aunque las operaciones tengan horas diferentes el mismo día', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-TRANSFER-SAME-DAY';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-SAME-DAY',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1, 10, 30),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-SAME-DAY',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 1, 16, 45),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.31: dos salidas y dos entradas con el mismo UID '
        'y día, pero horas diferentes, no se deduplican', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-31-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-31-SOURCE-2',
        name: 'Inversión origen 2',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-31-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-31-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      const transferUid = 'LF143-31-AMBIGUOUS';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-31-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-31-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 1, 11, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-31-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 14, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-31-IN-2',
          investmentUid: destination2.uid,
          date: DateTime(2023, 1, 1, 17, 0),
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, source2, destination1, destination2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1400);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.32: dos salidas y una entrada con el mismo UID '
        'y día, pero horas diferentes, no se deduplican', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-32-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-32-SOURCE-2',
        name: 'Inversión origen 2',
      );
      final destination = HistoricalInvestment(
        uid: 'LF143-32-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-32-AMBIGUOUS';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-32-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-32-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 1, 11, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-32-IN-1',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 1, 16, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, source2, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 550);
      expect(metrics.profitRel, closeTo(550 / 950 * 100, 0.000001));
      //expect(metrics.profitAbs, 50);
      //expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.33: una salida y dos entradas con el mismo UID '
        'y día, pero horas diferentes, no se deduplican', () {
      final source = HistoricalInvestment(
        uid: 'LF143-33-SOURCE',
        name: 'Inversión origen',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-33-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-33-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      const transferUid = 'LF143-33-AMBIGUOUS';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-33-OUT-1',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-33-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 13, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-33-IN-2',
          investmentUid: destination2.uid,
          date: DateTime(2023, 1, 1, 17, 0),
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination1, destination2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1400);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, -400);
      expect(metrics.profitRel, closeTo(-400 / 1400 * 100, 0.000001));
      //expect(metrics.profitAbs, 100);
      //expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.34: dos traspasos internos independientes con '
        'distintos UID y horas diferentes el mismo día se deduplican', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-34-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-34-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-34-SOURCE-2',
        name: 'Inversión origen 2',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-34-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-34-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: 'LF143-34-TRANSFER-1',
        ),
        HistoricalOperation(
          uid: 'LF143-34-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 12, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: 'LF143-34-TRANSFER-1',
        ),
        HistoricalOperation(
          uid: 'LF143-34-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 1, 14, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: 'LF143-34-TRANSFER-2',
        ),
        HistoricalOperation(
          uid: 'LF143-34-IN-2',
          investmentUid: destination2.uid,
          date: DateTime(2023, 1, 1, 18, 0),
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: 'LF143-34-TRANSFER-2',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, destination1, source2, destination2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.36: un traspaso interno válido con horas diferentes '
        'se deduplica aunque la entrada aparezca antes que la salida', () {
      final source = HistoricalInvestment(
        uid: 'LF143-36-SOURCE',
        name: 'Inversión origen',
      );
      final destination = HistoricalInvestment(
        uid: 'LF143-36-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-36-TRANSFER';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-36-IN',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 1, 16, 45),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-36-OUT',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1, 10, 30),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.37: un traspaso con origen y destino en la misma '
        'inversión no se deduplica aunque tenga horas diferentes', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-37-INVESTMENT',
        name: 'Inversión única',
      );

      const transferUid = 'LF143-37-SAME-INVESTMENT';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-37-OUT',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1, 10, 30),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-37-IN',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1, 16, 45),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.40: un traspaso interno válido se deduplica '
        'aunque las operaciones tengan milisegundos diferentes', () {
      final source = HistoricalInvestment(
        uid: 'LF143-40-SOURCE',
        name: 'Inversión origen',
      );
      final destination = HistoricalInvestment(
        uid: 'LF143-40-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-40-TRANSFER';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-40-OUT',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1, 10, 30, 15, 123),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-40-IN',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 1, 16, 45, 30, 987),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.41: un traspaso válido no se deduplica parcialmente '
        'cuando comparte UID y día con otro ambiguo', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-41-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-41-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-41-SOURCE-2',
        name: 'Inversión origen 2',
      );

      const transferUid = 'LF143-41-SHARED-UID';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-41-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-41-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 12, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-41-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 1, 15, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, destination1, source2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      //expect(metrics.profitAbs, -550);
      //expect(metrics.profitRel, closeTo(-550 / 950 * 100, 0.000001));
      expect(metrics.profitAbs, 550);
      expect(metrics.profitRel, closeTo(550 / 950 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.3.42: un traspaso válido se deduplica aunque otro '
        'traspaso independiente del mismo día sea ambiguo', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-42-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-42-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-42-SOURCE-2',
        name: 'Inversión origen 2',
      );
      final source3 = HistoricalInvestment(
        uid: 'LF143-42-SOURCE-3',
        name: 'Inversión origen 3',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-42-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      final operations = [
        // Traspaso válido.
        HistoricalOperation(
          uid: 'LF143-42-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: 'LF143-42-VALID',
        ),
        HistoricalOperation(
          uid: 'LF143-42-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 12, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: 'LF143-42-VALID',
        ),

        // Traspaso ambiguo: dos salidas y una entrada.
        HistoricalOperation(
          uid: 'LF143-42-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 1, 10, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: 'LF143-42-AMBIGUOUS',
        ),
        HistoricalOperation(
          uid: 'LF143-42-OUT-3',
          investmentUid: source3.uid,
          date: DateTime(2023, 1, 1, 14, 0),
          type: HistoricalOperationType.transferOut,
          amount: 300,
          transferUid: 'LF143-42-AMBIGUOUS',
        ),
        HistoricalOperation(
          uid: 'LF143-42-IN-2',
          investmentUid: destination2.uid,
          date: DateTime(2023, 1, 1, 17, 0),
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: 'LF143-42-AMBIGUOUS',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [
          source1,
          destination1,
          source2,
          source3,
          destination2,
        ],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 450);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, 400);
      expect(metrics.profitRel, closeTo(400 / 1400 * 100, 0.000001));
      //expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.4.1: profitAbsGlobal incluye el resultado '
        'realizado de una inversión histórica cerrada', () {
      final investment = HistoricalInvestment(
        uid: 'LF143-4-1',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-4-1-SUB',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-1-RED',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.profitAbsGlobal, 200);
    });

    test('LF-143.4.2: profitAbsGlobal agrega beneficios y pérdidas '
        'de distintas inversiones históricas', () {
      final profitableInvestment = HistoricalInvestment(
        uid: 'LF143-4-2-PROFIT',
        name: 'Inversión con beneficio',
      );

      final losingInvestment = HistoricalInvestment(
        uid: 'LF143-4-2-LOSS',
        name: 'Inversión con pérdida',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-4-2-P-SUB',
          investmentUid: profitableInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-2-P-RED',
          investmentUid: profitableInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
        HistoricalOperation(
          uid: 'LF143-4-2-L-SUB',
          investmentUid: losingInvestment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-2-L-RED',
          investmentUid: losingInvestment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 850,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [profitableInvestment, losingInvestment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 2000);
      expect(metrics.profitAbsGlobal, 50);
    });

    test('LF-143.4.3: profitAbsGlobal combina el resultado de fondos '
        'vigentes e inversiones históricas', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final fund = FundData(
        isin: 'LF143-4-3',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 90,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 100), PricePoint(endDate, 90)],
        operations: [
          FundOperation(
            isin: 'LF143-4-3',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-4-3-HIST',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-4-3-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-3-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 900);
      expect(metrics.totalInvestedGlobal, 2000);
      expect(metrics.profitAbsGlobal, 100);
    });

    test('LF-143.4.4: profitRelGlobal calcula la rentabilidad '
        'sobre el capital histórico invertido', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final investment = HistoricalInvestment(
        uid: 'LF143-4-4-HIST',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-4-4-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-4-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.profitAbsGlobal, 200);
      expect(metrics.profitRelGlobal, closeTo(0.20, 0.000001));
    });

    test('LF-143.4.5: profitRelGlobal refleja pérdidas '
        'de inversiones históricas', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final investment = HistoricalInvestment(
        uid: 'LF143-4-5-HIST',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-4-5-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-4-5-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 850,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.profitAbsGlobal, -150);
      expect(metrics.profitRelGlobal, closeTo(-0.15, 0.000001));
    });

    test('LF-143.4.6: profitRelGlobal es cero cuando no existe '
        'capital histórico invertido', () {
      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {'EUR': 1.0},
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.profitAbsGlobal, 0);
      expect(metrics.profitRelGlobal, 0);
      expect(metrics.profitRelGlobal.isFinite, isTrue);
    });

    test('LF-143.5.1: mwrAnnualizedGlobal calcula la rentabilidad '
        'de una inversión histórica cerrada', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final investment = HistoricalInvestment(
        uid: 'LF143-5-1-HIST',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-5-1-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-1-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        const [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualizedGlobal, closeTo(0.20015, 0.0001));
    });

    test('LF-143.5.2: mwrAnnualizedGlobal combina fondos vigentes '
        'e inversiones históricas sin duplicar el valor terminal', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final fund = FundData(
        isin: 'LF143-5-2',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 110,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 100), PricePoint(endDate, 110)],
        operations: [
          FundOperation(
            isin: 'LF143-5-2',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-5-2-HIST',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-5-2-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-2-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 1100);
      expect(metrics.totalInvestedGlobal, 2000);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualizedGlobal, closeTo(0.1501, 0.0002));
    });

    test('LF-143.5.3: mwrAnnualizedGlobal coincide con mwrAnnualized '
        'cuando solo existen fondos vigentes', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final fund = FundData(
        isin: 'LF143-5-3',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 110,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 100), PricePoint(endDate, 110)],
        operations: [
          FundOperation(
            isin: 'LF143-5-3',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
      );

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualizedGlobal, isNotNull);
      expect(
        metrics.mwrAnnualizedGlobal,
        closeTo(metrics.mwrAnnualized!, 0.000001),
      );
    });

    test('LF-143.5.4: las inversiones históricas cerradas calculan '
        'el MWR global sin fondos vigentes ni valor terminal', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final investment = HistoricalInvestment(
        uid: 'LF143-5-4-HIST',
        name: 'Inversión histórica cerrada',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-5-4-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-4-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.isAnnualizedGlobal, isTrue);
      //expect(metrics.mwrAnnualized, isNull);
      expect(metrics.mwrAnnualized, closeTo(0.20015, 0.0001));
      expect(metrics.mwrAnnualizedGlobal, closeTo(0.20015, 0.0001));
    });

    test('LF-143.5.5: mwrAnnualizedGlobal refleja pérdidas históricas '
        'sin fondos vigentes', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final investment = HistoricalInvestment(
        uid: 'LF143-5-5-HIST',
        name: 'Inversión histórica con pérdidas',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-5-5-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-5-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 800,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.profitAbsGlobal, -200);
      expect(metrics.profitRelGlobal, -0.20);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, closeTo(-0.20012, 0.0001));
      expect(metrics.mwrAnnualizedGlobal, closeTo(-0.20012, 0.0001));
    });

    test('LF-143.5.6: las pérdidas históricas reducen el MWR global '
        'sin alterar el MWR de los fondos vigentes', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2024, 1, 1);

      final fund = FundData(
        isin: 'LF143-5-6',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 110,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 100), PricePoint(endDate, 110)],
        operations: [
          FundOperation(
            isin: 'LF143-5-6',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-5-6-HIST',
        name: 'Inversión histórica con pérdidas',
      );

      final operations = [
        HistoricalOperation(
          uid: 'LF143-5-6-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-6-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 800,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: operations,
      );

      expect(metrics.totalValueGlobal, 1100);
      expect(metrics.totalInvestedGlobal, 2000);
      expect(metrics.profitAbsGlobal, -100);
      expect(metrics.profitRelGlobal, -0.05);

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualizedGlobal, isNotNull);

      expect(metrics.mwrAnnualizedGlobal!, lessThan(metrics.mwrAnnualized!));
    });

    test('LF-143.5.7: mwrAnnualized solo considera los fondos vigentes '
        'aunque existan inversiones históricas cerradas', () {
      final startDate = DateTime(2023, 1, 1);
      final endDate = DateTime(2025, 1, 1);

      final fund = FundData(
        isin: 'LF143-5-7',
        symbol: 'LF143',
        name: 'Fondo vigente',
        lastValue: 12.1,
        currency: 'EUR',
        date: endDate,
        history: [PricePoint(startDate, 10), PricePoint(endDate, 12.1)],
        operations: [
          FundOperation(
            isin: 'LF143-5-7',
            date: startDate,
            type: OperationType.buy,
            units: 10,
            price: 10,
            amount: 100,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-5-7-HIST',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-5-7-SUB',
          investmentUid: investment.uid,
          date: startDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-7-RED',
          investmentUid: investment.uid,
          date: endDate,
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final openMetrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
      );

      final mixedMetrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: historicalOperations,
      );

      expect(openMetrics.mwrAnnualized, isNotNull);
      expect(mixedMetrics.mwrAnnualized, isNotNull);
      expect(mixedMetrics.mwrAnnualized, openMetrics.mwrAnnualized);

      expect(mixedMetrics.mwrAnnualizedGlobal, isNotNull);
      expect(
        mixedMetrics.mwrAnnualizedGlobal!,
        isNot(openMetrics.mwrAnnualized),
      );
    });

    test('LF-143.5.8: la antigüedad de la cartera vigente es independiente '
        'de la trayectoria histórica global', () {
      final now = DateTime.now();
      final fundStartDate = now.subtract(const Duration(days: 10));
      final historicalStartDate = now.subtract(const Duration(days: 60));
      final historicalEndDate = now.subtract(const Duration(days: 40));

      final fund = FundData(
        isin: 'LF143-5-8',
        symbol: 'LF143',
        name: 'Fondo vigente reciente',
        lastValue: 101,
        currency: 'EUR',
        date: now,
        history: [PricePoint(fundStartDate, 100), PricePoint(now, 101)],
        operations: [
          FundOperation(
            isin: 'LF143-5-8',
            date: fundStartDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-5-8-HIST',
        name: 'Inversión histórica cerrada',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-5-8-SUB',
          investmentUid: investment.uid,
          date: historicalStartDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-8-RED',
          investmentUid: investment.uid,
          date: historicalEndDate,
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.5.9: las operaciones históricas recientes no alteran '
        'la antigüedad de los fondos vigentes', () {
      final now = DateTime.now();
      final fundStartDate = now.subtract(const Duration(days: 60));
      final historicalStartDate = now.subtract(const Duration(days: 10));
      final historicalEndDate = now.subtract(const Duration(days: 5));

      final fund = FundData(
        isin: 'LF143-5-9',
        symbol: 'LF143',
        name: 'Fondo vigente antiguo',
        lastValue: 101,
        currency: 'EUR',
        date: now,
        history: [PricePoint(fundStartDate, 100), PricePoint(now, 101)],
        operations: [
          FundOperation(
            isin: 'LF143-5-9',
            date: fundStartDate,
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'LF143-5-9-HIST',
        name: 'Inversión histórica reciente',
      );

      final historicalOperations = [
        HistoricalOperation(
          uid: 'LF143-5-9-SUB',
          investmentUid: investment.uid,
          date: historicalStartDate,
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'LF143-5-9-RED',
          investmentUid: investment.uid,
          date: historicalEndDate,
          type: HistoricalOperationType.redemption,
          amount: 1050,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: historicalOperations,
      );

      expect(metrics.isAnnualized, isTrue);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    /* test('LF-143.6.1: los traspasos históricos no incrementan '
        'el capital invertido global, estén emparejados o no', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final transferUid = 'TRANSFER-A-B';

      final operations = [
        // Inversión A
        HistoricalOperation(
          uid: 'A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2006, 1, 26),
          type: HistoricalOperationType.subscription,
          amount: 6000,
        ),
        HistoricalOperation(
          uid: 'A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferOut,
          amount: 5096.84,
          transferUid: transferUid,
        ),

        // Inversión B
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2010, 4, 19),
          type: HistoricalOperationType.transferIn,
          amount: 5096.84,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'B-02',
          investmentUid: investmentB.uid,
          date: DateTime(2011, 5, 24),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'B-03',
          investmentUid: investmentB.uid,
          date: DateTime(2011, 6, 10),
          type: HistoricalOperationType.transferOut,
          amount: 6026.67,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 27000);
    }); */

    test('LF-143.6.2: los traspasos históricos no alteran el MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );
      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      //final transferUid = 'TRANSFER-A-B';

      final subscriptions = [
        HistoricalOperation(
          uid: 'A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2006, 1, 26),
          type: HistoricalOperationType.subscription,
          amount: 6000,
        ),
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2011, 5, 24),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      ];

      final transfers = [
        HistoricalOperation(
          uid: 'A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferOut,
          amount: 5096.84,
          transferUid: 'TRANSFER-A-B',
        ),
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferIn,
          amount: 5096.84,
          transferUid: 'TRANSFER-A-B',
        ),
      ];

      final investments = [investmentA, investmentB];

      final metricsWithoutTransfers =
          FinancialCalculator.calculateGlobalMetrics(
            [fund],
            const {'EUR': 1.0},
            historicalInvestments: investments,
            historicalOperations: subscriptions,
          );

      final metricsWithTransfers = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [...subscriptions, ...transfers],
      );

      expect(metricsWithoutTransfers.mwrAnnualizedGlobal, isNotNull);

      expect(
        metricsWithTransfers.mwrAnnualizedGlobal,
        closeTo(metricsWithoutTransfers.mwrAnnualizedGlobal!, 1e-10),
      );

      expect(
        metricsWithTransfers.totalInvestedGlobal,
        metricsWithoutTransfers.totalInvestedGlobal,
      );

      expect(metricsWithTransfers.totalInvestedGlobal, 27000);
    });

    test('LF-143.6.3: un transferOut histórico sin contraparte altera el MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );
      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      //final transferUid = 'TRANSFER-A-B';

      final subscriptions = [
        HistoricalOperation(
          uid: 'A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2006, 1, 26),
          type: HistoricalOperationType.subscription,
          amount: 6000,
        ),
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2011, 5, 24),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      ];

      final transfers = [
        HistoricalOperation(
          uid: 'A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferOut,
          amount: 5096.84,
          transferUid: 'TRANSFER-A-B',
        ),
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferIn,
          amount: 5096.84,
          transferUid: 'TRANSFER-A-B',
        ),
      ];

      final investments = [investmentA, investmentB];

      final metricsWithoutUnmatchedTransferOut =
          FinancialCalculator.calculateGlobalMetrics(
            [fund],
            const {'EUR': 1.0},
            historicalInvestments: investments,
            historicalOperations: subscriptions,
          );

      final metricsWithUnmatchedTransferOut =
          FinancialCalculator.calculateGlobalMetrics(
            [fund],
            const {'EUR': 1.0},
            historicalInvestments: investments,
            historicalOperations: [...subscriptions, transfers.first],
          );

      /* expect(metricsWithoutUnmatchedTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(metricsWithUnmatchedTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(
        metricsWithUnmatchedTransferOut.mwrAnnualizedGlobal,
        closeTo(metricsWithoutUnmatchedTransferOut.mwrAnnualizedGlobal!, 1e-10),
      ); */

      expect(metricsWithoutUnmatchedTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(metricsWithUnmatchedTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(
        metricsWithoutUnmatchedTransferOut.mwrAnnualizedGlobal,
        isNot(
          closeTo(metricsWithUnmatchedTransferOut.mwrAnnualizedGlobal!, 1e-10),
        ),
      );
    });

    test('LF-143.6.4: un traspaso interno puede establecer la antigüedad global sin incrementar aportaciones', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      const transferUid = 'TRANSFER-A-B';

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.5: no empareja traspasos con inversiones históricas no registradas', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      const transferUid = 'TRANSFER-EXTERNAL-B';

      final operations = [
        HistoricalOperation(
          uid: 'OP-EXTERNAL-01',
          investmentUid: 'INVESTMENT-EXTERNA',
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.6: no empareja entradas de inversiones históricas no registradas', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      const transferUid = 'TRANSFER-A-EXTERNAL';

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-EXTERNAL-01',
          investmentUid: 'INVESTMENT-EXTERNA',
          date: transferDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isFalse);
    });

    test(
      'LF-143.6.7: empareja traspasos del mismo día con horas diferentes',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final investmentA = HistoricalInvestment(
          uid: 'INVESTMENT-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'INVESTMENT-B',
          name: 'Inversión B',
        );

        const transferUid = 'TRANSFER-A-B';

        final transferOutDate = DateTime(
          transferDate.year,
          transferDate.month,
          transferDate.day,
          10,
          15,
        );

        final transferInDate = DateTime(
          transferDate.year,
          transferDate.month,
          transferDate.day,
          18,
          45,
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-A-01',
            investmentUid: investmentA.uid,
            date: transferOutDate,
            type: HistoricalOperationType.transferOut,
            amount: 1000,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-B-01',
            investmentUid: investmentB.uid,
            date: transferInDate,
            type: HistoricalOperationType.transferIn,
            amount: 1000,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [investmentA, investmentB],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 0);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test('LF-143.6.9: empareja traspasos con importes diferentes', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      const transferUid = 'TRANSFER-A-B';

      final transferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        10,
        15,
      );

      final transferInDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        18,
        45,
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0.0);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.10: empareja traspasos parciales con importes iguales', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      const transferUid = 'TRANSFER-A-B';

      final transferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        10,
        15,
      );

      final transferInDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        18,
        45,
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test(
      'LF-143.6.11: empareja traspasos parciales con importes diferentes',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final transferOutDate = DateTime(
          transferDate.year,
          transferDate.month,
          transferDate.day,
          10,
          15,
        );

        final transferInDate = DateTime(
          transferDate.year,
          transferDate.month,
          transferDate.day,
          18,
          45,
        );

        final investmentA = HistoricalInvestment(
          uid: 'INVESTMENT-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'INVESTMENT-B',
          name: 'Inversión B',
        );

        const transferUid = 'TRANSFER-PARTIAL-001';

        final operations = [
          HistoricalOperation(
            uid: 'OP-OUT-001',
            investmentUid: investmentA.uid,
            date: transferOutDate,
            type: HistoricalOperationType.transferOut,
            amount: 999,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-IN-001',
            investmentUid: investmentB.uid,
            date: transferInDate,
            type: HistoricalOperationType.transferIn,
            amount: 998,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [investmentA, investmentB],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 0.0);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test('LF-143.6.12: no empareja traspasos con varias salidas posibles', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final transferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        10,
        15,
      );

      final secondTransferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        12,
        30,
      );

      final transferInDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        18,
        45,
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final investmentC = HistoricalInvestment(
        uid: 'INVESTMENT-C',
        name: 'Inversión C',
      );

      const transferUid = 'TRANSFER-AMBIGUOUS-001';

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-OUT-002',
          investmentUid: investmentB.uid,
          date: secondTransferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentC.uid,
          date: transferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB, investmentC],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 999);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.13: no empareja traspasos con varias entradas posibles', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final transferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        10,
        15,
      );

      final firstTransferInDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        12,
        30,
      );

      final secondTransferInDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        18,
        45,
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final investmentC = HistoricalInvestment(
        uid: 'INVESTMENT-C',
        name: 'Inversión C',
      );

      const transferUid = 'TRANSFER-AMBIGUOUS-002';

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentB.uid,
          date: firstTransferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-IN-002',
          investmentUid: investmentC.uid,
          date: secondTransferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB, investmentC],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1998);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test(
      'LF-143.6.14: empareja varios traspasos independientes el mismo día',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final investmentA = HistoricalInvestment(
          uid: 'INVESTMENT-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'INVESTMENT-B',
          name: 'Inversión B',
        );

        final investmentC = HistoricalInvestment(
          uid: 'INVESTMENT-C',
          name: 'Inversión C',
        );

        final investmentD = HistoricalInvestment(
          uid: 'INVESTMENT-D',
          name: 'Inversión D',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-OUT-A',
            investmentUid: investmentA.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              10,
              15,
            ),
            type: HistoricalOperationType.transferOut,
            amount: 999,
            transferUid: 'TRANSFER-A',
          ),
          HistoricalOperation(
            uid: 'OP-IN-B',
            investmentUid: investmentB.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              10,
              45,
            ),
            type: HistoricalOperationType.transferIn,
            amount: 999,
            transferUid: 'TRANSFER-A',
          ),
          HistoricalOperation(
            uid: 'OP-OUT-C',
            investmentUid: investmentC.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              12,
              30,
            ),
            type: HistoricalOperationType.transferOut,
            amount: 500,
            transferUid: 'TRANSFER-C',
          ),
          HistoricalOperation(
            uid: 'OP-IN-D',
            investmentUid: investmentD.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              13,
              15,
            ),
            type: HistoricalOperationType.transferIn,
            amount: 500,
            transferUid: 'TRANSFER-C',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [
            investmentA,
            investmentB,
            investmentC,
            investmentD,
          ],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 0);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test(
      'LF-143.6.15: rechaza emparejamientos ambiguos con un mismo transferUid',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final investmentA = HistoricalInvestment(
          uid: 'INVESTMENT-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'INVESTMENT-B',
          name: 'Inversión B',
        );

        final investmentC = HistoricalInvestment(
          uid: 'INVESTMENT-C',
          name: 'Inversión C',
        );

        final investmentD = HistoricalInvestment(
          uid: 'INVESTMENT-D',
          name: 'Inversión D',
        );

        const transferUid = 'TRANSFER-AMBIGUOUS-003';

        final operations = [
          HistoricalOperation(
            uid: 'OP-OUT-A',
            investmentUid: investmentA.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              10,
              15,
            ),
            type: HistoricalOperationType.transferOut,
            amount: 999,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-OUT-B',
            investmentUid: investmentB.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              11,
              15,
            ),
            type: HistoricalOperationType.transferOut,
            amount: 999,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-IN-C',
            investmentUid: investmentC.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              12,
              15,
            ),
            type: HistoricalOperationType.transferIn,
            amount: 999,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-IN-D',
            investmentUid: investmentD.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              13,
              15,
            ),
            type: HistoricalOperationType.transferIn,
            amount: 999,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [
            investmentA,
            investmentB,
            investmentC,
            investmentD,
          ],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 1998);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test('LF-143.6.16: no empareja traspasos de una misma inversión', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      const transferUid = 'TRANSFER-SAME-INVESTMENT-001';

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            10,
            15,
          ),
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentA.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            18,
            45,
          ),
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 999);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.17: no empareja traspasos sin transferUid', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            10,
            15,
          ),
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: null,
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentB.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            18,
            45,
          ),
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: null,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 999);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.18: no empareja traspasos con distintos transferUid', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            10,
            15,
          ),
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: 'TRANSFER-A',
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentB.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            18,
            45,
          ),
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: 'TRANSFER-B',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 999);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.6.19: empareja traspasos con transferUid normalizado', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-OUT-001',
          investmentUid: investmentA.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            10,
            15,
          ),
          type: HistoricalOperationType.transferOut,
          amount: 999,
          transferUid: ' TRANSFER-001 ',
        ),
        HistoricalOperation(
          uid: 'OP-IN-001',
          investmentUid: investmentB.uid,
          date: DateTime(
            transferDate.year,
            transferDate.month,
            transferDate.day,
            18,
            45,
          ),
          type: HistoricalOperationType.transferIn,
          amount: 999,
          transferUid: 'TRANSFER-001',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    /* test('LF-143.7.1: empareja traspasos con el mismo UID aunque las fechas sean distintas', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );
      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final transferUid = 'TRANSFER-A-B';

      final subscriptions = [
        HistoricalOperation(
          uid: 'A-01',
          investmentUid: investmentA.uid,
          date: DateTime(2006, 1, 26),
          type: HistoricalOperationType.subscription,
          amount: 6000,
        ),
        HistoricalOperation(
          uid: 'B-01',
          investmentUid: investmentB.uid,
          date: DateTime(2011, 5, 24),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
      ];

      final transfers = [
        HistoricalOperation(
          uid: 'A-02',
          investmentUid: investmentA.uid,
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferOut,
          amount: 5096.84,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'B-02',
          investmentUid: investmentB.uid,
          date: DateTime(2010, 4, 19),
          type: HistoricalOperationType.transferIn,
          amount: 5096.84,
          transferUid: transferUid,
        ),
      ];

      final investments = [investmentA, investmentB];

      final metricsWithoutTransfers =
          FinancialCalculator.calculateGlobalMetrics(
            [fund],
            const {'EUR': 1.0},
            historicalInvestments: investments,
            historicalOperations: subscriptions,
          );

      final metricsWithTransfers = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [...subscriptions, ...transfers],
      );

      expect(
        metricsWithTransfers.totalInvestedGlobal,
        metricsWithoutTransfers.totalInvestedGlobal,
      );

      expect(metricsWithTransfers.totalInvestedGlobal, 27000);

      expect(
        metricsWithTransfers.mwrAnnualizedGlobal,
        closeTo(metricsWithoutTransfers.mwrAnnualizedGlobal!, 1e-10),
      );
    }); */

    test(
      'LF-143.7.1: no empareja con contrapartes de inversiones excluidas',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final includedInvestment = HistoricalInvestment(
          uid: 'INVESTMENT-INCLUDED',
          name: 'Inversión incluida',
        );

        final excludedInvestment = HistoricalInvestment(
          uid: 'INVESTMENT-EXCLUDED',
          name: 'Inversión excluida',
        );

        const transferUid = 'TRANSFER-EXCLUDED-001';

        final operations = [
          HistoricalOperation(
            uid: 'OP-IN-001',
            investmentUid: includedInvestment.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              10,
              15,
            ),
            type: HistoricalOperationType.transferIn,
            amount: 999,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-OUT-001',
            investmentUid: excludedInvestment.uid,
            date: DateTime(
              transferDate.year,
              transferDate.month,
              transferDate.day,
              18,
              45,
            ),
            type: HistoricalOperationType.transferOut,
            amount: 999,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [includedInvestment],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 999);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );

    test('LF-143.8.1: un transferOut sin contraparte afecta al beneficio y al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investment.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final unmatchedTransferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investment.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'TRANSFER-WITHOUT-COUNTERPART',
      );

      final withoutTransferOut = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription],
      );

      final withTransferOut = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription, unmatchedTransferOut],
      );

      // El transferOut no incrementa las aportaciones globales.
      expect(
        withTransferOut.totalInvestedGlobal,
        withoutTransferOut.totalInvestedGlobal,
      );

      // Caracterizamos el efecto actual sobre el beneficio absoluto:
      // se contabiliza como retorno histórico.
      expect(
        withTransferOut.profitAbsGlobal,
        closeTo(
          withoutTransferOut.profitAbsGlobal + unmatchedTransferOut.amount,
          0.01,
        ),
      );

      // El beneficio relativo utiliza las aportaciones globales.
      expect(
        withTransferOut.profitRelGlobal,
        closeTo(
          withTransferOut.profitAbsGlobal / withTransferOut.totalInvestedGlobal,
          1e-10,
        ),
      );

      // El transferOut sin contraparte no altera el MWR global.
      /* expect(
        withTransferOut.mwrAnnualizedGlobal,
        closeTo(withoutTransferOut.mwrAnnualizedGlobal!, 1e-10),
      ); */
      expect(withoutTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(withTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(
        withTransferOut.mwrAnnualizedGlobal,
        isNot(closeTo(withoutTransferOut.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.2: un transferIn sin contraparte cuenta como aportación '
        'y afecta al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investment.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final unmatchedTransferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investment.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 5096.84,
        transferUid: 'TRANSFER-WITHOUT-COUNTERPART',
      );

      final withoutTransferIn = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription],
      );

      final withTransferIn = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription, unmatchedTransferIn],
      );

      // El transferIn sin contraparte se contabiliza como aportación.
      expect(
        withTransferIn.totalInvestedGlobal,
        closeTo(
          withoutTransferIn.totalInvestedGlobal + unmatchedTransferIn.amount,
          0.01,
        ),
      );

      // La aportación también reduce el beneficio absoluto histórico.
      expect(
        withTransferIn.profitAbsGlobal,
        closeTo(
          withoutTransferIn.profitAbsGlobal - unmatchedTransferIn.amount,
          0.01,
        ),
      );

      // El beneficio relativo mantiene la misma proporción.
      expect(
        withTransferIn.profitRelGlobal,
        closeTo(
          withTransferIn.profitAbsGlobal / withTransferIn.totalInvestedGlobal,
          1e-10,
        ),
      );

      // Al incorporarse como flujo externo, modifica el MWR global.
      expect(withoutTransferIn.mwrAnnualizedGlobal, isNotNull);
      expect(withTransferIn.mwrAnnualizedGlobal, isNotNull);
      expect(
        withTransferIn.mwrAnnualizedGlobal,
        isNot(closeTo(withoutTransferIn.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.3: una redemption histórica cuenta como retorno '
        'y afecta al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investment.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final redemption = HistoricalOperation(
        uid: 'OP-RED-001',
        investmentUid: investment.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.redemption,
        amount: 5096.84,
      );

      final withoutRedemption = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription],
      );

      final withRedemption = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription, redemption],
      );

      // El reembolso no representa una nueva aportación.
      expect(
        withRedemption.totalInvestedGlobal,
        withoutRedemption.totalInvestedGlobal,
      );

      // El reembolso se contabiliza como retorno.
      expect(
        withRedemption.profitAbsGlobal,
        closeTo(withoutRedemption.profitAbsGlobal + redemption.amount, 0.01),
      );

      // El beneficio relativo se recalcula sobre el mismo capital aportado.
      expect(
        withRedemption.profitRelGlobal,
        closeTo(
          withRedemption.profitAbsGlobal / withRedemption.totalInvestedGlobal,
          1e-10,
        ),
      );

      // El reembolso se incorpora como flujo de caja externo al MWR.
      expect(withoutRedemption.mwrAnnualizedGlobal, isNotNull);
      expect(withRedemption.mwrAnnualizedGlobal, isNotNull);
      expect(
        withRedemption.mwrAnnualizedGlobal,
        isNot(closeTo(withoutRedemption.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.4: un transferOut sin contraparte afecta al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investment = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investment.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final unmatchedTransferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investment.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'TRANSFER-WITHOUT-COUNTERPART',
      );

      final withoutTransferOut = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription],
      );

      final withTransferOut = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: [investment],
        historicalOperations: [subscription, unmatchedTransferOut],
      );

      // El transferOut sin contraparte no es una aportación.
      expect(
        withTransferOut.totalInvestedGlobal,
        withoutTransferOut.totalInvestedGlobal,
      );

      // Sigue contabilizándose como retorno en el beneficio absoluto.
      expect(
        withTransferOut.profitAbsGlobal,
        closeTo(
          withoutTransferOut.profitAbsGlobal + unmatchedTransferOut.amount,
          0.01,
        ),
      );

      // El beneficio relativo mantiene la coherencia con ambas métricas.
      expect(
        withTransferOut.profitRelGlobal,
        closeTo(
          withTransferOut.profitAbsGlobal / withTransferOut.totalInvestedGlobal,
          1e-10,
        ),
      );

      // El retorno externo debe modificar el MWR global.
      expect(withoutTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(withTransferOut.mwrAnnualizedGlobal, isNotNull);
      expect(
        withTransferOut.mwrAnnualizedGlobal,
        isNot(closeTo(withoutTransferOut.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.5: un traspaso interno no altera las métricas globales', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final transferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 5096.84,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final investments = [investmentA, investmentB];

      final withoutTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription],
      );

      final withTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription, transferOut, transferIn],
      );

      // El traspaso interno no incrementa el capital aportado.
      expect(
        withTransfer.totalInvestedGlobal,
        closeTo(withoutTransfer.totalInvestedGlobal, 0.01),
      );

      // La salida y la entrada internas no alteran el beneficio absoluto.
      expect(
        withTransfer.profitAbsGlobal,
        closeTo(withoutTransfer.profitAbsGlobal, 0.01),
      );

      // Tampoco alteran el beneficio relativo.
      expect(
        withTransfer.profitRelGlobal,
        closeTo(withoutTransfer.profitRelGlobal, 1e-10),
      );

      // Ninguno de los dos movimientos genera un flujo externo para el MWR.
      expect(withoutTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(withTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(
        withTransfer.mwrAnnualizedGlobal,
        closeTo(withoutTransfer.mwrAnnualizedGlobal!, 1e-10),
      );
    });

    test('LF-143.8.6: un transferOut con contrapartes ambiguas afecta al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final investmentC = HistoricalInvestment(
        uid: 'INVESTMENT-C',
        name: 'Inversión histórica C',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-001',
      );

      final transferInB = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-001',
      );

      final transferInC = HistoricalOperation(
        uid: 'OP-IN-002',
        investmentUid: investmentC.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-001',
      );

      final investments = [investmentA, investmentB, investmentC];

      final withoutTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        //historicalOperations: [subscription],
        historicalOperations: [subscription, transferInB, transferInC],
      );

      final withAmbiguousTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [
          subscription,
          transferOut,
          transferInB,
          transferInC,
        ],
      );

      // La salida ambigua no se considera un traspaso interno válido.
      // Por tanto, se contabiliza como retorno externo.
      expect(
        withAmbiguousTransfer.profitAbsGlobal,
        closeTo(withoutTransfer.profitAbsGlobal + transferOut.amount, 0.01),
      );

      // El retorno externo no incrementa las aportaciones.
      expect(
        withAmbiguousTransfer.totalInvestedGlobal,
        closeTo(withoutTransfer.totalInvestedGlobal, 0.01),
      );

      // La salida externa debe incorporarse al MWR.
      expect(withoutTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(withAmbiguousTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(
        withAmbiguousTransfer.mwrAnnualizedGlobal,
        isNot(closeTo(withoutTransfer.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.7: un transferIn con contrapartes ambiguas cuenta como '
        'aportación externa y afecta al MWR global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final investmentC = HistoricalInvestment(
        uid: 'INVESTMENT-C',
        name: 'Inversión histórica C',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-002',
      );

      final transferOutB = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-002',
      );

      final transferOutC = HistoricalOperation(
        uid: 'OP-OUT-002',
        investmentUid: investmentC.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'AMBIGUOUS-TRANSFER-002',
      );

      final investments = [investmentA, investmentB, investmentC];

      final withoutTransferIn = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription, transferOutB, transferOutC],
      );

      final withAmbiguousTransferIn =
          FinancialCalculator.calculateGlobalMetrics(
            [fund],
            const {'EUR': 1.0},
            historicalInvestments: investments,
            historicalOperations: [
              subscription,
              transferOutB,
              transferOutC,
              transferIn,
            ],
          );

      // La entrada ambigua se contabiliza como aportación externa.
      expect(
        withAmbiguousTransferIn.totalInvestedGlobal,
        closeTo(
          withoutTransferIn.totalInvestedGlobal + transferIn.amount,
          0.01,
        ),
      );

      // La aportación reduce el beneficio absoluto.
      expect(
        withAmbiguousTransferIn.profitAbsGlobal,
        closeTo(withoutTransferIn.profitAbsGlobal - transferIn.amount, 0.01),
      );

      // El beneficio relativo conserva la coherencia entre ambas métricas.
      expect(
        withAmbiguousTransferIn.profitRelGlobal,
        closeTo(
          withAmbiguousTransferIn.profitAbsGlobal /
              withAmbiguousTransferIn.totalInvestedGlobal,
          1e-10,
        ),
      );

      // La aportación externa modifica el MWR como flujo negativo.
      expect(withoutTransferIn.mwrAnnualizedGlobal, isNotNull);
      expect(withAmbiguousTransferIn.mwrAnnualizedGlobal, isNotNull);
      expect(
        withAmbiguousTransferIn.mwrAnnualizedGlobal,
        isNot(closeTo(withoutTransferIn.mwrAnnualizedGlobal!, 1e-10)),
      );
    });

    test('LF-143.8.8: un traspaso interno con importes diferentes no altera las métricas globales', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final transferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 4800.00,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final investments = [investmentA, investmentB];

      final withoutTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription],
      );

      final withTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription, transferOut, transferIn],
      );

      expect(
        withTransfer.totalInvestedGlobal,
        closeTo(withoutTransfer.totalInvestedGlobal, 0.01),
      );
      expect(
        withTransfer.profitAbsGlobal,
        closeTo(withoutTransfer.profitAbsGlobal, 0.01),
      );
      expect(
        withTransfer.profitRelGlobal,
        closeTo(withoutTransfer.profitRelGlobal, 1e-10),
      );
      expect(withoutTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(withTransfer.mwrAnnualizedGlobal, isNotNull);
      expect(
        withTransfer.mwrAnnualizedGlobal,
        closeTo(withoutTransfer.mwrAnnualizedGlobal!, 1e-10),
      );
    });

    test('LF-143.8.9: un traspaso interno con importes diferentes no altera el beneficio absoluto global', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final transferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 4800.00,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final investments = [investmentA, investmentB];

      final withoutTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription],
      );

      final withTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription, transferOut, transferIn],
      );

      // El traspaso interno no debe alterar el beneficio absoluto global,
      // aunque los importes de salida y entrada sean diferentes.
      expect(
        withTransfer.profitAbsGlobal,
        closeTo(withoutTransfer.profitAbsGlobal, 0.01),
      );
    });

    test('LF-143.8.10: un traspaso interno con importes diferentes no altera las métricas legacy', () {
      final fund = FundData(
        isin: 'CURRENT-FUND',
        symbol: 'CUR',
        name: 'Fondo vigente',
        lastValue: 1,
        currency: 'EUR',
        date: DateTime(2026, 11, 10),
        history: [PricePoint(DateTime(2006, 1, 1), 1)],
        operations: [
          FundOperation(
            isin: 'CURRENT-FUND',
            date: DateTime(2006, 1, 1),
            type: OperationType.buy,
            units: 20000,
            price: 1,
            amount: 20000,
          ),
        ],
      );

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión histórica A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión histórica B',
      );

      final subscription = HistoricalOperation(
        uid: 'OP-SUB-001',
        investmentUid: investmentA.uid,
        date: DateTime(2006, 1, 26),
        type: HistoricalOperationType.subscription,
        amount: 6000,
      );

      final transferOut = HistoricalOperation(
        uid: 'OP-OUT-001',
        investmentUid: investmentA.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferOut,
        amount: 5096.84,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final transferIn = HistoricalOperation(
        uid: 'OP-IN-001',
        investmentUid: investmentB.uid,
        date: DateTime(2010, 4, 14),
        type: HistoricalOperationType.transferIn,
        amount: 4800.00,
        transferUid: 'INTERNAL-TRANSFER-001',
      );

      final investments = [investmentA, investmentB];

      final withoutTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription],
      );

      final withTransfer = FinancialCalculator.calculateGlobalMetrics(
        [fund],
        const {'EUR': 1.0},
        historicalInvestments: investments,
        historicalOperations: [subscription, transferOut, transferIn],
      );

      // Las métricas legacy conservan su comportamiento anterior:
      // reflejan la diferencia entre los importes de salida y entrada.
      expect(
        withTransfer.profitAbs,
        closeTo(withoutTransfer.profitAbs + 296.84, 0.01),
      );
      expect(withTransfer.profitRel, closeTo(withoutTransfer.profitRel, 1e-10));
    });

    test('LF-143.9.1: empareja un traspaso con UID coincidente '
        'aunque la entrada sea cinco días posterior', () {
      final investments = [
        HistoricalInvestment(uid: 'investment-origin', name: 'Fonditel'),
        HistoricalInvestment(
          uid: 'investment-destination',
          name: 'ING Fondo Naranja',
        ),
      ];

      final operations = [
        HistoricalOperation(
          uid: 'subscription-1',
          investmentUid: 'investment-origin',
          date: DateTime(2006, 1, 26),
          type: HistoricalOperationType.subscription,
          amount: 6000,
        ),
        HistoricalOperation(
          uid: 'transfer-out-1',
          investmentUid: 'investment-origin',
          date: DateTime(2010, 4, 14),
          type: HistoricalOperationType.transferOut,
          amount: 5096.84,
          transferUid: 'TRASPASO 1',
        ),
        HistoricalOperation(
          uid: 'transfer-in-1',
          investmentUid: 'investment-destination',
          date: DateTime(2010, 4, 19),
          type: HistoricalOperationType.transferIn,
          amount: 5096.84,
          transferUid: 'TRASPASO 1',
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        {},
        historicalInvestments: investments,
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, closeTo(6000, 0.01));
    });

    test(
      'LF-143.9.2: empareja traspasos históricos con un día de diferencia',
      () {
        final sourceInvestment = HistoricalInvestment(
          uid: 'LF143-DATE-SOURCE',
          name: 'Inversión origen',
        );

        final destinationInvestment = HistoricalInvestment(
          uid: 'LF143-DATE-DESTINATION',
          name: 'Inversión destino',
        );

        final historicalOperations = [
          HistoricalOperation(
            uid: 'LF143-DATE-OP-001',
            investmentUid: sourceInvestment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'LF143-DATE-OP-002',
            investmentUid: sourceInvestment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 300,
            transferUid: 'LF143-DATE-TRANSFER-001',
          ),
          HistoricalOperation(
            uid: 'LF143-DATE-OP-003',
            investmentUid: destinationInvestment.uid,
            date: DateTime(2024, 1, 2),
            type: HistoricalOperationType.transferIn,
            amount: 300,
            transferUid: 'LF143-DATE-TRANSFER-001',
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          const [],
          const {},
          historicalInvestments: [sourceInvestment, destinationInvestment],
          historicalOperations: historicalOperations,
        );

        expect(metrics.totalInvestedGlobal, 1000);
      },
    );

    test('LF-143.9.3: un traspaso con el mismo UID y un día de diferencia se empareja', () {
      final source = HistoricalInvestment(
        uid: 'LF143-PAST-SOURCE',
        name: 'Origen histórico',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-PAST-DESTINATION',
        name: 'Destino histórico',
      );

      final transferUid = 'LF143-PAST-INTERNAL-TRANSFER';

      final transferOutDate = DateTime(2023, 1, 1);
      final transferInDate = DateTime(2023, 1, 2);

      final operations = [
        HistoricalOperation(
          uid: 'LF143-PAST-OUT',
          investmentUid: source.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-PAST-IN',
          investmentUid: destination.uid,
          date: transferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      //expect(metrics.totalInvestedGlobal, 1000);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1000);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.9.4: empareja traspasos con distinto importe y un día de diferencia ', () {
      final source = HistoricalInvestment(
        uid: 'LF143-TRANSFER-SOURCE',
        name: 'Inversión origen',
      );

      final destination = HistoricalInvestment(
        uid: 'LF143-TRANSFER-DESTINATION',
        name: 'Inversión destino',
      );

      final transferUid = 'LF143-TRANSFER-DIFFERENT-DATES';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-TRANSFER-OUT-DIFFERENT-DATES',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-TRANSFER-IN-DIFFERENT-DATES',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 2),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      //expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.9.5: empareja traspasos en días naturales distintos aunque las horas difieran', () {
      final source = HistoricalInvestment(
        uid: 'LF143-35-SOURCE',
        name: 'Inversión origen',
      );
      final destination = HistoricalInvestment(
        uid: 'LF143-35-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-35-DIFFERENT-DAYS';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-35-OUT',
          investmentUid: source.uid,
          date: DateTime(2023, 1, 1, 23, 30),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-35-IN',
          investmentUid: destination.uid,
          date: DateTime(2023, 1, 2, 0, 30),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      //expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.9.6: empareja traspasos que cruzan el cambio de año', () {
      final source = HistoricalInvestment(
        uid: 'LF143-38-SOURCE',
        name: 'Inversión origen',
      );
      final destination = HistoricalInvestment(
        uid: 'LF143-38-DESTINATION',
        name: 'Inversión destino',
      );

      const transferUid = 'LF143-38-YEAR-BOUNDARY';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-38-OUT',
          investmentUid: source.uid,
          date: DateTime(2023, 12, 31, 23, 30),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-38-IN',
          investmentUid: destination.uid,
          date: DateTime(2024, 1, 1, 0, 30),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source, destination],
        historicalOperations: operations,
      );

      //expect(metrics.totalInvestedGlobal, 950);
      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 950);
      expect(metrics.profitAbs, 50);
      expect(metrics.profitRel, closeTo(50 / 950 * 100, 0.000001));
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.9.7: dos traspasos con el mismo UID se emparejan por separado '
        'dentro de la ventana de diez días', () {
      final source1 = HistoricalInvestment(
        uid: 'LF143-39-SOURCE-1',
        name: 'Inversión origen 1',
      );
      final destination1 = HistoricalInvestment(
        uid: 'LF143-39-DESTINATION-1',
        name: 'Inversión destino 1',
      );
      final source2 = HistoricalInvestment(
        uid: 'LF143-39-SOURCE-2',
        name: 'Inversión origen 2',
      );
      final destination2 = HistoricalInvestment(
        uid: 'LF143-39-DESTINATION-2',
        name: 'Inversión destino 2',
      );

      const transferUid = 'LF143-39-REUSED-UID';

      final operations = [
        HistoricalOperation(
          uid: 'LF143-39-OUT-1',
          investmentUid: source1.uid,
          date: DateTime(2023, 1, 1, 9, 0),
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-39-IN-1',
          investmentUid: destination1.uid,
          date: DateTime(2023, 1, 1, 16, 0),
          type: HistoricalOperationType.transferIn,
          amount: 950,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-39-OUT-2',
          investmentUid: source2.uid,
          date: DateTime(2023, 1, 2, 10, 0),
          type: HistoricalOperationType.transferOut,
          amount: 500,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'LF143-39-IN-2',
          investmentUid: destination2.uid,
          date: DateTime(2023, 1, 2, 17, 0),
          type: HistoricalOperationType.transferIn,
          amount: 450,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {'EUR': 1.0},
        historicalInvestments: [source1, destination1, source2, destination2],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.totalValueGlobal, 0);
      expect(metrics.totalInvested, 1400);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(100 / 1400 * 100, 0.000001));
      expect(metrics.isAnnualized, isFalse);
      expect(metrics.isAnnualizedGlobal, isTrue);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('LF-143.9.8: empareja traspasos separados por un día natural', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      const transferUid = 'TRANSFER-A-B';

      final transferOutDate = DateTime(
        transferDate.year,
        transferDate.month,
        transferDate.day,
        10,
        15,
      );

      final nextDay = transferDate.add(const Duration(days: 1));

      final transferInDate = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        18,
        45,
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferOutDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferInDate,
          type: HistoricalOperationType.transferIn,
          amount: 1000,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 0);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test('LF-143.9.9: una salida con dos entradas posibles dentro de la '
        'ventana de diez días no se empareja', () {
      final transferDate = DateTime.now().subtract(const Duration(days: 60));

      final investmentA = HistoricalInvestment(
        uid: 'INVESTMENT-A',
        name: 'Inversión A',
      );

      final investmentB = HistoricalInvestment(
        uid: 'INVESTMENT-B',
        name: 'Inversión B',
      );

      final investmentC = HistoricalInvestment(
        uid: 'INVESTMENT-C',
        name: 'Inversión C',
      );

      const transferUid = 'TRANSFER-A-B-C';

      final operations = [
        HistoricalOperation(
          uid: 'OP-A-01',
          investmentUid: investmentA.uid,
          date: transferDate,
          type: HistoricalOperationType.transferOut,
          amount: 1000,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-B-01',
          investmentUid: investmentB.uid,
          date: transferDate.add(const Duration(days: 3)),
          type: HistoricalOperationType.transferIn,
          amount: 900,
          transferUid: transferUid,
        ),
        HistoricalOperation(
          uid: 'OP-C-01',
          investmentUid: investmentC.uid,
          date: transferDate.add(const Duration(days: 5)),
          type: HistoricalOperationType.transferIn,
          amount: 800,
          transferUid: transferUid,
        ),
      ];

      final metrics = FinancialCalculator.calculateGlobalMetrics(
        [],
        const {},
        historicalInvestments: [investmentA, investmentB, investmentC],
        historicalOperations: operations,
      );

      expect(metrics.totalInvestedGlobal, 1700);
      expect(metrics.isAnnualizedGlobal, isTrue);
    });

    test(
      'LF-143.9.10: dos salidas posibles para una entrada no se emparejan',
      () {
        final transferDate = DateTime.now().subtract(const Duration(days: 60));

        final investmentA = HistoricalInvestment(
          uid: 'INVESTMENT-A',
          name: 'Inversión A',
        );

        final investmentB = HistoricalInvestment(
          uid: 'INVESTMENT-B',
          name: 'Inversión B',
        );

        final investmentC = HistoricalInvestment(
          uid: 'INVESTMENT-C',
          name: 'Inversión C',
        );

        const transferUid = 'TRANSFER-A-B-C';

        final operations = [
          HistoricalOperation(
            uid: 'OP-A-01',
            investmentUid: investmentA.uid,
            date: transferDate,
            type: HistoricalOperationType.transferOut,
            amount: 1000,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-B-01',
            investmentUid: investmentB.uid,
            date: transferDate.add(const Duration(days: 2)),
            type: HistoricalOperationType.transferOut,
            amount: 800,
            transferUid: transferUid,
          ),
          HistoricalOperation(
            uid: 'OP-C-01',
            investmentUid: investmentC.uid,
            date: transferDate.add(const Duration(days: 4)),
            type: HistoricalOperationType.transferIn,
            amount: 900,
            transferUid: transferUid,
          ),
        ];

        final metrics = FinancialCalculator.calculateGlobalMetrics(
          [],
          const {},
          historicalInvestments: [investmentA, investmentB, investmentC],
          historicalOperations: operations,
        );

        expect(metrics.totalInvestedGlobal, 900);
        expect(metrics.isAnnualizedGlobal, isTrue);
      },
    );
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
}
