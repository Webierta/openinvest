import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/fund_scraper.dart';

class MonthlyReturnsTab extends StatelessWidget {
  final FundData fund;
  final NumberFormat percentFormat;

  const MonthlyReturnsTab({
    super.key,
    required this.fund,
    required this.percentFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (fund.history.isEmpty) {
      return const Center(
        child: Text(
          'No hay historial de precios para calcular rentabilidades.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final data = _calculateMonthlyReturns();
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Datos insuficientes para generar el mapa de calor.',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    final years = data.keys.toList()..sort((a, b) => b.compareTo(a));
    final months = [
      'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
      'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cálculo del ancho adaptativo real considerando márgenes internos
        const double minCellWidth = 38.0;
        const double totalColumnWeight = 1.3;
        const double totalUnits = 14 + totalColumnWeight; 
        const double totalMargins = 15 * 2; // 15 celdas * 2px de margen horizontal cada una
        
        final double availableWidth = constraints.maxWidth - 16; // Ancho menos padding del contenedor
        final double availableForCells = availableWidth - totalMargins;
        
        final double adaptiveCellWidth = max(minCellWidth, availableForCells / totalUnits);
        final double adaptiveTotalWidth = adaptiveCellWidth * totalColumnWeight;

        // Comprobamos si el contenido total realmente cabe
        final double totalContentWidth = (adaptiveCellWidth * 14) + adaptiveTotalWidth + totalMargins;
        final bool needsScroll = totalContentWidth > availableWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: needsScroll 
              ? const AlwaysScrollableScrollPhysics() 
              : const NeverScrollableScrollPhysics(),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera de meses
                  Row(
                    children: [
                      _HeatBox(text: 'Año', isHeader: true, width: adaptiveCellWidth),
                      ...months.map((m) => _HeatBox(text: m, isHeader: true, width: adaptiveCellWidth)),
                      _HeatBox(text: 'TOTAL', isHeader: true, width: adaptiveTotalWidth),
                      _HeatBox(text: 'Año', isHeader: true, width: adaptiveCellWidth),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Filas por año
                  ...years.map((year) {
                    final yearData = data[year]!;
                    double yearAcc = 1.0;
                    bool hasData = false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          _HeatBox(text: year.toString(), isHeader: true, width: adaptiveCellWidth),
                          ...List.generate(12, (index) {
                            final month = index + 1;
                            final value = yearData[month];
                            if (value != null) {
                              yearAcc *= (1 + value / 100);
                              hasData = true;
                              return _HeatBox(value: value, width: adaptiveCellWidth);
                            }
                            return _HeatBox(width: adaptiveCellWidth);
                          }),
                          _HeatBox(
                            value: hasData ? (yearAcc - 1) * 100 : null,
                            width: adaptiveTotalWidth,
                            isBold: true,
                          ),
                          _HeatBox(text: year.toString(), isHeader: true, width: adaptiveCellWidth),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  Map<int, Map<int, double>> _calculateMonthlyReturns() {
    final Map<int, Map<int, double>> returns = {};
    if (fund.history.length < 2) return returns;

    // Agrupar por mes/año y tomar el último precio disponible de cada mes
    final Map<int, Map<int, double>> lastPrices = {};
    for (var point in fund.history) {
      lastPrices.putIfAbsent(point.date.year, () => {})[point.date.month] = point.price;
    }

    final sortedYears = lastPrices.keys.toList()..sort();
    
    for (var year in sortedYears) {
      final months = lastPrices[year]!.keys.toList()..sort();
      for (var month in months) {
        double? prevPrice;
        
        if (month > 1) {
          // Intentar el mes anterior del mismo año
          prevPrice = lastPrices[year]![month - 1];
        } else {
          // Intentar diciembre del año anterior
          prevPrice = lastPrices[year - 1]?[12];
        }

        if (prevPrice != null && prevPrice > 0) {
          final currentPrice = lastPrices[year]![month]!;
          final change = ((currentPrice / prevPrice) - 1) * 100;
          returns.putIfAbsent(year, () => {})[month] = change;
        }
      }
    }

    return returns;
  }
}

class _HeatBox extends StatelessWidget {
  final String? text;
  final double? value;
  final bool isHeader;
  final bool isBold;
  final double width;

  const _HeatBox({
    this.text,
    this.value,
    this.isHeader = false,
    this.isBold = false,
    this.width = 45,
  });

  Color _getBackgroundColor() {
    if (isHeader) return Colors.white10;
    if (value == null) return Colors.transparent;
    
    if (value! > 0) {
      // Escala de verdes
      final opacity = (value! / 8).clamp(0.1, 0.8);
      return Colors.greenAccent[400]!.withValues(alpha: opacity);
    } else if (value! < 0) {
      // Escala de rojos
      final opacity = (value!.abs() / 8).clamp(0.1, 0.8);
      return Colors.redAccent[200]!.withValues(alpha: opacity);
    }
    return Colors.white.withValues(alpha: 0.05);
  }

  @override
  Widget build(BuildContext context) {
    String display = '';
    if (text != null) {
      display = text!;
    } else if (value != null) {
      display = value!.toStringAsFixed(1);
      if (value! > 0 && !isBold) display = '+$display';
    }

    return Container(
      width: width,
      height: 35,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(4),
        border: isHeader ? null : Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      alignment: Alignment.center,
      child: Text(
        display,
        style: TextStyle(
          fontSize: isHeader ? 10 : 11,
          fontWeight: (isHeader || isBold) ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.white54 : Colors.white,
        ),
      ),
    );
  }
}
