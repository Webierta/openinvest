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
      'LF-140.25: el formulario delega el guardado de sus operaciones válidas',
      (tester) async {
        HistoricalInvestment? savedInvestment;
        List<HistoricalOperation>? savedOperations;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                savedInvestment = investment;
                savedOperations = operations;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión válida',
        );

        // Primera operación: entrada de capital.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: salida de capital.
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

        expect(find.byType(HistoricalInvestmentFormPage), findsOneWidget);
        expect(find.text('Inversión válida'), findsOneWidget);
        expect(find.byTooltip('Añadir operación'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(savedInvestment, isNotNull);
        expect(savedInvestment!.name, 'Inversión válida');

        expect(savedOperations, isNotNull);
        expect(savedOperations, hasLength(2));
        expect(
          savedOperations!.first.type,
          HistoricalOperationType.subscription,
        );
        expect(savedOperations!.last.type, HistoricalOperationType.redemption);

        expect(
          find.textContaining('No se pudo guardar el histórico'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'LF-142.33: no delega el guardado si la primera operación es una salida',
      (tester) async {
        var saveCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalled = true;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión con primera salida',
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

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(saveCalled, isFalse);
        expect(
          find.textContaining('La primera operación debe ser una entrada'),
          findsOneWidget,
        );

        expect(find.text('Reembolso'), findsOneWidget);
        expect(find.text('Inversión con primera salida'), findsOneWidget);
      },
    );

    testWidgets(
      'LF-142.34: no delega el guardado si la secuencia cronológica es inválida',
      (tester) async {
        var saveCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalled = true;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión con secuencia inválida',
        );

        // Primera operación: reembolso.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Suscripción').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reembolso').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '500',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        expect(find.text('Reembolso'), findsOneWidget);
        expect(find.text('Suscripción'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(saveCalled, isFalse);
        expect(
          find.textContaining('La primera operación debe ser una entrada'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'LF-142.35: permite guardar operaciones añadidas en orden cronológico inverso',
      (tester) async {
        HistoricalInvestment? savedInvestment;
        List<HistoricalOperation>? savedOperations;

        final yesterday = DateTime.now().subtract(const Duration(days: 1));

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                savedInvestment = investment;
                savedOperations = operations;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión con orden inverso',
        );

        // Primera operación añadida: reembolso con fecha de hoy.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Suscripción').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reembolso').last);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '500',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación añadida: suscripción con fecha de ayer.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Fecha'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('${yesterday.day}').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('${yesterday.day}').last);
        await tester.pumpAndSettle();

        final datePicker = find.byType(DatePickerDialog);
        await tester.tap(
          find.descendant(of: datePicker, matching: find.text('Aceptar')),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        expect(find.text('Reembolso'), findsOneWidget);
        expect(find.text('Suscripción'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(savedInvestment, isNotNull);
        expect(savedInvestment!.name, 'Inversión con orden inverso');

        expect(savedOperations, isNotNull);
        expect(savedOperations, hasLength(2));

        // Se conserva el orden de introducción.
        expect(savedOperations![0].type, HistoricalOperationType.redemption);
        expect(savedOperations![1].type, HistoricalOperationType.subscription);

        // Pero cronológicamente la entrada precede a la salida.
        expect(
          savedOperations![1].date.isBefore(savedOperations![0].date),
          isTrue,
        );

        expect(
          find.textContaining('No se pudo guardar el histórico'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'LF-142.36: conserva el orden de registro cuando dos operaciones comparten fecha',
      (tester) async {
        HistoricalInvestment? savedInvestment;
        List<HistoricalOperation>? savedOperations;

        final today = DateTime.now();

        Future<void> selectToday() async {
          await tester.tap(find.text('Fecha').last);
          await tester.pumpAndSettle();

          final datePicker = find.byType(DatePickerDialog);
          await tester.tap(
            find
                .descendant(of: datePicker, matching: find.text('${today.day}'))
                .last,
          );
          await tester.pumpAndSettle();

          await tester.tap(
            find.descendant(of: datePicker, matching: find.text('Aceptar')),
          );
          await tester.pumpAndSettle();
        }

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                savedInvestment = investment;
                savedOperations = operations;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión con fecha coincidente',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await selectToday();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        // Segunda operación: reembolso en la misma fecha.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Suscripción').last);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Reembolso').last);
        await tester.pumpAndSettle();

        await selectToday();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '500',
        );

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(savedInvestment, isNotNull);
        expect(savedOperations, isNotNull);
        expect(savedOperations, hasLength(2));

        expect(savedOperations![0].type, HistoricalOperationType.subscription);
        expect(savedOperations![1].type, HistoricalOperationType.redemption);

        expect(savedOperations![0].date, savedOperations![1].date);

        expect(
          find.textContaining('No se pudo guardar el histórico'),
          findsNothing,
        );
      },
    );
  });
}
