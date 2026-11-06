import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    testWidgets(
      'LF-140.23: no persiste una inversión cuya primera operación es una salida',
      (WidgetTester tester) async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;

        final temporaryDirectory = await Directory.systemTemp.createTemp(
          'historical_investment_form_test_',
        );

        try {
          await DatabaseService.useDatabasePathForTesting(
            path.join(temporaryDirectory.path, 'test.db'),
          );

          await tester.pumpWidget(
            const MaterialApp(home: HistoricalInvestmentFormPage()),
          );

          // Identificación de la inversión.
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Nombre de la inversión'),
            'Inversión inválida',
          );

          // Abrimos el diálogo para añadir una operación.
          await tester.tap(find.byTooltip('Añadir operación'));
          await tester.pumpAndSettle();

          // Seleccionamos Reembolso como primera operación.
          await tester.tap(find.text('Suscripción').last);
          await tester.pumpAndSettle();

          await tester.tap(find.text('Reembolso').last);
          await tester.pumpAndSettle();

          // Introducimos el importe.
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Importe'),
            '1000',
          );

          await tester.tap(find.widgetWithText(FilledButton, 'Aceptar'));
          await tester.pumpAndSettle();

          // Intentamos guardar la inversión.
          await tester.ensureVisible(find.text('Guardar'));

          /* await tester.tap(find.text('Guardar'));
          await tester.pumpAndSettle();

          // Esperamos a que termine la operación asíncrona de guardado.
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          });
          await tester.pumpAndSettle(); */

          await tester.tap(find.text('Guardar'));

          // Dejamos que Flutter procese el inicio del guardado.
          await tester.pump();

          // Permitimos que se completen las operaciones asíncronas reales de SQLite.
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(seconds: 1));
          });

          // Actualizamos la interfaz sin esperar a que desaparezcan todas
          // las animaciones o elementos temporales.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // La inversión inválida no debe persistirse.
          final investments = await DatabaseService.getHistoricalInvestments();

          expect(investments, isEmpty);

          // El formulario debe seguir mostrando el error.
          expect(
            find.textContaining('No se pudo guardar el histórico'),
            findsOneWidget,
          );
        } finally {
          await DatabaseService.resetDatabasePathForTesting();
          await temporaryDirectory.delete(recursive: true);
        }
      },
    );
  });
}
