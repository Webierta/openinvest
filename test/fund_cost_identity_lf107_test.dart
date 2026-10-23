import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temporaryDirectory;

  final purchaseDate = DateTime(2026, 10, 1);
  final chargeDate = DateTime(2026, 10, 10);
  final valuationDate = DateTime(2026, 10, 20);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'lf107_identity_test_',
    );

    await DatabaseService.useDatabasePathForTesting(
      path.join(temporaryDirectory.path, 'test.db'),
    );
  });

  tearDown(() async {
    await DatabaseService.resetDatabasePathForTesting();
    await temporaryDirectory.delete(recursive: true);
  });

  FundCostPeriod performancePeriod({
    required String uid,
    required double rate,
  }) {
    return FundCostPeriod(
      uid: uid,
      concept: FundCostConcept.performance,
      ratePercent: rate,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: DateTime(2026, 1, 1),
      validTo: DateTime(2026, 12, 31),
    );
  }

  FundCostCharge performanceCharge({
    required String uid,
    required String periodUid,
    required double amount,
  }) {
    return FundCostCharge(
      uid: uid,
      concept: FundCostConcept.performance,
      date: chargeDate,
      amount: amount,
      performancePeriodUid: periodUid,
    );
  }

  FundOperation purchase({
    required String isin,
    required double units,
    required double price,
  }) {
    return FundOperation(
      isin: isin,
      date: purchaseDate,
      type: OperationType.buy,
      units: units,
      price: price,
      amount: units * price,
    );
  }

  FundData fundA({
    List<FundCostPeriod>? periods,
    List<FundCostCharge>? charges,
    List<FundOperation>? operations,
  }) {
    return FundData(
      isin: 'ES0123456789',
      symbol: 'FUND-A',
      name: 'Fondo A',
      lastValue: 110.0,
      currency: 'EUR',
      date: valuationDate,
      history: [PricePoint(valuationDate, 110.0)],
      operations:
          operations ?? [purchase(isin: 'ES0123456789', units: 10, price: 100)],
      costPeriods: periods ?? [performancePeriod(uid: 'A-P1', rate: 10)],
      costCharges:
          charges ??
          [performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 5)],
    );
  }

  FundData fundB() {
    return FundData(
      isin: 'ES9876543210',
      symbol: 'FUND-B',
      name: 'Fondo B',
      lastValue: 220.0,
      currency: 'EUR',
      date: valuationDate,
      history: [PricePoint(valuationDate, 220.0)],
      operations: [purchase(isin: 'ES9876543210', units: 20, price: 200)],
      costPeriods: [performancePeriod(uid: 'B-P1', rate: 15)],
      costCharges: [
        performanceCharge(uid: 'B-C1', periodUid: 'B-P1', amount: 12),
      ],
    );
  }

  group('LF-107: identidad del fondo y persistencia de costes', () {
    test('LF-107.1: actualizar el mismo ISIN sustituye los costes '
        'sin duplicarlos ni insertar operaciones nuevas', () async {
      final original = fundA();
      await DatabaseService.saveFund(original);

      // Intentamos guardar una versión actualizada del mismo fondo.
      // La operación recibida es distinta de la que ya está persistida.
      final updated = fundA(
        periods: [performancePeriod(uid: 'A-P2', rate: 12)],
        charges: [performanceCharge(uid: 'A-C2', periodUid: 'A-P2', amount: 8)],
        operations: [purchase(isin: 'ES0123456789', units: 99, price: 50)],
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P2');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C2');
      expect(saved.costCharges.single.amount, 8);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P2');

      // saveFund no debe insertar las operaciones recibidas cuando
      // el ISIN ya existe: debe conservar la operación original.
      expect(saved.operations, hasLength(1));
      expect(saved.operations.single.units, 10);
      expect(saved.operations.single.price, 100);
      expect(saved.operations.single.amount, 1000);
    });

    test('LF-107.2: guardar otro ISIN mantiene aislados ambos fondos, '
        'sus costes y sus operaciones', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      expect(savedA!.name, 'Fondo A');
      expect(savedA.costPeriods, hasLength(1));
      expect(savedA.costPeriods.single.uid, 'A-P1');
      expect(savedA.costPeriods.single.ratePercent, 10);
      expect(savedA.costCharges, hasLength(1));
      expect(savedA.costCharges.single.uid, 'A-C1');
      expect(savedA.costCharges.single.performancePeriodUid, 'A-P1');
      expect(savedA.operations, hasLength(1));
      expect(savedA.operations.single.units, 10);

      expect(savedB!.name, 'Fondo B');
      expect(savedB.costPeriods, hasLength(1));
      expect(savedB.costPeriods.single.uid, 'B-P1');
      expect(savedB.costPeriods.single.ratePercent, 15);
      expect(savedB.costCharges, hasLength(1));
      expect(savedB.costCharges.single.uid, 'B-C1');
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P1');
      expect(savedB.operations, hasLength(1));
      expect(savedB.operations.single.units, 20);

      // Repetir la lectura también permite detectar duplicados
      // introducidos al guardar un fondo distinto.
      final portfolio = await DatabaseService.getPortfolio();

      expect(portfolio, hasLength(2));
      expect(portfolio.map((fund) => fund.isin).toSet(), {
        'ES0123456789',
        'ES9876543210',
      });
    });

    test('LF-107.3: costes inválidos del segundo fondo no alteran '
        'el primero ni dejan datos parciales', () async {
      final originalA = fundA();
      await DatabaseService.saveFund(originalA);

      final invalidB = fundB().copyWith(
        costCharges: [
          performanceCharge(
            uid: 'B-C-INVALID',
            periodUid: 'PERIODO-INEXISTENTE',
            amount: 12,
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidB),
        throwsA(isA<ArgumentError>()),
      );

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');
      final portfolio = await DatabaseService.getPortfolio();

      // El fondo A conserva sus datos y costes originales.
      expect(savedA, isNotNull);
      expect(savedA!.name, 'Fondo A');
      expect(savedA.costPeriods, hasLength(1));
      expect(savedA.costPeriods.single.uid, 'A-P1');
      expect(savedA.costCharges, hasLength(1));
      expect(savedA.costCharges.single.uid, 'A-C1');
      expect(savedA.costCharges.single.performancePeriodUid, 'A-P1');
      expect(savedA.operations, hasLength(1));
      expect(savedA.operations.single.units, 10);

      // El fondo B no debe persistirse parcialmente.
      expect(savedB, isNull);
      expect(portfolio.map((fund) => fund.isin).toSet(), {'ES0123456789'});
      expect(portfolio, hasLength(1));
    });

    test('LF-107.4: las referencias de los cargos siguen siendo '
        'válidas tras actualizar y recargar los periodos', () async {
      await DatabaseService.saveFund(fundA());

      final updatedA = fundA().copyWith(
        operations: [
          FundOperation(
            isin: 'ES0123456789',
            date: DateTime(2026, 1, 1),
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'A-P2',
            concept: FundCostConcept.performance,
            ratePercent: 12,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 6, 30),
          ),
          FundCostPeriod(
            uid: 'A-P3',
            concept: FundCostConcept.performance,
            ratePercent: 15,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 7, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'A-C2',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 6, 15),
            amount: 8,
            performancePeriodUid: 'A-P2',
          ),
          FundCostCharge(
            uid: 'A-C3',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 7, 15),
            amount: 3,
            performancePeriodUid: 'A-P3',
          ),
        ],
      );

      await DatabaseService.saveFund(updatedA);

      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.costPeriods.map((period) => period.uid).toSet(), {
        'A-P2',
        'A-P3',
      });
      expect(reloaded.costCharges.map((charge) => charge.uid).toSet(), {
        'A-C2',
        'A-C3',
      });

      final periodsByUid = {
        for (final period in reloaded.costPeriods) period.uid: period,
      };

      for (final charge in reloaded.costCharges) {
        final referencedUid = charge.performancePeriodUid;

        expect(referencedUid, isNotNull);
        expect(periodsByUid.containsKey(referencedUid), isTrue);
        expect(
          periodsByUid[referencedUid]!.concept,
          FundCostConcept.performance,
        );
      }

      expect(
        reloaded.costCharges
            .map((charge) => charge.performancePeriodUid)
            .toSet(),
        {'A-P2', 'A-P3'},
      );
    });
  });

  group('LF-108', () {
    test('LF-108.1: actualizar metadatos y valoración conserva '
        'el origen, los costes y las operaciones', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        name: 'Fondo A actualizado',
        lastValue: 125,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.name, 'Fondo A actualizado');
      expect(saved.lastValue, 125);

      // El origen persistente no debe confundirse con la
      // fuente de la última valoración aceptada.
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      // Los costes y sus referencias deben seguir intactos.
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // Guardar una valoración no debe insertar operaciones nuevas
      // ni modificar las ya persistidas.
      expect(saved.operations, hasLength(1));
      expect(saved.operations.single.units, 10);
      expect(saved.operations.single.price, 100);
      expect(saved.operations.single.amount, 1000);
    });

    test('LF-108.2: actualizar el historial conserva los costes, '
        'sus referencias y las operaciones', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 19), 118),
          PricePoint(DateTime(2026, 10, 20), 121),
          PricePoint(DateTime(2026, 10, 21), 125),
        ],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.valuationSource, FundSource.financialTimes);
      expect(saved.source, FundSource.cnmv);

      // El historial recuperado debe coincidir con el actualizado.
      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);
      expect(saved.history.map((point) => point.price).toList(), [
        118,
        121,
        125,
      ]);

      // Los costes y las referencias se mantienen.
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // La actualización de precios no altera las operaciones.
      expect(saved.operations, hasLength(1));
      expect(saved.operations.single.units, 10);
      expect(saved.operations.single.price, 100);
      expect(saved.operations.single.amount, 1000);
    });
  });

  group('LF-109.', () {
    test('LF-109.1: guardar y recargar conserva la coherencia '
        'entre la valoración actual y el historial', () async {
      final fund = fundA().copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
          PricePoint(DateTime(2026, 10, 21), 125),
        ],
        source: FundSource.cnmv,
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(fund);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));

      expect(saved.history, hasLength(4));
      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);
      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
        125,
      ]);

      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      // La valoración no debe alterar las relaciones de costes.
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // Tampoco debe modificar la operación original.
      expect(saved.operations, hasLength(1));
      expect(saved.operations.single.units, 10);
      expect(saved.operations.single.amount, 1000);
    });

    test('LF-109.2: actualizar la valoración añade el nuevo punto '
        'sin duplicar fechas ni perder el historial anterior', () async {
      final original = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.valuationSource, FundSource.financialTimes);

      expect(saved.history, hasLength(4));

      final dates = saved.history.map((point) => point.date).toList();
      expect(dates.toSet(), hasLength(dates.length));
      expect(dates, [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
        125,
      ]);

      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');
      expect(saved.operations, hasLength(1));
      expect(saved.operations.single.amount, 1000);
    });

    test('LF-109.3: caracteriza una discrepancia entre la valoración '
        'actual y el último punto del historial', () async {
      final fund = fundA().copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      expect(fund.lastValue, 125);
      expect(fund.date, DateTime(2026, 10, 21));

      // _syncHistory incorpora la valoración actual al historial.
      expect(fund.history, hasLength(3));

      expect(fund.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);

      expect(fund.history.map((point) => point.price).toList(), [
        115,
        120,
        125,
      ]);
    });
  });

  group('LF-110.', () {
    test('LF-110.1: actualizar una fecha existente en el historial '
        'no duplica el punto y actualiza su precio', () async {
      final fund = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 118),
        ],
      );

      // La construcción inicial conserva el punto histórico explícito.
      expect(fund.history, hasLength(3));
      expect(fund.history.last.date, DateTime(2026, 10, 20));
      expect(fund.history.last.price, 118);

      final updated = fund.copyWith(
        lastValue: 123,
        date: DateTime(2026, 10, 20),
      );

      expect(updated.lastValue, 123);
      expect(updated.date, DateTime(2026, 10, 20));
      expect(updated.history, hasLength(3));

      final pointsForDate = updated.history
          .where((point) => point.date == DateTime(2026, 10, 20))
          .toList();

      expect(pointsForDate, hasLength(1));
      expect(pointsForDate.single.price, 123);

      // Los puntos históricos anteriores permanecen intactos.
      expect(
        updated.history
            .where((point) => point.date == DateTime(2026, 10, 18))
            .single
            .price,
        110,
      );
      expect(
        updated.history
            .where((point) => point.date == DateTime(2026, 10, 19))
            .single
            .price,
        115,
      );
    });

    test('LF-110.2: actualizar una valoración anterior conserva '
        'los puntos históricos posteriores', () async {
      final fund = fundA().copyWith(
        lastValue: 130,
        date: DateTime(2026, 10, 22),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 20), 120),
          PricePoint(DateTime(2026, 10, 22), 130),
        ],
      );

      // Actualizamos la valoración a una fecha intermedia.
      final updated = fund.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
      );

      expect(updated.lastValue, 125);
      expect(updated.date, DateTime(2026, 10, 21));

      // Caracterizamos si _syncHistory conserva el punto posterior.
      expect(updated.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
      ]);

      expect(updated.history.map((point) => point.price).toList(), [
        110,
        120,
        125,
        130,
      ]);
    });

    test('LF-110.3: repetir la misma actualización mantiene '
        'el historial estable y sin fechas duplicadas', () async {
      final original = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      final firstUpdate = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
      );

      final secondUpdate = firstUpdate.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
      );

      expect(secondUpdate.history, hasLength(firstUpdate.history.length));

      expect(
        secondUpdate.history.map((point) => point.date).toList(),
        firstUpdate.history.map((point) => point.date).toList(),
      );

      expect(
        secondUpdate.history.map((point) => point.price).toList(),
        firstUpdate.history.map((point) => point.price).toList(),
      );

      final dates = secondUpdate.history.map((point) => point.date).toList();
      expect(dates.toSet(), hasLength(dates.length));

      expect(secondUpdate.history.last.date, DateTime(2026, 10, 21));
      expect(secondUpdate.history.last.price, 125);
    });
  });

  group('LF-111.', () {
    test(
      'LF-111.1: guardar dos veces el mismo historial no duplica precios',
      () async {
        final fund = fundA().copyWith(
          lastValue: 120,
          date: DateTime(2026, 10, 20),
          history: [
            PricePoint(DateTime(2026, 10, 18), 110),
            PricePoint(DateTime(2026, 10, 19), 115),
            PricePoint(DateTime(2026, 10, 20), 120),
          ],
        );

        await DatabaseService.saveFund(fund);
        await DatabaseService.saveFund(fund);

        final saved = await DatabaseService.getFund('ES0123456789');

        expect(saved, isNotNull);
        expect(saved!.history, hasLength(3));
        expect(saved.history.map((point) => point.date).toList(), [
          DateTime(2026, 10, 18),
          DateTime(2026, 10, 19),
          DateTime(2026, 10, 20),
        ]);
        expect(saved.history.map((point) => point.price).toList(), [
          110,
          115,
          120,
        ]);
      },
    );

    test(
      'LF-111.2: actualizar una fecha persistida sustituye su precio',
      () async {
        final original = fundA().copyWith(
          lastValue: 120,
          date: DateTime(2026, 10, 20),
          history: [
            PricePoint(DateTime(2026, 10, 18), 110),
            PricePoint(DateTime(2026, 10, 19), 115),
            PricePoint(DateTime(2026, 10, 20), 120),
          ],
        );

        await DatabaseService.saveFund(original);

        final updated = original.copyWith(
          lastValue: 123,
          history: [
            PricePoint(DateTime(2026, 10, 18), 110),
            PricePoint(DateTime(2026, 10, 19), 115),
            PricePoint(DateTime(2026, 10, 20), 123),
          ],
        );

        await DatabaseService.saveFund(updated);

        final saved = await DatabaseService.getFund('ES0123456789');

        expect(saved, isNotNull);
        expect(saved!.history, hasLength(3));

        final pointsForDate = saved.history
            .where((point) => point.date == DateTime(2026, 10, 20))
            .toList();

        expect(pointsForDate, hasLength(1));
        expect(pointsForDate.single.price, 123);
      },
    );

    test('LF-111.3: actualizar una valoración intermedia conserva '
        'los puntos posteriores tras recargar', () async {
      final original = fundA().copyWith(
        lastValue: 130,
        date: DateTime(2026, 10, 22),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 20), 120),
          PricePoint(DateTime(2026, 10, 22), 130),
        ],
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.history, hasLength(4));

      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
      ]);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        120,
        125,
        130,
      ]);
    });

    test('LF-111.4: repetir la misma actualización en SQLite '
        'mantiene el historial estable', () async {
      final original = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
      );

      await DatabaseService.saveFund(updated);
      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.history, hasLength(4));

      final dates = saved.history.map((point) => point.date).toList();
      expect(dates.toSet(), hasLength(dates.length));

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
        125,
      ]);
      expect(saved.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
    });
  });

  group('LF-112.', () {
    test('LF-112.1: guardar puntos fuera de orden los recupera '
        'en orden cronológico', () async {
      final fund = fundA().copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          PricePoint(DateTime(2026, 10, 21), 125),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      await DatabaseService.saveFund(fund);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.history, hasLength(4));

      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
        125,
      ]);
    });

    test('LF-112.2: actualizar la valoración conserva los precios '
        'históricos anteriores', () async {
      final original = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 125)],
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.history, hasLength(4));

      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 18),
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
      ]);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
        125,
      ]);
    });

    test('LF-112.3: actualizar un precio existente sustituye '
        'su valor sin duplicar la fecha', () async {
      final original = fundA().copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 20),
        history: [
          PricePoint(DateTime(2026, 10, 18), 110),
          PricePoint(DateTime(2026, 10, 19), 115),
          PricePoint(DateTime(2026, 10, 20), 120),
        ],
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(lastValue: 123);

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.history, hasLength(3));

      final pointsOnDate = saved.history
          .where((point) => point.date == DateTime(2026, 10, 20))
          .toList();

      expect(pointsOnDate, hasLength(1));
      expect(pointsOnDate.single.price, 123);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        123,
      ]);
    });

    test('LF-112.4: actualizar el historial conserva costes, '
        'operaciones y origen del fondo', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      expect(saved!.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      expect(saved.operations, hasLength(original.operations.length));
      expect(saved.costPeriods, hasLength(original.costPeriods.length));
      expect(saved.costCharges, hasLength(original.costCharges.length));

      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      expect(saved.history.map((point) => point.price).toList(), [110, 125]);
    });
  });

  group('LF-113.', () {
    test('LF-113.1: guardar repetidamente el mismo fondo '
        'no duplica operaciones, periodos ni cargos', () async {
      final fund = fundA();

      await DatabaseService.saveFund(fund);
      await DatabaseService.saveFund(fund);
      await DatabaseService.saveFund(fund);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      expect(saved!.operations, hasLength(fund.operations.length));
      expect(saved.costPeriods, hasLength(fund.costPeriods.length));
      expect(saved.costCharges, hasLength(fund.costCharges.length));

      expect(saved.costPeriods.map((period) => period.uid).toSet(), {'A-P1'});

      expect(saved.costCharges.map((charge) => charge.uid).toSet(), {'A-C1'});

      expect(
        saved.costCharges.single.performancePeriodUid,
        saved.costPeriods.single.uid,
      );

      expect(
        saved.history.map((point) => point.date).toSet().length,
        saved.history.length,
      );
    });

    test('LF-113.2: actualizar varias veces la valoración '
        'conserva las operaciones originales', () async {
      final original = fundA();

      await DatabaseService.saveFund(original);

      final firstUpdate = original.copyWith(
        lastValue: 115,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 115)],
      );

      await DatabaseService.saveFund(firstUpdate);

      final secondUpdate = firstUpdate.copyWith(
        lastValue: 120,
        date: DateTime(2026, 10, 22),
        history: [
          ...firstUpdate.history,
          PricePoint(DateTime(2026, 10, 22), 120),
        ],
      );

      await DatabaseService.saveFund(secondUpdate);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.operations, hasLength(original.operations.length));

      expect(saved.history.map((point) => point.date).toList(), [
        DateTime(2026, 10, 20),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 22),
      ]);

      expect(saved.history.map((point) => point.price).toList(), [
        110,
        115,
        120,
      ]);

      expect(saved.lastValue, 120);
      expect(saved.date, DateTime(2026, 10, 22));
    });

    test('LF-113.3: modificar costes conserva las referencias '
        'entre cargos y periodos tras guardar y recargar', () async {
      final original = fundA();

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
        costCharges: [
          performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
        ],
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.costPeriods, hasLength(1));
      expect(saved.costCharges, hasLength(1));

      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      expect(saved.operations, hasLength(original.operations.length));
    });

    test('LF-113.4: guardar y recargar repetidamente conserva '
        'la identidad y los datos asociados', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      var current = await DatabaseService.getFund('ES0123456789');
      expect(current, isNotNull);

      await DatabaseService.saveFund(current!);

      current = await DatabaseService.getFund('ES0123456789');
      expect(current, isNotNull);

      await DatabaseService.saveFund(current!);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.isin, original.isin);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);

      expect(saved.operations, hasLength(original.operations.length));
      expect(saved.costPeriods, hasLength(original.costPeriods.length));
      expect(saved.costCharges, hasLength(original.costCharges.length));

      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      expect(
        saved.history.map((point) => point.date).toSet().length,
        saved.history.length,
      );

      expect(
        saved.history.map((point) => point.price).toList(),
        original.history.map((point) => point.price).toList(),
      );
    });
  });

  group('LF-114.', () {
    test('LF-114.1: actualizar solo la valoración conserva '
        'los costes y las operaciones', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // La valoración se actualiza.
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.valuationSource, FundSource.financialTimes);

      // El origen persistente del fondo no cambia.
      expect(saved.source, FundSource.cnmv);

      // Las operaciones originales se conservan.
      expect(saved.operations, hasLength(original.operations.length));

      // Los costes y sus identificadores se conservan.
      expect(saved.costPeriods, hasLength(original.costPeriods.length));
      expect(saved.costCharges, hasLength(original.costCharges.length));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // El historial incorpora la nueva valoración sin perder los puntos previos.
      expect(saved.history.map((point) => point.price).toList(), [110, 125]);
    });

    test('LF-114.2: actualizar solo los costes conserva '
        'la valoración, el historial y las fuentes', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
        costCharges: [
          performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
        ],
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // La valoración y sus metadatos permanecen intactos.
      expect(saved!.lastValue, original.lastValue);
      expect(saved.date, original.date);
      expect(saved.valuationSource, FundSource.yahoo);
      expect(saved.source, FundSource.cnmv);

      // El historial mantiene sus fechas y precios.
      expect(
        saved.history.map((point) => point.date).toList(),
        original.history.map((point) => point.date).toList(),
      );
      expect(
        saved.history.map((point) => point.price).toList(),
        original.history.map((point) => point.price).toList(),
      );

      // Los costes modificados se persisten con sus referencias.
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // Las operaciones no se modifican.
      expect(saved.operations, hasLength(original.operations.length));
    });

    test('LF-114.3: cambiar nombre y símbolo conserva '
        'la identidad del fondo por ISIN', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        name: 'Fondo A Actualizado',
        symbol: 'FUND-A-NEW',
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // La identidad persistente no cambia.
      expect(saved!.isin, original.isin);

      // Los datos descriptivos se actualizan.
      expect(saved.name, 'Fondo A Actualizado');
      expect(saved.symbol, 'FUND-A-NEW');

      // Las valoraciones y fuentes se conservan.
      expect(saved.lastValue, original.lastValue);
      expect(saved.date, original.date);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);

      // Los datos asociados siguen intactos.
      expect(saved.operations, hasLength(original.operations.length));
      expect(saved.costPeriods, hasLength(original.costPeriods.length));
      expect(saved.costCharges, hasLength(original.costCharges.length));

      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // El fondo no se ha duplicado con otro ISIN.
      final otherFund = await DatabaseService.getFund('ES9876543210');
      expect(otherFund, isNull);
    });

    test('LF-114.4: una actualización combinada conserva '
        'todos los datos no modificados', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final updated = original.copyWith(
        name: 'Fondo A Revisado',
        symbol: 'FUND-A-R',
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...original.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
        costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
        costCharges: [
          performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
        ],
      );

      await DatabaseService.saveFund(updated);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // Identidad y datos descriptivos.
      expect(saved!.isin, original.isin);
      expect(saved.name, 'Fondo A Revisado');
      expect(saved.symbol, 'FUND-A-R');

      // Valoración y fuentes.
      expect(saved.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      // Historial previo más la nueva valoración.
      expect(saved.history.map((point) => point.price).toList(), [110, 125]);

      // Operaciones originales conservadas.
      expect(saved.operations, hasLength(original.operations.length));

      // Costes modificados y referencias válidas.
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');
    });
  });

  group('LF-115.', () {
    test('LF-115.1: dos actualizaciones parciales consecutivas '
        'conservan los cambios de ambas', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      // Primera actualización: modifica los datos descriptivos.
      final firstUpdate = original.copyWith(
        name: 'Fondo A Actualizado',
        symbol: 'FUND-A-NEW',
      );

      await DatabaseService.saveFund(firstUpdate);

      // Recargamos el estado persistido antes de la segunda actualización.
      final reloaded = await DatabaseService.getFund('ES0123456789');
      expect(reloaded, isNotNull);

      // Segunda actualización: modifica la valoración.
      final secondUpdate = reloaded!.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...reloaded.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(secondUpdate);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // Se conservan los cambios de la primera actualización.
      expect(saved!.name, 'Fondo A Actualizado');
      expect(saved.symbol, 'FUND-A-NEW');

      // También se conservan los cambios de la segunda.
      expect(saved.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.valuationSource, FundSource.financialTimes);

      // El origen persistente no cambia.
      expect(saved.source, FundSource.cnmv);

      // Los datos asociados permanecen intactos.
      expect(saved.operations, hasLength(original.operations.length));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      expect(saved.history.map((point) => point.price).toList(), [110, 125]);
    });

    test('LF-115.2: actualizar costes después del nombre y símbolo '
        'conserva los cambios descriptivos', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      final descriptiveUpdate = original.copyWith(
        name: 'Fondo A Actualizado',
        symbol: 'FUND-A-NEW',
      );

      await DatabaseService.saveFund(descriptiveUpdate);

      final reloaded = await DatabaseService.getFund('ES0123456789');
      expect(reloaded, isNotNull);

      final costUpdate = reloaded!.copyWith(
        costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
        costCharges: [
          performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
        ],
      );

      await DatabaseService.saveFund(costUpdate);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // Los datos descriptivos siguen actualizados.
      expect(saved!.name, 'Fondo A Actualizado');
      expect(saved.symbol, 'FUND-A-NEW');
      expect(saved.isin, original.isin);

      // Los costes nuevos se conservan.
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // Valoración, fuentes, historial y operaciones intactos.
      expect(saved.lastValue, original.lastValue);
      expect(saved.date, original.date);
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.yahoo);

      expect(
        saved.history.map((point) => point.price).toList(),
        original.history.map((point) => point.price).toList(),
      );

      expect(saved.operations, hasLength(original.operations.length));
    });

    test('LF-115.3: actualizar la valoración después de modificar '
        'los costes conserva los costes nuevos', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      // Primera actualización: modifica los costes.
      final costUpdate = original.copyWith(
        costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
        costCharges: [
          performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
        ],
      );

      await DatabaseService.saveFund(costUpdate);

      final reloaded = await DatabaseService.getFund('ES0123456789');
      expect(reloaded, isNotNull);

      // Segunda actualización: modifica la valoración.
      final valuationUpdate = reloaded!.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [...reloaded.history, PricePoint(DateTime(2026, 10, 21), 125)],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(valuationUpdate);

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);

      // La valoración y sus fuentes quedan actualizadas.
      expect(saved!.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      // Los costes modificados sobreviven a la actualización.
      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');

      // Operaciones e historial previo conservados.
      expect(saved.operations, hasLength(original.operations.length));
      expect(saved.history.map((point) => point.price).toList(), [110, 125]);
    });

    test('LF-115.4: una secuencia completa de actualizaciones '
        'conserva el estado final del fondo', () async {
      final original = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      await DatabaseService.saveFund(original);

      // Paso 1: actualizar nombre y símbolo.
      await DatabaseService.saveFund(
        original.copyWith(name: 'Fondo A Revisado', symbol: 'FUND-A-R'),
      );

      var current = await DatabaseService.getFund('ES0123456789');
      expect(current, isNotNull);

      // Paso 2: actualizar costes sobre el estado recargado.
      await DatabaseService.saveFund(
        current!.copyWith(
          costPeriods: [performancePeriod(uid: 'A-P1', rate: 12)],
          costCharges: [
            performanceCharge(uid: 'A-C1', periodUid: 'A-P1', amount: 7),
          ],
        ),
      );

      current = await DatabaseService.getFund('ES0123456789');
      expect(current, isNotNull);

      // Paso 3: actualizar valoración sobre el estado recargado.
      await DatabaseService.saveFund(
        current!.copyWith(
          lastValue: 125,
          date: DateTime(2026, 10, 21),
          history: [
            ...current.history,
            PricePoint(DateTime(2026, 10, 21), 125),
          ],
          valuationSource: FundSource.financialTimes,
        ),
      );

      // Recarga final: validar el estado persistido.
      final saved = await DatabaseService.getFund('ES0123456789');
      expect(saved, isNotNull);

      expect(saved!.isin, original.isin);
      expect(saved.name, 'Fondo A Revisado');
      expect(saved.symbol, 'FUND-A-R');

      expect(saved.lastValue, 125);
      expect(saved.date, DateTime(2026, 10, 21));
      expect(saved.source, FundSource.cnmv);
      expect(saved.valuationSource, FundSource.financialTimes);

      expect(saved.history.map((point) => point.price).toList(), [110, 125]);

      expect(saved.operations, hasLength(original.operations.length));

      expect(saved.costPeriods, hasLength(1));
      expect(saved.costPeriods.single.uid, 'A-P1');
      expect(saved.costPeriods.single.ratePercent, 12);

      expect(saved.costCharges, hasLength(1));
      expect(saved.costCharges.single.uid, 'A-C1');
      expect(saved.costCharges.single.amount, 7);
      expect(saved.costCharges.single.performancePeriodUid, 'A-P1');
    });
  });

  group('LF-116.', () {
    test('LF-116.1: actualizar la valoración de A no modifica '
        'la valoración ni los datos de B', () async {
      final fundAOriginal = fundA().copyWith(
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );
      final fundBOriginal = fundB().copyWith(
        source: FundSource.ecb,
        valuationSource: FundSource.morningstar,
      );

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      final updatedA = fundAOriginal.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          ...fundAOriginal.history,
          PricePoint(DateTime(2026, 10, 21), 125),
        ],
        valuationSource: FundSource.financialTimes,
      );

      await DatabaseService.saveFund(updatedA);

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // A contiene la nueva valoración.
      expect(savedA!.lastValue, 125);
      expect(savedA.date, DateTime(2026, 10, 21));
      expect(savedA.source, FundSource.cnmv);
      expect(savedA.valuationSource, FundSource.financialTimes);

      // B conserva su identidad y valoración.
      expect(savedB!.isin, fundBOriginal.isin);
      expect(savedB.lastValue, fundBOriginal.lastValue);
      expect(savedB.date, fundBOriginal.date);
      expect(savedB.source, FundSource.ecb);
      expect(savedB.valuationSource, FundSource.morningstar);

      // Las entidades asociadas a B permanecen intactas.
      expect(savedB.operations.length, fundBOriginal.operations.length);
      expect(savedB.costPeriods.single.uid, 'B-P1');
      expect(savedB.costCharges.single.uid, 'B-C1');
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P1');

      expect(
        savedB.history.map((point) => point.price).toList(),
        fundBOriginal.history.map((point) => point.price).toList(),
      );
    });

    test('LF-116.2: modificar los costes de A no altera los costes '
        'ni las referencias de B', () async {
      final fundAOriginal = fundA();
      final fundBOriginal = fundB();

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      final updatedA = fundAOriginal.copyWith(
        costPeriods: [performancePeriod(uid: 'A-P2', rate: 20)],
        costCharges: [
          performanceCharge(uid: 'A-C2', periodUid: 'A-P2', amount: 9),
        ],
      );

      await DatabaseService.saveFund(updatedA);

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // Los costes de A se han actualizado.
      expect(savedA!.costPeriods, hasLength(1));
      expect(savedA.costPeriods.single.uid, 'A-P2');
      expect(savedA.costPeriods.single.ratePercent, 20);
      expect(savedA.costCharges, hasLength(1));
      expect(savedA.costCharges.single.uid, 'A-C2');
      expect(savedA.costCharges.single.performancePeriodUid, 'A-P2');
      expect(savedA.costCharges.single.amount, 9);

      // Los costes de B siguen siendo independientes.
      expect(savedB!.costPeriods, hasLength(1));
      expect(savedB.costPeriods.single.uid, 'B-P1');
      expect(savedB.costPeriods.single.ratePercent, 15);

      expect(savedB.costCharges, hasLength(1));
      expect(savedB.costCharges.single.uid, 'B-C1');
      expect(savedB.costCharges.single.amount, 12);
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P1');

      // La actualización de costes de A no cambia el resto de B.
      expect(savedB.isin, fundBOriginal.isin);
      expect(savedB.name, fundBOriginal.name);
      expect(savedB.symbol, fundBOriginal.symbol);
      expect(savedB.lastValue, fundBOriginal.lastValue);
      expect(savedB.date, fundBOriginal.date);
      expect(
        savedB.history.map((point) => point.price).toList(),
        fundBOriginal.history.map((point) => point.price).toList(),
      );
      expect(savedB.operations.length, fundBOriginal.operations.length);
    });

    test('LF-116.3: cambiar nombre y símbolo de A no afecta '
        'a la identidad de B', () async {
      final fundAOriginal = fundA();
      final fundBOriginal = fundB();

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      final updatedA = fundAOriginal.copyWith(
        name: 'Fondo A Actualizado',
        symbol: 'FUND-A-NEW',
      );

      await DatabaseService.saveFund(updatedA);

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // A conserva su ISIN y recibe los cambios descriptivos.
      expect(savedA!.isin, fundAOriginal.isin);
      expect(savedA.name, 'Fondo A Actualizado');
      expect(savedA.symbol, 'FUND-A-NEW');

      // B conserva su identidad y sus datos descriptivos.
      expect(savedB!.isin, fundBOriginal.isin);
      expect(savedB.name, fundBOriginal.name);
      expect(savedB.symbol, fundBOriginal.symbol);
      expect(savedB.lastValue, fundBOriginal.lastValue);
      expect(savedB.date, fundBOriginal.date);

      // Las relaciones y los datos asociados de B permanecen intactos.
      expect(savedB.operations.length, fundBOriginal.operations.length);
      expect(savedB.costPeriods.single.uid, 'B-P1');
      expect(savedB.costCharges.single.uid, 'B-C1');
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P1');

      expect(
        savedB.history.map((point) => point.price).toList(),
        fundBOriginal.history.map((point) => point.price).toList(),
      );
    });

    test('LF-116.4: alternar actualizaciones de A y B conserva '
        'el estado final de ambos fondos', () async {
      final fundAOriginal = fundA();
      final fundBOriginal = fundB();

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      // 1. Actualizamos la valoración de A.
      final updatedA1 = fundAOriginal.copyWith(
        lastValue: 125,
        date: DateTime(2026, 10, 21),
        history: [
          ...fundAOriginal.history,
          PricePoint(DateTime(2026, 10, 21), 125),
        ],
        valuationSource: FundSource.yahoo,
      );
      await DatabaseService.saveFund(updatedA1);

      // 2. Actualizamos los costes de B.
      final updatedB1 = fundBOriginal.copyWith(
        costPeriods: [performancePeriod(uid: 'B-P2', rate: 18)],
        costCharges: [
          performanceCharge(uid: 'B-C2', periodUid: 'B-P2', amount: 14),
        ],
      );
      await DatabaseService.saveFund(updatedB1);

      // 3. Cambiamos la identidad descriptiva de A.
      final updatedA2 = updatedA1.copyWith(
        name: 'Fondo A Final',
        symbol: 'FUND-A-FINAL',
      );
      await DatabaseService.saveFund(updatedA2);

      // 4. Actualizamos la valoración de B.
      final updatedB2 = updatedB1.copyWith(
        lastValue: 235,
        date: DateTime(2026, 10, 22),
        history: [
          ...updatedB1.history,
          PricePoint(DateTime(2026, 10, 22), 235),
        ],
        valuationSource: FundSource.financialTimes,
      );
      await DatabaseService.saveFund(updatedB2);

      // 5. Recargamos ambos fondos desde SQLite.
      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // Estado final de A.
      expect(savedA!.isin, fundAOriginal.isin);
      expect(savedA.name, 'Fondo A Final');
      expect(savedA.symbol, 'FUND-A-FINAL');
      expect(savedA.lastValue, 125);
      expect(savedA.date, DateTime(2026, 10, 21));
      expect(savedA.valuationSource, FundSource.yahoo);
      expect(savedA.costPeriods.single.uid, 'A-P1');
      expect(savedA.costCharges.single.uid, 'A-C1');
      expect(savedA.costCharges.single.performancePeriodUid, 'A-P1');

      // Estado final de B.
      expect(savedB!.isin, fundBOriginal.isin);
      expect(savedB.name, fundBOriginal.name);
      expect(savedB.symbol, fundBOriginal.symbol);
      expect(savedB.lastValue, 235);
      expect(savedB.date, DateTime(2026, 10, 22));
      expect(savedB.valuationSource, FundSource.financialTimes);

      expect(savedB.costPeriods, hasLength(1));
      expect(savedB.costPeriods.single.uid, 'B-P2');
      expect(savedB.costPeriods.single.ratePercent, 18);

      expect(savedB.costCharges, hasLength(1));
      expect(savedB.costCharges.single.uid, 'B-C2');
      expect(savedB.costCharges.single.amount, 14);
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P2');

      // Los historiales de ambos fondos siguen siendo independientes.
      expect(savedA.history.map((point) => point.price).toList(), [110, 125]);
      expect(savedB.history.map((point) => point.price).toList(), [220, 235]);

      // Las operaciones originales no se duplican ni se pierden.
      expect(savedA.operations.length, fundAOriginal.operations.length);
      expect(savedB.operations.length, fundBOriginal.operations.length);
    });
  });

  group('LF-117.', () {
    test('LF-117.1: añadir operaciones a A no modifica '
        'las operaciones de B', () async {
      final fundAOriginal = fundA();
      final fundBOriginal = fundB();

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      final persistedA = await DatabaseService.getFund(fundAOriginal.isin);
      final persistedB = await DatabaseService.getFund(fundBOriginal.isin);

      expect(persistedA, isNotNull);
      expect(persistedB, isNotNull);

      expect(
        persistedA!.operations,
        hasLength(fundAOriginal.operations.length),
      );
      expect(
        persistedB!.operations,
        hasLength(fundBOriginal.operations.length),
      );

      final originalBOperations = persistedB.operations
          .map(
            (operation) => (
              id: operation.id,
              isin: operation.isin,
              date: operation.date,
              type: operation.type,
              units: operation.units,
              price: operation.price,
              amount: operation.amount,
            ),
          )
          .toList();

      // Añadir una operación nueva exclusivamente al fondo A.
      await DatabaseService.saveOperation(
        purchase(isin: fundAOriginal.isin, units: 3, price: 105),
      );

      final savedA = await DatabaseService.getFund(fundAOriginal.isin);
      final savedB = await DatabaseService.getFund(fundBOriginal.isin);

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      // A tiene una operación adicional.
      expect(
        savedA!.operations,
        hasLength(fundAOriginal.operations.length + 1),
      );

      final addedOperation = savedA.operations.singleWhere(
        (operation) => operation.units == 3 && operation.price == 105,
      );

      expect(addedOperation.id, isNotNull);
      expect(addedOperation.isin, fundAOriginal.isin);
      expect(addedOperation.units, 3);
      expect(addedOperation.price, 105);

      // B conserva exactamente sus operaciones originales.
      expect(savedB!.operations, hasLength(originalBOperations.length));

      for (var i = 0; i < originalBOperations.length; i++) {
        final original = originalBOperations[i];
        final saved = savedB.operations[i];

        expect(saved.id, original.id);
        expect(saved.isin, original.isin);
        expect(saved.date, original.date);
        expect(saved.type, original.type);
        expect(saved.units, original.units);
        expect(saved.price, original.price);
        expect(saved.amount, original.amount);
      }

      // Los costes y sus referencias de B tampoco cambian.
      expect(savedB.costPeriods.single.uid, 'B-P1');
      expect(savedB.costCharges.single.uid, 'B-C1');
      expect(savedB.costCharges.single.performancePeriodUid, 'B-P1');
    });

    test('LF-117.2: guardar de nuevo un fondo recuperado '
        'no duplica sus operaciones existentes', () async {
      final original = fundA();

      await DatabaseService.saveFund(original);

      final persisted = await DatabaseService.getFund(original.isin);
      expect(persisted, isNotNull);
      expect(persisted!.operations, hasLength(original.operations.length));
      expect(
        persisted.operations.every((operation) => operation.id != null),
        isTrue,
      );

      await DatabaseService.saveFund(persisted);

      final reloaded = await DatabaseService.getFund(original.isin);

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(original.operations.length));
      expect(
        reloaded.operations.map((operation) => operation.id).toSet(),
        persisted.operations.map((operation) => operation.id).toSet(),
      );
    });
  });

  group('LF-118: identidad e integridad de operaciones', () {
    test(
      'LF-118.1: actualizar una operación por id no crea duplicados',
      () async {
        await DatabaseService.saveFund(fundA());

        final persisted = await DatabaseService.getFund('ES0123456789');
        expect(persisted, isNotNull);
        expect(persisted!.operations, hasLength(1));

        final original = persisted.operations.single;
        expect(original.id, isNotNull);

        await DatabaseService.saveOperation(
          FundOperation(
            id: original.id,
            isin: original.isin,
            date: original.date,
            type: original.type,
            units: 12,
            price: 105,
            amount: 1260,
          ),
        );

        final saved = await DatabaseService.getFund('ES0123456789');

        expect(saved, isNotNull);
        expect(saved!.operations, hasLength(1));
        expect(saved.operations.single.id, original.id);
        expect(saved.operations.single.units, 12);
        expect(saved.operations.single.price, 105);
        expect(saved.operations.single.amount, 1260);
      },
    );

    test('LF-118.2: actualizar una operación conserva las demás '
        'operaciones del mismo fondo', () async {
      final first = purchase(isin: 'ES0123456789', units: 10, price: 100);
      final second = FundOperation(
        isin: 'ES0123456789',
        date: DateTime(2026, 10, 5),
        type: OperationType.buy,
        units: 4,
        price: 90,
        amount: 360,
      );

      await DatabaseService.saveFund(fundA(operations: [first, second]));

      final persisted = await DatabaseService.getFund('ES0123456789');
      expect(persisted, isNotNull);
      expect(persisted!.operations, hasLength(2));

      final operationToUpdate = persisted.operations.firstWhere(
        (operation) => operation.units == 10,
      );
      final untouched = persisted.operations.firstWhere(
        (operation) => operation.units == 4,
      );

      await DatabaseService.saveOperation(
        FundOperation(
          id: operationToUpdate.id,
          isin: operationToUpdate.isin,
          date: operationToUpdate.date,
          type: operationToUpdate.type,
          units: 11,
          price: 101,
          amount: 1111,
        ),
      );

      final saved = await DatabaseService.getFund('ES0123456789');

      expect(saved, isNotNull);
      expect(saved!.operations, hasLength(2));

      final updated = saved.operations.singleWhere(
        (operation) => operation.id == operationToUpdate.id,
      );
      final preserved = saved.operations.singleWhere(
        (operation) => operation.id == untouched.id,
      );

      expect(updated.units, 11);
      expect(updated.price, 101);
      expect(updated.amount, 1111);

      expect(preserved.units, 4);
      expect(preserved.price, 90);
      expect(preserved.amount, 360);
    });

    test(
      'LF-118.3: insertar una operación nueva asigna un id persistente',
      () async {
        await DatabaseService.saveFund(fundA());

        final newOperation = purchase(
          isin: 'ES0123456789',
          units: 3,
          price: 105,
        );

        expect(newOperation.id, isNull);

        await DatabaseService.saveOperation(newOperation);

        final firstReload = await DatabaseService.getFund('ES0123456789');

        expect(firstReload, isNotNull);
        expect(firstReload!.operations, hasLength(2));

        final inserted = firstReload.operations.singleWhere(
          (operation) => operation.units == 3 && operation.price == 105,
        );

        expect(inserted.id, isNotNull);
        expect(inserted.amount, 315);

        final secondReload = await DatabaseService.getFund('ES0123456789');

        expect(secondReload, isNotNull);
        expect(secondReload!.operations, hasLength(2));

        final reloadedInserted = secondReload.operations.singleWhere(
          (operation) => operation.id == inserted.id,
        );

        expect(reloadedInserted.units, 3);
        expect(reloadedInserted.price, 105);
        expect(reloadedInserted.amount, 315);
      },
    );

    test('LF-118.4: actualizar una operación no modifica otro fondo', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final persistedA = await DatabaseService.getFund('ES0123456789');
      final persistedB = await DatabaseService.getFund('ES9876543210');

      expect(persistedA, isNotNull);
      expect(persistedB, isNotNull);

      final operationA = persistedA!.operations.single;
      final operationB = persistedB!.operations.single;

      await DatabaseService.saveOperation(
        FundOperation(
          id: operationA.id,
          isin: operationA.isin,
          date: operationA.date,
          type: operationA.type,
          units: 15,
          price: 110,
          amount: 1650,
        ),
      );

      final savedA = await DatabaseService.getFund('ES0123456789');
      final savedB = await DatabaseService.getFund('ES9876543210');

      expect(savedA, isNotNull);
      expect(savedB, isNotNull);

      expect(savedA!.operations, hasLength(1));
      expect(savedA.operations.single.id, operationA.id);
      expect(savedA.operations.single.units, 15);
      expect(savedA.operations.single.amount, 1650);

      expect(savedB!.operations, hasLength(1));
      expect(savedB.operations.single.id, operationB.id);
      expect(savedB.operations.single.isin, operationB.isin);
      expect(savedB.operations.single.units, operationB.units);
      expect(savedB.operations.single.price, operationB.price);
      expect(savedB.operations.single.amount, operationB.amount);
    });

    test('LF-118.5: una operación actualizada conserva su id tras '
        'guardar y recargar repetidamente', () async {
      await DatabaseService.saveFund(fundA());

      final persisted = await DatabaseService.getFund('ES0123456789');
      expect(persisted, isNotNull);

      final original = persisted!.operations.single;
      final originalId = original.id;
      expect(originalId, isNotNull);

      final updated = FundOperation(
        id: originalId,
        isin: original.isin,
        date: DateTime(2026, 10, 2),
        type: original.type,
        units: 14,
        price: 95,
        amount: 1330,
      );

      await DatabaseService.saveOperation(updated);

      var reloaded = await DatabaseService.getFund('ES0123456789');
      expect(reloaded, isNotNull);

      final afterFirstUpdate = reloaded!.operations.single;
      expect(afterFirstUpdate.id, originalId);
      expect(afterFirstUpdate.date, DateTime(2026, 10, 2));
      expect(afterFirstUpdate.units, 14);
      expect(afterFirstUpdate.price, 95);
      expect(afterFirstUpdate.amount, 1330);

      await DatabaseService.saveOperation(afterFirstUpdate);

      reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(1));
      expect(reloaded.operations.single.id, originalId);
      expect(reloaded.operations.single.date, DateTime(2026, 10, 2));
      expect(reloaded.operations.single.units, 14);
      expect(reloaded.operations.single.price, 95);
      expect(reloaded.operations.single.amount, 1330);
    });
  });

  group('LF-119: integridad de identidad de operaciones', () {
    test(
      'LF-119.1: actualizar con un id inexistente no inserta una operación',
      () async {
        await DatabaseService.saveFund(fundA());

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(1));

        final original = before.operations.single;
        expect(original.id, isNotNull);

        await DatabaseService.saveOperation(
          FundOperation(
            id: 999999,
            isin: 'ES0123456789',
            date: DateTime(2026, 10, 15),
            type: OperationType.buy,
            units: 7,
            price: 95,
            amount: 665,
          ),
        );

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(
          after!.operations,
          hasLength(1),
          reason: 'Un id inexistente no debe provocar una inserción.',
        );

        final persisted = after.operations.single;

        expect(persisted.id, original.id);
        expect(persisted.units, original.units);
        expect(persisted.price, original.price);
        expect(persisted.amount, original.amount);
      },
    );

    test(
      'LF-119.2: un id de B no permite modificar su operación desde A',
      () async {
        await DatabaseService.saveFund(fundA());
        await DatabaseService.saveFund(fundB());

        final beforeA = await DatabaseService.getFund('ES0123456789');
        final beforeB = await DatabaseService.getFund('ES9876543210');

        expect(beforeA, isNotNull);
        expect(beforeB, isNotNull);
        expect(beforeA!.operations, hasLength(1));
        expect(beforeB!.operations, hasLength(1));

        final operationA = beforeA.operations.single;
        final operationB = beforeB.operations.single;

        expect(operationA.id, isNotNull);
        expect(operationB.id, isNotNull);
        expect(operationA.id, isNot(operationB.id));

        // Se intenta actualizar la operación de B indicando el ISIN de A.
        await DatabaseService.saveOperation(
          FundOperation(
            id: operationB.id,
            isin: 'ES0123456789',
            date: operationB.date,
            type: operationB.type,
            units: 99,
            price: 999,
            amount: 98901,
          ),
        );

        final afterA = await DatabaseService.getFund('ES0123456789');
        final afterB = await DatabaseService.getFund('ES9876543210');

        expect(afterA, isNotNull);
        expect(afterB, isNotNull);

        // A debe conservar su operación original.
        expect(afterA!.operations, hasLength(1));
        expect(afterA.operations.single.id, operationA.id);
        expect(afterA.operations.single.units, operationA.units);
        expect(afterA.operations.single.price, operationA.price);
        expect(afterA.operations.single.amount, operationA.amount);

        // B tampoco debe aceptar una operación reasignada a A.
        expect(afterB!.operations, hasLength(1));
        expect(afterB.operations.single.id, operationB.id);
        expect(afterB.operations.single.isin, 'ES9876543210');
        expect(afterB.operations.single.units, operationB.units);
        expect(afterB.operations.single.price, operationB.price);
        expect(afterB.operations.single.amount, operationB.amount);
      },
    );

    test(
      'LF-119.3: una operación eliminada no reaparece al recargar el fondo',
      () async {
        final first = purchase(isin: 'ES0123456789', units: 10, price: 100);

        final second = FundOperation(
          isin: 'ES0123456789',
          date: DateTime(2026, 10, 5),
          type: OperationType.buy,
          units: 4,
          price: 90,
          amount: 360,
        );

        await DatabaseService.saveFund(fundA(operations: [first, second]));

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(2));

        final deleted = before.operations.singleWhere(
          (operation) => operation.units == 10,
        );
        final preserved = before.operations.singleWhere(
          (operation) => operation.units == 4,
        );

        expect(deleted.id, isNotNull);
        expect(preserved.id, isNotNull);
        expect(deleted.id, isNot(preserved.id));

        await DatabaseService.deleteOperation(deleted.id!);

        final afterFirstDelete = await DatabaseService.getFund('ES0123456789');

        expect(afterFirstDelete, isNotNull);
        expect(afterFirstDelete!.operations, hasLength(1));
        expect(afterFirstDelete.operations.single.id, preserved.id);
        expect(afterFirstDelete.operations.single.units, 4);
        expect(afterFirstDelete.operations.single.price, 90);
        expect(afterFirstDelete.operations.single.amount, 360);

        // Una segunda lectura confirma que la eliminación persiste.
        final afterSecondRead = await DatabaseService.getFund('ES0123456789');

        expect(afterSecondRead, isNotNull);
        expect(afterSecondRead!.operations, hasLength(1));
        expect(afterSecondRead.operations.single.id, preserved.id);
        expect(
          afterSecondRead.operations.any(
            (operation) => operation.id == deleted.id,
          ),
          isFalse,
        );
      },
    );

    test('LF-119.4: eliminar una operación no modifica otro fondo', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);
      expect(beforeA!.operations, hasLength(1));
      expect(beforeB!.operations, hasLength(1));

      final operationA = beforeA.operations.single;
      final operationB = beforeB.operations.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      await DatabaseService.deleteOperation(operationA.id!);

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      // A ya no debe tener la operación eliminada.
      expect(afterA!.operations, isEmpty);

      // B debe conservar su operación y todos sus datos.
      expect(afterB!.operations, hasLength(1));
      expect(afterB.operations.single.id, operationB.id);
      expect(afterB.operations.single.isin, operationB.isin);
      expect(afterB.operations.single.units, operationB.units);
      expect(afterB.operations.single.price, operationB.price);
      expect(afterB.operations.single.amount, operationB.amount);
    });

    test('LF-119.5: una operación nueva tras eliminar otra recibe una identidad nueva', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final original = before.operations.single;
      expect(original.id, isNotNull);

      await DatabaseService.deleteOperation(original.id!);

      final afterDelete = await DatabaseService.getFund('ES0123456789');

      expect(afterDelete, isNotNull);
      expect(afterDelete!.operations, isEmpty);

      final replacement = purchase(isin: 'ES0123456789', units: 3, price: 105);

      await DatabaseService.saveOperation(replacement);

      final afterInsert = await DatabaseService.getFund('ES0123456789');

      expect(afterInsert, isNotNull);
      expect(afterInsert!.operations, hasLength(1));

      final inserted = afterInsert.operations.single;

      expect(inserted.id, isNotNull);
      expect(
        inserted.id,
        isNot(original.id),
        reason: 'La nueva operación no debe reutilizar la identidad eliminada.',
      );
      expect(inserted.isin, original.isin);
      expect(inserted.units, 3);
      expect(inserted.price, 105);
      expect(inserted.amount, 315);

      // Verificar que la nueva identidad sigue siendo estable.
      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(1));
      expect(reloaded.operations.single.id, inserted.id);
      expect(reloaded.operations.single.units, 3);
      expect(reloaded.operations.single.amount, 315);
    });
  });

  group('LF-120: robustez de eliminación de operaciones', () {
    test(
      'LF-120.1: eliminar un id inexistente no modifica las operaciones',
      () async {
        await DatabaseService.saveFund(fundA());
        await DatabaseService.saveFund(fundB());

        final beforeA = await DatabaseService.getFund('ES0123456789');
        final beforeB = await DatabaseService.getFund('ES9876543210');

        expect(beforeA, isNotNull);
        expect(beforeB, isNotNull);
        expect(beforeA!.operations, hasLength(1));
        expect(beforeB!.operations, hasLength(1));

        final operationA = beforeA.operations.single;
        final operationB = beforeB.operations.single;

        await DatabaseService.deleteOperation(999999);

        final afterA = await DatabaseService.getFund('ES0123456789');
        final afterB = await DatabaseService.getFund('ES9876543210');

        expect(afterA, isNotNull);
        expect(afterB, isNotNull);

        expect(afterA!.operations, hasLength(1));
        expect(afterA.operations.single.id, operationA.id);
        expect(afterA.operations.single.units, operationA.units);
        expect(afterA.operations.single.price, operationA.price);
        expect(afterA.operations.single.amount, operationA.amount);

        expect(afterB!.operations, hasLength(1));
        expect(afterB.operations.single.id, operationB.id);
        expect(afterB.operations.single.units, operationB.units);
        expect(afterB.operations.single.price, operationB.price);
        expect(afterB.operations.single.amount, operationB.amount);
      },
    );

    test(
      'LF-120.2: eliminar dos veces la misma operación conserva las demás',
      () async {
        final first = purchase(isin: 'ES0123456789', units: 10, price: 100);

        final second = FundOperation(
          isin: 'ES0123456789',
          date: DateTime(2026, 10, 5),
          type: OperationType.buy,
          units: 4,
          price: 90,
          amount: 360,
        );

        await DatabaseService.saveFund(fundA(operations: [first, second]));

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(2));

        final deleted = before.operations.singleWhere(
          (operation) => operation.units == 10,
        );
        final preserved = before.operations.singleWhere(
          (operation) => operation.units == 4,
        );

        expect(deleted.id, isNotNull);
        expect(preserved.id, isNotNull);

        await DatabaseService.deleteOperation(deleted.id!);
        await DatabaseService.deleteOperation(deleted.id!);

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(1));

        final remaining = after.operations.single;

        expect(remaining.id, preserved.id);
        expect(remaining.isin, preserved.isin);
        expect(remaining.units, 4);
        expect(remaining.price, 90);
        expect(remaining.amount, 360);
      },
    );

    test(
      'LF-120.3: guardar de nuevo el fondo no restaura una operación eliminada',
      () async {
        final first = purchase(isin: 'ES0123456789', units: 10, price: 100);

        final second = FundOperation(
          isin: 'ES0123456789',
          date: DateTime(2026, 10, 5),
          type: OperationType.buy,
          units: 4,
          price: 90,
          amount: 360,
        );

        final originalFund = fundA(operations: [first, second]);

        await DatabaseService.saveFund(originalFund);

        final persisted = await DatabaseService.getFund('ES0123456789');

        expect(persisted, isNotNull);
        expect(persisted!.operations, hasLength(2));

        final deleted = persisted.operations.singleWhere(
          (operation) => operation.units == 10,
        );
        final preserved = persisted.operations.singleWhere(
          (operation) => operation.units == 4,
        );

        expect(deleted.id, isNotNull);
        expect(preserved.id, isNotNull);

        await DatabaseService.deleteOperation(deleted.id!);

        final afterDelete = await DatabaseService.getFund('ES0123456789');

        expect(afterDelete, isNotNull);
        expect(afterDelete!.operations, hasLength(1));

        // Volvemos a guardar el fondo recuperado de SQLite.
        await DatabaseService.saveFund(afterDelete);

        final afterSave = await DatabaseService.getFund('ES0123456789');

        expect(afterSave, isNotNull);
        expect(afterSave!.operations, hasLength(1));
        expect(afterSave.operations.single.id, preserved.id);
        expect(afterSave.operations.single.units, 4);
        expect(afterSave.operations.single.price, 90);
        expect(afterSave.operations.single.amount, 360);
      },
    );

    test('LF-120.4: eliminar una operación conserva los datos y el historial del fondo', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final operation = before.operations.single;
      expect(operation.id, isNotNull);

      final originalIsin = before.isin;
      final originalName = before.name;
      final originalSymbol = before.symbol;
      final originalValue = before.lastValue;
      final originalCurrency = before.currency;
      final originalDate = before.date;
      final originalHistory = List.of(before.history);

      await DatabaseService.deleteOperation(operation.id!);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, isEmpty);

      expect(after.isin, originalIsin);
      expect(after.name, originalName);
      expect(after.symbol, originalSymbol);
      expect(after.lastValue, originalValue);
      expect(after.currency, originalCurrency);
      expect(after.date, originalDate);

      expect(after.history, hasLength(originalHistory.length));

      for (var i = 0; i < originalHistory.length; i++) {
        expect(after.history[i].date, originalHistory[i].date);
        expect(after.history[i].price, originalHistory[i].price);
      }
    });

    test('LF-120.5: eliminar una operación conserva los periodos y cargos de costes', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));
      expect(before.costPeriods, hasLength(1));
      expect(before.costCharges, hasLength(1));

      final operation = before.operations.single;
      final originalPeriod = before.costPeriods.single;
      final originalCharge = before.costCharges.single;

      expect(operation.id, isNotNull);

      await DatabaseService.deleteOperation(operation.id!);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);

      // Solo debe desaparecer la operación.
      expect(after!.operations, isEmpty);

      // El periodo de costes debe conservar su identidad y sus datos.
      expect(after.costPeriods, hasLength(1));

      final persistedPeriod = after.costPeriods.single;

      expect(persistedPeriod.uid, originalPeriod.uid);
      expect(persistedPeriod.ratePercent, originalPeriod.ratePercent);
      expect(persistedPeriod.validFrom, originalPeriod.validFrom);
      expect(persistedPeriod.validTo, originalPeriod.validTo);

      // El cargo debe conservar su identidad, referencia e importe.
      expect(after.costCharges, hasLength(1));

      final persistedCharge = after.costCharges.single;

      expect(persistedCharge.uid, originalCharge.uid);
      expect(persistedCharge.date, originalCharge.date);
      expect(persistedCharge.amount, originalCharge.amount);
      expect(persistedCharge.date, originalCharge.date);
    });
  });

  group('LF-121: atomicidad de actualización de operaciones', () {
    test('LF-121.1: una reasignación rechazada conserva ambos fondos tras recargarlos', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);
      expect(beforeA!.operations, hasLength(1));
      expect(beforeB!.operations, hasLength(1));

      final operationA = beforeA.operations.single;
      final operationB = beforeB.operations.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      // Intentar modificar B enviando el ISIN de A.
      await DatabaseService.saveOperation(
        FundOperation(
          id: operationB.id,
          isin: operationA.isin,
          date: DateTime(2026, 10, 15),
          type: OperationType.buy,
          units: 99,
          price: 999,
          amount: 98901,
        ),
      );

      // Guardar de nuevo los fondos recuperados no debe ocultar
      // una modificación parcial de las operaciones.
      final reloadedA = await DatabaseService.getFund('ES0123456789');
      final reloadedB = await DatabaseService.getFund('ES9876543210');

      expect(reloadedA, isNotNull);
      expect(reloadedB, isNotNull);
      expect(reloadedA!.operations, hasLength(1));
      expect(reloadedB!.operations, hasLength(1));

      expect(reloadedA.operations.single.id, operationA.id);
      expect(reloadedA.operations.single.units, operationA.units);
      expect(reloadedA.operations.single.price, operationA.price);
      expect(reloadedA.operations.single.amount, operationA.amount);

      expect(reloadedB.operations.single.id, operationB.id);
      expect(reloadedB.operations.single.isin, operationB.isin);
      expect(reloadedB.operations.single.units, operationB.units);
      expect(reloadedB.operations.single.price, operationB.price);
      expect(reloadedB.operations.single.amount, operationB.amount);
    });

    test('LF-121.2: actualizar una operación conserva valoración, historial y costes', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final operation = before.operations.single;
      expect(operation.id, isNotNull);

      final originalValue = before.lastValue;
      final originalDate = before.date;
      final originalHistory = List.of(before.history);
      final originalPeriods = List.of(before.costPeriods);
      final originalCharges = List.of(before.costCharges);

      await DatabaseService.saveOperation(
        FundOperation(
          id: operation.id,
          isin: operation.isin,
          date: operation.date,
          type: operation.type,
          units: 12,
          price: 105,
          amount: 1260,
        ),
      );

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, hasLength(1));

      final updated = after.operations.single;

      expect(updated.id, operation.id);
      expect(updated.units, 12);
      expect(updated.price, 105);
      expect(updated.amount, 1260);

      expect(after.lastValue, originalValue);
      expect(after.date, originalDate);

      expect(after.history, hasLength(originalHistory.length));
      for (var i = 0; i < originalHistory.length; i++) {
        expect(after.history[i].date, originalHistory[i].date);
        expect(after.history[i].price, originalHistory[i].price);
      }

      expect(after.costPeriods, hasLength(originalPeriods.length));
      for (var i = 0; i < originalPeriods.length; i++) {
        expect(after.costPeriods[i].uid, originalPeriods[i].uid);
        expect(
          after.costPeriods[i].ratePercent,
          originalPeriods[i].ratePercent,
        );
        expect(after.costPeriods[i].validFrom, originalPeriods[i].validFrom);
        expect(after.costPeriods[i].validTo, originalPeriods[i].validTo);
      }

      expect(after.costCharges, hasLength(originalCharges.length));
      for (var i = 0; i < originalCharges.length; i++) {
        expect(after.costCharges[i].uid, originalCharges[i].uid);
        expect(after.costCharges[i].date, originalCharges[i].date);
        expect(after.costCharges[i].amount, originalCharges[i].amount);
      }
    });

    test('LF-121.3: la actualización conserva la identidad y la fecha de la operación', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final original = before.operations.single;
      final originalId = original.id;
      final originalDate = original.date;

      expect(originalId, isNotNull);

      await DatabaseService.saveOperation(
        FundOperation(
          id: originalId,
          isin: original.isin,
          date: originalDate,
          type: original.type,
          units: 13,
          price: 97,
          amount: 1261,
        ),
      );

      final afterFirstUpdate = await DatabaseService.getFund('ES0123456789');

      expect(afterFirstUpdate, isNotNull);
      expect(afterFirstUpdate!.operations, hasLength(1));

      final firstUpdated = afterFirstUpdate.operations.single;

      expect(firstUpdated.id, originalId);
      expect(firstUpdated.date, originalDate);
      expect(firstUpdated.units, 13);
      expect(firstUpdated.price, 97);
      expect(firstUpdated.amount, 1261);

      await DatabaseService.saveOperation(firstUpdated);

      final afterSecondUpdate = await DatabaseService.getFund('ES0123456789');

      expect(afterSecondUpdate, isNotNull);
      expect(afterSecondUpdate!.operations, hasLength(1));

      final secondUpdated = afterSecondUpdate.operations.single;

      expect(secondUpdated.id, originalId);
      expect(secondUpdated.date, originalDate);
      expect(secondUpdated.units, 13);
      expect(secondUpdated.price, 97);
      expect(secondUpdated.amount, 1261);
    });

    test('LF-121.4: actualizar una operación conserva los costes y operaciones de otro fondo', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);
      expect(beforeA!.operations, hasLength(1));
      expect(beforeB!.operations, hasLength(1));

      final operationA = beforeA.operations.single;
      final operationB = beforeB.operations.single;
      final periodB = beforeB.costPeriods.single;
      final chargeB = beforeB.costCharges.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      await DatabaseService.saveOperation(
        FundOperation(
          id: operationA.id,
          isin: operationA.isin,
          date: operationA.date,
          type: operationA.type,
          units: 15,
          price: 110,
          amount: 1650,
        ),
      );

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      expect(afterA!.operations, hasLength(1));
      expect(afterA.operations.single.id, operationA.id);
      expect(afterA.operations.single.units, 15);
      expect(afterA.operations.single.price, 110);
      expect(afterA.operations.single.amount, 1650);

      // La operación de B permanece intacta.
      expect(afterB!.operations, hasLength(1));
      expect(afterB.operations.single.id, operationB.id);
      expect(afterB.operations.single.units, operationB.units);
      expect(afterB.operations.single.price, operationB.price);
      expect(afterB.operations.single.amount, operationB.amount);

      // Los costes de B mantienen sus identidades y valores.
      expect(afterB.costPeriods, hasLength(1));
      expect(afterB.costPeriods.single.uid, periodB.uid);
      expect(afterB.costPeriods.single.ratePercent, periodB.ratePercent);
      expect(afterB.costPeriods.single.validFrom, periodB.validFrom);
      expect(afterB.costPeriods.single.validTo, periodB.validTo);

      expect(afterB.costCharges, hasLength(1));
      expect(afterB.costCharges.single.uid, chargeB.uid);
      expect(afterB.costCharges.single.date, chargeB.date);
      expect(afterB.costCharges.single.amount, chargeB.amount);
    });

    test('LF-121.5: una actualización con identidad incompatible no modifica ningún fondo', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);

      final operationA = beforeA!.operations.single;
      final operationB = beforeB!.operations.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      // Intentamos actualizar la operación de A usando la identidad de B.
      await DatabaseService.saveOperation(
        FundOperation(
          id: operationA.id,
          isin: operationB.isin,
          date: operationA.date.add(const Duration(days: 1)),
          type: operationA.type,
          units: 999,
          price: 999,
          amount: 999,
        ),
      );

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      // A conserva íntegramente su operación original.
      expect(afterA!.operations, hasLength(1));
      expect(afterA.operations.single.id, operationA.id);
      expect(afterA.operations.single.isin, operationA.isin);
      expect(afterA.operations.single.date, operationA.date);
      expect(afterA.operations.single.units, operationA.units);
      expect(afterA.operations.single.price, operationA.price);
      expect(afterA.operations.single.amount, operationA.amount);

      // B tampoco debe verse afectado por el intento.
      expect(afterB!.operations, hasLength(1));
      expect(afterB.operations.single.id, operationB.id);
      expect(afterB.operations.single.isin, operationB.isin);
      expect(afterB.operations.single.date, operationB.date);
      expect(afterB.operations.single.units, operationB.units);
      expect(afterB.operations.single.price, operationB.price);
      expect(afterB.operations.single.amount, operationB.amount);
    });

    test('LF-121.6: las actualizaciones repetidas conservan una única operación y aíslan el otro fondo', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);

      final operationA = beforeA!.operations.single;
      final operationB = beforeB!.operations.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      for (var i = 1; i <= 3; i++) {
        await DatabaseService.saveOperation(
          FundOperation(
            id: operationA.id,
            isin: operationA.isin,
            date: operationA.date,
            type: operationA.type,
            units: 10.0 + i,
            price: 100.0 + i,
            amount: (10.0 + i) * (100.0 + i),
          ),
        );
      }

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      // Tres actualizaciones deben seguir representando una sola operación.
      expect(afterA!.operations, hasLength(1));
      expect(afterA.operations.single.id, operationA.id);
      expect(afterA.operations.single.units, 13.0);
      expect(afterA.operations.single.price, 103.0);
      expect(afterA.operations.single.amount, 1339.0);

      // La operación del otro fondo permanece intacta.
      expect(afterB!.operations, hasLength(1));
      expect(afterB.operations.single.id, operationB.id);
      expect(afterB.operations.single.units, operationB.units);
      expect(afterB.operations.single.price, operationB.price);
      expect(afterB.operations.single.amount, operationB.amount);
    });
  });

  group('LF-122: integridad de operaciones al guardar fondos', () {
    test('LF-122.1: guardar una copia antigua del fondo no elimina operaciones nuevas', () async {
      await DatabaseService.saveFund(fundA());

      // Conservamos una copia del fondo con una sola operación.
      final staleFund = await DatabaseService.getFund('ES0123456789');

      expect(staleFund, isNotNull);
      expect(staleFund!.operations, hasLength(1));

      final originalOperationId = staleFund.operations.single.id;
      expect(originalOperationId, isNotNull);

      // Añadimos una operación después de recuperar la copia.
      await DatabaseService.saveOperation(
        purchase(isin: 'ES0123456789', units: 3, price: 90),
      );

      final beforeStaleSave = await DatabaseService.getFund('ES0123456789');

      expect(beforeStaleSave, isNotNull);
      expect(beforeStaleSave!.operations, hasLength(2));

      final newOperation = beforeStaleSave.operations.singleWhere(
        (operation) => operation.id != originalOperationId,
      );

      expect(newOperation.id, isNotNull);

      // Guardar la copia antigua no debe borrar la operación recién añadida.
      await DatabaseService.saveFund(staleFund);

      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(2));

      expect(
        reloaded.operations.map((operation) => operation.id),
        containsAll([originalOperationId, newOperation.id]),
      );

      final persistedNewOperation = reloaded.operations.singleWhere(
        (operation) => operation.id == newOperation.id,
      );

      expect(persistedNewOperation.units, 3);
      expect(persistedNewOperation.price, 90);
      expect(persistedNewOperation.amount, 270);
    });

    test(
      'LF-122.2: guardar una copia antigua no restaura operaciones eliminadas',
      () async {
        await DatabaseService.saveFund(fundA());

        final staleFund = await DatabaseService.getFund('ES0123456789');

        expect(staleFund, isNotNull);
        expect(staleFund!.operations, hasLength(1));

        final deletedOperation = staleFund.operations.single;
        expect(deletedOperation.id, isNotNull);

        await DatabaseService.deleteOperation(deletedOperation.id!);

        final afterDelete = await DatabaseService.getFund('ES0123456789');

        expect(afterDelete, isNotNull);
        expect(afterDelete!.operations, isEmpty);

        // La copia recuperada antes del borrado sigue conteniendo la operación.
        expect(staleFund.operations, hasLength(1));

        await DatabaseService.saveFund(staleFund);

        final reloaded = await DatabaseService.getFund('ES0123456789');

        expect(reloaded, isNotNull);
        expect(
          reloaded!.operations,
          isEmpty,
          reason:
              'Guardar una copia antigua no debe resucitar '
              'una operación eliminada explícitamente.',
        );
      },
    );

    test('LF-122.3: guardar una copia antigua no revierte una operación actualizada', () async {
      await DatabaseService.saveFund(fundA());

      final staleFund = await DatabaseService.getFund('ES0123456789');

      expect(staleFund, isNotNull);
      expect(staleFund!.operations, hasLength(1));

      final originalOperation = staleFund.operations.single;
      expect(originalOperation.id, isNotNull);

      // Actualizamos la operación después de recuperar la copia antigua.
      await DatabaseService.saveOperation(
        FundOperation(
          id: originalOperation.id,
          isin: originalOperation.isin,
          date: originalOperation.date,
          type: originalOperation.type,
          units: 17,
          price: 125,
          amount: 2125,
        ),
      );

      final afterUpdate = await DatabaseService.getFund('ES0123456789');

      expect(afterUpdate, isNotNull);
      expect(afterUpdate!.operations, hasLength(1));
      expect(afterUpdate.operations.single.units, 17);
      expect(afterUpdate.operations.single.price, 125);
      expect(afterUpdate.operations.single.amount, 2125);

      // Guardamos el objeto recuperado antes de la actualización.
      await DatabaseService.saveFund(staleFund);

      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(1));

      final persistedOperation = reloaded.operations.single;

      expect(persistedOperation.id, originalOperation.id);
      expect(persistedOperation.units, 17);
      expect(persistedOperation.price, 125);
      expect(persistedOperation.amount, 2125);
    });

    test('LF-122.4: guardar una copia antigua de A no modifica las operaciones de B', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final staleA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(staleA, isNotNull);
      expect(beforeB, isNotNull);
      expect(staleA!.operations, hasLength(1));
      expect(beforeB!.operations, hasLength(1));

      final operationB = beforeB.operations.single;
      expect(operationB.id, isNotNull);

      // B cambia después de recuperar la copia antigua de A.
      await DatabaseService.saveOperation(
        FundOperation(
          id: operationB.id,
          isin: operationB.isin,
          date: operationB.date,
          type: operationB.type,
          units: 35,
          price: 240,
          amount: 8400,
        ),
      );

      // También añadimos una operación nueva a B.
      await DatabaseService.saveOperation(
        purchase(isin: 'ES9876543210', units: 2, price: 210),
      );

      // Guardar la copia antigua de A no debe alterar B.
      await DatabaseService.saveFund(staleA);

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      expect(afterA!.operations, hasLength(1));

      expect(afterB!.operations, hasLength(2));

      final persistedBOperation = afterB.operations.singleWhere(
        (operation) => operation.id == operationB.id,
      );

      expect(persistedBOperation.units, 35);
      expect(persistedBOperation.price, 240);
      expect(persistedBOperation.amount, 8400);

      final addedBOperation = afterB.operations.singleWhere(
        (operation) => operation.id != operationB.id,
      );

      expect(addedBOperation.units, 2);
      expect(addedBOperation.price, 210);
      expect(addedBOperation.amount, 420);
    });

    test('LF-122.5: guardar una copia antigua conserva la identidad y el estado financiero', () async {
      await DatabaseService.saveFund(fundA());

      final staleFund = await DatabaseService.getFund('ES0123456789');

      expect(staleFund, isNotNull);
      expect(staleFund!.operations, hasLength(1));

      final beforeUpdate = await DatabaseService.getFund('ES0123456789');

      expect(beforeUpdate, isNotNull);

      final original = beforeUpdate!;
      final originalOperation = original.operations.single;

      // Modificamos la operación después de recuperar staleFund.
      await DatabaseService.saveOperation(
        FundOperation(
          id: originalOperation.id,
          isin: originalOperation.isin,
          date: originalOperation.date,
          type: originalOperation.type,
          units: 19,
          price: 130,
          amount: 2470,
        ),
      );

      // Guardamos la copia antigua.
      await DatabaseService.saveFund(staleFund);

      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);

      // Identidad y valoración del fondo.
      expect(reloaded!.isin, original.isin);
      expect(reloaded.symbol, original.symbol);
      expect(reloaded.name, original.name);
      expect(reloaded.lastValue, original.lastValue);
      expect(reloaded.currency, original.currency);
      expect(reloaded.date, original.date);

      // Historial de valoración.
      expect(reloaded.history, hasLength(original.history.length));
      for (var i = 0; i < original.history.length; i++) {
        expect(reloaded.history[i].date, original.history[i].date);
        expect(reloaded.history[i].price, original.history[i].price);
      }

      // Periodos y cargos de costes.
      expect(reloaded.costPeriods, hasLength(original.costPeriods.length));
      for (var i = 0; i < original.costPeriods.length; i++) {
        expect(reloaded.costPeriods[i].uid, original.costPeriods[i].uid);
        expect(
          reloaded.costPeriods[i].ratePercent,
          original.costPeriods[i].ratePercent,
        );
      }

      expect(reloaded.costCharges, hasLength(original.costCharges.length));
      for (var i = 0; i < original.costCharges.length; i++) {
        expect(reloaded.costCharges[i].uid, original.costCharges[i].uid);
        expect(reloaded.costCharges[i].amount, original.costCharges[i].amount);
      }

      // La actualización de la operación tampoco se pierde.
      expect(reloaded.operations, hasLength(1));
      expect(reloaded.operations.single.id, originalOperation.id);
      expect(reloaded.operations.single.units, 19);
      expect(reloaded.operations.single.price, 130);
      expect(reloaded.operations.single.amount, 2470);
    });
  });

  group('LF-123: consistencia de operaciones tras guardar y recargar', () {
    test('LF-123.1: guardar y recargar conserva la colección exacta de operaciones', () async {
      await DatabaseService.saveFund(fundA());

      // Añadimos dos operaciones independientes.
      await DatabaseService.saveOperation(
        purchase(isin: 'ES0123456789', units: 3, price: 90),
      );

      await DatabaseService.saveOperation(
        purchase(isin: 'ES0123456789', units: 4, price: 95),
      );

      final firstReload = await DatabaseService.getFund('ES0123456789');

      expect(firstReload, isNotNull);
      expect(firstReload!.operations, hasLength(3));

      final firstById = {
        for (final operation in firstReload.operations)
          operation.id!: operation,
      };

      expect(firstById.length, 3);

      // Actualizamos una operación sin cambiar su identidad.
      final operationToUpdate = firstReload.operations.first;

      await DatabaseService.saveOperation(
        FundOperation(
          id: operationToUpdate.id,
          isin: operationToUpdate.isin,
          date: operationToUpdate.date,
          type: operationToUpdate.type,
          units: 21,
          price: 115,
          amount: 2415,
        ),
      );

      // Guardamos el fondo recuperado y volvemos a cargarlo.
      await DatabaseService.saveFund(firstReload);

      final secondReload = await DatabaseService.getFund('ES0123456789');

      expect(secondReload, isNotNull);
      expect(secondReload!.operations, hasLength(3));

      final secondById = {
        for (final operation in secondReload.operations)
          operation.id!: operation,
      };

      // No se pierden ni aparecen identificadores.
      expect(secondById.keys.toSet(), firstById.keys.toSet());
      expect(secondById.length, 3);

      // La actualización persiste y no se duplica.
      final persistedUpdated = secondById[operationToUpdate.id];

      expect(persistedUpdated, isNotNull);
      expect(persistedUpdated!.units, 21);
      expect(persistedUpdated.price, 115);
      expect(persistedUpdated.amount, 2415);

      // Las otras operaciones conservan sus datos.
      for (final original in firstReload.operations) {
        if (original.id == operationToUpdate.id) {
          continue;
        }

        final persisted = secondById[original.id];

        expect(persisted, isNotNull);
        expect(persisted!.isin, original.isin);
        expect(persisted.date, original.date);
        expect(persisted.type, original.type);
        expect(persisted.units, original.units);
        expect(persisted.price, original.price);
        expect(persisted.amount, original.amount);
      }
    });

    test('LF-123.2: las operaciones mantienen el orden cronológico tras actualizar y recargar', () async {
      await DatabaseService.saveFund(fundA());

      final base = DateTime(2026, 1, 1);

      FundOperation operationFor({
        required DateTime date,
        required double units,
        required double price,
      }) {
        return FundOperation(
          isin: 'ES0123456789',
          date: date,
          type: OperationType.buy,
          units: units,
          price: price,
          amount: units * price,
        );
      }

      // Insertamos las operaciones deliberadamente fuera de orden.
      await DatabaseService.saveOperation(
        operationFor(
          date: base.add(const Duration(days: 20)),
          units: 3,
          price: 90,
        ),
      );

      await DatabaseService.saveOperation(
        operationFor(
          date: base.add(const Duration(days: 5)),
          units: 2,
          price: 80,
        ),
      );

      await DatabaseService.saveOperation(
        operationFor(
          date: base.add(const Duration(days: 12)),
          units: 4,
          price: 100,
        ),
      );

      final firstReload = await DatabaseService.getFund('ES0123456789');

      expect(firstReload, isNotNull);
      expect(firstReload!.operations, hasLength(4));

      // La operación original del fondo tiene la fecha de valoración.
      final operationToUpdate = firstReload.operations.firstWhere(
        (operation) => operation.units == 2,
      );

      final updatedDate = base.add(const Duration(days: 5));

      await DatabaseService.saveOperation(
        FundOperation(
          id: operationToUpdate.id,
          isin: operationToUpdate.isin,
          date: updatedDate,
          type: operationToUpdate.type,
          units: 7,
          price: 85,
          amount: 595,
        ),
      );

      final reloaded = await DatabaseService.getFund('ES0123456789');

      expect(reloaded, isNotNull);
      expect(reloaded!.operations, hasLength(4));

      for (var i = 1; i < reloaded.operations.length; i++) {
        expect(
          reloaded.operations[i - 1].date.isBefore(
                reloaded.operations[i].date,
              ) ||
              reloaded.operations[i - 1].date.isAtSameMomentAs(
                reloaded.operations[i].date,
              ),
          isTrue,
          reason: 'Las operaciones deben recuperarse en orden cronológico.',
        );
      }

      final persistedUpdated = reloaded.operations.singleWhere(
        (operation) => operation.id == operationToUpdate.id,
      );

      expect(persistedUpdated.date, updatedDate);
      expect(persistedUpdated.units, 7);
      expect(persistedUpdated.price, 85);
      expect(persistedUpdated.amount, 595);
    });

    test('LF-123.3: dos fondos conservan sus operaciones y su orden de forma independiente', () async {
      final a = fundA(
        operations: [
          purchase(isin: 'ES0123456789', units: 2, price: 100),
          purchase(isin: 'ES0123456789', units: 3, price: 110),
        ],
      );

      final b = fundB();

      await DatabaseService.saveFund(a);
      await DatabaseService.saveFund(b);

      // Añadimos operaciones en fechas distintas para comprobar
      // que cada fondo recupera su propia colección ordenada.
      final aFirst = purchase(isin: 'ES0123456789', units: 1, price: 90);
      final aSecond = purchase(isin: 'ES0123456789', units: 4, price: 120);
      final bFirst = purchase(isin: 'ES9876543210', units: 5, price: 200);

      await DatabaseService.saveOperation(aFirst);
      await DatabaseService.saveOperation(aSecond);
      await DatabaseService.saveOperation(bFirst);

      final loadedA = await DatabaseService.getFund('ES0123456789');
      final loadedB = await DatabaseService.getFund('ES9876543210');

      expect(loadedA, isNotNull);
      expect(loadedB, isNotNull);

      final operationsA = loadedA!.operations;
      final operationsB = loadedB!.operations;

      expect(operationsA, hasLength(4));
      expect(operationsB, hasLength(2));

      expect(
        operationsA.every((op) => op.isin == 'ES0123456789'),
        isTrue,
        reason: 'El fondo A no debe recuperar operaciones de B.',
      );
      expect(
        operationsB.every((op) => op.isin == 'ES9876543210'),
        isTrue,
        reason: 'El fondo B no debe recuperar operaciones de A.',
      );

      for (var i = 1; i < operationsA.length; i++) {
        expect(
          operationsA[i - 1].date.isBefore(operationsA[i].date) ||
              operationsA[i - 1].date.isAtSameMomentAs(operationsA[i].date),
          isTrue,
          reason: 'Las operaciones de A deben estar ordenadas por fecha.',
        );
      }

      for (var i = 1; i < operationsB.length; i++) {
        expect(
          operationsB[i - 1].date.isBefore(operationsB[i].date) ||
              operationsB[i - 1].date.isAtSameMomentAs(operationsB[i].date),
          isTrue,
          reason: 'Las operaciones de B deben estar ordenadas por fecha.',
        );
      }
    });

    test(
      'LF-123.4: actualizar una operación conserva el aislamiento entre fondos',
      () async {
        await DatabaseService.saveFund(fundA());
        await DatabaseService.saveFund(fundB());

        final beforeA = await DatabaseService.getFund('ES0123456789');
        final beforeB = await DatabaseService.getFund('ES9876543210');

        expect(beforeA, isNotNull);
        expect(beforeB, isNotNull);
        expect(beforeA!.operations, hasLength(1));
        expect(beforeB!.operations, hasLength(1));

        final originalA = beforeA.operations.single;
        final originalB = beforeB.operations.single;

        expect(originalA.id, isNotNull);
        expect(originalB.id, isNotNull);

        final updatedA = FundOperation(
          id: originalA.id,
          isin: originalA.isin,
          date: originalA.date,
          type: originalA.type,
          units: originalA.units + 2,
          price: originalA.price + 10,
          amount: (originalA.units + 2) * (originalA.price + 10),
        );

        await DatabaseService.saveOperation(updatedA);

        final afterA = await DatabaseService.getFund('ES0123456789');
        final afterB = await DatabaseService.getFund('ES9876543210');

        expect(afterA, isNotNull);
        expect(afterB, isNotNull);

        final persistedA = afterA!.operations.single;
        final persistedB = afterB!.operations.single;

        expect(persistedA.id, originalA.id);
        expect(persistedA.units, updatedA.units);
        expect(persistedA.price, updatedA.price);
        expect(persistedA.amount, updatedA.amount);

        expect(persistedB.id, originalB.id);
        expect(persistedB.isin, originalB.isin);
        expect(persistedB.units, originalB.units);
        expect(persistedB.price, originalB.price);
        expect(persistedB.amount, originalB.amount);
      },
    );

    test('LF-123.5: guardar repetidamente un fondo recuperado no duplica operaciones', () async {
      await DatabaseService.saveFund(fundA());

      final initial = await DatabaseService.getFund('ES0123456789');
      expect(initial, isNotNull);
      expect(initial!.operations, hasLength(1));

      final initialIds = initial.operations.map((op) => op.id).toList();
      expect(initialIds.every((id) => id != null), isTrue);

      // Repetimos el ciclo de recuperación y guardado.
      await DatabaseService.saveFund(initial);

      final second = await DatabaseService.getFund('ES0123456789');
      expect(second, isNotNull);
      expect(second!.operations, hasLength(1));
      expect(
        second.operations.map((op) => op.id).toList(),
        initialIds,
        reason: 'El segundo guardado debe conservar la operación original.',
      );

      await DatabaseService.saveFund(second);

      final third = await DatabaseService.getFund('ES0123456789');
      expect(third, isNotNull);
      expect(third!.operations, hasLength(1));
      expect(
        third.operations.map((op) => op.id).toList(),
        initialIds,
        reason:
            'Los guardados sucesivos no deben duplicar ni recrear operaciones.',
      );
    });
  });

  group('LF-124', () {
    test('LF-124.1: eliminar una operación conserva las restantes y no afecta a otro fondo', () async {
      final operationA1 = purchase(isin: 'ES0123456789', units: 2, price: 100);
      final operationA2 = purchase(isin: 'ES0123456789', units: 3, price: 110);
      //final operationB = purchase(isin: 'ES9876543210', units: 4, price: 200);

      await DatabaseService.saveFund(
        fundA(operations: [operationA1, operationA2]),
      );
      await DatabaseService.saveFund(fundB());

      // Recuperamos los identificadores asignados por SQLite.
      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);
      expect(beforeA!.operations, hasLength(2));
      expect(beforeB!.operations, hasLength(1));

      final deletedId = beforeA.operations.first.id;
      final remainingId = beforeA.operations.last.id;
      final otherFundOperationId = beforeB.operations.single.id;

      expect(deletedId, isNotNull);
      expect(remainingId, isNotNull);
      expect(otherFundOperationId, isNotNull);

      await DatabaseService.deleteOperation(deletedId!);

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      expect(afterA!.operations, hasLength(1));
      expect(afterA.operations.single.id, remainingId);
      expect(afterA.operations.single.isin, 'ES0123456789');

      expect(afterB!.operations, hasLength(1));
      expect(afterB.operations.single.id, otherFundOperationId);
      expect(afterB.operations.single.isin, 'ES9876543210');
    });

    test('LF-124.2: eliminar una operación inexistente no altera las operaciones válidas', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);

      final idsA = beforeA!.operations.map((op) => op.id).toList();
      final idsB = beforeB!.operations.map((op) => op.id).toList();

      expect(idsA, hasLength(1));
      expect(idsB, hasLength(1));

      // Repetimos la eliminación del mismo identificador.
      final existingId = idsA.single!;
      await DatabaseService.deleteOperation(existingId);
      await DatabaseService.deleteOperation(existingId);

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      expect(afterA!.operations, isEmpty);
      expect(afterB!.operations, hasLength(1));
      expect(
        afterB.operations.map((op) => op.id).toList(),
        idsB,
        reason: 'Eliminar dos veces el ID de A no debe afectar a B.',
      );
    });

    test(
      'LF-124.3: guardar el fondo tras eliminar una operación no la recupera',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [
              purchase(isin: 'ES0123456789', units: 2, price: 100),
              purchase(isin: 'ES0123456789', units: 3, price: 110),
            ],
          ),
        );

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(2));

        final deletedId = before.operations.first.id;
        final remainingId = before.operations.last.id;

        expect(deletedId, isNotNull);
        expect(remainingId, isNotNull);

        await DatabaseService.deleteOperation(deletedId!);

        final afterDelete = await DatabaseService.getFund('ES0123456789');

        expect(afterDelete, isNotNull);
        expect(afterDelete!.operations, hasLength(1));
        expect(afterDelete.operations.single.id, remainingId);

        await DatabaseService.saveFund(afterDelete);

        final afterSave = await DatabaseService.getFund('ES0123456789');

        expect(afterSave, isNotNull);
        expect(
          afterSave!.operations,
          hasLength(1),
          reason: 'Guardar el fondo recuperado no debe resucitar la operación.',
        );
        expect(afterSave.operations.single.id, remainingId);
      },
    );

    test('LF-124.4: eliminar una operación conserva la valoración y el historial', () async {
      final fund = fundA();

      await DatabaseService.saveFund(fund);

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final deletedId = before.operations.single.id;
      expect(deletedId, isNotNull);

      final valueBefore = before.lastValue;
      final dateBefore = before.date;
      final historyBefore = before.history
          .map((point) => (point.date, point.price))
          .toList();

      await DatabaseService.deleteOperation(deletedId!);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, isEmpty);

      expect(after.lastValue, valueBefore);
      expect(after.date, dateBefore);
      expect(
        after.history.map((point) => (point.date, point.price)).toList(),
        historyBefore,
        reason:
            'Eliminar una operación no debe modificar el historial de precios.',
      );
    });

    test('LF-124.5: eliminar una operación conserva los periodos y cargos de costes', () async {
      await DatabaseService.saveFund(fundA());

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));
      expect(before.costPeriods, hasLength(1));
      expect(before.costCharges, hasLength(1));

      final deletedId = before.operations.single.id;
      expect(deletedId, isNotNull);

      final periodsBefore = before.costPeriods
          .map(
            (period) => (
              period.uid,
              period.ratePercent,
              period.validFrom,
              period.validTo,
            ),
          )
          .toList();

      final chargesBefore = before.costCharges
          .map((charge) => (charge.uid, charge.date, charge.amount))
          .toList();

      await DatabaseService.deleteOperation(deletedId!);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, isEmpty);

      expect(
        after.costPeriods
            .map(
              (period) => (
                period.uid,
                period.ratePercent,
                period.validFrom,
                period.validTo,
              ),
            )
            .toList(),
        periodsBefore,
        reason:
            'Eliminar una operación no debe modificar los periodos de costes.',
      );

      expect(
        after.costCharges
            .map((charge) => (charge.uid, charge.date, charge.amount))
            .toList(),
        chargesBefore,
        reason:
            'Eliminar una operación no debe modificar los cargos de costes.',
      );
    });
  });

  group('LF-125:', () {
    test('LF-125.1: actualizar una operación con el ISIN de otro fondo no modifica ninguna', () async {
      await DatabaseService.saveFund(fundA());
      await DatabaseService.saveFund(fundB());

      final beforeA = await DatabaseService.getFund('ES0123456789');
      final beforeB = await DatabaseService.getFund('ES9876543210');

      expect(beforeA, isNotNull);
      expect(beforeB, isNotNull);
      expect(beforeA!.operations, hasLength(1));
      expect(beforeB!.operations, hasLength(1));

      final operationA = beforeA.operations.single;
      final operationB = beforeB.operations.single;

      expect(operationA.id, isNotNull);
      expect(operationB.id, isNotNull);

      final forgedUpdate = FundOperation(
        id: operationA.id,
        isin: operationB.isin,
        date: operationB.date,
        type: operationB.type,
        units: 999,
        price: 999,
        amount: 998001,
      );

      await DatabaseService.saveOperation(forgedUpdate);

      final afterA = await DatabaseService.getFund('ES0123456789');
      final afterB = await DatabaseService.getFund('ES9876543210');

      expect(afterA, isNotNull);
      expect(afterB, isNotNull);

      final persistedA = afterA!.operations.single;
      final persistedB = afterB!.operations.single;

      expect(persistedA.id, operationA.id);
      expect(persistedA.isin, operationA.isin);
      expect(persistedA.units, operationA.units);
      expect(persistedA.price, operationA.price);
      expect(persistedA.amount, operationA.amount);

      expect(persistedB.id, operationB.id);
      expect(persistedB.isin, operationB.isin);
      expect(persistedB.units, operationB.units);
      expect(persistedB.price, operationB.price);
      expect(persistedB.amount, operationB.amount);
    });

    test(
      'LF-125.2: actualizar con un ID inexistente no inserta una operación',
      () async {
        await DatabaseService.saveFund(fundA());
        await DatabaseService.saveFund(fundB());

        final beforeA = await DatabaseService.getFund('ES0123456789');
        final beforeB = await DatabaseService.getFund('ES9876543210');

        expect(beforeA, isNotNull);
        expect(beforeB, isNotNull);
        expect(beforeA!.operations, hasLength(1));
        expect(beforeB!.operations, hasLength(1));

        final originalA = beforeA.operations.single;
        final originalB = beforeB.operations.single;

        final nonexistentId = 999999999;

        final attemptedUpdate = FundOperation(
          id: nonexistentId,
          isin: originalA.isin,
          date: originalA.date,
          type: originalA.type,
          units: 999,
          price: 999,
          amount: 998001,
        );

        await DatabaseService.saveOperation(attemptedUpdate);

        final afterA = await DatabaseService.getFund('ES0123456789');
        final afterB = await DatabaseService.getFund('ES9876543210');

        expect(afterA, isNotNull);
        expect(afterB, isNotNull);

        expect(afterA!.operations, hasLength(1));
        expect(afterB!.operations, hasLength(1));

        expect(afterA.operations.single.id, originalA.id);
        expect(afterA.operations.single.units, originalA.units);
        expect(afterA.operations.single.price, originalA.price);
        expect(afterA.operations.single.amount, originalA.amount);

        expect(afterB.operations.single.id, originalB.id);
        expect(afterB.operations.single.units, originalB.units);
        expect(afterB.operations.single.price, originalB.price);
        expect(afterB.operations.single.amount, originalB.amount);
      },
    );

    test(
      'LF-125.3: actualizar una operación conserva su identidad y fecha',
      () async {
        await DatabaseService.saveFund(fundA());

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(1));

        final original = before.operations.single;
        expect(original.id, isNotNull);

        final updated = FundOperation(
          id: original.id,
          isin: original.isin,
          date: original.date,
          type: original.type,
          units: original.units + 3,
          price: original.price + 7,
          amount: (original.units + 3) * (original.price + 7),
        );

        await DatabaseService.saveOperation(updated);

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(1));

        final persisted = after.operations.single;

        expect(persisted.id, original.id);
        expect(persisted.isin, original.isin);
        expect(persisted.date, original.date);
        expect(persisted.type, original.type);
        expect(persisted.units, updated.units);
        expect(persisted.price, updated.price);
        expect(persisted.amount, updated.amount);
      },
    );

    test(
      'LF-125.4: actualizar repetidamente una operación no duplica registros',
      () async {
        await DatabaseService.saveFund(fundA());

        final initial = await DatabaseService.getFund('ES0123456789');

        expect(initial, isNotNull);
        expect(initial!.operations, hasLength(1));

        final original = initial.operations.single;
        expect(original.id, isNotNull);

        var updated = FundOperation(
          id: original.id,
          isin: original.isin,
          date: original.date,
          type: original.type,
          units: original.units + 1,
          price: original.price + 5,
          amount: (original.units + 1) * (original.price + 5),
        );

        await DatabaseService.saveOperation(updated);

        updated = FundOperation(
          id: original.id,
          isin: original.isin,
          date: original.date,
          type: original.type,
          units: original.units + 2,
          price: original.price + 10,
          amount: (original.units + 2) * (original.price + 10),
        );

        await DatabaseService.saveOperation(updated);

        final persisted = await DatabaseService.getFund('ES0123456789');

        expect(persisted, isNotNull);
        expect(
          persisted!.operations,
          hasLength(1),
          reason: 'Actualizar por ID debe modificar la fila, no insertar otra.',
        );

        final operation = persisted.operations.single;

        expect(operation.id, original.id);
        expect(operation.units, updated.units);
        expect(operation.price, updated.price);
        expect(operation.amount, updated.amount);
      },
    );

    test(
      'LF-125.5: actualizar una operación conserva las demás del fondo',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [
              purchase(isin: 'ES0123456789', units: 2, price: 100),
              purchase(isin: 'ES0123456789', units: 3, price: 110),
              purchase(isin: 'ES0123456789', units: 4, price: 120),
            ],
          ),
        );

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(3));

        final originalOperations = before.operations;
        final target = originalOperations[1];
        final untouched = [originalOperations[0], originalOperations[2]];

        expect(target.id, isNotNull);

        final updated = FundOperation(
          id: target.id,
          isin: target.isin,
          date: target.date,
          type: target.type,
          units: target.units + 5,
          price: target.price + 15,
          amount: (target.units + 5) * (target.price + 15),
        );

        await DatabaseService.saveOperation(updated);

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(3));

        for (final original in untouched) {
          final matching = after.operations
              .where((operation) => operation.id == original.id)
              .toList();

          expect(matching, hasLength(1));

          final persisted = matching.single;
          expect(persisted.isin, original.isin);
          expect(persisted.date, original.date);
          expect(persisted.type, original.type);
          expect(persisted.units, original.units);
          expect(persisted.price, original.price);
          expect(persisted.amount, original.amount);
        }

        final persistedTarget = after.operations.singleWhere(
          (operation) => operation.id == target.id,
        );

        expect(persistedTarget.units, updated.units);
        expect(persistedTarget.price, updated.price);
        expect(persistedTarget.amount, updated.amount);
      },
    );
  });

  group('LF-126', () {
    test(
      'LF-126.1: guardar y recuperar operaciones conserva sus fechas y valores',
      () async {
        final date1 = DateTime(2026, 1, 15);
        final date2 = DateTime(2026, 5, 20);
        final date3 = DateTime(2026, 10, 10);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: date3,
                type: OperationType.buy,
                units: 4,
                price: 120,
                amount: 480,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date1,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date2,
                type: OperationType.sell,
                units: 1,
                price: 115,
                amount: 115,
              ),
            ],
          ),
        );

        final loaded = await DatabaseService.getFund('ES0123456789');

        expect(loaded, isNotNull);
        expect(loaded!.operations, hasLength(3));

        final operationsByDate = [...loaded.operations]
          ..sort((a, b) => a.date.compareTo(b.date));

        expect(operationsByDate.map((op) => op.date).toList(), [
          date1,
          date2,
          date3,
        ]);

        expect(operationsByDate.map((op) => op.units).toList(), [
          2.0,
          1.0,
          4.0,
        ]);
        expect(operationsByDate.map((op) => op.price).toList(), [
          100.0,
          115.0,
          120.0,
        ]);
        expect(operationsByDate.map((op) => op.amount).toList(), [
          200.0,
          115.0,
          480.0,
        ]);
        expect(operationsByDate.map((op) => op.type).toList(), [
          OperationType.buy,
          OperationType.sell,
          OperationType.buy,
        ]);
        expect(
          operationsByDate.every((op) => op.id != null),
          isTrue,
          reason: 'Cada operación debe conservar su identidad en SQLite.',
        );
      },
    );

    test(
      'LF-126.2: operaciones con la misma fecha conservan su identidad',
      () async {
        final sameDate = DateTime(2026, 6, 15);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: sameDate,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: sameDate,
                type: OperationType.sell,
                units: 1,
                price: 120,
                amount: 120,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: sameDate,
                type: OperationType.buy,
                units: 3,
                price: 110,
                amount: 330,
              ),
            ],
          ),
        );

        final loaded = await DatabaseService.getFund('ES0123456789');

        expect(loaded, isNotNull);
        expect(loaded!.operations, hasLength(3));

        final operations = loaded.operations;

        expect(
          operations.map((op) => op.id).toSet(),
          hasLength(3),
          reason: 'Cada operación debe conservar un ID distinto.',
        );

        expect(operations.every((op) => op.date == sameDate), isTrue);

        expect(
          operations
              .map((op) => (op.type, op.units, op.price, op.amount))
              .toSet(),
          {
            (OperationType.buy, 2.0, 100.0, 200.0),
            (OperationType.sell, 1.0, 120.0, 120.0),
            (OperationType.buy, 3.0, 110.0, 330.0),
          },
          reason:
              'Las operaciones de la misma fecha deben conservar sus datos.',
        );
      },
    );

    test(
      'LF-126.3: actualizar una operación no altera las fechas de las demás',
      () async {
        final date1 = DateTime(2026, 2, 10);
        final date2 = DateTime(2026, 5, 15);
        final date3 = DateTime(2026, 9, 20);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: date1,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date2,
                type: OperationType.buy,
                units: 3,
                price: 110,
                amount: 330,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date3,
                type: OperationType.sell,
                units: 1,
                price: 125,
                amount: 125,
              ),
            ],
          ),
        );

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(3));

        final originalOperations = before.operations;
        final target = originalOperations.singleWhere((op) => op.date == date2);

        final otherDates = {
          for (final op in originalOperations.where((op) => op.id != target.id))
            op.id: op.date,
        };

        final updated = FundOperation(
          id: target.id,
          isin: target.isin,
          date: target.date,
          type: target.type,
          units: target.units + 4,
          price: target.price + 10,
          amount: (target.units + 4) * (target.price + 10),
        );

        await DatabaseService.saveOperation(updated);

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(3));

        for (final entry in otherDates.entries) {
          final persisted = after.operations.singleWhere(
            (op) => op.id == entry.key,
          );

          expect(
            persisted.date,
            entry.value,
            reason: 'Actualizar otra operación no debe cambiar esta fecha.',
          );
        }

        final persistedTarget = after.operations.singleWhere(
          (op) => op.id == target.id,
        );

        expect(persistedTarget.date, date2);
        expect(persistedTarget.units, updated.units);
        expect(persistedTarget.price, updated.price);
        expect(persistedTarget.amount, updated.amount);
      },
    );

    test('LF-126.4: cambiar la fecha de una operación conserva el orden cronológico', () async {
      final date1 = DateTime(2026, 1, 10);
      final date2 = DateTime(2026, 5, 15);
      final date3 = DateTime(2026, 9, 20);
      final newDate = DateTime(2026, 3, 12);

      await DatabaseService.saveFund(
        fundA(
          operations: [
            FundOperation(
              isin: 'ES0123456789',
              date: date1,
              type: OperationType.buy,
              units: 2,
              price: 100,
              amount: 200,
            ),
            FundOperation(
              isin: 'ES0123456789',
              date: date2,
              type: OperationType.buy,
              units: 3,
              price: 110,
              amount: 330,
            ),
            FundOperation(
              isin: 'ES0123456789',
              date: date3,
              type: OperationType.sell,
              units: 1,
              price: 125,
              amount: 125,
            ),
          ],
        ),
      );

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(3));

      final target = before.operations.singleWhere((op) => op.date == date2);

      final updated = FundOperation(
        id: target.id,
        isin: target.isin,
        date: newDate,
        type: target.type,
        units: target.units,
        price: target.price,
        amount: target.amount,
      );

      await DatabaseService.saveOperation(updated);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, hasLength(3));

      final chronological = [...after.operations]
        ..sort((a, b) => a.date.compareTo(b.date));

      expect(chronological.map((op) => op.date).toList(), [
        date1,
        newDate,
        date3,
      ]);

      final persistedTarget = after.operations.singleWhere(
        (op) => op.id == target.id,
      );

      expect(persistedTarget.date, newDate);
      expect(persistedTarget.id, target.id);
      expect(persistedTarget.units, target.units);
      expect(persistedTarget.price, target.price);
      expect(persistedTarget.amount, target.amount);
    });

    test(
      'LF-126.5: ciclos repetidos de guardado conservan fechas e identidad',
      () async {
        final date1 = DateTime(2026, 2, 5);
        final date2 = DateTime(2026, 6, 15);
        final date3 = DateTime(2026, 10, 10);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: date3,
                type: OperationType.sell,
                units: 1,
                price: 125,
                amount: 125,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date1,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date2,
                type: OperationType.buy,
                units: 3,
                price: 110,
                amount: 330,
              ),
            ],
          ),
        );

        final first = await DatabaseService.getFund('ES0123456789');

        expect(first, isNotNull);
        expect(first!.operations, hasLength(3));

        final initialById = {for (final op in first.operations) op.id: op.date};

        expect(initialById.keys.every((id) => id != null), isTrue);

        await DatabaseService.saveFund(first);

        final second = await DatabaseService.getFund('ES0123456789');

        expect(second, isNotNull);
        expect(second!.operations, hasLength(3));
        expect({
          for (final op in second.operations) op.id: op.date,
        }, initialById);

        await DatabaseService.saveFund(second);

        final third = await DatabaseService.getFund('ES0123456789');

        expect(third, isNotNull);
        expect(third!.operations, hasLength(3));
        expect(
          {for (final op in third.operations) op.id: op.date},
          initialById,
          reason: 'Los ciclos repetidos no deben alterar fechas ni IDs.',
        );
      },
    );
  });

  group('LF-127', () {
    test('LF-127.1: eliminar una operación conserva la identidad y los datos de las demás', () async {
      final date1 = DateTime(2026, 2, 5);
      final date2 = DateTime(2026, 6, 15);
      final date3 = DateTime(2026, 10, 10);

      await DatabaseService.saveFund(
        fundA(
          operations: [
            FundOperation(
              isin: 'ES0123456789',
              date: date1,
              type: OperationType.buy,
              units: 2,
              price: 100,
              amount: 200,
            ),
            FundOperation(
              isin: 'ES0123456789',
              date: date2,
              type: OperationType.buy,
              units: 3,
              price: 110,
              amount: 330,
            ),
            FundOperation(
              isin: 'ES0123456789',
              date: date3,
              type: OperationType.sell,
              units: 1,
              price: 125,
              amount: 125,
            ),
          ],
        ),
      );

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(3));

      final toDelete = before.operations.singleWhere((op) => op.date == date2);
      final deletedId = toDelete.id;

      expect(deletedId, isNotNull);

      final preservedById = {
        for (final op in before.operations.where((op) => op.id != deletedId))
          op.id: (
            date: op.date,
            type: op.type,
            units: op.units,
            price: op.price,
            amount: op.amount,
          ),
      };

      await DatabaseService.deleteOperation(deletedId!);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, hasLength(2));
      expect(after.operations.any((op) => op.id == deletedId), isFalse);

      final actualById = {
        for (final op in after.operations)
          op.id: (
            date: op.date,
            type: op.type,
            units: op.units,
            price: op.price,
            amount: op.amount,
          ),
      };

      expect(actualById, equals(preservedById));
    });

    test(
      'LF-127.2: eliminar una operación de A no modifica las operaciones de B',
      () async {
        final sharedDate = DateTime(2026, 7, 15);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: sharedDate,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
            ],
          ),
        );

        await DatabaseService.saveFund(
          fundB().copyWith(
            operations: [
              FundOperation(
                isin: 'ES9876543210',
                date: sharedDate,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
            ],
          ),
        );

        final fundABefore = await DatabaseService.getFund('ES0123456789');
        final fundBBefore = await DatabaseService.getFund('ES9876543210');

        expect(fundABefore, isNotNull);
        expect(fundBBefore, isNotNull);
        expect(fundABefore!.operations, hasLength(1));
        expect(fundBBefore!.operations, hasLength(1));

        final idA = fundABefore.operations.single.id;
        final operationBBefore = fundBBefore.operations.single;

        expect(idA, isNotNull);

        await DatabaseService.deleteOperation(idA!);

        final fundAAfter = await DatabaseService.getFund('ES0123456789');
        final fundBAfter = await DatabaseService.getFund('ES9876543210');

        expect(fundAAfter, isNotNull);
        expect(fundBAfter, isNotNull);
        expect(fundAAfter!.operations, isEmpty);
        expect(fundBAfter!.operations, hasLength(1));

        final operationBAfter = fundBAfter.operations.single;

        expect(operationBAfter.id, operationBBefore.id);
        expect(operationBAfter.isin, operationBBefore.isin);
        expect(operationBAfter.date, operationBBefore.date);
        expect(operationBAfter.type, operationBBefore.type);
        expect(operationBAfter.units, operationBBefore.units);
        expect(operationBAfter.price, operationBBefore.price);
        expect(operationBAfter.amount, operationBBefore.amount);
      },
    );

    test(
      'LF-127.3: guardar el fondo tras borrar una operación no la resucita',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [
              purchase(isin: 'ES0123456789', units: 2, price: 100),
              purchase(isin: 'ES0123456789', units: 3, price: 110),
            ],
          ),
        );

        final initial = await DatabaseService.getFund('ES0123456789');

        expect(initial, isNotNull);
        expect(initial!.operations, hasLength(2));

        final deletedId = initial.operations.first.id;
        expect(deletedId, isNotNull);

        await DatabaseService.deleteOperation(deletedId!);

        final afterDelete = await DatabaseService.getFund('ES0123456789');

        expect(afterDelete, isNotNull);
        expect(afterDelete!.operations, hasLength(1));
        expect(afterDelete.operations.any((op) => op.id == deletedId), isFalse);

        await DatabaseService.saveFund(afterDelete);

        final afterResave = await DatabaseService.getFund('ES0123456789');

        expect(afterResave, isNotNull);
        expect(afterResave!.operations, hasLength(1));
        expect(afterResave.operations.any((op) => op.id == deletedId), isFalse);

        expect(
          afterResave.operations.single.id,
          afterDelete.operations.single.id,
        );
      },
    );

    test(
      'LF-127.4: guardar A no resucita una operación eliminada de B',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [purchase(isin: 'ES0123456789', units: 2, price: 100)],
          ),
        );

        await DatabaseService.saveFund(
          fundB().copyWith(
            operations: [
              purchase(isin: 'ES9876543210', units: 4, price: 200),
              purchase(isin: 'ES9876543210', units: 5, price: 210),
            ],
          ),
        );

        final aBefore = await DatabaseService.getFund('ES0123456789');
        final bBefore = await DatabaseService.getFund('ES9876543210');

        expect(aBefore, isNotNull);
        expect(bBefore, isNotNull);
        expect(aBefore!.operations, hasLength(1));
        expect(bBefore!.operations, hasLength(2));

        final deletedId = bBefore.operations.first.id;
        final remainingId = bBefore.operations.last.id;

        expect(deletedId, isNotNull);
        expect(remainingId, isNotNull);

        await DatabaseService.deleteOperation(deletedId!);

        final bAfterDelete = await DatabaseService.getFund('ES9876543210');

        expect(bAfterDelete, isNotNull);
        expect(bAfterDelete!.operations, hasLength(1));
        expect(bAfterDelete.operations.single.id, remainingId);

        await DatabaseService.saveFund(aBefore);

        final aAfter = await DatabaseService.getFund('ES0123456789');
        final bAfter = await DatabaseService.getFund('ES9876543210');

        expect(aAfter, isNotNull);
        expect(bAfter, isNotNull);
        expect(aAfter!.operations, hasLength(1));
        expect(aAfter.operations.single.id, aBefore.operations.single.id);

        expect(bAfter!.operations, hasLength(1));
        expect(bAfter.operations.any((op) => op.id == deletedId), isFalse);
        expect(bAfter.operations.single.id, remainingId);
        expect(bAfter.operations.single.units, 5);
        expect(bAfter.operations.single.price, 210);
        expect(bAfter.operations.single.amount, 1050);
      },
    );

    test('LF-127.5: varios ciclos de guardado conservan las eliminaciones y los IDs', () async {
      await DatabaseService.saveFund(
        fundA(
          operations: [
            purchase(isin: 'ES0123456789', units: 2, price: 100),
            purchase(isin: 'ES0123456789', units: 3, price: 110),
          ],
        ),
      );

      await DatabaseService.saveFund(
        fundB().copyWith(
          operations: [
            purchase(isin: 'ES9876543210', units: 4, price: 200),
            purchase(isin: 'ES9876543210', units: 5, price: 210),
          ],
        ),
      );

      final a0 = await DatabaseService.getFund('ES0123456789');
      final b0 = await DatabaseService.getFund('ES9876543210');

      expect(a0, isNotNull);
      expect(b0, isNotNull);
      expect(a0!.operations, hasLength(2));
      expect(b0!.operations, hasLength(2));

      final deletedAId = a0.operations.first.id;
      final keptAId = a0.operations.last.id;
      final deletedBId = b0.operations.first.id;
      final keptBId = b0.operations.last.id;

      expect(deletedAId, isNotNull);
      expect(keptAId, isNotNull);
      expect(deletedBId, isNotNull);
      expect(keptBId, isNotNull);

      await DatabaseService.deleteOperation(deletedAId!);
      await DatabaseService.deleteOperation(deletedBId!);

      for (var cycle = 0; cycle < 3; cycle++) {
        final a = await DatabaseService.getFund('ES0123456789');
        final b = await DatabaseService.getFund('ES9876543210');

        expect(a, isNotNull);
        expect(b, isNotNull);
        expect(a!.operations, hasLength(1));
        expect(b!.operations, hasLength(1));

        expect(a.operations.single.id, keptAId);
        expect(b.operations.single.id, keptBId);

        expect(a.operations.any((op) => op.id == deletedAId), isFalse);
        expect(b.operations.any((op) => op.id == deletedBId), isFalse);

        await DatabaseService.saveFund(a);
        await DatabaseService.saveFund(b);
      }

      final finalA = await DatabaseService.getFund('ES0123456789');
      final finalB = await DatabaseService.getFund('ES9876543210');

      expect(finalA, isNotNull);
      expect(finalB, isNotNull);
      expect(finalA!.operations, hasLength(1));
      expect(finalB!.operations, hasLength(1));
      expect(finalA.operations.single.id, keptAId);
      expect(finalB.operations.single.id, keptBId);
    });
  });

  group('LF-128', () {
    test(
      'LF-128.1: actualizar una operación conserva las demás y sus IDs',
      () async {
        final date1 = DateTime(2026, 3, 10);
        final date2 = DateTime(2026, 8, 20);

        await DatabaseService.saveFund(
          fundA(
            operations: [
              FundOperation(
                isin: 'ES0123456789',
                date: date1,
                type: OperationType.buy,
                units: 2,
                price: 100,
                amount: 200,
              ),
              FundOperation(
                isin: 'ES0123456789',
                date: date2,
                type: OperationType.buy,
                units: 3,
                price: 110,
                amount: 330,
              ),
            ],
          ),
        );

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(2));

        final original = before.operations.first;
        final untouched = before.operations.last;

        expect(original.id, isNotNull);
        expect(untouched.id, isNotNull);

        final untouchedSnapshot = (
          id: untouched.id,
          isin: untouched.isin,
          date: untouched.date,
          type: untouched.type,
          units: untouched.units,
          price: untouched.price,
          amount: untouched.amount,
        );

        final updated = FundOperation(
          id: original.id,
          isin: original.isin,
          date: DateTime(2026, 4, 12),
          type: OperationType.buy,
          units: 4,
          price: 105,
          amount: 420,
        );

        await DatabaseService.saveOperation(updated);

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(2));

        final persistedUpdated = after.operations.singleWhere(
          (op) => op.id == original.id,
        );
        final persistedUntouched = after.operations.singleWhere(
          (op) => op.id == untouched.id,
        );

        expect(persistedUpdated.id, original.id);
        expect(persistedUpdated.date, DateTime(2026, 4, 12));
        expect(persistedUpdated.units, 4);
        expect(persistedUpdated.price, 105);
        expect(persistedUpdated.amount, 420);

        expect(persistedUntouched.id, untouchedSnapshot.id);
        expect(persistedUntouched.isin, untouchedSnapshot.isin);
        expect(persistedUntouched.date, untouchedSnapshot.date);
        expect(persistedUntouched.type, untouchedSnapshot.type);
        expect(persistedUntouched.units, untouchedSnapshot.units);
        expect(persistedUntouched.price, untouchedSnapshot.price);
        expect(persistedUntouched.amount, untouchedSnapshot.amount);
      },
    );

    test(
      'LF-128.2: actualizar con otro ISIN no modifica ningún fondo',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [purchase(isin: 'ES0123456789', units: 2, price: 100)],
          ),
        );

        await DatabaseService.saveFund(
          fundB().copyWith(
            operations: [purchase(isin: 'ES9876543210', units: 5, price: 200)],
          ),
        );

        final aBefore = await DatabaseService.getFund('ES0123456789');
        final bBefore = await DatabaseService.getFund('ES9876543210');

        expect(aBefore, isNotNull);
        expect(bBefore, isNotNull);

        final operationA = aBefore!.operations.single;
        final operationBBefore = bBefore!.operations.single;

        expect(operationA.id, isNotNull);
        expect(operationBBefore.id, isNotNull);

        await DatabaseService.saveOperation(
          FundOperation(
            id: operationA.id,
            isin: 'ES9876543210',
            date: DateTime(2026, 9, 1),
            type: OperationType.sell,
            units: 1,
            price: 150,
            amount: 150,
          ),
        );

        final aAfter = await DatabaseService.getFund('ES0123456789');
        final bAfter = await DatabaseService.getFund('ES9876543210');

        expect(aAfter, isNotNull);
        expect(bAfter, isNotNull);
        expect(aAfter!.operations, hasLength(1));
        expect(bAfter!.operations, hasLength(1));

        final operationAAfter = aAfter.operations.single;
        final operationBAfter = bAfter.operations.single;

        expect(operationAAfter.id, operationA.id);
        expect(operationAAfter.isin, operationA.isin);
        expect(operationAAfter.date, operationA.date);
        expect(operationAAfter.type, operationA.type);
        expect(operationAAfter.units, operationA.units);
        expect(operationAAfter.price, operationA.price);
        expect(operationAAfter.amount, operationA.amount);

        expect(operationBAfter.id, operationBBefore.id);
        expect(operationBAfter.isin, operationBBefore.isin);
        expect(operationBAfter.date, operationBBefore.date);
        expect(operationBAfter.type, operationBBefore.type);
        expect(operationBAfter.units, operationBBefore.units);
        expect(operationBAfter.price, operationBBefore.price);
        expect(operationBAfter.amount, operationBBefore.amount);
      },
    );

    test(
      'LF-128.3: actualizar con un ID inexistente no inserta una operación',
      () async {
        await DatabaseService.saveFund(
          fundA(
            operations: [purchase(isin: 'ES0123456789', units: 2, price: 100)],
          ),
        );

        final before = await DatabaseService.getFund('ES0123456789');

        expect(before, isNotNull);
        expect(before!.operations, hasLength(1));

        final original = before.operations.single;
        const nonexistentId = 999999999;

        expect(original.id, isNotNull);
        expect(original.id, isNot(nonexistentId));

        await DatabaseService.saveOperation(
          FundOperation(
            id: nonexistentId,
            isin: 'ES0123456789',
            date: DateTime(2026, 10, 1),
            type: OperationType.buy,
            units: 7,
            price: 120,
            amount: 840,
          ),
        );

        final after = await DatabaseService.getFund('ES0123456789');

        expect(after, isNotNull);
        expect(after!.operations, hasLength(1));

        final persisted = after.operations.single;

        expect(persisted.id, original.id);
        expect(persisted.isin, original.isin);
        expect(persisted.date, original.date);
        expect(persisted.type, original.type);
        expect(persisted.units, original.units);
        expect(persisted.price, original.price);
        expect(persisted.amount, original.amount);
      },
    );

    test('LF-128.4: guardar una operación sin ID inserta sin alterar las existentes', () async {
      await DatabaseService.saveFund(
        fundA(
          operations: [purchase(isin: 'ES0123456789', units: 2, price: 100)],
        ),
      );

      final before = await DatabaseService.getFund('ES0123456789');

      expect(before, isNotNull);
      expect(before!.operations, hasLength(1));

      final original = before.operations.single;
      expect(original.id, isNotNull);

      final newOperation = purchase(isin: 'ES0123456789', units: 3, price: 120);

      expect(newOperation.id, isNull);

      await DatabaseService.saveOperation(newOperation);

      final after = await DatabaseService.getFund('ES0123456789');

      expect(after, isNotNull);
      expect(after!.operations, hasLength(2));

      final persistedOriginal = after.operations.singleWhere(
        (op) => op.id == original.id,
      );

      final inserted = after.operations.singleWhere(
        (op) => op.id != original.id,
      );

      expect(persistedOriginal.isin, original.isin);
      expect(persistedOriginal.date, original.date);
      expect(persistedOriginal.units, original.units);
      expect(persistedOriginal.price, original.price);
      expect(persistedOriginal.amount, original.amount);

      expect(inserted.id, isNotNull);
      expect(inserted.isin, 'ES0123456789');
      expect(inserted.units, 3);
      expect(inserted.price, 120);
      expect(inserted.amount, 360);
    });
  });

  group('LF-129', () {
    test('LF-129.1: actualizar un fondo conserva el rowid de SQLite', () async {
      final fundAInitial = fundA();
      final fundBInitial = fundB();

      await DatabaseService.saveFund(fundAInitial);
      await DatabaseService.saveFund(fundBInitial);

      final db = await DatabaseService.database;

      final beforeRows = await db.rawQuery(
        'SELECT rowid FROM funds WHERE isin = ?',
        ['ES0123456789'],
      );

      expect(beforeRows, hasLength(1));

      final rowIdBefore = beforeRows.single['rowid'];

      await DatabaseService.saveFund(fundAInitial.copyWith(lastValue: 115));

      final afterRows = await db.rawQuery(
        'SELECT rowid FROM funds WHERE isin = ?',
        ['ES0123456789'],
      );

      expect(afterRows, hasLength(1));
      expect(afterRows.single['rowid'], rowIdBefore);

      final persisted = await DatabaseService.getFund('ES0123456789');

      expect(persisted, isNotNull);
      expect(persisted!.lastValue, 115);

      // La actualización tampoco debe afectar a la identidad de B.
      final persistedB = await DatabaseService.getFund('ES9876543210');

      expect(persistedB, isNotNull);
      expect(persistedB!.lastValue, fundBInitial.lastValue);
    });

    test('LF-129.2: guardar de nuevo un fondo conserva los IDs internos de sus costes', () async {
      final fund = fundA();

      await DatabaseService.saveFund(fund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          columns: ['id', 'uid', 'isin'],
          where: 'isin = ?',
          whereArgs: [fund.isin],
          orderBy: 'id ASC',
        );
      }

      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      expect(periodsBefore, isNotEmpty);
      expect(chargesBefore, isNotEmpty);

      await DatabaseService.saveFund(fund);

      final periodsAfter = await readRows('fund_cost_periods');
      final chargesAfter = await readRows('fund_cost_charges');

      expect(periodsAfter, hasLength(periodsBefore.length));
      expect(chargesAfter, hasLength(chargesBefore.length));

      expect(
        periodsAfter.map((row) => row['id']).toList(),
        periodsBefore.map((row) => row['id']).toList(),
      );
      expect(
        periodsAfter.map((row) => row['uid']).toList(),
        periodsBefore.map((row) => row['uid']).toList(),
      );

      expect(
        chargesAfter.map((row) => row['id']).toList(),
        chargesBefore.map((row) => row['id']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['uid']).toList(),
        chargesBefore.map((row) => row['uid']).toList(),
      );
    });

    test(
      'LF-129.3: actualizar los datos de los costes conserva sus IDs internos',
      () async {
        final fund = fundA();

        await DatabaseService.saveFund(fund);

        final db = await DatabaseService.database;

        final periodsBefore = await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [fund.isin],
          orderBy: 'id ASC',
        );

        final chargesBefore = await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [fund.isin],
          orderBy: 'id ASC',
        );

        expect(periodsBefore, isNotEmpty);
        expect(chargesBefore, isNotEmpty);

        final periodBefore = periodsBefore.first;
        final chargeBefore = chargesBefore.first;

        final updatedPeriods = fund.costPeriods.map((period) {
          if (period.uid != periodBefore['uid']) return period;

          return FundCostPeriod(
            id: period.id,
            uid: period.uid,
            concept: period.concept,
            ratePercent: period.ratePercent + 0.25,
            basis: period.basis,
            treatment: period.treatment,
            validFrom: period.validFrom,
            validTo: period.validTo,
            description: period.description,
          );
        }).toList();

        final updatedCharges = fund.costCharges.map((charge) {
          if (charge.uid != chargeBefore['uid']) return charge;

          return FundCostCharge(
            id: charge.id,
            uid: charge.uid,
            concept: charge.concept,
            date: charge.date,
            amount: charge.amount + 1.0,
            description: charge.description,
            performancePeriodUid: charge.performancePeriodUid,
            settledThrough: charge.settledThrough,
          );
        }).toList();

        final updatedFund = fund.copyWith(
          costPeriods: updatedPeriods,
          costCharges: updatedCharges,
        );

        await DatabaseService.saveFund(updatedFund);

        final periodsAfter = await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [fund.isin],
          orderBy: 'id ASC',
        );

        final chargesAfter = await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [fund.isin],
          orderBy: 'id ASC',
        );

        final updatedPeriod = periodsAfter.firstWhere(
          (row) => row['uid'] == periodBefore['uid'],
        );

        final updatedCharge = chargesAfter.firstWhere(
          (row) => row['uid'] == chargeBefore['uid'],
        );

        expect(updatedPeriod['id'], periodBefore['id']);
        expect(
          (updatedPeriod['rate_percent'] as num).toDouble(),
          closeTo(
            (periodBefore['rate_percent'] as num).toDouble() + 0.25,
            0.000001,
          ),
        );

        expect(updatedCharge['id'], chargeBefore['id']);
        expect(
          (updatedCharge['amount'] as num).toDouble(),
          closeTo((chargeBefore['amount'] as num).toDouble() + 1.0, 0.000001),
        );
      },
    );

    test('LF-129.4: eliminar costes del modelo elimina solo sus registros en SQLite', () async {
      final base = fundA();

      final period1 = FundCostPeriod(
        uid: 'lf129-4-period-1',
        concept: FundCostConcept.performance,
        ratePercent: 0.5,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 10, 1),
        validTo: DateTime(2026, 10, 14),
      );

      final period2 = FundCostPeriod(
        uid: 'lf129-4-period-2',
        concept: FundCostConcept.performance,
        ratePercent: 0.2,
        basis: FundCostRateBasis.positiveProfit,
        treatment: FundCostTreatment.chargedSeparately,
        validFrom: DateTime(2026, 10, 15),
        validTo: DateTime(2026, 12, 31),
      );

      final charge1 = FundCostCharge(
        uid: 'lf129-4-charge-1',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 10),
        amount: 2.0,
        performancePeriodUid: period1.uid,
      );

      final charge2 = FundCostCharge(
        uid: 'lf129-4-charge-2',
        concept: FundCostConcept.performance,
        date: DateTime(2026, 10, 20),
        amount: 3.0,
        performancePeriodUid: period2.uid,
      );

      final fund = base.copyWith(
        costPeriods: [period1, period2],
        costCharges: [charge1, charge2],
      );

      await DatabaseService.saveFund(fund);

      final db = await DatabaseService.database;

      final periodsBefore = await db.query(
        'fund_cost_periods',
        columns: ['id', 'uid'],
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      final chargesBefore = await db.query(
        'fund_cost_charges',
        columns: ['id', 'uid'],
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      expect(periodsBefore, hasLength(2));
      expect(chargesBefore, hasLength(2));

      const removedPeriodUid = 'lf129-4-period-1';
      const removedChargeUid = 'lf129-4-charge-1';

      final retainedPeriod = periodsBefore.singleWhere(
        (row) => row['uid'] == 'lf129-4-period-2',
      );
      final retainedCharge = chargesBefore.singleWhere(
        (row) => row['uid'] == 'lf129-4-charge-2',
      );

      final updatedFund = fund.copyWith(
        costPeriods: [period2],
        costCharges: [charge2],
      );

      await DatabaseService.saveFund(updatedFund);

      final periodsAfter = await db.query(
        'fund_cost_periods',
        columns: ['id', 'uid'],
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      final chargesAfter = await db.query(
        'fund_cost_charges',
        columns: ['id', 'uid'],
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      expect(periodsAfter, hasLength(1));
      expect(chargesAfter, hasLength(1));

      expect(
        periodsAfter.any((row) => row['uid'] == removedPeriodUid),
        isFalse,
      );
      expect(
        chargesAfter.any((row) => row['uid'] == removedChargeUid),
        isFalse,
      );

      expect(periodsAfter.single['uid'], 'lf129-4-period-2');
      expect(periodsAfter.single['id'], retainedPeriod['id']);

      expect(chargesAfter.single['uid'], 'lf129-4-charge-2');
      expect(chargesAfter.single['id'], retainedCharge['id']);
    });

    test('LF-129.5: modificar los costes de A no altera los costes ni los IDs de B', () async {
      final fundAOriginal = fundA();
      final fundBOriginal = fundB();

      await DatabaseService.saveFund(fundAOriginal);
      await DatabaseService.saveFund(fundBOriginal);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readCosts(
        String table,
        String isin,
      ) async {
        final columns = table == 'fund_cost_periods'
            ? <String>[
                'id',
                'uid',
                'isin',
                'concept',
                'rate_percent',
                'valid_from',
                'valid_to',
              ]
            : <String>['id', 'uid', 'isin', 'concept', 'date', 'amount'];

        return db.query(
          table,
          columns: columns,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final bPeriodsBefore = await readCosts(
        'fund_cost_periods',
        fundBOriginal.isin,
      );
      final bChargesBefore = await readCosts(
        'fund_cost_charges',
        fundBOriginal.isin,
      );

      expect(bPeriodsBefore, isNotEmpty);
      expect(bChargesBefore, isNotEmpty);

      // Actualizamos el periodo de A y eliminamos sus cargos.
      final updatedPeriodA = performancePeriod(uid: 'LF129-5-A-P2', rate: 12);

      final updatedFundA = fundA(periods: [updatedPeriodA], charges: const []);

      await DatabaseService.saveFund(updatedFundA);

      final bPeriodsAfter = await readCosts(
        'fund_cost_periods',
        fundBOriginal.isin,
      );
      final bChargesAfter = await readCosts(
        'fund_cost_charges',
        fundBOriginal.isin,
      );

      expect(bPeriodsAfter, hasLength(bPeriodsBefore.length));
      expect(bChargesAfter, hasLength(bChargesBefore.length));

      expect(
        bPeriodsAfter.map((row) => row['id']).toList(),
        bPeriodsBefore.map((row) => row['id']).toList(),
      );
      expect(
        bPeriodsAfter.map((row) => row['uid']).toList(),
        bPeriodsBefore.map((row) => row['uid']).toList(),
      );
      expect(
        bPeriodsAfter.map((row) => row['rate_percent']).toList(),
        bPeriodsBefore.map((row) => row['rate_percent']).toList(),
      );

      expect(
        bChargesAfter.map((row) => row['id']).toList(),
        bChargesBefore.map((row) => row['id']).toList(),
      );
      expect(
        bChargesAfter.map((row) => row['uid']).toList(),
        bChargesBefore.map((row) => row['uid']).toList(),
      );
      expect(
        bChargesAfter.map((row) => row['amount']).toList(),
        bChargesBefore.map((row) => row['amount']).toList(),
      );
    });

    test('LF-129.6: vaciar los costes conserva el fondo, las operaciones y el historial', () async {
      final fund = fundA();

      await DatabaseService.saveFund(fund);

      final db = await DatabaseService.database;

      final operationsBefore = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      final pricesBefore = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'date ASC',
      );

      expect(operationsBefore, isNotEmpty);
      expect(pricesBefore, isNotEmpty);

      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [fund.isin],
        ),
        isNotEmpty,
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [fund.isin],
        ),
        isNotEmpty,
      );

      final updatedFund = fund.copyWith(
        costPeriods: const [],
        costCharges: const [],
      );

      await DatabaseService.saveFund(updatedFund);

      final savedFund = await DatabaseService.getFund(fund.isin);

      expect(savedFund, isNotNull);
      expect(savedFund!.isin, fund.isin);

      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [fund.isin],
        ),
        isEmpty,
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [fund.isin],
        ),
        isEmpty,
      );

      final operationsAfter = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'id ASC',
      );

      final pricesAfter = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [fund.isin],
        orderBy: 'date ASC',
      );

      expect(operationsAfter, hasLength(operationsBefore.length));
      expect(pricesAfter, hasLength(pricesBefore.length));

      expect(
        operationsAfter.map((row) => row['id']).toList(),
        operationsBefore.map((row) => row['id']).toList(),
      );
      expect(
        pricesAfter.map((row) => row['date']).toList(),
        pricesBefore.map((row) => row['date']).toList(),
      );
      expect(
        pricesAfter.map((row) => row['value']).toList(),
        pricesBefore.map((row) => row['value']).toList(),
      );
    });

    test('LF-129.7: un error de validación conserva íntegramente los datos persistidos', () async {
      final originalFund = fundA();
      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final fundBefore = await db.query(
        'funds',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
      );
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final operationsBefore = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final pricesBefore = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'date ASC',
      );

      expect(periodsBefore, isNotEmpty);
      expect(chargesBefore, isNotEmpty);

      // El UID del cargo referencia un periodo que no existe.
      final invalidCharge = FundCostCharge(
        uid: 'LF129-7-invalid-charge',
        concept: FundCostConcept.performance,
        date: chargeDate,
        amount: 99,
        performancePeriodUid: 'LF129-7-missing-period',
      );

      final invalidFund = originalFund.copyWith(
        name: 'Nombre que no debe persistirse',
        costPeriods: const [],
        costCharges: [invalidCharge],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsA(anything),
      );

      final fundAfter = await db.query(
        'funds',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
      );
      final periodsAfter = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final chargesAfter = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final operationsAfter = await db.query(
        'operations',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final pricesAfter = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'date ASC',
      );

      expect(fundAfter, equals(fundBefore));
      expect(periodsAfter, equals(periodsBefore));
      expect(chargesAfter, equals(chargesBefore));
      expect(operationsAfter, equals(operationsBefore));
      expect(pricesAfter, equals(pricesBefore));
    });

    test(
      'LF-129.8: un fallo de SQLite revierte todas las escrituras del guardado',
      () async {
        final originalFund = fundA();
        await DatabaseService.saveFund(originalFund);

        final db = await DatabaseService.database;

        Future<List<Map<String, Object?>>> readTable(
          String table,
          String isin,
        ) {
          return db.query(
            table,
            where: 'isin = ?',
            whereArgs: [isin],
            orderBy: 'id ASC',
          );
        }

        final fundBefore = await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        );
        final periodsBefore = await readTable(
          'fund_cost_periods',
          originalFund.isin,
        );
        final chargesBefore = await readTable(
          'fund_cost_charges',
          originalFund.isin,
        );
        final operationsBefore = await readTable(
          'operations',
          originalFund.isin,
        );
        final pricesBefore = await db.query(
          'prices',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'date ASC',
        );

        await db.execute('''
      CREATE TEMP TRIGGER lf129_8_fail_cost_charge_insert
      BEFORE INSERT ON fund_cost_charges
      BEGIN
        SELECT RAISE(ABORT, 'LF-129.8 forced SQLite failure');
      END
    ''');

        try {
          final updatedFund = originalFund.copyWith(
            name: 'Nombre que no debe persistirse',
            lastValue: 999.0,
            costPeriods: [
              performancePeriod(uid: 'LF129-8-new-period', rate: 25),
            ],
            costCharges: [
              performanceCharge(
                uid: 'LF129-8-new-charge',
                periodUid: 'LF129-8-new-period',
                amount: 77,
              ),
            ],
          );

          await expectLater(
            DatabaseService.saveFund(updatedFund),
            throwsA(anything),
          );
        } finally {
          await db.execute(
            'DROP TRIGGER IF EXISTS lf129_8_fail_cost_charge_insert',
          );
        }

        final fundAfter = await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        );
        final periodsAfter = await readTable(
          'fund_cost_periods',
          originalFund.isin,
        );
        final chargesAfter = await readTable(
          'fund_cost_charges',
          originalFund.isin,
        );
        final operationsAfter = await readTable(
          'operations',
          originalFund.isin,
        );
        final pricesAfter = await db.query(
          'prices',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'date ASC',
        );

        expect(fundAfter, equals(fundBefore));
        expect(periodsAfter, equals(periodsBefore));
        expect(chargesAfter, equals(chargesBefore));
        expect(operationsAfter, equals(operationsBefore));
        expect(pricesAfter, equals(pricesBefore));
      },
    );

    test('LF-129.9: un fallo al guardar costes revierte cambios de operaciones y valoración', () async {
      final originalFund = fundA();
      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readTable(String table, String isin) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final fundBefore = await db.query(
        'funds',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
      );
      final periodsBefore = await readTable(
        'fund_cost_periods',
        originalFund.isin,
      );
      final chargesBefore = await readTable(
        'fund_cost_charges',
        originalFund.isin,
      );
      final operationsBefore = await readTable('operations', originalFund.isin);
      final pricesBefore = await db.query(
        'prices',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'date ASC',
      );

      await db.execute('''
      CREATE TEMP TRIGGER lf129_9_fail_cost_charge_insert
      BEFORE INSERT ON fund_cost_charges
      BEGIN
        SELECT RAISE(ABORT, 'LF-129.9 forced SQLite failure');
      END
    ''');

      try {
        final updatedFund = originalFund.copyWith(
          name: 'Nombre temporal',
          lastValue: 999.0,
          date: DateTime(2026, 10, 21),
          history: [
            ...originalFund.history,
            PricePoint(DateTime(2026, 10, 21), 999.0),
          ],
          operations: [
            ...originalFund.operations,
            purchase(isin: originalFund.isin, units: 2, price: 150),
          ],
          costPeriods: [performancePeriod(uid: 'LF129-9-new-period', rate: 25)],
          costCharges: [
            performanceCharge(
              uid: 'LF129-9-new-charge',
              periodUid: 'LF129-9-new-period',
              amount: 77,
            ),
          ],
        );

        await expectLater(
          DatabaseService.saveFund(updatedFund),
          throwsA(anything),
        );
      } finally {
        await db.execute(
          'DROP TRIGGER IF EXISTS lf129_9_fail_cost_charge_insert',
        );
      }

      expect(
        await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        ),
        equals(fundBefore),
      );
      expect(
        await readTable('fund_cost_periods', originalFund.isin),
        equals(periodsBefore),
      );
      expect(
        await readTable('fund_cost_charges', originalFund.isin),
        equals(chargesBefore),
      );
      expect(
        await readTable('operations', originalFund.isin),
        equals(operationsBefore),
      );
      expect(
        await db.query(
          'prices',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'date ASC',
        ),
        equals(pricesBefore),
      );
    });

    test(
      'LF-129.10: un fallo posterior conserva el último estado confirmado',
      () async {
        final originalFund = fundA();
        await DatabaseService.saveFund(originalFund);

        final db = await DatabaseService.database;

        Future<List<Map<String, Object?>>> readTable(
          String table,
          String isin,
        ) {
          return db.query(
            table,
            where: 'isin = ?',
            whereArgs: [isin],
            orderBy: 'id ASC',
          );
        }

        // Primera actualización válida: debe quedar confirmada.
        final confirmedFund = originalFund.copyWith(
          name: 'Estado confirmado LF-129.10',
          lastValue: 125.0,
          costPeriods: [
            performancePeriod(uid: 'LF129-10-confirmed-period', rate: 12),
          ],
          costCharges: [
            performanceCharge(
              uid: 'LF129-10-confirmed-charge',
              periodUid: 'LF129-10-confirmed-period',
              amount: 8,
            ),
          ],
        );

        await DatabaseService.saveFund(confirmedFund);

        final fundConfirmed = await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        );
        final periodsConfirmed = await readTable(
          'fund_cost_periods',
          originalFund.isin,
        );
        final chargesConfirmed = await readTable(
          'fund_cost_charges',
          originalFund.isin,
        );
        final operationsConfirmed = await readTable(
          'operations',
          originalFund.isin,
        );
        final pricesConfirmed = await db.query(
          'prices',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'date ASC',
        );

        await db.execute('''
      CREATE TEMP TRIGGER lf129_10_fail_cost_charge_insert
      BEFORE INSERT ON fund_cost_charges
      BEGIN
        SELECT RAISE(ABORT, 'LF-129.10 forced SQLite failure');
      END
    ''');

        try {
          final rejectedFund = confirmedFund.copyWith(
            name: 'Estado que debe rechazarse',
            lastValue: 999.0,
            costPeriods: [
              performancePeriod(uid: 'LF129-10-rejected-period', rate: 30),
            ],
            costCharges: [
              performanceCharge(
                uid: 'LF129-10-rejected-charge',
                periodUid: 'LF129-10-rejected-period',
                amount: 99,
              ),
            ],
          );

          await expectLater(
            DatabaseService.saveFund(rejectedFund),
            throwsA(anything),
          );
        } finally {
          await db.execute(
            'DROP TRIGGER IF EXISTS lf129_10_fail_cost_charge_insert',
          );
        }

        // La segunda actualización debe haberse revertido al estado confirmado.
        expect(
          await db.query(
            'funds',
            where: 'isin = ?',
            whereArgs: [originalFund.isin],
          ),
          equals(fundConfirmed),
        );
        expect(
          await readTable('fund_cost_periods', originalFund.isin),
          equals(periodsConfirmed),
        );
        expect(
          await readTable('fund_cost_charges', originalFund.isin),
          equals(chargesConfirmed),
        );
        expect(
          await readTable('operations', originalFund.isin),
          equals(operationsConfirmed),
        );
        expect(
          await db.query(
            'prices',
            where: 'isin = ?',
            whereArgs: [originalFund.isin],
            orderBy: 'date ASC',
          ),
          equals(pricesConfirmed),
        );

        final savedFund = await DatabaseService.getFund(originalFund.isin);

        expect(savedFund, isNotNull);
        expect(savedFund!.name, 'Estado confirmado LF-129.10');
        expect(savedFund.lastValue, 125.0);
        expect(savedFund.costPeriods.map((period) => period.uid).toList(), [
          'LF129-10-confirmed-period',
        ]);
        expect(savedFund.costCharges.map((charge) => charge.uid).toList(), [
          'LF129-10-confirmed-charge',
        ]);
      },
    );
  });

  group('LF-130', () {
    test('LF-130.1: rechaza UID duplicados de periodos sin alterar los datos persistidos', () async {
      final originalFund = fundA();
      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final fundBefore = await db.query(
        'funds',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
      );
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );

      final duplicatedUid = 'LF130-1-duplicate-period';

      final invalidFund = originalFund.copyWith(
        name: 'Nombre que no debe persistirse',
        costPeriods: [
          performancePeriod(uid: duplicatedUid, rate: 10),
          performancePeriod(uid: duplicatedUid, rate: 20),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsA(anything),
      );

      expect(
        await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        ),
        equals(fundBefore),
      );
      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'id ASC',
        ),
        equals(periodsBefore),
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'id ASC',
        ),
        equals(chargesBefore),
      );
    });

    test('LF-130.2: rechaza UID duplicados de cargos sin alterar los datos persistidos', () async {
      final originalFund = fundA();
      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final fundBefore = await db.query(
        'funds',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
      );
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [originalFund.isin],
        orderBy: 'id ASC',
      );

      final duplicatedUid = 'LF130-2-duplicate-charge';

      final invalidFund = originalFund.copyWith(
        name: 'Nombre que no debe persistirse',
        costCharges: [
          performanceCharge(uid: duplicatedUid, periodUid: 'A-P1', amount: 5),
          performanceCharge(uid: duplicatedUid, periodUid: 'A-P1', amount: 15),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(invalidFund),
        throwsA(anything),
      );

      expect(
        await db.query(
          'funds',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
        ),
        equals(fundBefore),
      );
      expect(
        await db.query(
          'fund_cost_periods',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'id ASC',
        ),
        equals(periodsBefore),
      );
      expect(
        await db.query(
          'fund_cost_charges',
          where: 'isin = ?',
          whereArgs: [originalFund.isin],
          orderBy: 'id ASC',
        ),
        equals(chargesBefore),
      );
    });

    test('LF-130.3: un periodo y un cargo pueden compartir UID', () async {
      final sharedUid = 'LF130-3-shared-uid';

      final fund = fundA().copyWith(
        costPeriods: [performancePeriod(uid: sharedUid, rate: 12)],
        costCharges: [
          performanceCharge(uid: sharedUid, periodUid: sharedUid, amount: 7),
        ],
      );

      await DatabaseService.saveFund(fund);

      final db = await DatabaseService.database;

      final periods = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [fund.isin],
      );
      final charges = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [fund.isin],
      );

      expect(periods, hasLength(1));
      expect(charges, hasLength(1));
      expect(periods.single['uid'], sharedUid);
      expect(charges.single['uid'], sharedUid);
      expect(charges.single['performance_period_uid'], sharedUid);

      final restoredFund = await DatabaseService.getFund(fund.isin);

      expect(restoredFund, isNotNull);
      expect(restoredFund!.costPeriods, hasLength(1));
      expect(restoredFund.costCharges, hasLength(1));
      expect(restoredFund.costPeriods.single.uid, sharedUid);
      expect(restoredFund.costCharges.single.uid, sharedUid);
      expect(restoredFund.costCharges.single.performancePeriodUid, sharedUid);
    });

    test('LF-130.4: los UID de costes iguales en fondos distintos son independientes', () async {
      const sharedPeriodUid = 'LF130-4-shared-period';
      const sharedChargeUid = 'LF130-4-shared-charge';

      final fundAData = fundA().copyWith(
        costPeriods: [performancePeriod(uid: sharedPeriodUid, rate: 10)],
        costCharges: [
          performanceCharge(
            uid: sharedChargeUid,
            periodUid: sharedPeriodUid,
            amount: 5,
          ),
        ],
      );

      final fundBData = fundB().copyWith(
        costPeriods: [performancePeriod(uid: sharedPeriodUid, rate: 20)],
        costCharges: [
          performanceCharge(
            uid: sharedChargeUid,
            periodUid: sharedPeriodUid,
            amount: 15,
          ),
        ],
      );

      await DatabaseService.saveFund(fundAData);
      await DatabaseService.saveFund(fundBData);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table, String isin) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final periodsBBefore = await readRows(
        'fund_cost_periods',
        fundBData.isin,
      );
      final chargesBBefore = await readRows(
        'fund_cost_charges',
        fundBData.isin,
      );

      final updatedFundA = fundAData.copyWith(
        costPeriods: [performancePeriod(uid: sharedPeriodUid, rate: 12)],
        costCharges: [
          performanceCharge(
            uid: sharedChargeUid,
            periodUid: sharedPeriodUid,
            amount: 8,
          ),
        ],
      );

      await DatabaseService.saveFund(updatedFundA);

      final periodsAAfter = await readRows('fund_cost_periods', fundAData.isin);
      final chargesAAfter = await readRows('fund_cost_charges', fundAData.isin);
      final periodsBAfter = await readRows('fund_cost_periods', fundBData.isin);
      final chargesBAfter = await readRows('fund_cost_charges', fundBData.isin);

      expect(periodsAAfter, hasLength(1));
      expect(chargesAAfter, hasLength(1));
      expect(periodsAAfter.single['uid'], sharedPeriodUid);
      expect(chargesAAfter.single['uid'], sharedChargeUid);
      expect(periodsAAfter.single['rate_percent'], 12.0);
      expect(chargesAAfter.single['amount'], 8.0);

      expect(periodsBAfter, equals(periodsBBefore));
      expect(chargesBAfter, equals(chargesBBefore));
      expect(periodsBAfter.single['uid'], sharedPeriodUid);
      expect(chargesBAfter.single['uid'], sharedChargeUid);
      expect(periodsBAfter.single['rate_percent'], 20.0);
      expect(chargesBAfter.single['amount'], 15.0);
    });

    test('LF-130.5: cambiar un UID crea una identidad nueva y conserva las restantes', () async {
      final isin = 'ES0123456789';

      final originalFund = fundA().copyWith(
        operations: [
          FundOperation(
            isin: isin,
            date: DateTime(2026, 1, 1),
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'LF130-5-period-keep',
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 10, 1),
            validTo: DateTime(2026, 10, 14),
          ),
          FundCostPeriod(
            uid: 'LF130-5-period-old',
            concept: FundCostConcept.performance,
            ratePercent: 20,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 10, 15),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'LF130-5-charge-keep',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 10),
            amount: 5,
            performancePeriodUid: 'LF130-5-period-keep',
          ),
          FundCostCharge(
            uid: 'LF130-5-charge-old',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 20),
            amount: 15,
            performancePeriodUid: 'LF130-5-period-old',
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      int idForUid(List<Map<String, Object?>> rows, String uid) {
        return rows.singleWhere((row) => row['uid'] == uid)['id']! as int;
      }

      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      final keptPeriodId = idForUid(periodsBefore, 'LF130-5-period-keep');
      final oldPeriodId = idForUid(periodsBefore, 'LF130-5-period-old');
      final keptChargeId = idForUid(chargesBefore, 'LF130-5-charge-keep');
      final oldChargeId = idForUid(chargesBefore, 'LF130-5-charge-old');

      final updatedFund = originalFund.copyWith(
        costPeriods: [
          FundCostPeriod(
            uid: 'LF130-5-period-keep',
            concept: FundCostConcept.performance,
            ratePercent: 11,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 10, 1),
            validTo: DateTime(2026, 10, 14),
          ),
          FundCostPeriod(
            uid: 'LF130-5-period-new',
            concept: FundCostConcept.performance,
            ratePercent: 25,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 10, 15),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'LF130-5-charge-keep',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 10),
            amount: 6,
            performancePeriodUid: 'LF130-5-period-keep',
          ),
          FundCostCharge(
            uid: 'LF130-5-charge-new',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 10, 20),
            amount: 22,
            performancePeriodUid: 'LF130-5-period-new',
          ),
        ],
      );

      await DatabaseService.saveFund(updatedFund);

      final periodsAfter = await readRows('fund_cost_periods');
      final chargesAfter = await readRows('fund_cost_charges');

      expect(periodsAfter, hasLength(2));
      expect(chargesAfter, hasLength(2));

      // Los UID conservados mantienen sus IDs internos.
      expect(idForUid(periodsAfter, 'LF130-5-period-keep'), keptPeriodId);
      expect(idForUid(chargesAfter, 'LF130-5-charge-keep'), keptChargeId);

      // Las identidades anteriores han desaparecido.
      expect(
        periodsAfter.any((row) => row['uid'] == 'LF130-5-period-old'),
        isFalse,
      );
      expect(
        chargesAfter.any((row) => row['uid'] == 'LF130-5-charge-old'),
        isFalse,
      );

      // Las identidades nuevas reciben IDs distintos de los sustituidos.
      expect(idForUid(periodsAfter, 'LF130-5-period-new'), isNot(oldPeriodId));
      expect(idForUid(chargesAfter, 'LF130-5-charge-new'), isNot(oldChargeId));

      // Los valores de las identidades conservadas se han actualizado.
      expect(
        periodsAfter.singleWhere(
          (row) => row['uid'] == 'LF130-5-period-keep',
        )['rate_percent'],
        11.0,
      );
      expect(
        chargesAfter.singleWhere(
          (row) => row['uid'] == 'LF130-5-charge-keep',
        )['amount'],
        6.0,
      );
    });
  });

  group('LF-131', () {
    test('LF-131.1: cambiar el UID de un periodo sin actualizar su cargo '
        'rechaza la operación y conserva el estado persistido', () async {
      final originalFund = fundA();
      final isin = originalFund.isin;

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      expect(periodsBefore, hasLength(1));
      expect(chargesBefore, hasLength(1));

      final periodBefore = periodsBefore.single;
      final chargeBefore = chargesBefore.single;

      expect(periodBefore['uid'], 'A-P1');
      expect(chargeBefore['uid'], 'A-C1');
      expect(chargeBefore['performance_period_uid'], 'A-P1');

      // Cambia la identidad del periodo, pero conserva el cargo
      // apuntando al UID anterior.
      final updatedFund = originalFund.copyWith(
        costPeriods: [
          FundCostPeriod(
            uid: 'A-P2',
            concept: FundCostConcept.performance,
            ratePercent: 20,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: originalFund.costCharges,
      );

      await expectLater(
        DatabaseService.saveFund(updatedFund),
        throwsA(isA<ArgumentError>()),
      );

      // La operación fallida no debe alterar los periodos ni los cargos.
      final periodsAfter = await readRows('fund_cost_periods');
      final chargesAfter = await readRows('fund_cost_charges');

      expect(periodsAfter, hasLength(1));
      expect(chargesAfter, hasLength(1));

      expect(periodsAfter.single['id'], periodBefore['id']);
      expect(periodsAfter.single['uid'], 'A-P1');
      expect(periodsAfter.single['rate_percent'], periodBefore['rate_percent']);

      expect(chargesAfter.single['id'], chargeBefore['id']);
      expect(chargesAfter.single['uid'], 'A-C1');
      expect(chargesAfter.single['performance_period_uid'], 'A-P1');
      expect(chargesAfter.single['amount'], chargeBefore['amount']);
    });

    test('LF-131.2: cambiar el UID de un periodo tras eliminar su cargo '
        'actualiza los costes correctamente', () async {
      final originalFund = fundA();
      final isin = originalFund.isin;

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      expect(periodsBefore, hasLength(1));
      expect(chargesBefore, hasLength(1));

      final oldPeriodId = periodsBefore.single['id'];

      final updatedFund = originalFund.copyWith(
        costPeriods: [
          FundCostPeriod(
            uid: 'A-P2',
            concept: FundCostConcept.performance,
            ratePercent: 20,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: const [],
      );

      await DatabaseService.saveFund(updatedFund);

      final periodsAfter = await readRows('fund_cost_periods');
      final chargesAfter = await readRows('fund_cost_charges');

      expect(periodsAfter, hasLength(1));
      expect(chargesAfter, isEmpty);

      expect(periodsAfter.single['uid'], 'A-P2');
      expect(periodsAfter.single['rate_percent'], 20.0);
      expect(periodsAfter.single['id'], isNot(oldPeriodId));
    });

    test('LF-131.3: cambiar la identidad de un periodo no altera '
        'los demás periodos ni sus cargos', () async {
      final isin = 'ES0123456789';

      final originalFund = fundA().copyWith(
        operations: [
          FundOperation(
            isin: isin,
            date: DateTime(2026, 1, 1),
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
        costPeriods: [
          FundCostPeriod(
            uid: 'LF131-3-period-A',
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 6, 30),
          ),
          FundCostPeriod(
            uid: 'LF131-3-period-B',
            concept: FundCostConcept.performance,
            ratePercent: 15,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 7, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'LF131-3-charge-A',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 3, 10),
            amount: 5,
            performancePeriodUid: 'LF131-3-period-A',
          ),
          FundCostCharge(
            uid: 'LF131-3-charge-B',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 9, 10),
            amount: 12,
            performancePeriodUid: 'LF131-3-period-B',
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      final periodBId = periodsBefore.singleWhere(
        (row) => row['uid'] == 'LF131-3-period-B',
      )['id'];

      final chargeBId = chargesBefore.singleWhere(
        (row) => row['uid'] == 'LF131-3-charge-B',
      )['id'];

      final updatedFund = originalFund.copyWith(
        costPeriods: [
          FundCostPeriod(
            uid: 'LF131-3-period-A-new',
            concept: FundCostConcept.performance,
            ratePercent: 20,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 6, 30),
          ),
          originalFund.costPeriods.singleWhere(
            (period) => period.uid == 'LF131-3-period-B',
          ),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'LF131-3-charge-A-new',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 3, 10),
            amount: 7,
            performancePeriodUid: 'LF131-3-period-A-new',
          ),
          originalFund.costCharges.singleWhere(
            (charge) => charge.uid == 'LF131-3-charge-B',
          ),
        ],
      );

      await DatabaseService.saveFund(updatedFund);

      final periodsAfter = await readRows('fund_cost_periods');
      final chargesAfter = await readRows('fund_cost_charges');

      expect(periodsAfter, hasLength(2));
      expect(chargesAfter, hasLength(2));

      final periodBAfter = periodsAfter.singleWhere(
        (row) => row['uid'] == 'LF131-3-period-B',
      );
      final chargeBAfter = chargesAfter.singleWhere(
        (row) => row['uid'] == 'LF131-3-charge-B',
      );

      expect(periodBAfter['id'], periodBId);
      expect(periodBAfter['rate_percent'], 15.0);

      expect(chargeBAfter['id'], chargeBId);
      expect(chargeBAfter['amount'], 12.0);
      expect(chargeBAfter['performance_period_uid'], 'LF131-3-period-B');

      expect(
        periodsAfter.any((row) => row['uid'] == 'LF131-3-period-A'),
        isFalse,
      );
      expect(
        chargesAfter.any((row) => row['uid'] == 'LF131-3-charge-A'),
        isFalse,
      );

      expect(
        periodsAfter.any((row) => row['uid'] == 'LF131-3-period-A-new'),
        isTrue,
      );
      expect(
        chargesAfter.any((row) => row['uid'] == 'LF131-3-charge-A-new'),
        isTrue,
      );
    });

    test('LF-131.4: un error al insertar el nuevo cargo revierte '
        'el cambio de identidad completo', () async {
      final isin = 'ES0123456789';
      const triggerName = 'lf131_4_fail_new_charge';

      final originalFund = fundA().copyWith(
        name: 'Fondo original LF-131.4',
        lastValue: 110,
        operations: [
          FundOperation(
            isin: isin,
            date: DateTime(2026, 1, 1),
            type: OperationType.buy,
            units: 10,
            price: 100,
            amount: 1000,
          ),
        ],
        costPeriods: [
          performancePeriod(uid: 'LF131-4-period-A', rate: 10),
          performancePeriod(uid: 'LF131-4-period-B', rate: 15),
        ],
        costCharges: [
          FundCostCharge(
            uid: 'LF131-4-charge-A',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 3, 10),
            amount: 5,
            performancePeriodUid: 'LF131-4-period-A',
          ),
          FundCostCharge(
            uid: 'LF131-4-charge-B',
            concept: FundCostConcept.performance,
            date: DateTime(2026, 9, 10),
            amount: 12,
            performancePeriodUid: 'LF131-4-period-B',
          ),
        ],
      );

      // Los periodos de la factoría abarcan todo el año y se solapan.
      // Usamos periodos consecutivos para cumplir la validación del fondo.
      final validOriginalFund = originalFund.copyWith(
        costPeriods: [
          FundCostPeriod(
            uid: 'LF131-4-period-A',
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 6, 30),
          ),
          FundCostPeriod(
            uid: 'LF131-4-period-B',
            concept: FundCostConcept.performance,
            ratePercent: 15,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 7, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
      );

      await DatabaseService.saveFund(validOriginalFund);

      final db = await DatabaseService.database;

      Future<List<Map<String, Object?>>> readRows(String table) {
        return db.query(
          table,
          where: 'isin = ?',
          whereArgs: [isin],
          orderBy: 'id ASC',
        );
      }

      final savedBefore = await DatabaseService.getFund(isin);
      final periodsBefore = await readRows('fund_cost_periods');
      final chargesBefore = await readRows('fund_cost_charges');

      expect(savedBefore, isNotNull);
      expect(periodsBefore, hasLength(2));
      expect(chargesBefore, hasLength(2));

      // Forzamos un error exclusivamente al insertar el nuevo cargo A.
      await db.execute('''
      CREATE TRIGGER $triggerName
      BEFORE INSERT ON fund_cost_charges
      WHEN NEW.uid = 'LF131-4-charge-A-new'
      BEGIN
        SELECT RAISE(ABORT, 'LF-131.4 forced insert failure');
      END
    ''');

      try {
        final updatedFund = validOriginalFund.copyWith(
          name: 'Fondo modificado LF-131.4',
          lastValue: 125,
          costPeriods: [
            FundCostPeriod(
              uid: 'LF131-4-period-A-new',
              concept: FundCostConcept.performance,
              ratePercent: 20,
              basis: FundCostRateBasis.positiveProfit,
              treatment: FundCostTreatment.chargedSeparately,
              validFrom: DateTime(2026, 1, 1),
              validTo: DateTime(2026, 6, 30),
            ),
            validOriginalFund.costPeriods.singleWhere(
              (period) => period.uid == 'LF131-4-period-B',
            ),
          ],
          costCharges: [
            FundCostCharge(
              uid: 'LF131-4-charge-A-new',
              concept: FundCostConcept.performance,
              //date: chargeDate,
              date: DateTime(2026, 3, 10),
              amount: 7,
              performancePeriodUid: 'LF131-4-period-A-new',
            ),
            validOriginalFund.costCharges.singleWhere(
              (charge) => charge.uid == 'LF131-4-charge-B',
            ),
          ],
        );

        await expectLater(
          DatabaseService.saveFund(updatedFund),
          throwsA(anything),
        );

        final savedAfter = await DatabaseService.getFund(isin);
        final periodsAfter = await readRows('fund_cost_periods');
        final chargesAfter = await readRows('fund_cost_charges');

        // También deben revertirse los cambios en el fondo principal.
        expect(savedAfter, isNotNull);
        expect(savedAfter!.name, savedBefore!.name);
        expect(savedAfter.lastValue, savedBefore.lastValue);

        // Los periodos anteriores deben seguir intactos.
        expect(periodsAfter, hasLength(2));
        expect(periodsAfter.map((row) => row['uid']).toSet(), {
          'LF131-4-period-A',
          'LF131-4-period-B',
        });
        expect(
          periodsAfter.map((row) => row['id']).toSet(),
          periodsBefore.map((row) => row['id']).toSet(),
        );

        // Los cargos anteriores deben seguir intactos, con sus referencias.
        expect(chargesAfter, hasLength(2));
        expect(chargesAfter.map((row) => row['uid']).toSet(), {
          'LF131-4-charge-A',
          'LF131-4-charge-B',
        });
        expect(
          chargesAfter.map((row) => row['id']).toSet(),
          chargesBefore.map((row) => row['id']).toSet(),
        );
        expect(
          chargesAfter.singleWhere(
            (row) => row['uid'] == 'LF131-4-charge-A',
          )['performance_period_uid'],
          'LF131-4-period-A',
        );

        expect(
          periodsAfter.any((row) => row['uid'] == 'LF131-4-period-A-new'),
          isFalse,
        );
        expect(
          chargesAfter.any((row) => row['uid'] == 'LF131-4-charge-A-new'),
          isFalse,
        );
      } finally {
        await db.execute('DROP TRIGGER IF EXISTS $triggerName');
      }
    });

    test('LF-131.5: rechaza UID duplicados de periodos sin alterar '
        'los datos persistidos', () async {
      const isin = 'ES0123456789';

      final originalFund = fundA().copyWith(
        name: 'Fondo original LF-131.5',
        lastValue: 110,
        costPeriods: [performancePeriod(uid: 'LF131-5-period-A', rate: 10)],
        costCharges: [
          performanceCharge(
            uid: 'LF131-5-charge-A',
            periodUid: 'LF131-5-period-A',
            amount: 5,
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final savedBefore = await DatabaseService.getFund(isin);
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      final duplicateUidFund = originalFund.copyWith(
        name: 'Fondo modificado LF-131.5',
        lastValue: 125,
        costPeriods: [
          performancePeriod(uid: 'LF131-5-period-DUP', rate: 10),
          performancePeriod(uid: 'LF131-5-period-DUP', rate: 15),
        ],
        costCharges: [],
      );

      await expectLater(
        DatabaseService.saveFund(duplicateUidFund),
        throwsA(anything),
      );

      final savedAfter = await DatabaseService.getFund(isin);
      final periodsAfter = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesAfter = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      expect(savedBefore, isNotNull);
      expect(savedAfter, isNotNull);
      expect(savedAfter!.name, savedBefore!.name);
      expect(savedAfter.lastValue, savedBefore.lastValue);

      expect(
        periodsAfter.map((row) => row['uid']).toList(),
        periodsBefore.map((row) => row['uid']).toList(),
      );
      expect(
        periodsAfter.map((row) => row['id']).toList(),
        periodsBefore.map((row) => row['id']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['uid']).toList(),
        chargesBefore.map((row) => row['uid']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['id']).toList(),
        chargesBefore.map((row) => row['id']).toList(),
      );
    });

    test('LF-131.6: Aislar la validación de UID duplicados ', () async {
      const isin = 'ES0123456789';

      final originalFund = fundA().copyWith(
        name: 'Fondo original LF-131.5',
        lastValue: 110,
        costPeriods: [performancePeriod(uid: 'LF131-5-period-A', rate: 10)],
        costCharges: [
          performanceCharge(
            uid: 'LF131-5-charge-A',
            periodUid: 'LF131-5-period-A',
            amount: 5,
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final savedBefore = await DatabaseService.getFund(isin);
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      final duplicateUidFund = originalFund.copyWith(
        name: 'Fondo modificado LF-131.5',
        lastValue: 125,
        /* costPeriods: [
          performancePeriod(uid: 'LF131-5-period-DUP', rate: 10),
          performancePeriod(uid: 'LF131-5-period-DUP', rate: 15),
        ], */
        costPeriods: [
          FundCostPeriod(
            uid: 'LF131-5-period-DUP',
            concept: FundCostConcept.performance,
            ratePercent: 10,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 1, 1),
            validTo: DateTime(2026, 6, 30),
          ),
          FundCostPeriod(
            uid: 'LF131-5-period-DUP',
            concept: FundCostConcept.performance,
            ratePercent: 15,
            basis: FundCostRateBasis.positiveProfit,
            treatment: FundCostTreatment.chargedSeparately,
            validFrom: DateTime(2026, 7, 1),
            validTo: DateTime(2026, 12, 31),
          ),
        ],
        costCharges: [],
      );

      await expectLater(
        DatabaseService.saveFund(duplicateUidFund),
        throwsA(anything),
      );

      final savedAfter = await DatabaseService.getFund(isin);
      final periodsAfter = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesAfter = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      expect(savedBefore, isNotNull);
      expect(savedAfter, isNotNull);
      expect(savedAfter!.name, savedBefore!.name);
      expect(savedAfter.lastValue, savedBefore.lastValue);

      expect(
        periodsAfter.map((row) => row['uid']).toList(),
        periodsBefore.map((row) => row['uid']).toList(),
      );
      expect(
        periodsAfter.map((row) => row['id']).toList(),
        periodsBefore.map((row) => row['id']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['uid']).toList(),
        chargesBefore.map((row) => row['uid']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['id']).toList(),
        chargesBefore.map((row) => row['id']).toList(),
      );
    });
  });

  group('LF-132', () {
    test('LF-132.1: rechaza UID duplicados de cargos sin alterar '
        'los datos persistidos', () async {
      const isin = 'ES0123456789';

      final originalFund = fundA().copyWith(
        name: 'Fondo original LF-132.1',
        lastValue: 110,
        costPeriods: [performancePeriod(uid: 'LF132-1-period-A', rate: 10)],
        costCharges: [
          performanceCharge(
            uid: 'LF132-1-charge-A',
            periodUid: 'LF132-1-period-A',
            amount: 5,
          ),
        ],
      );

      await DatabaseService.saveFund(originalFund);

      final db = await DatabaseService.database;

      final savedBefore = await DatabaseService.getFund(isin);
      final periodsBefore = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesBefore = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      final duplicateUidFund = originalFund.copyWith(
        name: 'Fondo modificado LF-132.1',
        lastValue: 125,
        costCharges: [
          performanceCharge(
            uid: 'LF132-1-charge-DUP',
            periodUid: 'LF132-1-period-A',
            amount: 7,
          ),
          performanceCharge(
            uid: 'LF132-1-charge-DUP',
            periodUid: 'LF132-1-period-A',
            amount: 9,
          ),
        ],
      );

      await expectLater(
        DatabaseService.saveFund(duplicateUidFund),
        throwsA(anything),
      );

      final savedAfter = await DatabaseService.getFund(isin);
      final periodsAfter = await db.query(
        'fund_cost_periods',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );
      final chargesAfter = await db.query(
        'fund_cost_charges',
        where: 'isin = ?',
        whereArgs: [isin],
        orderBy: 'id ASC',
      );

      expect(savedBefore, isNotNull);
      expect(savedAfter, isNotNull);
      expect(savedAfter!.name, savedBefore!.name);
      expect(savedAfter.lastValue, savedBefore.lastValue);

      expect(
        periodsAfter.map((row) => row['uid']).toList(),
        periodsBefore.map((row) => row['uid']).toList(),
      );
      expect(
        periodsAfter.map((row) => row['id']).toList(),
        periodsBefore.map((row) => row['id']).toList(),
      );

      expect(
        chargesAfter.map((row) => row['uid']).toList(),
        chargesBefore.map((row) => row['uid']).toList(),
      );
      expect(
        chargesAfter.map((row) => row['id']).toList(),
        chargesBefore.map((row) => row['id']).toList(),
      );
      expect(chargesAfter, hasLength(1));
      expect(chargesAfter.single['uid'], 'LF132-1-charge-A');
      expect(chargesAfter.single['amount'], 5);
    });
  });
}
