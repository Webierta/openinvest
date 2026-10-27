import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:investing/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/fund_data.dart';
import '../../providers/fund_provider.dart';
import '../../services/export_service.dart';
import '../../utils/financial_calculator.dart';

class PriceHistoryTable extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;
  final NumberFormat smartFormat;
  final DateFormat dateFormat;
  final VoidCallback? onExported;

  const PriceHistoryTable({
    super.key,
    required this.fund,
    required this.priceFormat,
    required this.percentFormat,
    required this.smartFormat,
    required this.dateFormat,
    this.onExported,
  });

  @override
  State<PriceHistoryTable> createState() => _PriceHistoryTableState();
}

class _PriceHistoryTableState extends State<PriceHistoryTable> {
  int _sortColumnIndex = 1;
  bool _isAscending = false;
  final Set<String> _pendingDeletedPricePoints = <String>{};

  final Set<DateTime> _selectedPriceDates = {};
  DateTime? _rangeAnchor;
  bool _isDeleting = false;

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  String _pricePointKey(DateTime date) =>
      '${widget.fund.isin}|${_day(date).toIso8601String()}';

  @override
  void didUpdateWidget(covariant PriceHistoryTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fund.isin != oldWidget.fund.isin) {
      _selectedPriceDates.clear();
      _rangeAnchor = null;
      _pendingDeletedPricePoints.clear();
      return;
    }

