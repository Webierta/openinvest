import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../models/fund_cost.dart';
import '../../models/fund_data.dart';
import '../../providers/fund_provider.dart';
import '../../utils/financial_calculator.dart';

class FundCostsTab extends StatelessWidget {
  static const _periodConcepts = [
    FundCostConcept.ter,
    FundCostConcept.management,
    FundCostConcept.depositary,
    FundCostConcept.operating,
    FundCostConcept.distributor,
    FundCostConcept.custody,
    FundCostConcept.performance,
    FundCostConcept.other,
  ];

  final FundData fund;

  const FundCostsTab({super.key, required this.fund});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    final amountFormat = NumberFormat('#,##0.00', locale);
    final costEstimate = FinancialCalculator.estimateCurrentFundCosts(fund);
    final periods = [...fund.costPeriods]
      ..sort((a, b) {
        final aDate = a.validFrom ?? DateTime(1);
        final bDate = b.validFrom ?? DateTime(1);
        return bDate.compareTo(aDate);
      });

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (costEstimate.hasEstimates)
                _costEstimateSummary(l10n, locale, fund.currency, costEstimate),
              _sectionHeader(
                context,
                l10n.costPeriodsTitle,
                l10n.addCostPeriod,
                () => _editPeriod(context),
              ),
              if (periods.isEmpty)
                _emptyText(l10n.costPeriodsEmpty)
              else
                ...periods.map((period) {
                  final index = fund.costPeriods.indexOf(period);
                  final validity = period.validFrom == null
                      ? l10n.costLegacyDateUnknown
                      : '${dateFormat.format(period.validFrom!)} - ${period.validTo == null ? l10n.costNoEndDate : dateFormat.format(period.validTo!)}';
                  return Card(
                    key: ValueKey(period.uid),
                    child: ListTile(
                      title: Text(
                        '${_conceptName(l10n, period.concept)} · ${NumberFormat('0.##', locale).format(period.ratePercent)}%',
                      ),
                      subtitle: Text(
                        '$validity\n${_basisName(l10n, period.basis)} · ${_treatmentName(l10n, period.treatment)}${period.description == null || period.description!.isEmpty ? '' : '\n${period.description}'}',
                      ),
                      isThreeLine: true,
                      onTap: () => _editPeriod(context, period: period),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'edit') {
                            _editPeriod(context, period: period);
                          } else if (action == 'delete') {
                            _deletePeriod(context, index);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text(l10n.editCostPeriod),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(l10n.delete),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              _sectionHeader(
                context,
                l10n.costChargesTitle,
                l10n.addCostCharge,
                () => _editCharge(context),
              ),
              if (fund.costCharges.isEmpty)
                _emptyText(l10n.costChargesEmpty)
              else
                ...fund.costCharges.map((charge) {
                  final index = fund.costCharges.indexOf(charge);
                  final chargeDetails = [
                    dateFormat.format(charge.date),
                    if (charge.description?.isNotEmpty ?? false)
                      charge.description!,
                    if (charge.concept == FundCostConcept.performance &&
                        charge.settledThrough != null)
                      '${l10n.costSettledThrough}: ${dateFormat.format(charge.settledThrough!)}',
                  ].join('\n');
                  return Card(
                    key: ValueKey(charge.uid),
                    child: ListTile(
                      title: Text(_conceptName(l10n, charge.concept)),
                      subtitle: Text(chargeDetails),
                      isThreeLine: chargeDetails.contains('\n'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-${amountFormat.format(charge.amount)} ${fund.currency}',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (action) {
                              if (action == 'edit') {
                                _editCharge(context, charge: charge);
                              } else if (action == 'delete') {
                                _deleteCharge(context, index);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text(l10n.editCostCharge),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(l10n.delete),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> showHelpDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.costHelpTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.costHelpNav),
              const SizedBox(height: 12),
              Text(l10n.costHelpTer),
              const SizedBox(height: 12),
              Text(l10n.costHelpRates),
              const SizedBox(height: 12),
              Text(l10n.costHelpExternal),
              const SizedBox(height: 12),
              Text(l10n.costHelpNet),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  Widget _costEstimateSummary(
    AppLocalizations l10n,
    String locale,
    String currency,
    FundCostEstimate estimate,
  ) {
    final amountFormat = NumberFormat('#,##0.00', locale);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.costEstimateTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (estimate.hasAnnualRates) ...[
              const SizedBox(height: 8),
              _estimateRow(
                l10n.costAnnualEstimate,
                '${amountFormat.format(estimate.annualRecurringCost)} $currency',
                l10n.costAnnualEstimateNote,
              ),
            ],
            if (estimate.hasPerformanceRate) ...[
              const SizedBox(height: 8),
              _estimateRow(
                l10n.costPerformancePotential,
                '${amountFormat.format(estimate.potentialPerformanceFee)} $currency',
                l10n.costPerformancePotentialNote,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _estimateRow(String label, String amount, String note) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            amount,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 3),
      Text(note, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    ],
  );

  Widget _emptyText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(text, style: const TextStyle(color: Colors.white38)),
  );

  Widget _sectionHeader(
    BuildContext context,
    String title,
    String actionLabel,
    VoidCallback onAdd,
  ) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      IconButton(
        tooltip: actionLabel,
        onPressed: onAdd,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );

  Future<void> _editPeriod(
    BuildContext context, {
    FundCostPeriod? period,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toString(),
    );
    var rateText = period?.ratePercent.toString().replaceAll('.', ',') ?? '';
    var descriptionText = period?.description ?? '';
    var concept = period?.concept ?? FundCostConcept.ter;
    var basis = period?.basis ?? FundCostRateBasis.annualBalance;
    var treatment = period?.treatment ?? FundCostTreatment.unknown;
    String? validationError;
    DateTime? startDate = period?.validFrom;
    DateTime? endDate = period?.validTo;

    final result = await showDialog<FundCostPeriod>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            period == null ? l10n.addCostPeriod : l10n.editCostPeriod,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                DropdownButtonFormField<FundCostConcept>(
                  initialValue: concept,
                  decoration: InputDecoration(labelText: l10n.costConcept),
                  items: _periodConcepts
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_conceptName(l10n, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    validationError = null;
                    concept = value!;
                    basis = concept == FundCostConcept.performance
                        ? FundCostRateBasis.positiveProfit
                        : FundCostRateBasis.annualBalance;
                  }),
                ),
                TextFormField(
                  initialValue: rateText,
                  onChanged: (value) => rateText = value,
                  decoration: InputDecoration(
                    labelText: l10n.costRate,
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                InputDecorator(
                  decoration: InputDecoration(labelText: l10n.costBasis),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<FundCostRateBasis>(
                      value: basis,
                      isExpanded: true,
                      items: FundCostRateBasis.values
                          .where(
                            (value) => concept == FundCostConcept.performance
                                ? value == FundCostRateBasis.positiveProfit
                                : value == FundCostRateBasis.annualBalance,
                          )
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_basisName(l10n, value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => basis = value!),
                    ),
                  ),
                ),
                DropdownButtonFormField<FundCostTreatment>(
                  initialValue: treatment,
                  decoration: InputDecoration(labelText: l10n.costTreatment),
                  items: FundCostTreatment.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_treatmentName(l10n, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => treatment = value!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.costStartDate),
                  subtitle: Text(
                    startDate == null
                        ? l10n.costLegacyDateUnknown
                        : dateFormat.format(startDate!),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await _pickDate(dialogContext, startDate);
                    if (picked != null && dialogContext.mounted) {
                      setDialogState(() => startDate = picked);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.costEndDate),
                  subtitle: Text(
                    endDate == null
                        ? l10n.costNoEndDate
                        : dateFormat.format(endDate!),
                  ),
                  trailing: endDate == null
                      ? const Icon(Icons.event_available)
                      : IconButton(
                          tooltip: l10n.costNoEndDate,
                          onPressed: () => setDialogState(() => endDate = null),
                          icon: const Icon(Icons.clear),
                        ),
                  onTap: () async {
                    final picked = await _pickDate(dialogContext, endDate);
                    if (picked != null && dialogContext.mounted) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                ),
                TextFormField(
                  initialValue: descriptionText,
                  onChanged: (value) => descriptionText = value,
                  decoration: InputDecoration(labelText: l10n.costDescription),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final rate = double.tryParse(rateText.replaceAll(',', '.'));
                if (rate == null || rate < 0) {
                  setDialogState(() => validationError = l10n.costRateInvalid);
                  return;
                }
                if (startDate == null ||
                    (endDate != null && endDate!.isBefore(startDate!))) {
                  setDialogState(
                    () => validationError = l10n.costPeriodInvalid,
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  FundCostPeriod(
                    id: period?.id,
                    uid: period?.uid,
                    concept: concept,
                    ratePercent: rate,
                    basis: basis,
                    treatment: treatment,
                    validFrom: startDate,
                    validTo: endDate,
                    description: _optionalText(descriptionText),
                  ),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    final updated = [...fund.costPeriods];
    final editIndex = period == null ? -1 : updated.indexOf(period);
    for (var index = 0; index < updated.length; index++) {
      if (index == editIndex || updated[index].concept != result.concept) {
        continue;
      }
      if (_periodsOverlap(updated[index], result)) {
        _showMessage(context, l10n.costPeriodOverlap);
        return;
      }
    }
    if (editIndex < 0) {
      updated.add(result);
    } else {
      updated[editIndex] = result;
    }
    await _saveCosts(context, updated, fund.costCharges);
  }

  Future<void> _editCharge(
    BuildContext context, {
    FundCostCharge? charge,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat.yMd(
      Localizations.localeOf(context).toString(),
    );
    var amountText = charge?.amount.toString().replaceAll('.', ',') ?? '';
    var descriptionText = charge?.description ?? '';
    var concept = charge?.concept ?? FundCostConcept.subscription;
    var date = charge?.date ?? DateTime.now();
    var performancePeriodUid = charge?.performancePeriodUid ?? '';
    DateTime? settledThrough = charge?.settledThrough;
    final performancePeriods = fund.costPeriods
        .where((period) => period.concept == FundCostConcept.performance)
        .toList();
    String? validationError;

    final result = await showDialog<FundCostCharge>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            charge == null ? l10n.addCostCharge : l10n.editCostCharge,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      validationError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                DropdownButtonFormField<FundCostConcept>(
                  initialValue: concept,
                  decoration: InputDecoration(labelText: l10n.costConcept),
                  items: FundCostConcept.values
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_conceptName(l10n, value)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() {
                    validationError = null;
                    concept = value!;
                    if (concept != FundCostConcept.performance) {
                      performancePeriodUid = '';
                      settledThrough = null;
                    }
                  }),
                ),
                if (concept == FundCostConcept.performance) ...[
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.costPerformancePeriod,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: performancePeriodUid,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(l10n.costSettlementUnlinked),
                          ),
                          if (performancePeriodUid.isNotEmpty &&
                              !performancePeriods.any(
                                (period) => period.uid == performancePeriodUid,
                              ))
                            DropdownMenuItem(
                              value: performancePeriodUid,
                              child: Text(l10n.costSettlementPeriodUnavailable),
                            ),
                          ...performancePeriods.map(
                            (period) => DropdownMenuItem(
                              value: period.uid,
                              child: Text(
                                '${NumberFormat('0.##', Localizations.localeOf(context).toString()).format(period.ratePercent)}%',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) => setDialogState(() {
                          performancePeriodUid = value ?? '';
                          if (performancePeriodUid.isEmpty) {
                            settledThrough = null;
                          }
                        }),
                      ),
                    ),
                  ),
                  if (performancePeriodUid.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.costSettledThrough),
                      subtitle: Text(
                        settledThrough == null
                            ? l10n.costSettlementUnspecified
                            : dateFormat.format(settledThrough!),
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await _pickDate(
                          dialogContext,
                          settledThrough,
                          lastDate: date,
                        );
                        if (picked != null && dialogContext.mounted) {
                          setDialogState(() {
                            settledThrough = picked;
                            validationError = null;
                          });
                        }
                      },
                    ),
                ],
                TextFormField(
                  initialValue: amountText,
                  onChanged: (value) => amountText = value,
                  decoration: InputDecoration(
                    labelText: l10n.costAmount,
                    suffixText: fund.currency,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.costDate),
                  subtitle: Text(dateFormat.format(date)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await _pickDate(
                      dialogContext,
                      date,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null && dialogContext.mounted) {
                      setDialogState(() => date = picked);
                    }
                  },
                ),
                TextFormField(
                  initialValue: descriptionText,
                  onChanged: (value) => descriptionText = value,
                  decoration: InputDecoration(labelText: l10n.costDescription),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final amount = double.tryParse(amountText.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  setDialogState(
                    () => validationError = l10n.costChargeInvalid,
                  );
                  return;
                }
                if (settledThrough != null && settledThrough!.isAfter(date)) {
                  setDialogState(
                    () => validationError = l10n.costSettlementDateInvalid,
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  FundCostCharge(
                    id: charge?.id,
                    uid: charge?.uid,
                    concept: concept,
                    date: date,
                    amount: amount,
                    description: _optionalText(descriptionText),
                    performancePeriodUid:
                        concept == FundCostConcept.performance &&
                            performancePeriodUid.isNotEmpty
                        ? performancePeriodUid
                        : null,
                    settledThrough:
                        concept == FundCostConcept.performance &&
                            performancePeriodUid.isNotEmpty
                        ? settledThrough
                        : null,
                  ),
                );
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (result == null || !context.mounted) return;

    final updated = [...fund.costCharges];
    final index = charge == null ? -1 : updated.indexOf(charge);
    if (index < 0) {
      updated.add(result);
    } else {
      updated[index] = result;
    }
    await _saveCosts(context, fund.costPeriods, updated);
  }

  Future<void> _deletePeriod(BuildContext context, int index) async {
    if (!await _confirmDelete(context)) return;
    if (!context.mounted) return;
    final updated = [...fund.costPeriods]..removeAt(index);
    await _saveCosts(context, updated, fund.costCharges);
  }

  Future<void> _deleteCharge(BuildContext context, int index) async {
    if (!await _confirmDelete(context)) return;
    if (!context.mounted) return;
    final updated = [...fund.costCharges]..removeAt(index);
    await _saveCosts(context, fund.costPeriods, updated);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(l10n.deleteCostTitle),
            content: Text(l10n.deleteCostConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _saveCosts(
    BuildContext context,
    List<FundCostPeriod> periods,
    List<FundCostCharge> charges,
  ) async {
    try {
      await context.read<FundProvider>().setFundCosts(
        fund.isin,
        periods: periods,
        charges: charges,
      );
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, AppLocalizations.of(context)!.saveCostsFailed);
      }
    }
  }

  Future<DateTime?> _pickDate(
    BuildContext context,
    DateTime? selected, {
    DateTime? lastDate,
  }) {
    final firstDate = DateTime(1900);
    final maxDate = lastDate ?? DateTime(2100);
    final requestedDate = selected ?? DateTime.now();
    final initialDate = requestedDate.isAfter(maxDate)
        ? maxDate
        : requestedDate.isBefore(firstDate)
        ? firstDate
        : requestedDate;
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: maxDate,
    );
  }

  bool _periodsOverlap(FundCostPeriod first, FundCostPeriod second) {
    final firstStart = first.validFrom ?? DateTime(1);
    final secondStart = second.validFrom ?? DateTime(1);
    final firstEnd = first.validTo ?? DateTime(9999);
    final secondEnd = second.validTo ?? DateTime(9999);
    return !firstStart.isAfter(secondEnd) && !secondStart.isAfter(firstEnd);
  }

  String? _optionalText(String value) =>
      value.trim().isEmpty ? null : value.trim();

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _conceptName(AppLocalizations l10n, FundCostConcept value) =>
      switch (value) {
        FundCostConcept.ter => l10n.costConceptTer,
        FundCostConcept.management => l10n.costConceptManagement,
        FundCostConcept.depositary => l10n.costConceptDepositary,
        FundCostConcept.operating => l10n.costConceptOperating,
        FundCostConcept.subscription => l10n.costConceptSubscription,
        FundCostConcept.redemption => l10n.costConceptRedemption,
        FundCostConcept.transfer => l10n.costConceptTransfer,
        FundCostConcept.distributor => l10n.costConceptDistributor,
        FundCostConcept.custody => l10n.costConceptCustody,
        FundCostConcept.performance => l10n.costConceptPerformance,
        FundCostConcept.tax => l10n.costConceptTax,
        FundCostConcept.other => l10n.costConceptOther,
      };

  String _basisName(AppLocalizations l10n, FundCostRateBasis value) =>
      switch (value) {
        FundCostRateBasis.annualBalance => l10n.costAnnualBalance,
        FundCostRateBasis.positiveProfit => l10n.costPositiveProfit,
      };

  String _treatmentName(AppLocalizations l10n, FundCostTreatment value) =>
      switch (value) {
        FundCostTreatment.includedInNav => l10n.costIncludedInNav,
        FundCostTreatment.chargedSeparately => l10n.costChargedSeparately,
        FundCostTreatment.unknown => l10n.costTreatmentUnknown,
      };
}
