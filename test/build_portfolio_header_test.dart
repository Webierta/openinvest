import 'package:flutter_test/flutter_test.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/models/historical_investment.dart';
import 'package:investing/models/historical_operation.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/widgets/build_portfolio_header.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('detecta mutaciones en sitio de cartera y tipos de cambio', (
    tester,
  ) async {
    final provider = FundProvider()
      ..portfolio = [_fund('USD1')]
      ..exchangeRates['USD'] = 1;
    addTearDown(provider.dispose);

    await tester.pumpWidget(_app(provider));
    await tester.pump();
    expect(find.text('10,00\u00a0€'), findsOneWidget);

    provider.exchangeRates['USD'] = 2;
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('20,00\u00a0€'), findsOneWidget);

    provider.portfolio.add(_fund('USD2'));
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('40,00\u00a0€'), findsOneWidget);
    expect(find.text('40 €'), findsOneWidget);

    provider.historicalInvestments.add(
      HistoricalInvestment(uid: 'historical-investment'),
    );
    provider.historicalOperations.add(
      HistoricalOperation(
        uid: 'historical-operation',
        investmentUid: 'historical-investment',
        date: DateTime(2026, 10, 1),
        type: HistoricalOperationType.subscription,
        amount: 1000,
      ),
    );
    provider.notifyListeners();
    await tester.pump();
    expect(find.text('40 €'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(FundProvider provider) => ChangeNotifierProvider.value(
  value: provider,
  child: MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: const Scaffold(
      body: SingleChildScrollView(child: BuildPortfolioHeader()),
    ),
  ),
);

FundData _fund(String isin) {
  final date = DateTime(2026, 11, 1);
  return FundData(
    isin: isin,
    symbol: isin,
    name: isin,
    lastValue: 10,
    currency: 'USD',
    date: date,
    history: [PricePoint(date, 10)],
    operations: [
      FundOperation(
        isin: isin,
        date: date.subtract(const Duration(days: 30)),
        type: OperationType.buy,
        units: 1,
        price: 10,
        amount: 10,
      ),
    ],
  );
}
