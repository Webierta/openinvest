class ScraperResult {
  final String? nombre;
  final String? valorLiquidativo;
  final String? fecha;
  final String? divisa;

  const ScraperResult({
    this.nombre,
    this.valorLiquidativo,
    this.fecha,
    this.divisa,
  });

  @override
  String toString() {
    return 'ScraperResult('
        'nombre: $nombre, '
        'valorLiquidativo: $valorLiquidativo, '
        'fecha: $fecha, '
        'divisa: $divisa'
        ')';
  }
}
