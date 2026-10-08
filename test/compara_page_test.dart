import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/compara_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('los selectores no desbordan en una pantalla estrecha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final provider = FundProvider()
      ..portfolio = [
        _fund(
          'ES0123456789',
          'Nombre de fondo extremadamente largo con clase de acumulación Alfa',
        ),
        _fund(
          'ES9876543210',
          'Nombre de fondo extremadamente largo con clase de distribución Beta',
        ),
      ];
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      _app(provider, textScaler: const TextScaler.linear(1.5)),
    );
    expect(tester.takeException(), isNull);
    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    final contentTop = tester.getTopLeft(find.text('Fondos para comparar')).dy;
    expect(contentTop - appBarBottom, closeTo(8, 1));

    const firstName =
        'Nombre de fondo extremadamente largo con clase de acumulación Alfa';
    const secondName =
        'Nombre de fondo extremadamente largo con clase de distribución Beta';

    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(firstName).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widgetList<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          )
          .map((dropdown) => dropdown.value)
          .toList(),
      ['ES0123456789', null],
    );

    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(secondName).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widgetList<DropdownButton<String>>(
            find.byType(DropdownButton<String>),
          )
          .map((dropdown) => dropdown.value)
          .toList(),
      ['ES0123456789', 'ES9876543210'],
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Resultado de la comparación'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Evolución histórica'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('comparison-return-chart')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('avisa cuando la cartera tiene menos de dos fondos', (
    tester,
  ) async {
    final provider = FundProvider()..portfolio = [_fund('ONLY', 'Fondo único')];
    addTearDown(provider.dispose);

    await tester.pumpWidget(_app(provider));

    expect(find.text('Comparador'), findsOneWidget);
    expect(
      find.text('Necesitas al menos dos fondos en cartera para compararlos.'),
      findsOneWidget,
    );
    expect(find.byType(DropdownButton<String>), findsNothing);
  });

  testWidgets('exige fondos distintos y muestra la comparación al confirmar', (
    tester,
  ) async {
    final provider = FundProvider()
      ..portfolio = [
        _fund('FIRST', 'Fondo Alfa'),
        _fund('SECOND', 'Fondo Beta'),
      ];
    addTearDown(provider.dispose);

    await tester.pumpWidget(_app(provider));

    expect(find.byType(DropdownButton<String>), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await _selectFund(tester, 0, 'Fondo Alfa');
    await _selectFund(tester, 1, 'Fondo Alfa');
    expect(find.text('Selecciona dos fondos diferentes.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await _selectFund(tester, 1, 'Fondo Beta');
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.text('Comparador'), findsOneWidget);
    expect(find.text('Comparar'), findsOneWidget);
    expect(find.text('Resultado de la comparación'), findsOneWidget);
    expect(find.text('Fondo e historial'), findsOneWidget);
    expect(find.text('Variación en 1 año'), findsOneWidget);
    expect(find.text('Variación desde el inicio'), findsOneWidget);
    expect(find.text('Costes y comisiones'), findsOneWidget);
    expect(find.text('TER total'), findsOneWidget);
    expect(find.text('Comisión de resultados'), findsOneWidget);
    expect(find.text('Gestión'), findsNothing);
    expect(find.text('Depositario'), findsNothing);
    expect(find.text('Gastos operativos'), findsNothing);
    expect(find.text('Tu inversión'), findsOneWidget);
    expect(find.text('Rentabilidad de la posición'), findsNothing);
    expect(
      find.text(
        'Las métricas de inversión requieren una posición abierta en ambos fondos.',
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star), findsNWidgets(10));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.star).at(0)).color,
      Colors.amber,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.star).at(4)).color,
      Colors.grey.shade700,
    );
    expect(find.text('FIRST'), findsAtLeastNWidgets(2));
    expect(find.text('SECOND'), findsAtLeastNWidgets(2));
    final secondRatingCell = tester.getRect(
      find.byKey(const ValueKey('comparison-second-rating-align')),
    );
    final lastRatingStar = tester.getRect(find.byIcon(Icons.star).at(9));
    expect(lastRatingStar.right, closeTo(secondRatingCell.right, 0.01));
    expect(
      tester
          .widgetList<Text>(find.text('+11,11%'))
          .every((text) => text.style?.color == Colors.greenAccent[400]),
      isTrue,
    );
    expect(
      tester
          .widgetList<Text>(find.text('-9,09%'))
          .every((text) => text.style?.color == Colors.redAccent[200]),
      isTrue,
    );

    final pinnedHeader = find.byKey(
      const ValueKey('comparison-pinned-fund-header'),
    );
    expect(pinnedHeader, findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(pinnedHeader).dy,
      closeTo(tester.getRect(find.byType(AppBar)).bottom, 1),
    );
    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('SECOND'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('comparison-return-chart')),
      findsOneWidget,
    );
  });
}

Widget _app(FundProvider provider, {TextScaler? textScaler}) =>
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: textScaler == null
            ? const ComparaPage()
            : Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: const ComparaPage(),
                ),
              ),
      ),
    );

Future<void> _selectFund(
  WidgetTester tester,
  int selectorIndex,
  String fundName,
) async {
  await tester.tap(find.byType(DropdownButton<String>).at(selectorIndex));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fundName).last);
  await tester.pumpAndSettle();
}

FundData _fund(String isin, String name) {
  final date = DateTime(2026, 10, 1);
  return FundData(
    isin: isin,
    symbol: isin,
    name: name,
    lastValue: 10,
    currency: 'EUR',
    date: date,
    history: [
      PricePoint(
        date.subtract(const Duration(days: 1)),
        isin == 'FIRST' ? 9 : 11,
      ),
      PricePoint(date, 10),
    ],
    morningstarRating: isin == 'FIRST' ? 4 : 2,
    ter: isin == 'FIRST' ? 0.5 : 1.2,
    performanceFee: isin == 'FIRST' ? 10 : 15,
  );
}
