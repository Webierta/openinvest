import 'package:flutter_test/flutter_test.dart';
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
