import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/utils/financial_calculator.dart';

void main() {
  group('Historical investment metrics', () {
    test('calcula el resultado y MWR de una inversión cerrada', () {
      final investment = HistoricalInvestment(
        uid: 'INV-001',
        name: 'Inversión de prueba',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1000);
      expect(metrics.totalReturns, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(10, 0.0001));
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test('trata los traspasos como aportaciones y retornos', () {
      final investment = HistoricalInvestment(
        uid: 'INV-002',
        name: 'Inversión con traspasos',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: investment.uid,
          date: DateTime(2023, 6, 1),
          type: HistoricalOperationType.transferIn,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: investment.uid,
          date: DateTime(2023, 9, 1),
          type: HistoricalOperationType.redemption,
          amount: 200,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1450,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1500);
      expect(metrics.totalReturns, 1650);
      expect(metrics.profitAbs, 150);
      expect(metrics.profitRel, closeTo(10, 0.0001));
    });

    test('ignora las operaciones pertenecientes a otras inversiones', () {
      final investment = HistoricalInvestment(
        uid: 'INV-003',
        name: 'Inversión principal',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: 'INV-OTHER',
          date: DateTime(2023, 3, 1),
          type: HistoricalOperationType.subscription,
          amount: 5000,
        ),
        HistoricalOperation(
          uid: 'OP-003',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-004',
          investmentUid: 'INV-OTHER',
          date: DateTime(2024, 3, 1),
          type: HistoricalOperationType.redemption,
          amount: 7000,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1000);
      expect(metrics.totalReturns, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, closeTo(10, 0.0001));
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.0005));
    });

    test(
      'devuelve métricas neutras cuando la inversión no tiene operaciones',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-004',
          name: 'Inversión sin operaciones',
        );

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentMetrics(
              investment,
              [],
            );

        expect(metrics.totalContributions, 0);
        expect(metrics.totalReturns, 0);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test('devuelve MWR nula cuando solo existen aportaciones', () {
      final investment = HistoricalInvestment(
        uid: 'INV-005',
        name: 'Inversión sin retornos',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-002',
          investmentUid: investment.uid,
          date: DateTime(2023, 6, 1),
          type: HistoricalOperationType.transferIn,
          amount: 500,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1500);
      expect(metrics.totalReturns, 0);
      expect(metrics.profitAbs, -1500);
      expect(metrics.profitRel, -100);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('devuelve rentabilidades nulas cuando solo existen retornos', () {
      final investment = HistoricalInvestment(
        uid: 'INV-006',
        name: 'Inversión sin aportaciones',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-001',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 500,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 0);
      expect(metrics.totalReturns, 500);
      expect(metrics.profitAbs, 500);
      expect(metrics.profitRel, isNull);
      expect(metrics.mwrAnnualized, isNull);
    });

    test('agrega correctamente dos inversiones cerradas', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-AGG-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-AGG-002',
        name: 'Segunda inversión',
      );

      final investments = [investment1, investment2];

      final operations = [
        HistoricalOperation(
          uid: 'OP-AGG-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-003',
          investmentUid: investment2.uid,
          date: DateTime(2022, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 2300,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        investments,
        operations,
      );

      expect(metrics.totalContributions, 3000);
      expect(metrics.totalReturns, 3400);
      expect(metrics.profitAbs, 400);
      expect(metrics.profitRel, closeTo(13.333333, 0.0001));
      expect(metrics.mwrAnnualized, isNotNull);
    });

    test('ignora operaciones de inversiones no incluidas en el agregado', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-AGG-101',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-AGG-102',
        name: 'Segunda inversión',
      );

      final investmentExcluded = HistoricalInvestment(
        uid: 'INV-AGG-103',
        name: 'Inversión excluida',
      );

      final investments = [investment1, investment2];

      final operations = [
        HistoricalOperation(
          uid: 'OP-AGG-101',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-102',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-103',
          investmentUid: investment2.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-104',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 2200,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-105',
          investmentUid: investmentExcluded.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 9000,
        ),
        HistoricalOperation(
          uid: 'OP-AGG-106',
          investmentUid: investmentExcluded.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 9900,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        investments,
        operations,
      );

      expect(metrics.totalContributions, 3000);
      expect(metrics.totalReturns, 3300);
      expect(metrics.profitAbs, 300);
      expect(metrics.profitRel, 10);
      expect(metrics.mwrAnnualized, isNotNull);
    });

    test('devuelve métricas neutras cuando no hay inversiones históricas', () {
      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [],
        [],
      );

      expect(metrics.totalContributions, 0);
      expect(metrics.totalReturns, 0);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      expect(metrics.mwrAnnualized, isNull);
    });

    test(
      'devuelve métricas neutras cuando las inversiones no tienen operaciones',
      () {
        final investments = [
          HistoricalInvestment(uid: 'INV-EMPTY-001', name: 'Primera inversión'),
          HistoricalInvestment(uid: 'INV-EMPTY-002', name: 'Segunda inversión'),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics(
              investments,
              [],
            );

        expect(metrics.totalContributions, 0);
        expect(metrics.totalReturns, 0);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test(
      'devuelve MWR nula cuando todas las inversiones solo tienen aportaciones',
      () {
        final investment1 = HistoricalInvestment(
          uid: 'INV-ONLY-IN-001',
          name: 'Primera inversión',
        );

        final investment2 = HistoricalInvestment(
          uid: 'INV-ONLY-IN-002',
          name: 'Segunda inversión',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-ONLY-IN-001',
            investmentUid: investment1.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-ONLY-IN-002',
            investmentUid: investment2.uid,
            date: DateTime(2023, 6, 1),
            type: HistoricalOperationType.transferIn,
            amount: 500,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment1,
              investment2,
            ], operations);

        expect(metrics.totalContributions, 1500);
        expect(metrics.totalReturns, 0);
        expect(metrics.profitAbs, -1500);
        expect(metrics.profitRel, -100);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test('devuelve rentabilidades nulas cuando todas las inversiones solo tienen retornos', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-ONLY-OUT-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-ONLY-OUT-002',
        name: 'Segunda inversión',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-ONLY-OUT-001',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-ONLY-OUT-002',
          investmentUid: investment2.uid,
          date: DateTime(2024, 6, 1),
          type: HistoricalOperationType.transferOut,
          amount: 300,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment1, investment2],
        operations,
      );

      expect(metrics.totalContributions, 0);
      expect(metrics.totalReturns, 800);
      expect(metrics.profitAbs, 800);
      expect(metrics.profitRel, isNull);
      expect(metrics.mwrAnnualized, isNull);
    });

    test(
      'calcula la MWR conjunta y no el promedio de las MWR individuales',
      () {
        final investment1 = HistoricalInvestment(
          uid: 'INV-MWR-001',
          name: 'Primera inversión',
        );

        final investment2 = HistoricalInvestment(
          uid: 'INV-MWR-002',
          name: 'Segunda inversión',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-MWR-001',
            investmentUid: investment1.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-MWR-002',
            investmentUid: investment1.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
          HistoricalOperation(
            uid: 'OP-MWR-003',
            investmentUid: investment2.uid,
            date: DateTime(2022, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 9000,
          ),
          HistoricalOperation(
            uid: 'OP-MWR-004',
            investmentUid: investment2.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 9900,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment1,
              investment2,
            ], operations);

        final individual1 =
            FinancialCalculator.calculateHistoricalInvestmentMetrics(
              investment1,
              operations,
            );

        final individual2 =
            FinancialCalculator.calculateHistoricalInvestmentMetrics(
              investment2,
              operations,
            );

        final averageIndividualMwr =
            (individual1.mwrAnnualized! + individual2.mwrAnnualized!) / 2;

        expect(metrics.mwrAnnualized, isNotNull);
        expect(
          metrics.mwrAnnualized,
          isNot(closeTo(averageIndividualMwr, 0.000001)),
        );
      },
    );

    test('pondera la MWR conjunta según importes y fechas de los flujos', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-WEIGHT-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-WEIGHT-002',
        name: 'Segunda inversión',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-WEIGHT-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-WEIGHT-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-WEIGHT-003',
          investmentUid: investment2.uid,
          date: DateTime(2022, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 9000,
        ),
        HistoricalOperation(
          uid: 'OP-WEIGHT-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 9900,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment1, investment2],
        operations,
      );

      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, closeTo(0.0514, 0.001));
    });

    test(
      'ignora todas las operaciones cuando no hay inversiones incluidas',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-ORPHAN-001',
          name: 'Inversión no incluida',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-ORPHAN-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-ORPHAN-002',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics(
              [],
              operations,
            );

        expect(metrics.totalContributions, 0);
        expect(metrics.totalReturns, 0);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        expect(metrics.mwrAnnualized, isNull);
      },
    );

    test('no duplica métricas cuando una inversión aparece varias veces', () {
      final investment = HistoricalInvestment(
        uid: 'INV-DUP-001',
        name: 'Inversión repetida',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-DUP-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-DUP-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment, investment, investment],
        operations,
      );

      expect(metrics.totalContributions, 1000);
      expect(metrics.totalReturns, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, 10);
      expect(metrics.mwrAnnualized, closeTo(0.10, 0.001));
    });

    test(
      'no duplica los flujos de MWR cuando una inversión aparece varias veces',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-DUP-MWR-001',
          name: 'Inversión repetida',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-DUP-MWR-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-DUP-MWR-002',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
        ];

        final singleMetrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations);

        final duplicatedMetrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
              investment,
            ], operations);

        expect(
          duplicatedMetrics.mwrAnnualized,
          closeTo(singleMetrics.mwrAnnualized!, 0.000001),
        );
      },
    );

    test('no modifica las listas originales al calcular el agregado', () {
      final investment = HistoricalInvestment(
        uid: 'INV-IMMUTABLE-001',
        name: 'Inversión histórica',
      );

      final investments = [investment];

      final operations = [
        HistoricalOperation(
          uid: 'OP-IMMUTABLE-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-IMMUTABLE-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final originalInvestments = List.of(investments);
      final originalOperations = List.of(operations);

      FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        investments,
        operations,
      );

      expect(investments, equals(originalInvestments));
      expect(operations, equals(originalOperations));
      expect(investments.length, 1);
      expect(operations.length, 2);
    });

    test(
      'calcula la misma MWR independientemente del orden de las operaciones',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-ORDER-001',
          name: 'Inversión histórica',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-ORDER-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-ORDER-002',
            investmentUid: investment.uid,
            date: DateTime(2023, 7, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-ORDER-003',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1650,
          ),
        ];

        final orderedMetrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations);

        final shuffledMetrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations.reversed.toList());

        expect(
          shuffledMetrics.mwrAnnualized,
          closeTo(orderedMetrics.mwrAnnualized!, 0.000001),
        );
        expect(
          shuffledMetrics.totalContributions,
          orderedMetrics.totalContributions,
        );
        expect(shuffledMetrics.totalReturns, orderedMetrics.totalReturns);
      },
    );

    test('calcula las mismas métricas independientemente del orden de las inversiones', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-ORDER-INV-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-ORDER-INV-002',
        name: 'Segunda inversión',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-ORDER-INV-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-ORDER-INV-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-ORDER-INV-003',
          investmentUid: investment2.uid,
          date: DateTime(2022, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-ORDER-INV-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 2300,
        ),
      ];

      final firstMetrics =
          FinancialCalculator.calculateHistoricalInvestmentsMetrics([
            investment1,
            investment2,
          ], operations);

      final reversedMetrics =
          FinancialCalculator.calculateHistoricalInvestmentsMetrics([
            investment2,
            investment1,
          ], operations);

      expect(
        reversedMetrics.totalContributions,
        firstMetrics.totalContributions,
      );
      expect(reversedMetrics.totalReturns, firstMetrics.totalReturns);
      expect(reversedMetrics.profitAbs, firstMetrics.profitAbs);
      expect(reversedMetrics.profitRel, firstMetrics.profitRel);
      expect(
        reversedMetrics.mwrAnnualized,
        closeTo(firstMetrics.mwrAnnualized!, 0.000001),
      );
    });

    test('mantiene separados los flujos de inversiones con UID diferentes', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-ISOLATION-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-ISOLATION-002',
        name: 'Segunda inversión',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-ISOLATION-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-ISOLATION-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
        HistoricalOperation(
          uid: 'OP-ISOLATION-003',
          investmentUid: investment2.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-ISOLATION-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1800,
        ),
      ];

      final metrics1 = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment1,
        operations,
      );

      final metrics2 = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment2,
        operations,
      );

      final aggregate =
          FinancialCalculator.calculateHistoricalInvestmentsMetrics([
            investment1,
            investment2,
          ], operations);

      expect(metrics1.profitAbs, 100);
      expect(metrics2.profitAbs, -200);
      expect(aggregate.totalContributions, 3000);
      expect(aggregate.totalReturns, 2900);
      expect(aggregate.profitAbs, -100);
    });

    test('calcula correctamente una pérdida agregada', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-LOSS-001',
        name: 'Primera inversión',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-LOSS-002',
        name: 'Segunda inversión',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-LOSS-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-LOSS-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 800,
        ),
        HistoricalOperation(
          uid: 'OP-LOSS-003',
          investmentUid: investment2.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-LOSS-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1700,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment1, investment2],
        operations,
      );

      expect(metrics.totalContributions, 3000);
      expect(metrics.totalReturns, 2500);
      expect(metrics.profitAbs, -500);
      expect(metrics.profitRel, closeTo(-16.666667, 0.0001));
      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, lessThan(0));
    });

    test('calcula correctamente un resultado positivo con inversiones ganadoras y perdedoras', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-MIXED-001',
        name: 'Inversión ganadora',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-MIXED-002',
        name: 'Inversión perdedora',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-MIXED-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 2000,
        ),
        HistoricalOperation(
          uid: 'OP-MIXED-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 2500,
        ),
        HistoricalOperation(
          uid: 'OP-MIXED-003',
          investmentUid: investment2.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-MIXED-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 800,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment1, investment2],
        operations,
      );

      expect(metrics.totalContributions, 3000);
      expect(metrics.totalReturns, 3300);
      expect(metrics.profitAbs, 300);
      expect(metrics.profitRel, 10);
      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, greaterThan(0));
    });

    test('calcula correctamente un resultado agregado exactamente neutro', () {
      final investment1 = HistoricalInvestment(
        uid: 'INV-BALANCED-001',
        name: 'Inversión ganadora',
      );

      final investment2 = HistoricalInvestment(
        uid: 'INV-BALANCED-002',
        name: 'Inversión perdedora',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-BALANCED-001',
          investmentUid: investment1.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-BALANCED-002',
          investmentUid: investment1.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1200,
        ),
        HistoricalOperation(
          uid: 'OP-BALANCED-003',
          investmentUid: investment2.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-BALANCED-004',
          investmentUid: investment2.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 800,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment1, investment2],
        operations,
      );

      expect(metrics.totalContributions, 2000);
      expect(metrics.totalReturns, 2000);
      expect(metrics.profitAbs, 0);
      expect(metrics.profitRel, 0);
      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, closeTo(0, 0.000001));
    });

    test('calcula la MWR con aportaciones y retornos parciales', () {
      final investment = HistoricalInvestment(
        uid: 'INV-PARTIAL-001',
        name: 'Inversión con movimientos parciales',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-PARTIAL-001',
          investmentUid: investment.uid,
          date: DateTime(2022, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-PARTIAL-002',
          investmentUid: investment.uid,
          date: DateTime(2022, 7, 1),
          type: HistoricalOperationType.subscription,
          amount: 500,
        ),
        HistoricalOperation(
          uid: 'OP-PARTIAL-003',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 600,
        ),
        HistoricalOperation(
          uid: 'OP-PARTIAL-004',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentMetrics(
        investment,
        operations,
      );

      expect(metrics.totalContributions, 1500);
      expect(metrics.totalReturns, 1700);
      expect(metrics.profitAbs, 200);
      expect(metrics.profitRel, closeTo(13.333333, 0.0001));
      expect(metrics.mwrAnnualized, isNotNull);
      expect(metrics.mwrAnnualized!, greaterThan(0));
    });

    test(
      'calcula la MWR conjunta con flujos parciales de varias inversiones',
      () {
        final investment1 = HistoricalInvestment(
          uid: 'INV-PARTIAL-AGG-001',
          name: 'Primera inversión',
        );

        final investment2 = HistoricalInvestment(
          uid: 'INV-PARTIAL-AGG-002',
          name: 'Segunda inversión',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-001',
            investmentUid: investment1.uid,
            date: DateTime(2022, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-002',
            investmentUid: investment1.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 600,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-003',
            investmentUid: investment1.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-004',
            investmentUid: investment2.uid,
            date: DateTime(2022, 7, 1),
            type: HistoricalOperationType.subscription,
            amount: 2000,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-005',
            investmentUid: investment2.uid,
            date: DateTime(2023, 7, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-AGG-006',
            investmentUid: investment2.uid,
            date: DateTime(2024, 7, 1),
            type: HistoricalOperationType.redemption,
            amount: 2800,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment1,
              investment2,
            ], operations);

        expect(metrics.totalContributions, 3500);
        expect(metrics.totalReturns, 3900);
        expect(metrics.profitAbs, 400);
        expect(metrics.profitRel, closeTo(11.428571, 0.0001));
        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized!, greaterThan(0));
      },
    );

    test(
      'agrega correctamente suscripciones, reembolsos y traspasos parciales',
      () {
        final investment1 = HistoricalInvestment(
          uid: 'INV-TRANSFER-AGG-001',
          name: 'Primera inversión',
        );

        final investment2 = HistoricalInvestment(
          uid: 'INV-TRANSFER-AGG-002',
          name: 'Segunda inversión',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-001',
            investmentUid: investment1.uid,
            date: DateTime(2022, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-002',
            investmentUid: investment1.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 300,
          ),
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-003',
            investmentUid: investment1.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 800,
          ),
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-004',
            investmentUid: investment2.uid,
            date: DateTime(2022, 6, 1),
            type: HistoricalOperationType.transferIn,
            amount: 1500,
          ),
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-005',
            investmentUid: investment2.uid,
            date: DateTime(2023, 6, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-TRANSFER-AGG-006',
            investmentUid: investment2.uid,
            date: DateTime(2024, 6, 1),
            type: HistoricalOperationType.transferOut,
            amount: 2100,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment1,
              investment2,
            ], operations);

        expect(metrics.totalContributions, 3000);
        expect(metrics.totalReturns, 3200);
        expect(metrics.profitAbs, 200);
        expect(metrics.profitRel, closeTo(6.666667, 0.0001));
        expect(metrics.mwrAnnualized, isNotNull);
      },
    );

    test('incluye traspasos sin contrapartida en el agregado', () {
      final investment = HistoricalInvestment(
        uid: 'INV-TRANSFER-ORPHAN-001',
        name: 'Inversión histórica',
      );

      final operations = [
        HistoricalOperation(
          uid: 'OP-TRANSFER-ORPHAN-001',
          investmentUid: investment.uid,
          date: DateTime(2023, 1, 1),
          type: HistoricalOperationType.subscription,
          amount: 1000,
        ),
        HistoricalOperation(
          uid: 'OP-TRANSFER-ORPHAN-002',
          investmentUid: investment.uid,
          date: DateTime(2024, 1, 1),
          type: HistoricalOperationType.transferOut,
          amount: 1100,
        ),
      ];

      final metrics = FinancialCalculator.calculateHistoricalInvestmentsMetrics(
        [investment],
        operations,
      );

      expect(metrics.totalContributions, 1000);
      expect(metrics.totalReturns, 1100);
      expect(metrics.profitAbs, 100);
      expect(metrics.profitRel, 10);
      expect(metrics.mwrAnnualized, isNotNull);
    });

    test(
      'calcula correctamente una inversión cerrada sin beneficio ni pérdida',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-CLOSED-001',
          name: 'Inversión cerrada',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-CLOSED-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-CLOSED-002',
            investmentUid: investment.uid,
            date: DateTime(2023, 7, 1),
            type: HistoricalOperationType.redemption,
            amount: 400,
          ),
          HistoricalOperation(
            uid: 'OP-CLOSED-003',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 600,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations);

        expect(metrics.totalContributions, 1000);
        expect(metrics.totalReturns, 1000);
        expect(metrics.profitAbs, 0);
        expect(metrics.profitRel, 0);
        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized!, closeTo(0, 0.000001));
      },
    );

    test(
      'calcula una inversión cerrada con recuperación parcial y pérdida',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-PARTIAL-LOSS-001',
          name: 'Inversión cerrada con pérdidas',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-PARTIAL-LOSS-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 2000,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-LOSS-002',
            investmentUid: investment.uid,
            date: DateTime(2023, 7, 1),
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-PARTIAL-LOSS-003',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1000,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations);

        expect(metrics.totalContributions, 2000);
        expect(metrics.totalReturns, 1500);
        expect(metrics.profitAbs, -500);
        expect(metrics.profitRel, -25);
        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized!, lessThan(0));
      },
    );

    test(
      'calcula una inversión cerrada con beneficio mediante traspaso de salida',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-CLOSED-PROFIT-001',
          name: 'Inversión cerrada con beneficio',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-CLOSED-PROFIT-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 2000,
          ),
          HistoricalOperation(
            uid: 'OP-CLOSED-PROFIT-002',
            investmentUid: investment.uid,
            date: DateTime(2023, 7, 1),
            type: HistoricalOperationType.redemption,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-CLOSED-PROFIT-003',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 1800,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentsMetrics([
              investment,
            ], operations);

        expect(metrics.totalContributions, 2000);
        expect(metrics.totalReturns, 2300);
        expect(metrics.profitAbs, 300);
        expect(metrics.profitRel, 15);
        expect(metrics.mwrAnnualized, isNotNull);
        expect(metrics.mwrAnnualized!, greaterThan(0));
      },
    );

    test(
      'incluye todos los flujos aunque varias operaciones compartan fecha',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-SAME-DATE-001',
          name: 'Inversión con operaciones simultáneas',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-SAME-DATE-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-SAME-DATE-002',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 500,
          ),
          HistoricalOperation(
            uid: 'OP-SAME-DATE-003',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 900,
          ),
          HistoricalOperation(
            uid: 'OP-SAME-DATE-004',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.transferOut,
            amount: 750,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentMetrics(
              investment,
              operations,
            );

        expect(metrics.totalContributions, 1500);
        expect(metrics.totalReturns, 1650);
        expect(metrics.profitAbs, 150);
        expect(metrics.profitRel, 10);
        expect(metrics.mwrAnnualized, isNotNull);
      },
    );

    test(
      'mantiene aisladas las operaciones de inversiones con UID diferentes',
      () {
        final investment = HistoricalInvestment(
          uid: 'INV-ISOLATION-001',
          name: 'Inversión objetivo',
        );

        final operations = [
          HistoricalOperation(
            uid: 'OP-ISOLATION-001',
            investmentUid: investment.uid,
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 1000,
          ),
          HistoricalOperation(
            uid: 'OP-ISOLATION-002',
            investmentUid: investment.uid,
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1100,
          ),
          HistoricalOperation(
            uid: 'OP-ISOLATION-003',
            investmentUid: 'INV-ISOLATION-OTHER',
            date: DateTime(2023, 1, 1),
            type: HistoricalOperationType.subscription,
            amount: 9000,
          ),
          HistoricalOperation(
            uid: 'OP-ISOLATION-004',
            investmentUid: 'INV-ISOLATION-OTHER',
            date: DateTime(2024, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 9900,
          ),
        ];

        final metrics =
            FinancialCalculator.calculateHistoricalInvestmentMetrics(
              investment,
              operations,
            );

        expect(metrics.totalContributions, 1000);
        expect(metrics.totalReturns, 1100);
        expect(metrics.profitAbs, 100);
        expect(metrics.profitRel, 10);
        expect(metrics.mwrAnnualized, closeTo(0.10, 0.001));
      },
    );

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
}
