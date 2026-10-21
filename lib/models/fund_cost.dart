enum FundCostConcept {
  ter,
  management,
  depositary,
  operating,
  subscription,
  redemption,
  transfer,
  distributor,
  custody,
  performance,
  tax,
  other,
}

enum FundCostTreatment { includedInNav, chargedSeparately, unknown }

enum FundCostRateBasis { annualBalance, positiveProfit }

int _costUidCounter = 0;

String _newCostUid() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_${_costUidCounter++}';

class FundCostPeriod {
  final int? id;
  final String uid;
  final FundCostConcept concept;
  final double ratePercent;
  final FundCostRateBasis basis;
  final FundCostTreatment treatment;
  final DateTime? validFrom;
  final DateTime? validTo;
  final String? description;

  FundCostPeriod({
    this.id,
    String? uid,
    required this.concept,
    required this.ratePercent,
    required this.basis,
    required this.treatment,
    this.validFrom,
    this.validTo,
    this.description,
  }) : uid = uid ?? _newCostUid();

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'concept': concept.name,
    'ratePercent': ratePercent,
    'basis': basis.name,
    'treatment': treatment.name,
    'validFrom': validFrom?.toIso8601String(),
    'validTo': validTo?.toIso8601String(),
    'description': description,
  };

  factory FundCostPeriod.fromJson(Map<String, dynamic> json) {
    final ratePercent = (json['ratePercent'] as num).toDouble();
    final validFrom = DateTime.tryParse(json['validFrom'] as String? ?? '');
    final validTo = DateTime.tryParse(json['validTo'] as String? ?? '');

    if (!ratePercent.isFinite) {
      throw ArgumentError.value(
        ratePercent,
        'ratePercent',
        'La tasa debe ser un número finito.',
      );
    }

    if (validFrom != null && validTo != null && validTo.isBefore(validFrom)) {
      throw ArgumentError(
        'La fecha final del periodo no puede preceder a la inicial.',
      );
    }

    return FundCostPeriod(
      uid: json['uid'] as String?,
      concept: FundCostConcept.values.firstWhere(
        (value) => value.name == json['concept'],
        orElse: () => FundCostConcept.other,
      ),
      ratePercent: ratePercent,
      basis: FundCostRateBasis.values.firstWhere(
        (value) => value.name == json['basis'],
        orElse: () => FundCostRateBasis.annualBalance,
      ),
      treatment: FundCostTreatment.values.firstWhere(
        (value) => value.name == json['treatment'],
        orElse: () => FundCostTreatment.unknown,
      ),
      validFrom: validFrom,
      validTo: validTo,
      description: json['description'] as String?,
    );
  }
}

class FundCostCharge {
  final int? id;
  final String uid;
  final FundCostConcept concept;
  final DateTime date;
  final double amount;
  final String? description;
  final String? performancePeriodUid;
  final DateTime? settledThrough;

  FundCostCharge({
    this.id,
    String? uid,
    required this.concept,
    required this.date,
    required this.amount,
    this.description,
    this.performancePeriodUid,
    this.settledThrough,
  }) : uid = uid ?? _newCostUid();

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'concept': concept.name,
    'date': date.toIso8601String(),
    'amount': amount,
    'description': description,
    'performancePeriodUid': performancePeriodUid,
    'settledThrough': settledThrough?.toIso8601String(),
  };

  factory FundCostCharge.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num).toDouble();

    if (!amount.isFinite) {
      throw ArgumentError.value(
        amount,
        'amount',
        'El importe debe ser un número finito.',
      );
    }

    return FundCostCharge(
      uid: json['uid'] as String?,
      concept: FundCostConcept.values.firstWhere(
        (value) => value.name == json['concept'],
        orElse: () => FundCostConcept.other,
      ),
      date: DateTime.parse(json['date'] as String),
      amount: amount,
      description: json['description'] as String?,
      performancePeriodUid: json['performancePeriodUid'] as String?,
      settledThrough: DateTime.tryParse(
        json['settledThrough'] as String? ?? '',
      ),
    );
  }
}
