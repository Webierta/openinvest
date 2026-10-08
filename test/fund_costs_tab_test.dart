import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:investing/l10n/app_localizations_es.dart';
import 'package:investing/models/fund_cost.dart';
import 'package:investing/models/fund_data.dart';
import 'package:investing/providers/fund_provider.dart';
import 'package:investing/screens/fund_details_tabs/fund_costs_tab.dart';
import 'package:investing/screens/fund_details_tabs/fund_market_tab.dart';
import 'package:provider/provider.dart';

class _RecordingFundProvider extends FundProvider {
  bool wasSaved = false;
  List<FundCostPeriod> savedPeriods = [];
  List<FundCostCharge> savedCharges = [];

  @override
  Future<void> setFundCosts(
    String isin, {
    required List<FundCostPeriod> periods,
    required List<FundCostCharge> charges,
  }) async {
    wasSaved = true;
    savedPeriods = periods;
    savedCharges = charges;
  }
}

void main() {
  final l10n = AppLocalizationsEs();
  final date = DateTime(2026, 9, 1);
  final fund = FundData(
    isin: 'COSTTEST',
    symbol: 'CST',
    name: 'Cost Test Fund',
    lastValue: 10,
    currency: 'EUR',
    date: DateTime(2026, 9, 30),
    history: [PricePoint(date, 10)],
  );

  Future<_RecordingFundProvider> mountCostsTab(
    WidgetTester tester, {
    FundData? testFund,
  }) async {
    final provider = _RecordingFundProvider();
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
          home: Scaffold(body: FundCostsTab(fund: testFund ?? fund)),
        ),
      ),
    );
    return provider;
  }

  testWidgets('valida tarifa dentro del diálogo sin crear otro overlay', (
    tester,
  ) async {
    final provider = await mountCostsTab(tester);

    await tester.tap(find.byTooltip(l10n.addCostPeriod));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text(l10n.costRateInvalid), findsOneWidget);
    expect(provider.wasSaved, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre la ayuda de costes y explica el cálculo neto', (
    tester,
  ) async {
    final provider = _RecordingFundProvider();
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
          home: Scaffold(
            body: FundMarketTab(fund: fund, priceFormat: NumberFormat('0.00')),
          ),
        ),
      ),
    );

    expect(find.byTooltip(l10n.costHelpTooltip), findsNothing);
    await tester.tap(find.text(l10n.marketCosts));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(l10n.costHelpTooltip));
    await tester.pumpAndSettle();

    expect(find.text(l10n.costHelpTitle), findsOneWidget);
    expect(find.text(l10n.costHelpRates), findsOneWidget);
    expect(find.text(l10n.costHelpExternal), findsOneWidget);
    expect(find.text(l10n.costHelpNet), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(l10n.close));
    await tester.pumpAndSettle();
  });

  testWidgets('muestra estimaciones actuales separadas del neto registrado', (
    tester,
  ) async {
    final startDate = date.subtract(const Duration(days: 10));
    final performancePeriod = FundCostPeriod(
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: startDate,
    );
    final fundWithRates = FundData(
      isin: fund.isin,
      symbol: fund.symbol,
      name: fund.name,
      lastValue: 10,
      currency: fund.currency,
      date: fund.date,
      history: fund.history,
      operations: [
        FundOperation(
          isin: fund.isin,
          date: date,
          type: OperationType.buy,
          units: 10,
          price: 10,
          amount: 100,
        ),
      ],
      costPeriods: [
        FundCostPeriod(
          concept: FundCostConcept.ter,
          ratePercent: 0.5,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: startDate,
        ),
        FundCostPeriod(
          concept: FundCostConcept.management,
          ratePercent: 0.25,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.chargedSeparately,
          validFrom: startDate,
        ),
        performancePeriod,
      ],
      costCharges: [
        FundCostCharge(
          concept: FundCostConcept.subscription,
          date: date,
          amount: 4,
        ),
        FundCostCharge(
          concept: FundCostConcept.performance,
          date: DateTime.now(),
          amount: 2,
          performancePeriodUid: performancePeriod.uid,
          settledThrough: date,
        ),
      ],
    );
    await mountCostsTab(tester, testFund: fundWithRates);

    expect(find.text(l10n.costEstimateTitle), findsOneWidget);
    expect(find.text(l10n.costAnnualEstimate), findsOneWidget);
    expect(find.text(l10n.costPerformancePotential), findsOneWidget);
    expect(find.text('0,50 EUR'), findsOneWidget);
    expect(find.text('0,00 EUR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actualizar concepto reinicia la base del desplegable', (
    tester,
  ) async {
    await mountCostsTab(tester);

    await tester.tap(find.byTooltip(l10n.addCostPeriod));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<FundCostConcept>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.costConceptPerformance).last);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('editar comisión de éxito conserva la identidad de la tarifa', (
    tester,
  ) async {
    final successFee = FundCostPeriod(
      concept: FundCostConcept.performance,
      ratePercent: 15,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.unknown,
      validFrom: date,
    );
    final fundWithSuccessFee = FundData(
      isin: fund.isin,
      symbol: fund.symbol,
      name: fund.name,
      lastValue: fund.lastValue,
      currency: fund.currency,
      date: fund.date,
      history: fund.history,
      costPeriods: [successFee],
    );
    final provider = await mountCostsTab(tester, testFund: fundWithSuccessFee);

    await tester.tap(find.textContaining(l10n.costConceptPerformance));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '20');
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(provider.wasSaved, isTrue);
    expect(provider.savedPeriods.single.ratePercent, 20);
    expect(provider.savedPeriods.single.uid, successFee.uid);
    expect(tester.takeException(), isNull);
  });

  testWidgets('valida cargo dentro del diálogo sin crear otro overlay', (
    tester,
  ) async {
    final provider = await mountCostsTab(tester);

    await tester.tap(find.byTooltip(l10n.addCostCharge));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(find.text(l10n.costChargeInvalid), findsOneWidget);
    expect(provider.wasSaved, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('nuevo cargo permite hoy aunque la cotización sea de ayer', (
    tester,
  ) async {
    final today = DateTime.now();
    final staleDate = today.subtract(const Duration(days: 1));
    final staleFund = FundData(
      isin: fund.isin,
      symbol: fund.symbol,
      name: fund.name,
      lastValue: fund.lastValue,
      currency: fund.currency,
      date: staleDate,
      history: [PricePoint(staleDate, fund.lastValue)],
    );
    final provider = await mountCostsTab(tester, testFund: staleFund);

    await tester.tap(find.byTooltip(l10n.addCostCharge));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '4');
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(provider.savedCharges, hasLength(1));
    expect(provider.savedCharges.single.date.year, today.year);
    expect(provider.savedCharges.single.date.month, today.month);
    expect(provider.savedCharges.single.date.day, today.day);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vincula un cargo de éxito con su tarifa', (tester) async {
    final performancePeriod = FundCostPeriod(
      concept: FundCostConcept.performance,
      ratePercent: 10,
      basis: FundCostRateBasis.positiveProfit,
      treatment: FundCostTreatment.chargedSeparately,
      validFrom: date.subtract(const Duration(days: 10)),
    );
    final fundWithPerformanceRate = FundData(
      isin: fund.isin,
      symbol: fund.symbol,
      name: fund.name,
      lastValue: fund.lastValue,
      currency: fund.currency,
      date: fund.date,
      history: fund.history,
      costPeriods: [performancePeriod],
    );
    final provider = await mountCostsTab(
      tester,
      testFund: fundWithPerformanceRate,
    );

    await tester.tap(find.byTooltip(l10n.addCostCharge));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<FundCostConcept>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.costConceptPerformance).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10%').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '5');
    await tester.tap(find.text(l10n.save));
    await tester.pumpAndSettle();

    expect(provider.savedCharges.single.concept, FundCostConcept.performance);
    expect(
      provider.savedCharges.single.performancePeriodUid,
      performancePeriod.uid,
    );
    expect(provider.savedCharges.single.settledThrough, isNull);
    expect(tester.takeException(), isNull);
  });
}
