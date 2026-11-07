import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/screens/historical_investment_form_page.dart';
import 'package:investing/screens/historical_investments_page.dart';
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

    testWidgets(
      'LF-142.62: delega una sola vez el guardado con la inversión y operaciones correctas',
      (tester) async {
        HistoricalInvestment? savedInvestment;
        List<HistoricalOperation>? savedOperations;
        var saveCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalls++;
                savedInvestment = investment;
                savedOperations = operations;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión LF-142.62',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: reembolso.
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

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(saveCalls, 1);

        expect(savedInvestment, isNotNull);
        expect(savedInvestment!.name, 'Inversión LF-142.62');

        expect(savedOperations, isNotNull);
        expect(savedOperations, hasLength(2));

        final operations = savedOperations!;

        expect(operations[0].type, HistoricalOperationType.subscription);
        expect(operations[0].amount, 1000);

        expect(operations[1].type, HistoricalOperationType.redemption);
        expect(operations[1].amount, 500);

        expect(
          operations.every(
            (operation) => operation.investmentUid == savedInvestment!.uid,
          ),
          isTrue,
        );

        expect(operations[0].uid, isNot(operations[1].uid));

        expect(
          find.textContaining('No se pudo guardar el histórico'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'LF-142.63: conserva el formulario y muestra el error si falla el guardado',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                throw Exception('Error de persistencia LF-142.63');
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión LF-142.63',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: reembolso.
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

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(
          find.textContaining(
            'No se pudo guardar el histórico: Exception: Error de persistencia LF-142.63',
          ),
          findsOneWidget,
        );

        expect(find.byType(HistoricalInvestmentFormPage), findsOneWidget);
        expect(find.text('Inversión LF-142.63'), findsOneWidget);
        expect(find.byTooltip('Añadir operación'), findsOneWidget);
      },
    );

    testWidgets(
      'LF-142.64: permite reintentar el guardado después de un error',
      (tester) async {
        var saveCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalls++;
                throw Exception('Error de intento $saveCalls');
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión LF-142.64',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: reembolso.
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

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        // Primer intento.
        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(saveCalls, 1);
        expect(find.textContaining('Error de intento 1'), findsOneWidget);

        // Esperamos a que desaparezca el SnackBar y se estabilice la pantalla.

        await tester.ensureVisible(find.text('Guardar'));
        await tester.pumpAndSettle();

        // Segundo intento.
        // Esperar a que termine el SnackBar.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        // Desplazar el formulario hasta el botón.
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();

        final saveButton = find.byType(FilledButton);
        expect(saveButton, findsOneWidget);

        await tester.tap(saveButton);
        await tester.pump();

        expect(saveCalls, 2);
        expect(find.textContaining('Error de intento 2'), findsOneWidget);

        expect(find.byType(HistoricalInvestmentFormPage), findsOneWidget);
      },
    );

    testWidgets(
      'LF-142.66: navega al histórico después de guardar correctamente',
      (tester) async {
        var saveCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalls++;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión LF-142.66',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: reembolso.
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

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        // Guardar la inversión.
        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        //await tester.pumpAndSettle();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // El guardado debe haberse delegado una sola vez.
        expect(saveCalls, 1);

        // El formulario debe haber sido sustituido por el histórico.
        expect(find.byType(HistoricalInvestmentFormPage), findsNothing);

        expect(find.byType(HistoricalInvestmentsPage), findsOneWidget);
      },
    );

    testWidgets(
      'LF-142.67: muestra confirmación después de guardar correctamente',
      (tester) async {
        var saveCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: HistoricalInvestmentFormPage(
              saveInvestment: (investment, operations) async {
                saveCalls++;
              },
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).first,
          'Inversión LF-142.67',
        );

        // Primera operación: suscripción.
        await tester.tap(find.byTooltip('Añadir operación'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe'),
          '1000',
        );

        await tester.tap(find.text('Aceptar'));
        await tester.pumpAndSettle();

        // Segunda operación: reembolso.
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

        await tester.tap(find.text('Aceptar').last);
        await tester.pumpAndSettle();

        // Guardar la inversión.
        await tester.scrollUntilVisible(
          find.text('Guardar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.tap(find.text('Guardar'));
        //await tester.pumpAndSettle();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(saveCalls, 1);

        // Debe mostrarse la confirmación del guardado.
        expect(
          find.text('Inversión histórica guardada correctamente'),
          findsOneWidget,
        );

        // La navegación al histórico también debe haberse completado.
        expect(find.byType(HistoricalInvestmentFormPage), findsNothing);
        expect(find.byType(HistoricalInvestmentsPage), findsOneWidget);
      },
    );

    testWidgets('LF-142.68: rechaza una secuencia inválida antes de guardar', (
      tester,
    ) async {
      var saveCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HistoricalInvestmentFormPage(
            saveInvestment: (investment, operations) async {
              saveCalls++;
            },
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'Inversión LF-142.68',
      );

      // Añadir una única operación de reembolso.
      // Una secuencia que comienza con una salida es inválida.
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

      await tester.tap(find.text('Aceptar').last);
      await tester.pumpAndSettle();

      // Intentar guardar.
      await tester.scrollUntilVisible(
        find.text('Guardar'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // El validador debe impedir que se invoque el callback.
      expect(saveCalls, 0);

      // Debe mostrarse el motivo del rechazo.
      expect(
        find.textContaining(
          'La primera operación debe ser una entrada de capital.',
        ),
        findsOneWidget,
      );

      // El formulario debe permanecer disponible.
      expect(find.byType(HistoricalInvestmentFormPage), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // No debe aparecer la confirmación de guardado.
      expect(
        find.text('Inversión histórica guardada correctamente'),
        findsNothing,
      );

      expect(find.byType(HistoricalInvestmentsPage), findsNothing);
    });
  });
}
