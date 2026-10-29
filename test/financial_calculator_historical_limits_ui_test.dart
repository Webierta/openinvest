import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_details_tabs/fund_operation_form_page.dart';
import 'package:investing/screens/fund_details_tabs/fund_operations_list.dart';
import 'package:investing/utils/financial_calculator.dart';
import 'package:provider/provider.dart';

import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime today;
  late DateTime firstBuyDate;
  late DateTime saleDate;
  late FundData fund;
  late FundProvider provider;

  setUp(() async {
    await initializeDateFormatting('es_ES');
    today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

    firstBuyDate = today.subtract(const Duration(days: 2));
    saleDate = today.subtract(const Duration(days: 1));

    fund = FundData(
      isin: 'TEST00000001',
      symbol: 'TEST',
      name: 'Fondo de prueba',
      lastValue: 10,
      currency: 'EUR',
      date: today,
      history: [
        PricePoint(firstBuyDate, 5),
        PricePoint(saleDate, 6),
        PricePoint(today, 10),
      ],
      operations: [
        FundOperation(
          isin: 'TEST00000001',
          date: firstBuyDate,
          type: OperationType.buy,
          units: 100,
          price: 5,
          amount: 500,
        ),
        FundOperation(
          isin: 'TEST00000001',
          date: saleDate,
          type: OperationType.sell,
          units: 80,
          price: 6,
          amount: 480,
        ),
        FundOperation(
          isin: 'TEST00000001',
          date: today,
          type: OperationType.buy,
          units: 100,
          price: 10,
          amount: 1000,
        ),
      ],
    );

    provider = FundProvider();
  });

  Future<void> openOperationDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FundProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FundOperationsList(fund: fund)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final context = tester.element(find.byType(FundOperationsList));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text(l10n.newOperation));
    await tester.pumpAndSettle();
  }

  Future<void> selectSellOperation(WidgetTester tester) async {
    final sellLabel = find.text('Vender');

    if (sellLabel.evaluate().isNotEmpty) {
      await tester.tap(sellLabel);
    } else {
      final l10n = AppLocalizations.of(
        tester.element(find.byType(SegmentedButton<OperationType>)),
      )!;

      final localizedSell = find.text(l10n.sell);
      expect(localizedSell, findsOneWidget);
      await tester.tap(localizedSell);
    }

    await tester.pumpAndSettle();
  }

  testWidgets('LF-131.1: inicializa los máximos al abrir el diálogo', (
    tester,
  ) async {
    await openOperationDialog(tester);

    await selectSellOperation(tester);

    expect(find.textContaining('Max:'), findsNWidgets(2));

    expect(
      find.text('Max: ${NumberFormat('#,##0.####', 'es_ES').format(120)}'),
      findsOneWidget,
    );

    expect(
      find.text('Max: ${NumberFormat('#,##0.## €', 'es_ES').format(1200)}'),
      findsOneWidget,
    );
  });

  testWidgets('LF-131.2: cambiar la fecha recalcula ambos máximos cronológicos', (
    tester,
  ) async {
    await openOperationDialog(tester);

    await selectSellOperation(tester);

    final context = tester.element(find.byType(FundOperationFormPage));
    final l10n = AppLocalizations.of(context)!;

    await tester.tap(find.text(l10n.dateLabel));
    await tester.pumpAndSettle();

    // Si la fecha está en el mes anterior, navegamos hasta ese mes.
    // Seleccionar directamente la fecha de la primera compra.
    while (find
        .text(DateFormat.yMMMM('es_ES').format(firstBuyDate))
        .evaluate()
        .isEmpty) {
      final previousMonth = find.byIcon(Icons.chevron_left);

      expect(
        previousMonth,
        findsWidgets,
        reason: 'Debe poder navegarse hasta el mes de la primera compra.',
      );

      await tester.tap(previousMonth.first);
      await tester.pumpAndSettle();
    }

    final targetDay = find.text('${firstBuyDate.day}').last;
    expect(targetDay, findsOneWidget);

    await tester.tap(targetDay);
    await tester.pumpAndSettle();

    final acceptButton = find.text('ACEPTAR');
    expect(acceptButton, findsOneWidget);

    await tester.tap(acceptButton);
    await tester.pumpAndSettle();

    debugPrint(
      'Fecha esperada: ${DateFormat('dd/MM/yyyy').format(firstBuyDate)}',
    );

    debugPrint(
      'Fecha mostrada: '
      '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().toList()}',
    );

    debugPrint(
      'Máximos visibles: '
      '${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).whereType<String>().where((s) => s.contains('Max:')).toList()}',
    );

    expect(
      find.text('Max: ${NumberFormat('#,##0.####', 'es_ES').format(20)}'),
      findsOneWidget,
    );

    expect(
      find.text('Max: ${NumberFormat('#,##0.## €', 'es_ES').format(100)}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'LF-131.3: cambiar la fecha hacia adelante recalcula ambos máximos cronológicos',
    (tester) async {
      await openOperationDialog(tester);
      await selectSellOperation(tester);

      final context = tester.element(find.byType(FundOperationFormPage));
      final l10n = AppLocalizations.of(context)!;
      String locale = Localizations.localeOf(context).toString();
      NumberFormat unitsFormat = NumberFormat('#,##0.####', locale);
      NumberFormat moneyFormat = NumberFormat('#,##0.## €', locale);

      // Primero situamos el formulario en la fecha de la primera compra.
      await tester.tap(find.text(l10n.dateLabel));
      await tester.pumpAndSettle();

      final firstMonth = DateFormat.yMMMM('es_ES').format(firstBuyDate);

      while (find.text(firstMonth).evaluate().isEmpty) {
        final previousMonth = find.byIcon(Icons.chevron_left);

        if (previousMonth.evaluate().isEmpty) {
          break;
        }

        await tester.tap(previousMonth.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('${firstBuyDate.day}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat('dd/MM/yyyy').format(firstBuyDate)),
        findsOneWidget,
      );
      expect(find.text('Max: 20'), findsOneWidget);
      expect(find.text('Max: 100 €'), findsOneWidget);

      // Ahora avanzamos a la fecha de la venta.
      await tester.tap(find.text(l10n.dateLabel));
      await tester.pumpAndSettle();

      final saleMonth = DateFormat.yMMMM('es_ES').format(saleDate);

      while (find.text(saleMonth).evaluate().isEmpty) {
        final nextMonth = find.byIcon(Icons.chevron_right);

        if (nextMonth.evaluate().isEmpty) {
          break;
        }

        await tester.tap(nextMonth.first);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('${saleDate.day}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ACEPTAR'));
      await tester.pumpAndSettle();

      // Comprobamos la fecha realmente seleccionada.
      expect(
        find.text(DateFormat('dd/MM/yyyy').format(saleDate)),
        findsOneWidget,
      );

      // La expectativa se obtiene del cálculo financiero para esta fecha,
      // evitando fijar un valor que no corresponda a la fixture.
      final expectedUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        saleDate,
      );

      //final expectedPrice = this.getPrice(saleDate);
      //expect(expectedPrice, isNotNull);
      final expectedPrice = 6.0;

      expect(
        find.text('Max: ${unitsFormat.format(expectedUnits)}'),
        findsOneWidget,
      );
      expect(
        find.text('Max: ${moneyFormat.format(expectedUnits * expectedPrice)}'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'LF-131.4: cambiar repetidamente la fecha actualiza ambos máximos',
    (tester) async {
      await openOperationDialog(tester);
      await selectSellOperation(tester);

      final context = tester.element(find.byType(FundOperationFormPage));
      final l10n = AppLocalizations.of(context)!;

      Future<void> selectDate(DateTime date) async {
        await tester.tap(find.text(l10n.dateLabel));
        await tester.pumpAndSettle();

        final monthLabel = DateFormat.yMMMM('es_ES').format(date);

        while (find.text(monthLabel).evaluate().isEmpty) {
          final displayedMonths = tester
              .widgetList<Text>(find.byType(Text))
              .map((text) => text.data)
              .whereType<String>()
              .toList();

          final targetMonth = DateTime(date.year, date.month);
          final visibleMonth = displayedMonths
              .where((text) => text == monthLabel)
              .toList();

          if (visibleMonth.isNotEmpty) break;

          final next = find.byIcon(Icons.chevron_right);
          final previous = find.byIcon(Icons.chevron_left);

          // Las fechas de la fixture están dentro del mismo mes.
          // Este fallback evita un bucle infinito si no aparece el mes.
          if (next.evaluate().isEmpty && previous.evaluate().isEmpty) {
            fail(
              'No se pudo navegar al mes ${targetMonth.month}/${targetMonth.year}',
            );
          }

          final displayedDateText = displayedMonths
              .where(
                (text) =>
                    RegExp(r'^[a-záéíóúñ]+ de \d{4}$')
                        .hasMatch(text.toLowerCase()),
              )
              .firstOrNull;

          if (displayedDateText == null) {
            fail('No se encontró el título del mes en el calendario');
          }

          final displayedDate = DateFormat.yMMMM('es_ES')
              .parse(displayedDateText);

          if (DateTime(
            displayedDate.year,
            displayedDate.month,
          ).isBefore(targetMonth)) {
            await tester.tap(next.first);
          } else {
            await tester.tap(previous.first);
          }

          await tester.pumpAndSettle();
        }

        await tester.tap(find.text('${date.day}').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ACEPTAR'));
        await tester.pumpAndSettle();

        expect(
          find.text(DateFormat('dd/MM/yyyy').format(date)),
          findsOneWidget,
        );
      }

      Future<void> expectMaxima(double units, double amount) async {
        final unitsText = NumberFormat('#,##0.###', 'es_ES').format(units);
        final amountText = NumberFormat('#,##0.##', 'es_ES').format(amount);

        expect(find.text('Max: $unitsText'), findsOneWidget);
        expect(find.text('Max: $amountText €'), findsOneWidget);
      }

      await selectDate(firstBuyDate);
      await expectMaxima(20, 100);

      await selectDate(saleDate);
      final saleUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        saleDate,
      );
      await expectMaxima(saleUnits, saleUnits * 6.0);

      await selectDate(today);
      final todayUnits = FinancialCalculator.calculateMaxOutflowUnitsAt(
        fund,
        today,
      );
      await expectMaxima(todayUnits, todayUnits * 10.0);

      await selectDate(firstBuyDate);
      await expectMaxima(20, 100);
    },
  );

  testWidgets(
    'LF-131.5: cancelar la selección de fecha conserva ambos máximos',
    (tester) async {
      await openOperationDialog(tester);
      await selectSellOperation(tester);

      final context = tester.element(find.byType(FundOperationFormPage));
      final l10n = AppLocalizations.of(context)!;

      // Estado inicial del formulario.
      expect(find.text(DateFormat('dd/MM/yyyy').format(today)), findsOneWidget);
      expect(find.text('Max: 120'), findsOneWidget);
      expect(find.text('Max: 1.200 €'), findsOneWidget);

      // Abrimos el selector y elegimos otra fecha, pero cancelamos.
      await tester.tap(find.text(l10n.dateLabel));
      await tester.pumpAndSettle();

      await tester.tap(find.text('${firstBuyDate.day}').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar').last);
      await tester.pumpAndSettle();

      // Cancelar no debe cambiar la fecha ni los máximos del formulario.
      expect(find.text(DateFormat('dd/MM/yyyy').format(today)), findsOneWidget);
      expect(find.text('Max: 120'), findsOneWidget);
      expect(find.text('Max: 1.200 €'), findsOneWidget);
    },
  );

  testWidgets('LF-131.6: confirmar la misma fecha conserva ambos máximos', (
    tester,
  ) async {
    await openOperationDialog(tester);
    await selectSellOperation(tester);

    final context = tester.element(find.byType(FundOperationFormPage));
    final l10n = AppLocalizations.of(context)!;
    final initialDate = DateFormat('dd/MM/yyyy').format(today);

    // Guardamos el estado inicial.
    expect(find.text(initialDate), findsOneWidget);
    expect(find.text('Max: 120'), findsOneWidget);
    expect(find.text('Max: 1.200 €'), findsOneWidget);

    // Abrimos el calendario y volvemos a confirmar la misma fecha.
    await tester.tap(find.text(l10n.dateLabel));
    await tester.pumpAndSettle();

    await tester.tap(find.text('${today.day}').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ACEPTAR'));
    await tester.pumpAndSettle();

    // La fecha y ambos máximos deben seguir siendo los mismos.
    expect(find.text(initialDate), findsOneWidget);
    expect(find.text('Max: 120'), findsOneWidget);
    expect(find.text('Max: 1.200 €'), findsOneWidget);
  });
}