    final availableDates = widget.fund.history
        .map((point) => _day(point.date))
        .toSet();
    _selectedPriceDates.retainAll(availableDates);
    if (_rangeAnchor != null && !availableDates.contains(_rangeAnchor)) {
      _rangeAnchor = null;
    }
  }

  void _onSort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _isAscending = !_isAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _isAscending = true;
      }
    });
  }

  void _showDeleteError(BuildContext context) {
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.deletePriceError),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l10n.backup,
          textColor: Colors.white,
          onPressed: () async {
            if (await ExportService.exportFund(context, widget.fund)) {
              widget.onExported?.call();
            }
          },
        ),
      ),
    );
  }

  void _onRowLongPress(DateTime date) {
    final day = _day(date);
    setState(() {
      _selectedPriceDates.add(day);
      _rangeAnchor = day;
    });
  }

  void _onRowTap(int index, List<Map<String, dynamic>> rows) {
    final day = _day(rows[index]['date'] as DateTime);
    setState(() {
      final anchor = _rangeAnchor;
      if (anchor == null) {
        if (!_selectedPriceDates.add(day)) {
          _selectedPriceDates.remove(day);
        }
        return;
      }

      final anchorIndex = rows.indexWhere(
        (row) => _day(row['date'] as DateTime) == anchor,
      );
      if (anchorIndex >= 0) {
        final first = anchorIndex < index ? anchorIndex : index;
        final last = anchorIndex > index ? anchorIndex : index;
        for (var rowIndex = first; rowIndex <= last; rowIndex++) {
          _selectedPriceDates.add(_day(rows[rowIndex]['date'] as DateTime));
        }
      } else {
        _selectedPriceDates.add(day);
      }
      _rangeAnchor = null;
    });
  }

  Future<void> _confirmAndDeleteSelected() async {
    if (_selectedPriceDates.isEmpty || _isDeleting) return;

    final points = widget.fund.history
        .where((point) => _selectedPriceDates.contains(_day(point.date)))
        .toList();
    if (points.isEmpty) {
      setState(() {
        _selectedPriceDates.clear();
        _rangeAnchor = null;
      });
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final confirmMessage = points.length == 1
        ? l10n.deletePriceConfirm(
            DateFormat('dd/MM/yyyy').format(points.single.date),
          )
        : l10n.deletePricesConfirm(points.length);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deletePriceTitle),
        content: Text(confirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final keys = points.map((point) => _pricePointKey(point.date)).toSet();
    setState(() {
      _isDeleting = true;
      _pendingDeletedPricePoints.addAll(keys);
    });

    try {
      await context.read<FundProvider>().deletePricePoints(
        widget.fund.isin,
        points.map((point) => point.date).toList(),
      );
      if (!mounted) return;

      setState(() {
        _pendingDeletedPricePoints.removeAll(keys);
        _selectedPriceDates.clear();
        _rangeAnchor = null;
      });

      final snackBarController = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            points.length == 1
                ? l10n.priceDeletedSuccess
                : l10n.pricesDeletedSuccess(points.length),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () async {
              try {
                await context.read<FundProvider>().restorePricePoints(
                  widget.fund.isin,
                  points,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l10n.deletionUndone)));
              } catch (_) {
                if (!mounted) return;
                _showDeleteError(context);
              }
            },
          ),
        ),
      );
      Future<void>.delayed(
        const Duration(seconds: 4),
        snackBarController.close,
      );
    } catch (_) {
      _pendingDeletedPricePoints.removeAll(keys);
      if (!mounted) return;
      _showDeleteError(context);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tableData = <Map<String, dynamic>>[];
    //provider = context.read<FundProvider>();

    for (int i = 0; i < widget.fund.history.length; i++) {
      final point = widget.fund.history[i];
      double? absVar;
      double? variation;
      if (i > 0) {
        final previous = widget.fund.history[i - 1].price;
        absVar = point.price - previous;
        if (previous != 0) variation = (absVar / previous) * 100;
      }
      double partes = FinancialCalculator.calculateUnitsAt(
        widget.fund,
        point.date,
      );
      double rendimiento = partes * point.price;
      tableData.add({
        'index': i + 1,
        'date': point.date,
        'price': point.price,
        'absVar': absVar,
        'variation': variation,
        'rendimiento': rendimiento,
      });
    }

    tableData.removeWhere(
      (row) => _pendingDeletedPricePoints.contains(
        _pricePointKey(row['date'] as DateTime),
      ),
    );
    tableData.sort((a, b) {
      int comparison;
      switch (_sortColumnIndex) {
        case 0:
          comparison = (a['index'] as int).compareTo(b['index'] as int);
          break;
        case 1:
          comparison = (a['date'] as DateTime).compareTo(b['date'] as DateTime);
          break;
        case 2:
          comparison = (a['price'] as double).compareTo(b['price'] as double);
          break;
        case 3:
          comparison = (a['absVar'] as double? ?? 0).compareTo(
            b['absVar'] as double? ?? 0,
          );
          break;
        case 4:
          comparison = (a['variation'] as double? ?? 0).compareTo(
            b['variation'] as double? ?? 0,
          );
          break;
        case 5:
          comparison = (a['rendimiento'] as double? ?? 0).compareTo(
            b['rendimiento'] as double? ?? 0,
          );
          break;
        default:
          comparison = 0;
      }
      return _isAscending ? comparison : -comparison;
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          const minTableWidth = 540.0; // 640
          final tableWidth = constraints.maxWidth < minTableWidth
              ? minTableWidth
              : constraints.maxWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      border: const Border(
                        top: BorderSide(color: Colors.white10, width: 0.5),
                        bottom: BorderSide(color: Colors.white10, width: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 8,
                            child: _SortableHeader(
                              label: l10n.numberLabel,
                              index: 0,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                          Expanded(
                            flex: 14,
                            child: _SortableHeader(
                              label: l10n.dateLabel,
                              index: 1,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                          Expanded(
                            flex: 14,
                            child: _SortableHeader(
                              label: l10n.priceLabel,
                              index: 2,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                          Expanded(
                            flex: 14,
                            child: _SortableHeader(
                              label: l10n.diffLabel,
                              index: 3,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                          Expanded(
                            flex: 14,
                            child: _SortableHeader(
                              label: l10n.varLabel,
                              index: 4,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                          Expanded(
                            flex: 18,
                            child: _SortableHeader(
                              label: 'Rendimiento',
                              index: 5,
                              selectedIndex: _sortColumnIndex,
                              ascending: _isAscending,
                              onSort: _onSort,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          border: const Border(
                            bottom: BorderSide(
                              color: Colors.white10,
                              width: 0.5,
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: tableData.length,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1, color: Colors.white10),
                          itemBuilder: (context, index) =>
                              _buildRow(context, tableData, index),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      persistentFooterDecoration: BoxDecoration(color: Colors.black54),
      persistentFooterButtons: _selectedPriceDates.isEmpty
          ? null
          : [
              Row(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  FilledButton.icon(
                    onPressed: _isDeleting
                        ? null
                        : () {
                            setState(() {
                              _selectedPriceDates.clear();
                            });
                          },
                    icon: const Icon(Icons.check_box_outline_blank),
                    label: Text('Desmarcar'),
                  ),
                  FilledButton.icon(
                    onPressed: _isDeleting ? null : _confirmAndDeleteSelected,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.delete),
                  ),
                ],
              ),
            ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    int index,
  ) {
    final row = rows[index];
    final absVar = row['absVar'] as double?;
    final variation = row['variation'] as double?;
    final date = row['date'] as DateTime;
    final color = absVar == null
        ? null
        : absVar > 0
        ? Colors.greenAccent[400]
        : absVar < 0
        ? Colors.redAccent[200]
        : null;
    final fecha = widget.dateFormat.format(date);
    double partes = FinancialCalculator.calculateUnitsAt(widget.fund, date);
    final precio = row['price'] as double;
    final rendimiento = precio * partes;
    final selected = _selectedPriceDates.contains(_day(date));

    return InkWell(
      onTap: () => _onRowTap(index, rows),
      onLongPress: () => _onRowLongPress(date),
      child: Container(
        color: selected ? Colors.redAccent.shade100 : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 8,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    row['index'].toString(),
                    style: const TextStyle(fontSize: 10, color: Colors.white24),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    fecha.substring(0, fecha.length - 3) +
                        fecha.substring(fecha.length - 1),
                    //DateFormat('dd/MM/yy').format(date),
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    widget.priceFormat.format(row['price']),
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    absVar == null
                        ? '-'
                        : '${absVar > 0 ? '+' : ''}${widget.priceFormat.format(absVar)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 14,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    variation == null
                        ? '-'
                        : '${variation > 0 ? '+' : ''}${widget.percentFormat.format(variation)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 18,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    widget.smartFormat.format(rendimiento),
                    style: TextStyle(
                      //color: color,
                      //fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final int index;
  final int selectedIndex;
  final bool ascending;
  final ValueChanged<int> onSort;

  const _SortableHeader({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final selected = selectedIndex == index;
    return InkWell(
      onTap: () => onSort(index),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
            if (selected)
              Icon(
                ascending ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 14,
                color: const Color(0xFF38BDF8),
              ),
          ],
        ),
      ),
    );
  }
}
