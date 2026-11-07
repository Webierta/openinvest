import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/screens/historical_investment_form_page.dart';
import 'package:investing/services/database_service.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('LF-135: HistoricalInvestmentFormPage', () {
    test('LF-135.1: se puede instanciar el formulario', () {
      const page = HistoricalInvestmentFormPage();

      expect(page, isNotNull);
    });

    testWidgets('LF-135.2: construye una pantalla con Scaffold', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: HistoricalInvestmentFormPage()),
      );

      expect(find.byType(Scaffold), findsOneWidget);
    });

    test('LF-140.23: no persiste una inversión cuya primera operación es una salida', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;

      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'historical_investment_form_test_',
      );

      try {
        await DatabaseService.useDatabasePathForTesting(
          path.join(temporaryDirectory.path, 'test.db'),
        );

        final investment = HistoricalInvestment(
          uid: 'investment-lf140-23',
          name: 'Inversión inválida',
        );
        final operation = HistoricalOperation(
          uid: 'operation-lf140-23',
          investmentUid: investment.uid,
          date: DateTime(2025, 1, 1),
          type: HistoricalOperationType.redemption,
          amount: 1000,
        );

        await expectLater(
          DatabaseService.saveHistoricalInvestmentWithOperations(investment, [
            operation,
          ]),
          throwsA(isA<ArgumentError>()),
        );

        final investments = await DatabaseService.getHistoricalInvestments();
        expect(investments, isEmpty);
      } finally {
        await DatabaseService.resetDatabasePathForTesting();
        await temporaryDirectory.delete(recursive: true);
      }
    });

    test(
      'LF-140.24: rechaza una inversión cuya primera operación es una salida',
      () async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'historical_investment_form_lf140_24_',
        );

        try {
          await DatabaseService.useDatabasePathForTesting(
            path.join(temporaryDirectory.path, 'test.db'),
          );

          final investment = HistoricalInvestment(
            uid: 'investment-lf140-24',
            name: 'Inversión LF-140.24',
          );

          final operation = HistoricalOperation(
            uid: 'operation-lf140-24',
            investmentUid: investment.uid,
            date: DateTime(2025, 1, 1),
            type: HistoricalOperationType.redemption,
            amount: 1000,
          );

          await expectLater(
            DatabaseService.saveHistoricalInvestmentWithOperations(investment, [
              operation,
            ]),
            throwsA(isA<ArgumentError>()),
          );

          final investments = await DatabaseService.getHistoricalInvestments();

          expect(investments, isEmpty);
        } finally {
          await DatabaseService.resetDatabasePathForTesting();
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );

    testWidgets(
      'LF-140.25: el formulario no persiste una inversión con primera operación de salida',
      (tester) async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'historical_investment_form_test_',
        );

        final saveCompleted = Completer<void>();

        try {
          await DatabaseService.useDatabasePathForTesting(
            path.join(temporaryDirectory.path, 'test.db'),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: HistoricalInvestmentFormPage(
                saveInvestment: (investment, operations) async {
                  try {
                    await DatabaseService.saveHistoricalInvestmentWithOperations(
                      investment,
                      operations,
                    );
                  } finally {
                    saveCompleted.complete();
                  }
                },
              ),
            ),
          );

          await tester.enterText(
            find.byType(TextFormField).first,
            'Inversión inválida',
          );

          await tester.tap(find.byTooltip('Añadir operación'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Suscripción').last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Reembolso').last);
          await tester.pumpAndSettle();

          await tester.enterText(
            find.widgetWithText(TextFormField, 'Importe'),
            '1000',
          );

          await tester.tap(find.text('Aceptar'));
          await tester.pumpAndSettle();

          await tester.ensureVisible(find.text('Guardar'));
          await tester.tap(find.text('Guardar'));
          await tester.pump();

          await tester.runAsync(() => saveCompleted.future);
          await tester.pump();

          final investments = await tester.runAsync(
            DatabaseService.getHistoricalInvestments,
          );

          expect(investments, isEmpty);
        } finally {
          await DatabaseService.resetDatabasePathForTesting();
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );
  });
}
