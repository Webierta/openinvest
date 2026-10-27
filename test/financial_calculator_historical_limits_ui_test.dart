import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_details_tabs/fund_operations_list.dart';
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

  testWidgets(
    'LF-131.2: cambiar la fecha recalcula ambos máximos cronológicos',
    (tester) async {
      await openOperationDialog(tester);

      await selectSellOperation(tester);

      final context = tester.element(find.byType(FundOperationsList));
      final l10n = AppLocalizations.of(context)!;

      await tester.tap(find.text(l10n.dateLabel));
      await tester.pumpAndSettle();

      // Si la fecha está en el mes anterior, navegamos hasta ese mes.
      while (find
          .text(DateFormat.yMMMM('es_ES').format(firstBuyDate))
          .evaluate()
          .isEmpty) {
        final previousMonth = find.byIcon(Icons.chevron_left);

        if (previousMonth.evaluate().isEmpty) {
          break;
        }

        await tester.tap(previousMonth.first);
        await tester.pumpAndSettle();
      }

      // La fecha objetivo es dos días anterior a hoy.
      await tester.tap(find.text('${firstBuyDate.day}').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Max: ${NumberFormat('#,##0.####', 'es_ES').format(20)}'),
        findsOneWidget,
      );

      expect(
        find.text('Max: ${NumberFormat('#,##0.## €', 'es_ES').format(100)}'),
        findsOneWidget,
      );
    },
  );
}
