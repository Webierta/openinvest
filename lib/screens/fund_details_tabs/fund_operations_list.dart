import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'fund_operation_form_page.dart';
import '../../models/fund_data.dart';
import '../../providers/fund_provider.dart';

class FundOperationsList extends StatefulWidget {
  final FundData fund;
  const FundOperationsList({super.key, required this.fund});

  @override
  State<FundOperationsList> createState() => _FundOperationsListState();
}

class _FundOperationsListState extends State<FundOperationsList> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;
  String get locale => Localizations.localeOf(context).toString();
  NumberFormat get smartFormat => NumberFormat('#,##0.####', locale);
  DateFormat get dateFormat => DateFormat.yMMMd(locale);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FundProvider>();
    return Column(
      children: [
        Padding(
          padding: const .all(16),
          child: ElevatedButton.icon(
            onPressed: provider.isBusy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          FundOperationFormPage(fund: widget.fund),
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: Text(l10n.newOperation),
          ),
        ),
        Expanded(
          child: widget.fund.operations.isEmpty
              ? Center(
                  child: Text(
                    l10n.noOperationsRegistered,
                    style: const TextStyle(color: Colors.white38),
                  ),
                )
              : ListView.separated(
                  itemCount: widget.fund.operations.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final operation = widget.fund.operations[index];
                    IconData icon = Icons.add_circle;
                    Color color = Colors.greenAccent;
                    String title = l10n.subscription;
                    String signo = '';
                    if (operation.type == OperationType.sell) {
                      icon = Icons.remove_circle;
                      color = Colors.redAccent;
                      title = l10n.redemption;
                      signo = '-';
                    } else if (operation.type == OperationType.outTransfer) {
                      icon = Icons.output_outlined;
                      color = Colors.redAccent;
                      title = l10n.outTransfer;
                      signo = '-';
                    } else if (operation.type == OperationType.inTransfer) {
                      icon = Icons.input_outlined;
                      color = Colors.greenAccent;
                      title = l10n.inTransfer;
                      signo = '';
                    }
                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        //DateFormat('dd/MM/yyyy').format(operation.date),
                        dateFormat.format(operation.date),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$signo${smartFormat.format(operation.amount)} ${widget.fund.currency}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            l10n.unitsAtPrice(
                              smartFormat.format(operation.units),
                              smartFormat.format(operation.price),
                            ),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FundOperationFormPage(
                            fund: widget.fund,
                            operation: operation,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
