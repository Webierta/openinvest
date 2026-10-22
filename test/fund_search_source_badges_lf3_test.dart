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

  group('LF-UI-3: Correspondencia entre fuentes e insignias', () {
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
        //source: source,
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

    testWidgets('LF-UI-3.1: muestra las insignias CNMV y Yahoo', (
      tester,
    ) async {
      await openFundDialog(
        tester,
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
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
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsOneWidget,
      );
    });

    testWidgets('LF-UI-3.2: muestra las insignias ECB y QueFondos', (
      tester,
    ) async {
      await openFundDialog(
        tester,
        source: FundSource.ecb,
        valuationSource: FundSource.queFondos,
      );

      final dialog = find.byType(AlertDialog);

      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsOneWidget,
      );

      // Estos textos deben coincidir con las etiquetas reales
      // que produce _buildSourceBadge() en tu implementación.
      expect(
        find.descendant(of: dialog, matching: find.text('ECB')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('QUEFONDOS')),
        findsOneWidget,
      );
    });

    testWidgets(
      'LF-UI-3.3: muestra las insignias Morningstar y Financial Times',
      (tester) async {
        await openFundDialog(
          tester,
          source: FundSource.morningstar,
          valuationSource: FundSource.financialTimes,
        );

        final dialog = find.byType(AlertDialog);

        expect(
          find.descendant(of: dialog, matching: find.text('Identity')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: dialog, matching: find.text('Valuation')),
          findsOneWidget,
        );

        expect(
          find.descendant(of: dialog, matching: find.text('MORNINGSTAR')),
          findsOneWidget,
        );

        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('FT'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}
