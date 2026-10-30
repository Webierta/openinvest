import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/screens/fund_details_tabs/price_history_table.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final date1 = DateTime(2026, 10, 20);
  final date2 = DateTime(2026, 10, 21);
  final date3 = DateTime(2026, 10, 22);

  FundData createFund() {
    return FundData(
      isin: 'TEST-LF-5',
      symbol: 'LF5',
      name: 'Fondo de prueba LF-5',
      lastValue: 120.0,
      currency: 'EUR',
      date: date3,
      history: [
        PricePoint(date1, 100.0, source: PricePointSource.yahoo),
        PricePoint(date2, 110.0, source: PricePointSource.manual),
        PricePoint(date3, 120.0, source: PricePointSource.cnmv),
      ],
      valuationSource: FundSource.financialTimes,
    );
  }

  Future<void> mountTable(WidgetTester tester, FundData fund) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            height: 700,
            width: 900,
            child: PriceHistoryTable(
              fund: fund,
              priceFormat: NumberFormat('#,##0.00', 'es_ES'),
              percentFormat: NumberFormat('#,##0.00', 'es_ES'),
              smartFormat: NumberFormat('#,##0.00', 'es_ES'),
              dateFormat: DateFormat('dd/MM/yyyy'),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('LF-5: visualización del origen de los precios', () {
    testWidgets(
      'LF-5.1: muestra el origen individual de cada precio histórico',
      (tester) async {
        await mountTable(tester, createFund());

        expect(find.text('Origen'), findsOneWidget);
        expect(find.text('yahoo'), findsOneWidget);
        expect(find.text('manual'), findsOneWidget);
        expect(find.text('cnmv'), findsOneWidget);

        // El origen de cada punto no debe sustituirse por
        // el proveedor de la última valoración del fondo.
        expect(find.text('financialTimes'), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'LF-5.2: muestra un marcador cuando el precio no tiene origen',
      (tester) async {
        final fund = FundData(
          isin: 'TEST-LF-5-NULL',
          symbol: 'LF5N',
          name: 'Fondo sin origen',
          lastValue: 100.0,
          currency: 'EUR',
          date: date1,
          history: [PricePoint(date1, 100.0)],
        );

        await mountTable(tester, fund);

        expect(find.text('Origen'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
