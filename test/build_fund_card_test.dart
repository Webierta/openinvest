import 'package:flutter_test/flutter_test.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/widgets/build_fund_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('muestra la variación absoluta en euros solo con operaciones', (
    tester,
  ) async {
    final fundWithOperations = _fund(
      'WITH-OPS',
      operations: [
        FundOperation(
          isin: 'WITH-OPS',
          date: DateTime(2026, 10, 1),
          type: OperationType.buy,
          units: 2,
          price: 9,
          amount: 18,
        ),
      ],
    );
    final fundWithoutOperations = _fund('WITHOUT-OPS');
    final provider = FundProvider()
      ..portfolio = [fundWithOperations, fundWithoutOperations]
      ..exchangeRates['USD'] = 0.5;
    addTearDown(provider.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  BuildFundCard(fund: fundWithOperations),
                  BuildFundCard(fund: fundWithoutOperations),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('+1,00\u00a0€'), findsOneWidget);
  });
}

FundData _fund(String isin, {List<FundOperation> operations = const []}) {
  final date = DateTime(2026, 11, 1);
  return FundData(
    isin: isin,
    symbol: isin,
    name: isin,
    lastValue: 10,
    currency: 'USD',
    date: date,
    history: [
      PricePoint(date.subtract(const Duration(days: 1)), 9),
      PricePoint(date, 10),
    ],
    operations: operations,
  );
}
