enum HistoricalOperationType {
  subscription,
  redemption,
  transferIn,
  transferOut,
}

class HistoricalOperation {
  final int? id;
  final String uid;
  final String investmentUid;
  final DateTime date;
  final HistoricalOperationType type;
  final double amount;
  final double? units;
  final double? price;
  final String? description;
  final String? transferUid;

  HistoricalOperation({
    this.id,
    required String uid,
    required String investmentUid,
    required this.date,
    required this.type,
    double? amount,
    this.units,
    this.price,
    this.description,
    String? transferUid,
  }) : uid = uid.trim(),
       investmentUid = investmentUid.trim(),
       transferUid = transferUid?.trim(),
       amount = amount ?? _calculateAmount(units, price) {
    _validate();
    _validateAmountConsistency();
  }

  static double _calculateAmount(double? units, double? price) {
    if (units == null || price == null) {
      throw ArgumentError(
        'Debe indicarse el importe o proporcionar participaciones y precio',
      );
    }

    return units * price;
  }

  void _validate() {
    if (uid.trim().isEmpty) {
      throw ArgumentError('El UID de la operación no puede estar vacío');
    }

    if (investmentUid.trim().isEmpty) {
      throw ArgumentError('El UID de la inversión no puede estar vacío');
    }

    if (transferUid != null && transferUid!.trim().isEmpty) {
      throw ArgumentError('El UID de transferencia no puede estar vacío');
    }

    if (!amount.isFinite || amount < 0) {
      throw ArgumentError('El importe debe ser finito y no negativo');
    }

    if (units != null && (!units!.isFinite || units! < 0)) {
      throw ArgumentError(
        'Las participaciones deben ser finitas y no negativas',
      );
    }

    if (price != null && (!price!.isFinite || price! < 0)) {
      throw ArgumentError('El precio debe ser finito y no negativo');
    }
  }

  void _validateAmountConsistency() {
    if (units == null || price == null) return;

    final calculatedAmount = units! * price!;

    // Tolerancia de un céntimo para diferencias de redondeo.
    if ((amount - calculatedAmount).abs() > 0.01) {
      throw ArgumentError(
        'El importe no coincide con las participaciones multiplicadas por el precio',
      );
    }
  }

  static const Object _unset = Object();

  HistoricalOperation copyWith({
    int? id,
    String? uid,
    String? investmentUid,
    DateTime? date,
    HistoricalOperationType? type,
    //double? amount,
    Object? amount = _unset,
    Object? units = _unset,
    Object? price = _unset,
    Object? description = _unset,
    Object? transferUid = _unset,
  }) {
    return HistoricalOperation(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      investmentUid: investmentUid ?? this.investmentUid,
      date: date ?? this.date,
      type: type ?? this.type,
      //amount: amount ?? this.amount,
      //amount: identical(amount, _unset) ? this.amount : amount as double?,
      amount: identical(amount, _unset)
          ? this.amount
          : (amount as num?)?.toDouble(),
      //units: identical(units, _unset) ? this.units : units as double?,
      //price: identical(price, _unset) ? this.price : price as double?,
      units: identical(units, _unset)
          ? this.units
          : (units as num?)?.toDouble(),
      price: identical(price, _unset)
          ? this.price
          : (price as num?)?.toDouble(),
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      transferUid: identical(transferUid, _unset)
          ? this.transferUid
          : transferUid as String?,
    );
  }
}
