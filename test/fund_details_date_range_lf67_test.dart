import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_details_page.dart';
import 'package:provider/provider.dart';

class _RecordingFundProvider extends FundProvider {
  String? requestedIsin;
  DateTimeRange? requestedRange;
  int rangeCallCount = 0;

  @override
  Future<bool> searchFundByRange(String isin, DateTimeRange range) async {
    requestedIsin = isin;
    requestedRange = range;
    rangeCallCount++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final valuationDate = DateTime.now();

  FundData createFund({required FundSource? valuationSource}) {
    return FundData(
      isin: 'ES0146722014',
      symbol: 'TEST',
      name: 'Fondo de prueba LF-67',
      lastValue: 110.0,
      currency: 'EUR',
      date: valuationDate,
      history: [PricePoint(valuationDate, 110.0)],
      source: FundSource.cnmv,
      valuationSource: valuationSource,
    );
  }

  Future<FundProvider> mountDetailsPage(
    WidgetTester tester, {
    required FundSource? valuationSource,
    FundProvider? testProvider,
  }) async {
    final provider = testProvider ?? FundProvider();

    provider.selectFund(createFund(valuationSource: valuationSource));

    await tester.pumpWidget(
      ChangeNotifierProvider<FundProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FundDetailsPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    return provider;
  }

  tearDown(() {
    FundProvider.disposeHttpClient();
  });

  group('LF-67: confirmación de descarga por rango', () {
    testWidgets(
      'LF-67.UI.1: cancelar la confirmación no abre el selector de fechas',
      (tester) async {
        await mountDetailsPage(tester, valuationSource: FundSource.queFondos);

        await tester.tap(find.byIcon(Icons.date_range));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación'), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('Confirmar'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación'), findsNothing);
        expect(find.byType(DateRangePickerDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('LF-67.UI.2: confirmar permite abrir el selector de fechas', (
      tester,
    ) async {
      await mountDetailsPage(tester, valuationSource: FundSource.queFondos);

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmación'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmación'), findsNothing);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'LF-67.UI.3: otra fuente de valoración no requiere confirmación',
      (tester) async {
        await mountDetailsPage(tester, valuationSource: FundSource.yahoo);

        await tester.tap(find.byIcon(Icons.date_range));
        await tester.pumpAndSettle();

        expect(find.text('Confirmación'), findsNothing);
        expect(find.byType(DateRangePickerDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('LF-67.UI.4: confirmar el rango solicita la valoración '
        'con el ISIN y las fechas seleccionadas', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange, isNotNull);

      final range = provider.requestedRange!;
      expect(
        range.start.isBefore(range.end) ||
            range.start.isAtSameMomentAs(range.end),
        isTrue,
      );
    });

    testWidgets('LF-68.1: transmite las fechas introducidas al solicitar '
        'la valoración por rango', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      final dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      await tester.enterText(dateFields.at(0), '01/10/2026');
      await tester.enterText(dateFields.at(1), '15/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange, isNotNull);

      expect(provider.requestedRange!.start, DateTime(2026, 10, 1));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 15));
    });

    testWidgets('LF-68.2: cancelar el selector de fechas no solicita '
        'una valoración por rango', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(provider.rangeCallCount, 0);
      expect(provider.requestedIsin, isNull);
      expect(provider.requestedRange, isNull);
    });

    testWidgets('LF-68.3: reconstruir la interfaz no duplica la solicitud '
        'de valoración por rango', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);

      // Reconstruir la interfaz conservando el mismo provider.
      await tester.pumpWidget(
        ChangeNotifierProvider<FundProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FundDetailsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
    });

    testWidgets('LF-68.4: un rango con fecha inicial posterior a la final '
        'no solicita una valoración', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      final dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      // La fecha inicial es posterior a la fecha final.
      await tester.enterText(dateFields.at(0), '15/10/2026');
      await tester.enterText(dateFields.at(1), '01/10/2026');
      await tester.pumpAndSettle();

      // No aceptar un rango inválido ni solicitar la valoración.
      expect(provider.rangeCallCount, 0);

      // El selector debe seguir abierto para permitir corregirlo.
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
    });

    testWidgets('LF-68.5: cancelar y reabrir el selector permite solicitar '
        'un nuevo rango válido', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      // Primera apertura y cancelación.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(provider.rangeCallCount, 0);

      // Segunda apertura con un rango nuevo.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      final dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      await tester.enterText(dateFields.at(0), '01/10/2026');
      await tester.enterText(dateFields.at(1), '15/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange, isNotNull);
      expect(provider.requestedRange!.start, DateTime(2026, 10, 1));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 15));
    });

