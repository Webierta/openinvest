import '../models/fund_data.dart';
import '../utils/fund_comparison_calculator.dart';

/// Representa la matriz de correlación de una cartera completa.
class PortfolioCorrelationMatrix {
  /// Lista ordenada de ISINs que corresponden a las filas y columnas de la matriz.
  final List<String> isins;

  /// Matriz bidimensional de valores de correlación.
  /// Puede ser null si no hay suficientes datos superpuestos entre dos fondos.
  final List<List<double?>> values;

  PortfolioCorrelationMatrix(this.isins, this.values);

  /// Obtiene la correlación entre dos ISINs específicos.
  double? getCorrelation(String isinA, String isinB) {
    final indexA = isins.indexOf(isinA);
    final indexB = isins.indexOf(isinB);
    if (indexA == -1 || indexB == -1) return null;
    return values[indexA][indexB];
  }

  /// Devuelve el número de fondos en la matriz.
  int get size => isins.length;
}

/// Calcula la matriz de correlación completa para una lista de fondos.
///
/// [funds]: La lista de fondos de la cartera del usuario.
/// [minDataPoints]: Mínimo de días de superposición requeridos para considerar
///                  la correlación válida (por defecto 30 días).
PortfolioCorrelationMatrix calculatePortfolioCorrelationMatrix(
  List<FundData> funds, {
  int minDataPoints = 30,
}) {
  if (funds.isEmpty) {
    return PortfolioCorrelationMatrix([], []);
  }

  final int n = funds.length;
  final List<String> isins = funds.map((f) => f.isin).toList();

  // Inicializamos la matriz con nulls
  final List<List<double?>> matrix = List.generate(
    n,
    (_) => List.filled(n, null),
  );

  for (int i = 0; i < n; i++) {
    // 1. La diagonal principal siempre es 1.0 (un fondo correlaciona perfectamente consigo mismo)
    matrix[i][i] = 1.0;

    // 2. Calculamos solo la mitad superior de la matriz (j empieza en i + 1)
    for (int j = i + 1; j < n; j++) {
      /* final correlation = calculateFundCorrelation(
        funds[i],
        funds[j],
        minDataPoints: minDataPoints,
      ); */
      final correlation = FundComparisonCalculator.calculateFundCorrelation(
        funds[i],
        funds[j],
        minDataPoints: minDataPoints,
      );

      // 3. Asignamos el valor a ambas posiciones (simetría)
      matrix[i][j] = correlation;
      matrix[j][i] = correlation;
    }
  }

  return PortfolioCorrelationMatrix(isins, matrix);
}
