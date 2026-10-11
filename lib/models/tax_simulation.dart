import '../models/fund_data.dart';

//import '../models/fund_operation.dart'; // Ajusta la ruta a tu modelo real

/// Configura los parámetros de entrada para la simulación fiscal.
class TaxSimulation {
  final FundData fund;

  /// Cantidad a reembolsar. Puede ser importe en euros o número de participaciones.
  final double amount;

  /// Si es true, 'amount' representa participaciones. Si es false, representa importe en la divisa del fondo.
  final bool isSharesInput;

  /// Tipo impositivo aplicable a la ganancia patrimonial (ej: 19.0, 21.0, 23.0).
  final double taxRate;

  /// (Opcional) Valor Liquidativo (VL) al que se simula la venta.
  /// Por defecto, usa el último VL conocido del fondo.
  final double? targetNav;

  TaxSimulation({
    required this.fund,
    required this.amount,
    required this.isSharesInput,
    this.taxRate =
        19.0, // 19% es el tramo más bajo y realista en España actualmente
    this.targetNav,
  }) : assert(amount > 0, 'La cantidad debe ser mayor a cero'),
       assert(
         taxRate >= 0 && taxRate <= 100,
         'El tipo impositivo debe estar entre 0 y 100',
       );
}

/// Resultado de la estimación fiscal.
class TaxSimulationResult {
  final double soldShares; // Participaciones que se venden
  final double saleValue; // Valor total de la venta (Bruto)
  // Coste de adquisición de esas participaciones (FIFO)
  final double acquisitionCost;
  final double capitalGain; // Plusvalía (o minusvalía si es negativa)
  final double estimatedTax; // Impuestos estimados a pagar
  // Dinero neto que recibe el usuario (Venta - Impuestos)
  final double netAmount;
  final bool hasSufficientShares; // Validación: ¿Tiene el usuario suficientes participaciones?
  final String? warningMessage; // Advertencias (ej: "No hay histórico de compras para calcular FIFO exacto")

  const TaxSimulationResult({
    required this.soldShares,
    required this.saleValue,
    required this.acquisitionCost,
    required this.capitalGain,
    required this.estimatedTax,
    required this.netAmount,
    required this.hasSufficientShares,
    this.warningMessage,
  });
}
