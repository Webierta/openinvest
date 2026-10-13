import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/fund_data.dart';
import '../providers/fund_provider.dart';
import '../tools/portfolio_correlation_matrix.dart';
//import '../utils/fund_comparison_calculator.dart'; // Ajusta la ruta a tu utilitario
import '../widgets/circle_avatar_fund.dart';
import '../widgets/gradient_background.dart'; // Tu widget existente

class CorrelationMatrixPage extends StatefulWidget {
  //final List<FundData> funds;
  //final PortfolioCorrelationMatrix matrix;

  const CorrelationMatrixPage({
    super.key,
    //required this.funds,
    //required this.matrix,
  });

  @override
  State<CorrelationMatrixPage> createState() => _CorrelationMatrixPageState();
}

class _CorrelationMatrixPageState extends State<CorrelationMatrixPage> {
  // Controladores explícitos para evitar conflictos en el Scrollbar
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Observamos el Provider para obtener los datos actualizados
    final provider = context.watch<FundProvider>();
    final funds = provider.portfolio;
    final matrix = provider.correlationMatrix;

    // 2. Manejo de estados (Carga o Datos insuficientes)
    if (provider.isCalculatingMatrix) {
      return const Scaffold(
        body: GradientBackground(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (matrix == null || funds.length < 2) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matriz de Correlación')),
        body: const GradientBackground(
          child: Center(
            child: Text(
              'No hay datos suficientes para generar la matriz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final int gridSize = matrix.size + 1; // +1 para las etiquetas

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matriz de Correlación'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '¿Cómo interpretar esta matriz?',
            onPressed: () => _showLegend(context),
          ),
        ],
      ),
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diversificación de la Cartera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  // 1. Asignamos el controlador vertical al Scrollbar
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: Platform.isLinux
                        ? true
                        : false, // Muestra la barra al interactuar
                    child: Scrollbar(
                      controller: _horizontalScrollController,
                      thumbVisibility: Platform.isLinux ? true : false,
                      notificationPredicate: (notification) =>
                          notification.depth == 1,
                      child: SingleChildScrollView(
                        // 2. Y el mismo controlador a la vista de scroll vertical
                        controller: _verticalScrollController,
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          // 3. Controlador independiente para el scroll horizontal
                          controller: _horizontalScrollController,
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: (gridSize * 100.0).clamp(
                              300.0,
                              double.infinity,
                            ),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridSize,
                                    childAspectRatio: 1.0,
                                    crossAxisSpacing: 4,
                                    mainAxisSpacing: 4,
                                  ),
                              itemCount: gridSize * gridSize,
                              itemBuilder: (context, index) {
                                final row = index ~/ gridSize;
                                final col = index % gridSize;
                                return _buildGridCell(
                                  context,
                                  funds,
                                  matrix,
                                  row,
                                  col,
                                  gridSize,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCell(
    BuildContext context,
    List<FundData> funds,
    PortfolioCorrelationMatrix matrix,
    int row,
    int col,
    int gridSize,
  ) {
    if (row == 0 && col == 0) return const SizedBox.shrink();

    if (row == 0) {
      //return _buildHeaderCell(widget.funds[col - 1].isin);
      return _buildHeaderAvatar(funds[col - 1]);
    }

    if (col == 0) {
      //return _buildHeaderCell(widget.funds[row - 1].isin, isRow: true);
      return _buildHeaderAvatar(funds[row - 1], isRow: true);
    }

    final fundA = funds[row - 1];
    final fundB = funds[col - 1];
    final correlation = matrix.getCorrelation(fundA.isin, fundB.isin);

    return _buildDataCell(context, fundA, fundB, correlation, row == col);
  }

  Widget _buildHeaderAvatar(FundData fund, {bool isRow = false}) {
    return Tooltip(
      message: fund.name,
      child: CircleAvatarFund(fund: fund, fontSize: 40),
    );
  }

  /* Widget _buildHeaderCell(String text, {bool isRow = false}) {
    return Container(
      alignment: isRow ? Alignment.centerRight : Alignment.center,
      padding: isRow
          ? const EdgeInsets.only(right: 8)
          : const EdgeInsets.all(4),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: isRow ? TextAlign.right : TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  } */

  Widget _buildDataCell(
    BuildContext context,
    FundData fundA,
    FundData fundB,
    double? correlation,
    bool isDiagonal,
  ) {
    if (isDiagonal) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white24),
        ),
        alignment: Alignment.center,
        child: const Text(
          '1.00',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (correlation == null) {
      return Tooltip(
        message: 'Datos históricos insuficientes para calcular',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.remove, color: Colors.white38, size: 20),
        ),
      );
    }

    final colorData = _getColorAndMessage(correlation);

    return Tooltip(
      message:
          '${fundA.name} vs ${fundB.name}: ${correlation.toStringAsFixed(2)}',

      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        onTap: () => _showCellDetails(context, fundA, fundB, correlation),
        child: Container(
          decoration: BoxDecoration(
            color: colorData.color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorData.color.withValues(alpha: 0.5)),
          ),
          alignment: Alignment.center,
          child: Text(
            correlation.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  ({Color color, String message}) _getColorAndMessage(double value) {
    if (value >= 0.8) {
      return (
        color: Colors.redAccent,
        message: 'Correlación muy alta (Riesgo de concentración)',
      );
    }
    if (value >= 0.5) {
      return (color: Colors.orange, message: 'Correlación alta');
    }
    if (value >= 0.2) {
      return (color: Colors.amber, message: 'Correlación moderada');
    }
    if (value >= -0.2) {
      return (
        color: Colors.blueGrey,
        message: 'Correlación baja (Buena diversificación)',
      );
    }
    return (
      color: Colors.green,
      message: 'Correlación negativa (Cobertura ideal)',
    );
  }

  void _showCellDetails(
    BuildContext context,
    FundData fundA,
    FundData fundB,
    double correlation,
  ) {
    final colorData = _getColorAndMessage(correlation);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorData.color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Correlación: ${correlation.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colorData.color,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${fundA.name} (${fundA.isin})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Text(
              'vs',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            Text(
              '${fundB.name} (${fundB.isin})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorData.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorData.color.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                colorData.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: Navigator.of(ctx).pop,
                child: const Text('Entendido'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLegend(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Matriz de Correlación',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: .start,
          children: [
            Text(
              'Valores cercanos a 1 indican que los fondos se mueven juntos, '
              'mientras que los valores cercanos a 0 o negativos indican buena diversificación.\n'
              'Pulsa sobre una celda de la matriz para ver más detalles.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Text('Leyenda de colores', style: TextStyle(fontSize: 16)),
            _legendItem(
              Colors.redAccent,
              '0.80 a 1.00',
              'Movimiento casi idéntico. Poca diversificación real.',
            ),
            _legendItem(
              Colors.orange,
              '0.50 a 0.79',
              'Tendencia a subir y bajar juntos.',
            ),
            _legendItem(
              Colors.blueGrey,
              '-0.20 a 0.49',
              'Movimientos independientes. Buena diversificación.',
            ),
            _legendItem(
              Colors.green,
              '-1.00 a -0.21',
              'Movimientos opuestos. Excelente cobertura de riesgo.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(ctx).pop,
            child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String range, String description) {
    return ListTile(
      titleAlignment: ListTileTitleAlignment.titleHeight,
      leading: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(
        range,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        description,
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }
}
