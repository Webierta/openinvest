import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/fund_search_mode.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_search_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LF-UI-4: Comportamiento con fuentes parciales', () {
    Future<void> openFundDialog(
      WidgetTester tester, {
      required FundSource? source,
      required FundSource? valuationSource,
    }) async {
      final date = DateTime(2026, 10, 20);
      final fund = FundData(
        isin: 'ES0146722014',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        source: source,
        valuationSource: valuationSource,
      );

      final match = FundSearchMatch(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        // La fuente de búsqueda no debe determinar las
        // insignias del fondo recuperado.
        source: source ?? FundSource.local,
      );

      final provider = FundProvider(
        fundSearch: (String query, {required FundSearchMode mode}) async => [
          match,
        ],
        fundSearchFetcher: (_) async =>
            ScrapeResult(data: fund, isResolved: true, source: source),
        fundIsinFetcher: (_) async => ScrapeResult(),
        ftByIsinFetcher: (_) async => null,
        queFondosFetcher: (_) async => null,
        ftFetcher: (_) async => null,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<FundProvider>.value(
          value: provider,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const FundSearchPage(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Fondo de prueba');
      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      final resultTile = find.ancestor(
        of: find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Fondo de prueba'),
        ),
        matching: find.byType(ListTile),
      );

      expect(resultTile, findsOneWidget);
      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    }

    testWidgets('LF-UI-4.1: muestra identidad CNMV sin valoración', (
      tester,
    ) async {
      await openFundDialog(
        tester,
        source: FundSource.cnmv,
        valuationSource: null,
      );

      final dialog = find.byType(AlertDialog);

      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsNothing,
      );
    });

    testWidgets('LF-UI-4.2: muestra valoración Yahoo sin identidad', (
      tester,
    ) async {
      await openFundDialog(
        tester,
        source: null,
        valuationSource: FundSource.yahoo,
      );

      final dialog = find.byType(AlertDialog);

      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsOneWidget,
      );
    });

    testWidgets('LF-UI-4.3: no muestra fuentes cuando ambas son null', (
      tester,
    ) async {
      await openFundDialog(tester, source: null, valuationSource: null);

      final dialog = find.byType(AlertDialog);

      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsNothing,
      );
    });
  });
}