    testWidgets('LF-68.6: dos rangos aceptados generan dos solicitudes '
        'con fechas independientes', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      // Primera consulta: del 1 al 5 de octubre.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      var dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      await tester.enterText(dateFields.at(0), '01/10/2026');
      await tester.enterText(dateFields.at(1), '05/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedRange!.start, DateTime(2026, 10, 1));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 5));

      // Segunda consulta: del 10 al 15 de octubre.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      await tester.enterText(dateFields.at(0), '10/10/2026');
      await tester.enterText(dateFields.at(1), '15/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 2);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange, isNotNull);
      expect(provider.requestedRange!.start, DateTime(2026, 10, 10));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 15));
    });

    testWidgets('LF-68.7: cancelar una nueva selección conserva la última '
        'consulta válida', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      // Primera consulta válida: del 1 al 5 de octubre.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      var dateFields = find.byType(TextField);
      expect(dateFields, findsNWidgets(2));

      await tester.enterText(dateFields.at(0), '01/10/2026');
      await tester.enterText(dateFields.at(1), '05/10/2026');
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedRange!.start, DateTime(2026, 10, 1));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 5));

      // Abrir una segunda selección y cancelarla.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // La cancelación no debe generar otra solicitud ni alterar
      // el rango de la última consulta aceptada.
      expect(provider.rangeCallCount, 1);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange!.start, DateTime(2026, 10, 1));
      expect(provider.requestedRange!.end, DateTime(2026, 10, 5));
    });

    testWidgets('LF-68.8: la fuente de valoración determina la confirmación '
        'después de una consulta por rango', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.queFondos,
        testProvider: provider,
      );

      // Primera consulta válida con QueFondos.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);

      // Cambiar el fondo seleccionado por otro cuya valoración
      // procede de Yahoo, conservando el mismo provider.
      provider.selectFund(createFund(valuationSource: FundSource.yahoo));
      await tester.pumpAndSettle();

      // Yahoo no debe exigir confirmación antes de abrir el selector.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsNothing);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // Cerrar el selector sin generar otra solicitud.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
    });

    testWidgets('LF-68.9: cambiar de Yahoo a QueFondos vuelve a exigir '
        'confirmación para descargar por rango', (WidgetTester tester) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.yahoo,
        testProvider: provider,
      );

      // Con Yahoo, el selector se abre directamente.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsNothing);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 0);

      // Cambiar el fondo a uno cuya valoración procede de QueFondos.
      provider.selectFund(createFund(valuationSource: FundSource.queFondos));
      await tester.pumpAndSettle();

      // Ahora debe solicitar confirmación y aún no abrir el selector.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.byType(DateRangePickerDialog), findsNothing);

      // Cancelar la confirmación no debe iniciar la descarga.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(provider.rangeCallCount, 0);
    });

    testWidgets('LF-68.10: cambiar la fuente antes de aceptar el rango '
        'solicita una sola valoración para el fondo actual', (
      WidgetTester tester,
    ) async {
      final provider = _RecordingFundProvider();

      await mountDetailsPage(
        tester,
        valuationSource: FundSource.yahoo,
        testProvider: provider,
      );

      // Con Yahoo, el selector se abre sin confirmación.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // Cancelar no debe generar solicitudes.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 0);

      // Cambiar el fondo seleccionado a QueFondos.
      provider.selectFund(createFund(valuationSource: FundSource.queFondos));
      await tester.pumpAndSettle();

      // La fuente nueva debe exigir confirmación.
      await tester.tap(find.byIcon(Icons.date_range));
      await tester.pumpAndSettle();

      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.byType(DateRangePickerDialog), findsNothing);

      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(find.byType(DateRangePickerDialog), findsOneWidget);

      // Aceptar el rango inicial propuesto por el selector.
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(provider.rangeCallCount, 1);
      expect(provider.requestedIsin, 'ES0146722014');
      expect(provider.requestedRange, isNotNull);
    });
  });
}
