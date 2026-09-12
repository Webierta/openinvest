import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/fund_provider.dart';
import '../../services/export_service.dart';
import '../../services/fund_scraper.dart';

class PriceHistoryTable extends StatefulWidget {
  final FundData fund;
  final NumberFormat priceFormat;
  final NumberFormat percentFormat;
  final VoidCallback? onExported;

  const PriceHistoryTable({
    super.key,
    required this.fund,
    required this.priceFormat,
    required this.percentFormat,
    this.onExported,
  });

  @override
  State<PriceHistoryTable> createState() => _PriceHistoryTableState();
}

class _PriceHistoryTableState extends State<PriceHistoryTable> {
  int _sortColumnIndex = 1;
  bool _isAscending = false;
  final Set<String> _pendingDeletedPricePoints = <String>{};

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'No se pudo eliminar el precio. Haz un backup del fondo y reinicia la aplicación.',
        ),
        backgroundColor: Colors.redAccent,
        action: SnackBarAction(
          label: 'Backup',
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

  @override
  Widget build(BuildContext context) {
    final tableData = <Map<String, dynamic>>[];
    for (int i = 0; i < widget.fund.history.length; i++) {
      final point = widget.fund.history[i];
      double? absVar;
      double? variation;
      if (i > 0) {
        final previous = widget.fund.history[i - 1].price;
        absVar = point.price - previous;
        if (previous != 0) variation = (absVar / previous) * 100;
      }
      tableData.add({
        'index': i + 1,
        'date': point.date,
        'price': point.price,
        'absVar': absVar,
        'variation': variation,
      });
    }

    tableData.removeWhere(
      (row) => _pendingDeletedPricePoints.contains(
        '${widget.fund.isin}|${(row['date'] as DateTime).toIso8601String()}',
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
        default:
          comparison = 0;
      }
      return _isAscending ? comparison : -comparison;
    });

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: const Border(
              top: BorderSide(color: Colors.white10, width: 0.5),
              bottom: BorderSide(color: Colors.white10, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 8,
                child: _SortableHeader(
                  label: 'No.',
                  index: 0,
                  selectedIndex: _sortColumnIndex,
                  ascending: _isAscending,
                  onSort: _onSort,
                ),
              ),
              Expanded(
                flex: 20,
                child: _SortableHeader(
                  label: 'Fecha',
                  index: 1,
                  selectedIndex: _sortColumnIndex,
                  ascending: _isAscending,
                  onSort: _onSort,
                ),
              ),
              Expanded(
                flex: 18,
                child: _SortableHeader(
                  label: 'Precio',
                  index: 2,
                  selectedIndex: _sortColumnIndex,
                  ascending: _isAscending,
                  onSort: _onSort,
                ),
              ),
              Expanded(
                flex: 15,
                child: _SortableHeader(
                  label: 'Diff.',
                  index: 3,
                  selectedIndex: _sortColumnIndex,
                  ascending: _isAscending,
                  onSort: _onSort,
                ),
              ),
              Expanded(
                flex: 12,
                child: _SortableHeader(
                  label: 'Var.',
                  index: 4,
                  selectedIndex: _sortColumnIndex,
                  ascending: _isAscending,
                  onSort: _onSort,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: const Border(
                bottom: BorderSide(color: Colors.white10, width: 0.5),
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
                  _buildRow(context, tableData[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, Map<String, dynamic> row) {
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
    return Dismissible(
      key: ValueKey(date.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white, size: 20),
      ),
      confirmDismiss: (direction) => showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Eliminar Precio'),
          content: Text(
            '¿Deseas eliminar el registro del día ${DateFormat('dd/MM/yyyy').format(date)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        final point = PricePoint(date, row['price'] as double);
        final key = '${widget.fund.isin}|${date.toIso8601String()}';
        _pendingDeletedPricePoints.add(key);
        setState(() {});
        try {
          await context.read<FundProvider>().deletePricePoint(
            widget.fund.isin,
            date,
          );
          _pendingDeletedPricePoints.remove(key);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Precio eliminado correctamente'),
              action: SnackBarAction(
                label: 'Deshacer',
                onPressed: () async {
                  try {
                    await context.read<FundProvider>().restorePricePoint(
                      widget.fund.isin,
                      point,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Eliminación deshecha')),
                    );
                  } catch (_) {
                    _showDeleteError(context);
                  }
                },
              ),
            ),
          );
        } catch (_) {
          _pendingDeletedPricePoints.remove(key);
          if (!context.mounted) return;
          setState(() {});
          _showDeleteError(context);
        }
      },
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
              flex: 20,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(date),
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  widget.priceFormat.format(row['price']),
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
            ),
            Expanded(
              flex: 15,
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
              flex: 12,
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
          ],
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
