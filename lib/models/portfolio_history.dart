class PortfolioHistory {
  final int? id;
  final String uid;
  final String? fundName;
  final String? isin;
  final DateTime startDate;
  final DateTime endDate;
  final double initialValue;
  final double finalValue;
  final DateTime createdAt;

  PortfolioHistory({
    this.id,
    required this.uid,
    this.fundName,
    this.isin,
    required this.startDate,
    required this.endDate,
    required this.initialValue,
    required this.finalValue,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now() {
    _validate();
  }

  double get returnPercent => (finalValue / initialValue - 1) * 100;

  double get returnAmount => finalValue - initialValue;

  void _validate() {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El UID del histórico no puede estar vacío.');
    }

    if (!initialValue.isFinite || initialValue <= 0) {
      throw ArgumentError('El valor inicial debe ser finito y positivo.');
    }

    if (!finalValue.isFinite || finalValue < 0) {
      throw ArgumentError('El valor final debe ser finito y no negativo.');
    }

    if (endDate.isBefore(startDate)) {
      throw ArgumentError('La fecha final no puede ser anterior a la inicial.');
    }
  }

  PortfolioHistory copyWith({
    int? id,
    String? uid,
    String? fundName,
    String? isin,
    DateTime? startDate,
    DateTime? endDate,
    double? initialValue,
    double? finalValue,
    DateTime? createdAt,
  }) {
    return PortfolioHistory(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      fundName: fundName ?? this.fundName,
      isin: isin ?? this.isin,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      initialValue: initialValue ?? this.initialValue,
      finalValue: finalValue ?? this.finalValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
