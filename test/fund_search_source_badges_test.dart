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

  group('LF-UI-1: fuentes de identidad y valoración', () {
    testWidgets(
      'LF-UI-1.1: muestra por separado identidad CNMV y valoración Yahoo',
      (WidgetTester tester) async {
        final date = DateTime(2026, 10, 20);

        final fund = FundData(
          // ISIN real y válido para evitar activar la resolución de identidad.
          isin: 'ES0146722014',
          symbol: 'TEST',
          name: 'Fondo de prueba',
          lastValue: 110.0,
          currency: 'EUR',
          date: date,
          history: [PricePoint(date, 110.0)],
          source: FundSource.cnmv,
          valuationSource: FundSource.yahoo,
        );

        final match = FundSearchMatch(
          isin: fund.isin,
          symbol: fund.symbol,
          name: fund.name,
          source: FundSource.cnmv,
        );

        var searchCalls = 0;
        var fetchCalls = 0;

        final provider = FundProvider(
          fundSearch: (String query, {required FundSearchMode mode}) async {
            searchCalls++;
            return [match];
          },
          fundSearchFetcher: (requestedMatch) async {
            fetchCalls++;
            expect(requestedMatch.isin, fund.isin);

            return ScrapeResult(
              data: fund,
              isResolved: true,
              source: FundSource.cnmv,
            );
          },

          // El resultado principal ya contiene una valoración válida.
          // Evitamos llamadas de red durante los fallbacks.
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

        // 1. Introducir el nombre y buscar.
        await tester.enterText(find.byType(TextField), 'Fondo de prueba');

        await tester.tap(find.byIcon(Icons.search));
        await tester.pumpAndSettle();

        expect(searchCalls, 1);
        //expect(find.text('Fondo de prueba'), findsOneWidget);
        expect(
          find.text('Fondo de prueba', skipOffstage: true),
          findsNWidgets(2),
        );

        // 2. Seleccionar el resultado, no el botón de búsqueda.
        //final resultName = find.text('Fondo de prueba');
        final resultName = find.descendant(
          of: find.byType(ListTile),
          matching: find.text('Fondo de prueba'),
        );
        final resultTile = find.ancestor(
          of: resultName,
          matching: find.byType(ListTile),
        );

        expect(resultTile, findsOneWidget);

        final tile = tester.widget<ListTile>(resultTile);
        expect(
          tile.onTap,
          isNotNull,
          reason: 'El resultado debe ejecutar _handleSearch(match).',
        );

        await tester.tap(resultTile);
        await tester.pumpAndSettle();

        // 3. Verificar que el fetch principal se ha ejecutado
        // y que se muestra el diálogo de confirmación.
        expect(fetchCalls, 1);
        expect(find.byType(AlertDialog), findsOneWidget);

        final dialog = find.byType(AlertDialog);

        // 4. Las dos etiquetas deben aparecer en el diálogo.
        expect(
          find.descendant(of: dialog, matching: find.text('Identity')),
          findsOneWidget,
        );

        expect(
          find.descendant(of: dialog, matching: find.text('Valuation')),
          findsOneWidget,
        );

        // 5. Cada etiqueta debe mostrar su fuente correspondiente.
        expect(
          find.descendant(of: dialog, matching: find.text('CNMV')),
          findsOneWidget,
        );

        expect(
          find.descendant(of: dialog, matching: find.text('YAHOO')),
          findsOneWidget,
        );

        // 6. Cerrar el diálogo sin añadir el fondo a la cartera.
        final closeButton = find.descendant(
          of: dialog,
          matching: find.text('Close'),
        );

        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('LF-UI-1.2: omite las fuentes cuando ambas son null', (
      WidgetTester tester,
    ) async {
      final date = DateTime(2026, 10, 20);

      final fund = FundData(
        // ISIN real y válido para evitar activar la resolución de identidad.
        isin: 'ES0146722014',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        source: null,
        valuationSource: null,
      );

      final match = FundSearchMatch(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        source: FundSource.cnmv,
      );

      var searchCalls = 0;
      var fetchCalls = 0;

      final provider = FundProvider(
        fundSearch: (String query, {required FundSearchMode mode}) async {
          searchCalls++;
          return [match];
        },
        fundSearchFetcher: (requestedMatch) async {
          fetchCalls++;
          expect(requestedMatch.isin, fund.isin);

          return ScrapeResult(
            data: fund,
            isResolved: true,
            source: FundSource.cnmv,
          );
        },

        // El resultado principal ya contiene una valoración válida.
        // Evitamos llamadas de red durante los fallbacks.
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

      // 1. Introducir el nombre y buscar.
      await tester.enterText(find.byType(TextField), 'Fondo de prueba');

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(searchCalls, 1);
      expect(
        find.text('Fondo de prueba', skipOffstage: true),
        findsNWidgets(2),
      );

      // 2. Seleccionar el resultado, no el botón de búsqueda.
      final resultName = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Fondo de prueba'),
      );
      final resultTile = find.ancestor(
        of: resultName,
        matching: find.byType(ListTile),
      );

      expect(resultTile, findsOneWidget);

      final tile = tester.widget<ListTile>(resultTile);
      expect(
        tile.onTap,
        isNotNull,
        reason: 'El resultado debe ejecutar _handleSearch(match).',
      );

      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      // 3. Verificar que el fetch principal se ha ejecutado
      // y que se muestra el diálogo de confirmación.
      expect(fetchCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);

      final dialog = find.byType(AlertDialog);

      // 4. Ninguna etiqueta de fuente debe aparecer si ambas fuentes son null.
      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsNothing,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsNothing,
      );

      // Tampoco deben aparecer los nombres de las fuentes.
      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsNothing,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsNothing,
      );

      // 5. Cerrar el diálogo sin añadir el fondo a la cartera.
      final closeButton = find.descendant(
        of: dialog,
        matching: find.text('Close'),
      );

      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('LF-UI-1.3: muestra identidad cuando la valoración es null', (
      WidgetTester tester,
    ) async {
      final date = DateTime(2026, 10, 20);

      final fund = FundData(
        // ISIN real y válido para evitar activar la resolución de identidad.
        isin: 'ES0146722014',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        source: FundSource.cnmv,
        valuationSource: null,
      );

      final match = FundSearchMatch(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        source: FundSource.cnmv,
      );

      var searchCalls = 0;
      var fetchCalls = 0;

      final provider = FundProvider(
        fundSearch: (String query, {required FundSearchMode mode}) async {
          searchCalls++;
          return [match];
        },
        fundSearchFetcher: (requestedMatch) async {
          fetchCalls++;
          expect(requestedMatch.isin, fund.isin);

          return ScrapeResult(
            data: fund,
            isResolved: true,
            source: FundSource.cnmv,
          );
        },

        // El resultado principal ya contiene una valoración válida.
        // Evitamos llamadas de red durante los fallbacks.
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

      // 1. Introducir el nombre y buscar.
      await tester.enterText(find.byType(TextField), 'Fondo de prueba');

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(searchCalls, 1);
      expect(
        find.text('Fondo de prueba', skipOffstage: true),
        findsNWidgets(2),
      );

      // 2. Seleccionar el resultado, no el botón de búsqueda.
      final resultName = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Fondo de prueba'),
      );
      final resultTile = find.ancestor(
        of: resultName,
        matching: find.byType(ListTile),
      );

      expect(resultTile, findsOneWidget);

      final tile = tester.widget<ListTile>(resultTile);
      expect(
        tile.onTap,
        isNotNull,
        reason: 'El resultado debe ejecutar _handleSearch(match).',
      );

      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      // 3. Verificar que el fetch principal se ha ejecutado
      // y que se muestra el diálogo de confirmación.
      expect(fetchCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);

      final dialog = find.byType(AlertDialog);

      // 4. La fuente de identidad debe aparecer.
      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsOneWidget,
      );

      // 5. La fuente de valoración no debe aparecer.
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsNothing,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsNothing,
      );

      // 6. Cerrar el diálogo sin añadir el fondo a la cartera.
      final closeButton = find.descendant(
        of: dialog,
        matching: find.text('Close'),
      );

      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('LF-UI-1.4: muestra valoración cuando la identidad es null', (
      WidgetTester tester,
    ) async {
      final date = DateTime(2026, 10, 20);

      final fund = FundData(
        // ISIN real y válido para evitar activar la resolución de identidad.
        isin: 'ES0146722014',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        source: null,
        valuationSource: FundSource.yahoo,
      );

      final match = FundSearchMatch(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        source: FundSource.cnmv,
      );

      var searchCalls = 0;
      var fetchCalls = 0;

      final provider = FundProvider(
        fundSearch: (String query, {required FundSearchMode mode}) async {
          searchCalls++;
          return [match];
        },
        fundSearchFetcher: (requestedMatch) async {
          fetchCalls++;
          expect(requestedMatch.isin, fund.isin);

          return ScrapeResult(
            data: fund,
            isResolved: true,
            source: FundSource.cnmv,
          );
        },

        // El resultado principal ya contiene una valoración válida.
        // Evitamos llamadas de red durante los fallbacks.
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

      // 1. Introducir el nombre y buscar.
      await tester.enterText(find.byType(TextField), 'Fondo de prueba');

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(searchCalls, 1);
      expect(
        find.text('Fondo de prueba', skipOffstage: true),
        findsNWidgets(2),
      );

      // 2. Seleccionar el resultado, no el botón de búsqueda.
      final resultName = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Fondo de prueba'),
      );
      final resultTile = find.ancestor(
        of: resultName,
        matching: find.byType(ListTile),
      );

      expect(resultTile, findsOneWidget);

      final tile = tester.widget<ListTile>(resultTile);
      expect(
        tile.onTap,
        isNotNull,
        reason: 'El resultado debe ejecutar _handleSearch(match).',
      );

      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      // 3. Verificar que el fetch principal se ha ejecutado
      // y que se muestra el diálogo de confirmación.
      expect(fetchCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);

      final dialog = find.byType(AlertDialog);

      // 4. La fuente de identidad no debe aparecer
      expect(
        find.descendant(of: dialog, matching: find.text('Identity')),
        findsNothing,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('CNMV')),
        findsNothing,
      );

      // La fuente de valoración debe aparecer.
      expect(
        find.descendant(of: dialog, matching: find.text('Valuation')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: dialog, matching: find.text('YAHOO')),
        findsOneWidget,
      );

      final closeButton = find.descendant(
        of: dialog,
        matching: find.text('Close'),
      );

      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('LF-UI-1.5: muestra correctamente ambas fuentes', (
      WidgetTester tester,
    ) async {
      final date = DateTime(2026, 10, 20);

      final fund = FundData(
        // ISIN real y válido para evitar activar la resolución de identidad.
        isin: 'ES0146722014',
        symbol: 'TEST',
        name: 'Fondo de prueba',
        lastValue: 110.0,
        currency: 'EUR',
        date: date,
        history: [PricePoint(date, 110.0)],
        source: FundSource.cnmv,
        valuationSource: FundSource.yahoo,
      );

      final match = FundSearchMatch(
        isin: fund.isin,
        symbol: fund.symbol,
        name: fund.name,
        source: FundSource.cnmv,
      );

      var searchCalls = 0;
      var fetchCalls = 0;

      final provider = FundProvider(
        fundSearch: (String query, {required FundSearchMode mode}) async {
          searchCalls++;
          return [match];
        },
        fundSearchFetcher: (requestedMatch) async {
          fetchCalls++;
          expect(requestedMatch.isin, fund.isin);

          return ScrapeResult(
            data: fund,
            isResolved: true,
            source: FundSource.cnmv,
          );
        },

        // El resultado principal ya contiene una valoración válida.
        // Evitamos llamadas de red durante los fallbacks.
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

      // 1. Introducir el nombre y buscar.
      await tester.enterText(find.byType(TextField), 'Fondo de prueba');

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(searchCalls, 1);
      expect(
        find.text('Fondo de prueba', skipOffstage: true),
        findsNWidgets(2),
      );

      // 2. Seleccionar el resultado, no el botón de búsqueda.
      final resultName = find.descendant(
        of: find.byType(ListTile),
        matching: find.text('Fondo de prueba'),
      );
      final resultTile = find.ancestor(
        of: resultName,
        matching: find.byType(ListTile),
      );

      expect(resultTile, findsOneWidget);

      final tile = tester.widget<ListTile>(resultTile);
      expect(
        tile.onTap,
        isNotNull,
        reason: 'El resultado debe ejecutar _handleSearch(match).',
      );

      await tester.tap(resultTile);
      await tester.pumpAndSettle();

      // 3. Verificar que el fetch principal se ha ejecutado
      // y que se muestra el diálogo de confirmación.
      expect(fetchCalls, 1);
      expect(find.byType(AlertDialog), findsOneWidget);

      final dialog = find.byType(AlertDialog);

      // 4.

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

      final closeButton = find.descendant(
        of: dialog,
        matching: find.text('Close'),
      );

      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
