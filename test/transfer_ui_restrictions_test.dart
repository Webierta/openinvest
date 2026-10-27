import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_details_tabs/fund_operations_list.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TR-2.2: tocar un traspaso no abre el diálogo de edición', (
    tester,
  ) async {
    final date = DateTime(2026, 10, 3);
    final operation = FundOperation(
      id: 1,
      isin: 'SOURCE',
      date: date,
      type: OperationType.outTransfer,
      units: 2,
      price: 100,
      amount: 200,
    );

    final fund = FundData(
      isin: 'SOURCE',
      symbol: 'SOURCE',
      name: 'Fondo origen',
      lastValue: 100,
      currency: 'EUR',
      date: date,
      history: [PricePoint(date, 100)],
      operations: [operation],
    );

    final provider = FundProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<FundProvider>.value(
        value: provider,
        child: MaterialApp(
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

    //await tester.pumpAndSettle();

    //await tester.tap(find.text('Traspaso').first);
    //await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(FundOperationsList)),
    )!;

    await tester.tap(find.byIcon(Icons.output_outlined));
    await tester.pumpAndSettle();

    expect(find.text(l10n.editOperation), findsNothing);

    expect(find.text('Editar operación'), findsNothing);
  });
}
