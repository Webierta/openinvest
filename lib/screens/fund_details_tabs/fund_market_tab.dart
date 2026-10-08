import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../../models/fund_data.dart';
import 'fund_costs_tab.dart';
import 'fund_operations_list.dart';

enum _MarketSection { operations, costs }

class FundMarketTab extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;

  const FundMarketTab({
    super.key,
    required this.fund,
    required this.priceFormat,
  });

  @override
  State<FundMarketTab> createState() => _FundMarketTabState();
}

class _FundMarketTabState extends State<FundMarketTab> {
  _MarketSection _section = _MarketSection.operations;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_MarketSection>(
                  segments: [
                    ButtonSegment(
                      value: _MarketSection.operations,
                      icon: const Icon(Icons.swap_vert),
                      label: Text(l10n.marketOperations),
                    ),
                    ButtonSegment(
                      value: _MarketSection.costs,
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Text(l10n.marketCosts),
                    ),
                  ],
                  selected: {_section},
                  onSelectionChanged: (selected) {
                    setState(() => _section = selected.first);
                  },
                ),
              ),
              if (_section == _MarketSection.costs)
                IconButton(
                  tooltip: l10n.costHelpTooltip,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: () => FundCostsTab.showHelpDialog(context),
                  icon: const Icon(Icons.info_outline, size: 18),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            _MarketSection.operations => FundOperationsList(
              fund: widget.fund,
              priceFormat: widget.priceFormat,
            ),
            _MarketSection.costs => FundCostsTab(fund: widget.fund),
          },
        ),
      ],
    );
  }
}
