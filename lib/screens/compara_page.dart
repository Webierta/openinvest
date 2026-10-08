import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import 'comparison_fund_chart.dart';
import '../utils/fund_comparison_calculator.dart';
import '../widgets/gradient_background.dart';

class ComparaPage extends StatefulWidget {
  const ComparaPage({super.key});

  @override
  State<ComparaPage> createState() => _ComparaPageState();
}

class _ComparaPageState extends State<ComparaPage> {
  String? _firstIsin;
  String? _secondIsin;
  bool _showResults = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<FundProvider>();
    final funds = provider.portfolio;
    final firstIsin = funds.any((fund) => fund.isin == _firstIsin)
        ? _firstIsin
        : null;
    final secondIsin = funds.any((fund) => fund.isin == _secondIsin)
        ? _secondIsin
        : null;
    final canCompare =
        firstIsin != null && secondIsin != null && firstIsin != secondIsin;
    final firstFund = firstIsin == null
        ? null
        : funds.firstWhere((fund) => fund.isin == firstIsin);
    final secondFund = secondIsin == null
        ? null
        : funds.firstWhere((fund) => fund.isin == secondIsin);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.comparePageTitle),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: provider.hasPortfolioLoadError
              ? Center(
                  child: Text(
                    l10n.portfolioLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : provider.isLoading && funds.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : funds.length < 2
              ? _buildInsufficientFunds(l10n)
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          Text(
                            l10n.compareFundSelection,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 16),
                          _buildFundSelector(
                            label: l10n.compareFundOne,
                            hint: l10n.compareSelectFund,
                            funds: funds,
                            selectedIsin: firstIsin,
                            onChanged: (isin) => setState(() {
                              _firstIsin = isin;
                              _showResults = false;
                            }),
                          ),
                          const SizedBox(height: 12),
                          _buildFundSelector(
                            label: l10n.compareFundTwo,
                            hint: l10n.compareSelectFund,
                            funds: funds,
                            selectedIsin: secondIsin,
                            onChanged: (isin) => setState(() {
                              _secondIsin = isin;
                              _showResults = false;
                            }),
                          ),
                          if (firstIsin != null && firstIsin == secondIsin) ...[
                            const SizedBox(height: 8),
                            Text(
                              l10n.compareChooseDifferentFunds,
                              style: TextStyle(color: Colors.orangeAccent[100]),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Center(
                            child: FilledButton.icon(
                              onPressed: canCompare
                                  ? () => setState(() => _showResults = true)
                                  : null,
                              icon: const Icon(Icons.compare_arrows),
                              label: Text(l10n.compareLabel),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    if (_showResults &&
                        firstFund != null &&
                        secondFund != null) ...[
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(
                          child: _ComparisonResultsIntro(
                            first: firstFund,
                            second: secondFund,
                          ),
                        ),
                      ),
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _ComparisonFundHeaderDelegate(
                          first: firstFund,
                          second: secondFund,
                          textScaleFactor:
                              MediaQuery.textScalerOf(context).scale(14) / 14,
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        sliver: SliverToBoxAdapter(
                          child: _ComparisonResults(
                            first: firstFund,
                            second: secondFund,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildInsufficientFunds(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows, size: 40, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              l10n.comparePortfolioNeedsTwo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFundSelector({
    required String label,
    required String hint,
    required List<FundData> funds,
    required String? selectedIsin,
    required ValueChanged<String?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white70),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedIsin,
          isExpanded: true,
          itemHeight: 64,
          hint: Text(hint, style: const TextStyle(color: Colors.white54)),
          dropdownColor: const Color(0xFF172033),
          iconEnabledColor: Colors.white70,
          items: funds
              .map(
                (fund) => DropdownMenuItem<String>(
                  value: fund.isin,
                  child: Row(
                    children: [
                      _FundAvatar(fund: fund, radius: 14),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fund.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              fund.isin,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ComparisonResultsIntro extends StatelessWidget {
  final FundData first;
  final FundData second;

  const _ComparisonResultsIntro({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final result = FundComparisonCalculator.calculate(first, second);
    final dateFormat = DateFormat.yMMMd(locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.compareResults,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${l10n.dateLabel}: ${dateFormat.format(result.asOf)}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ComparisonFundHeaderDelegate extends SliverPersistentHeaderDelegate {
  final FundData first;
  final FundData second;
  final double textScaleFactor;

  _ComparisonFundHeaderDelegate({
    required this.first,
    required this.second,
    required this.textScaleFactor,
  });

  double get _extent => 64 + (textScaleFactor - 1).clamp(0, 2) * 48;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(
      child: Material(
        key: const ValueKey('comparison-pinned-fund-header'),
        color: const Color(0xFF1E293B),
        elevation: overlapsContent ? 4 : 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(child: _ComparisonFundName(fund: first)),
              const SizedBox(width: 12),
              Expanded(child: _ComparisonFundName(fund: second)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ComparisonFundHeaderDelegate oldDelegate) =>
      first.isin != oldDelegate.first.isin ||
      second.isin != oldDelegate.second.isin;
}

class _ComparisonFundName extends StatelessWidget {
  final FundData fund;

  const _ComparisonFundName({required this.fund});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FundAvatar(fund: fund, radius: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fund.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                fund.isin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComparisonResults extends StatelessWidget {
  final FundData first;
  final FundData second;

  const _ComparisonResults({required this.first, required this.second});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final result = FundComparisonCalculator.calculate(first, second);
    final dateFormat = DateFormat.yMMMd(locale);
    final navFormat = NumberFormat('#,##0.0000', locale);
    final amountFormat = NumberFormat('#,##0.##', locale);
    final percentFormat = NumberFormat('#,##0.00', locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection(
          title: l10n.compareMarketHistory,
          rows: [
            _ComparisonRow(
              l10n.compareHistoryStart,
              _date(result.first.historyStart, dateFormat),
              _date(result.second.historyStart, dateFormat),
            ),
            _ComparisonRow(
              l10n.compareCurrency,
              result.first.fund.currency,
              result.second.fund.currency,
            ),
            _ComparisonRow(
              l10n.compareLastNav,
              _money(
                result.first.latestNav,
                result.first.fund.currency,
                navFormat,
              ),
              _money(
                result.second.latestNav,
                result.second.fund.currency,
                navFormat,
              ),
            ),
            _ComparisonRow(
              l10n.compareLastChange,
              _fraction(result.first.latestChange, percentFormat),
              _fraction(result.second.latestChange, percentFormat),
              firstColor: _variationColor(result.first.latestChange),
              secondColor: _variationColor(result.second.latestChange),
            ),
            _ComparisonRow(
              l10n.compareMonthChange,
              _fraction(result.first.monthChange, percentFormat),
              _fraction(result.second.monthChange, percentFormat),
              firstColor: _variationColor(result.first.monthChange),
              secondColor: _variationColor(result.second.monthChange),
            ),
            _ComparisonRow(
              l10n.compareSixMonthChange,
              _fraction(result.first.sixMonthChange, percentFormat),
              _fraction(result.second.sixMonthChange, percentFormat),
              firstColor: _variationColor(result.first.sixMonthChange),
              secondColor: _variationColor(result.second.sixMonthChange),
            ),
            _ComparisonRow(
              l10n.compareYearChange,
              _fraction(result.first.yearChange, percentFormat),
              _fraction(result.second.yearChange, percentFormat),
              firstColor: _variationColor(result.first.yearChange),
              secondColor: _variationColor(result.second.yearChange),
            ),
            _ComparisonRow(
              l10n.compareSinceInceptionChange,
              _fraction(result.first.sinceInceptionChange, percentFormat),
              _fraction(result.second.sinceInceptionChange, percentFormat),
              firstColor: _variationColor(result.first.sinceInceptionChange),
              secondColor: _variationColor(result.second.sinceInceptionChange),
            ),
            _ComparisonRow(
              l10n.compareAnnualVolatility,
              _fraction(result.first.annualizedVolatility, percentFormat),
              _fraction(result.second.annualizedVolatility, percentFormat),
            ),
            _ComparisonRow.widgets(
              l10n.compareMorningstarRating,
              firstWidget: _ratingStars(result.first.fund.morningstarRating),
              secondWidget: _ratingStars(result.second.fund.morningstarRating),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSection(
          title: l10n.compareCosts,
          rows: [
            _ComparisonRow(
              l10n.costConceptTer,
              _percent(result.first.terRate, percentFormat),
              _percent(result.second.terRate, percentFormat),
            ),
            _ComparisonRow(
              l10n.costConceptPerformance,
              _percent(result.first.performanceFeeRate, percentFormat),
              _percent(result.second.performanceFeeRate, percentFormat),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildInvestmentSection(
          l10n: l10n,
          first: result.first,
          second: result.second,
          amountFormat: amountFormat,
          percentFormat: percentFormat,
        ),
        const SizedBox(height: 24),
        ComparisonFundChart(first: first, second: second),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<_ComparisonRow> rows,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Divider(color: Colors.white24),
        for (final row in rows) _buildMetricRow(row),
      ],
    );
  }

  Widget _buildInvestmentSection({
    required AppLocalizations l10n,
    required FundComparisonMetrics first,
    required FundComparisonMetrics second,
    required NumberFormat amountFormat,
    required NumberFormat percentFormat,
  }) {
    final firstMetrics = first.investment;
    final secondMetrics = second.investment;
    if (firstMetrics == null || secondMetrics == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.compareInvestmentPosition,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white24),
          Text(
            l10n.compareNoSharedPositions,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      );
    }

    return _buildSection(
      title: l10n.compareInvestmentPosition,
      rows: [
        _ComparisonRow(
          l10n.compareInvested,
          _money(firstMetrics.totalInvested, first.fund.currency, amountFormat),
          _money(
            secondMetrics.totalInvested,
            second.fund.currency,
            amountFormat,
          ),
        ),
        _ComparisonRow(
          l10n.compareCurrentValue,
          _money(firstMetrics.currentValue, first.fund.currency, amountFormat),
          _money(
            secondMetrics.currentValue,
            second.fund.currency,
            amountFormat,
          ),
        ),
        _ComparisonRow(
          l10n.compareProfit,
          _profit(firstMetrics.profitAbs, first.fund.currency, amountFormat),
          _profit(secondMetrics.profitAbs, second.fund.currency, amountFormat),
          firstColor: _variationColor(firstMetrics.profitAbs),
          secondColor: _variationColor(secondMetrics.profitAbs),
        ),
        _ComparisonRow(
          l10n.compareReturn,
          _percent(firstMetrics.profitRel, percentFormat),
          _percent(secondMetrics.profitRel, percentFormat),
          firstColor: _variationColor(firstMetrics.profitRel),
          secondColor: _variationColor(secondMetrics.profitRel),
        ),
        _ComparisonRow(
          l10n.compareTwr,
          _fraction(firstMetrics.twrAnnualized, percentFormat),
          _fraction(secondMetrics.twrAnnualized, percentFormat),
          firstColor: _variationColor(firstMetrics.twrAnnualized),
          secondColor: _variationColor(secondMetrics.twrAnnualized),
        ),
        _ComparisonRow(
          l10n.compareMwr,
          _fraction(firstMetrics.mwrAnnualized, percentFormat),
          _fraction(secondMetrics.mwrAnnualized, percentFormat),
          firstColor: _variationColor(firstMetrics.mwrAnnualized),
          secondColor: _variationColor(secondMetrics.mwrAnnualized),
        ),
        _ComparisonRow(
          l10n.compareMoic,
          '${amountFormat.format(firstMetrics.moic)}x',
          '${amountFormat.format(secondMetrics.moic)}x',
          firstColor: _variationColor(firstMetrics.moic - 1),
          secondColor: _variationColor(secondMetrics.moic - 1),
        ),
      ],
    );
  }

  Widget _buildMetricRow(_ComparisonRow row) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.label,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child:
                    row.firstWidget ??
                    Text(
                      row.first ?? '—',
                      style: TextStyle(color: row.firstColor ?? Colors.white),
                    ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: row.secondWidget != null
                    ? Align(
                        key: row.secondWidget != null
                            ? const ValueKey('comparison-second-rating-align')
                            : null,
                        alignment: Alignment.centerRight,
                        child: row.secondWidget,
                      )
                    : Text(
                        row.second ?? '—',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: row.secondColor ?? Colors.white,
                        ),
                      ),
              ),
            ],
          ),
          const Divider(height: 16, color: Colors.white10),
        ],
      ),
    );
  }

  String _date(DateTime? value, DateFormat format) =>
      value == null ? '—' : format.format(value);

  String _money(double? value, String currency, NumberFormat format) =>
      value == null ? '—' : '${format.format(value)} $currency';

  String _profit(double value, String currency, NumberFormat format) =>
      '${value > 0 ? '+' : ''}${format.format(value)} $currency';

  String _fraction(double? value, NumberFormat format) => value == null
      ? '—'
      : '${value > 0 ? '+' : ''}${format.format(value * 100)}%';

  String _percent(double? value, NumberFormat format) =>
      value == null ? '—' : '${format.format(value)}%';

  Widget _ratingStars(int? value) {
    if (value == null) {
      return const Text('—', style: TextStyle(color: Colors.white));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          Icons.star,
          color: index < value ? Colors.amber : Colors.grey.shade700,
          size: 18,
        ),
      ),
    );
  }

  Color? _variationColor(double? value) {
    if (value == null || value == 0) return null;
    return value > 0 ? Colors.greenAccent[400] : Colors.redAccent[200];
  }
}

class _ComparisonRow {
  final String label;
  final String? first;
  final String? second;
  final Widget? firstWidget;
  final Widget? secondWidget;
  final Color? firstColor;
  final Color? secondColor;

  const _ComparisonRow(
    this.label,
    this.first,
    this.second, {
    this.firstColor,
    this.secondColor,
  }) : firstWidget = null,
       secondWidget = null;

  const _ComparisonRow.widgets(
    this.label, {
    required this.firstWidget,
    required this.secondWidget,
  }) : first = null,
       second = null,
       firstColor = null,
       secondColor = null;
}

class _FundAvatar extends StatelessWidget {
  final FundData fund;
  final double radius;

  const _FundAvatar({required this.fund, required this.radius});

  @override
  Widget build(BuildContext context) {
    final color = _fundColor(fund.isin);
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.2),
      child: Text(
        fund.name.isNotEmpty ? fund.name[0].toUpperCase() : 'F',
        style: TextStyle(
          color: color,
          fontSize: radius,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

Color _fundColor(String isin) {
  final colors = [
    Colors.blueAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.indigoAccent,
    Colors.amberAccent,
    Colors.cyanAccent,
    Colors.lightGreenAccent,
  ];
  return colors[isin.hashCode.abs() % colors.length];
}
