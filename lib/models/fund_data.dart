import '../services/isin_resolver.dart';
import '../utils/app_error.dart';
import 'fund_cost.dart';

class PricePoint {
  final DateTime date;
  final double price;

  PricePoint(this.date, this.price);

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'price': price,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) =>
      PricePoint(DateTime.parse(json['date']), json['price'].toDouble());
}

enum OperationType { buy, sell }

class FundOperation {
  final int? id;
  final String isin;
  final DateTime date;
  final OperationType type;
  final double units;
  final double price;
  final double amount;

  FundOperation({
    this.id,
    required this.isin,
    required this.date,
    required this.type,
    required this.units,
    required this.price,
    required this.amount,
  });

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'date': date.toIso8601String(),
    'type': type.name,
    'units': units,
    'price': price,
    'amount': amount,
  };

  factory FundOperation.fromJson(Map<String, dynamic> json) => FundOperation(
    isin: json['isin'],
    date: DateTime.parse(json['date']),
    type: json['type'] == 'buy' ? OperationType.buy : OperationType.sell,
    units: json['units'].toDouble(),
    price: json['price'].toDouble(),
    amount:
        json['amount']?.toDouble() ??
        (json['units'] * json['price']).toDouble(),
  );
}

class FundData {
  final String isin;
  final String symbol;
  final String name;
  final double lastValue;
  final String currency;
  final DateTime date;
  final List<PricePoint> history;
  final List<FundOperation> operations;
  final double? alertMin;
  final double? alertMax;
  final double? ter;
  final double? performanceFee;
  final List<FundCostPeriod> costPeriods;
  final List<FundCostCharge> costCharges;
  final int? morningstarRating;
  final DateTime? morningstarCheckedAt;
  final DateTime? morningstarLastAttemptAt;

  FundData({
    required this.isin,
    required this.symbol,
    required this.name,
    required this.lastValue,
    required this.currency,
    required this.date,
    required List<PricePoint> history,
    this.operations = const [],
    this.alertMin,
    this.alertMax,
    this.ter,
    this.performanceFee,
    List<FundCostPeriod>? costPeriods,
    List<FundCostCharge> costCharges = const [],
    this.morningstarRating,
    this.morningstarCheckedAt,
    this.morningstarLastAttemptAt,
  }) : history = _syncHistory(history, lastValue, date),
       costPeriods = List.unmodifiable(
         costPeriods ?? _legacyCostPeriods(ter, performanceFee),
       ),
       costCharges = List.unmodifiable(costCharges);

  // Asegura que lastValue esté en history y sea el punto más reciente para esa fecha
  static List<PricePoint> _syncHistory(
    List<PricePoint> history,
    double lastValue,
    DateTime date,
  ) {
    final DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    final List<PricePoint> synced = List.from(history);

    if (lastValue <= 0) {
      synced.sort((a, b) => a.date.compareTo(b.date));
      return synced;
    }

    final int existingIdx = synced.indexWhere(
      (p) =>
          p.date.year == normalizedDate.year &&
          p.date.month == normalizedDate.month &&
          p.date.day == normalizedDate.day,
    );

    if (existingIdx != -1) {
      // Reemplazamos el punto del día con el lastValue más preciso
      synced[existingIdx] = PricePoint(normalizedDate, lastValue);
    } else {
      // Si no existe el día en el historial (ej: es hoy), lo añadimos
      synced.add(PricePoint(normalizedDate, lastValue));
    }

    synced.sort((a, b) => a.date.compareTo(b.date));
    return synced;
  }

  Map<String, dynamic> toJson() => {
    'isin': isin,
    'symbol': symbol,
    'name': name,
    'lastValue': lastValue,
    'currency': currency,
    'date': date.toIso8601String(),
    'history': history.map((e) => e.toJson()).toList(),
    'operations': operations.map((e) => e.toJson()).toList(),
    'alertMin': alertMin,
    'alertMax': alertMax,
    'ter': ter,
    'performanceFee': performanceFee,
    'costPeriods': costPeriods.map((cost) => cost.toJson()).toList(),
    'costCharges': costCharges.map((charge) => charge.toJson()).toList(),
    'morningstarRating': morningstarRating,
    'morningstarCheckedAt': morningstarCheckedAt?.toIso8601String(),
    'morningstarLastAttemptAt': morningstarLastAttemptAt?.toIso8601String(),
  };

  bool get hasValidIsin =>
      RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin.toUpperCase());

  factory FundData.fromJson(Map<String, dynamic> json) => FundData(
    isin: json['isin'],
    symbol: json['symbol'],
    name: json['name'],
    lastValue: json['lastValue'],
    currency: json['currency'],
    date: DateTime.parse(json['date']),
    history:
        (json['history'] as List?)
            ?.map((e) => PricePoint.fromJson(e))
            .toList() ??
        [],
    operations:
        (json['operations'] as List?)
            ?.map((e) => FundOperation.fromJson(e))
            .toList() ??
        [],
    alertMin: json['alertMin']?.toDouble(),
    alertMax: json['alertMax']?.toDouble(),
    ter: json['ter']?.toDouble(),
    performanceFee: json['performanceFee']?.toDouble(),
    costPeriods: _readCostPeriods(json),
    costCharges:
        (json['costCharges'] as List?)
            ?.map((item) => FundCostCharge.fromJson(item))
            .toList() ??
        [],
    morningstarRating: (json['morningstarRating'] as num?)?.toInt(),
    morningstarCheckedAt: DateTime.tryParse(
      json['morningstarCheckedAt'] as String? ?? '',
    ),
    morningstarLastAttemptAt: DateTime.tryParse(
      json['morningstarLastAttemptAt'] as String? ?? '',
    ),
  );

  static List<FundCostPeriod> _readCostPeriods(Map<String, dynamic> json) {
    final serialized = json['costPeriods'] as List?;
    if (serialized != null) {
      return serialized.map((item) => FundCostPeriod.fromJson(item)).toList();
    }

    final ter = (json['ter'] as num?)?.toDouble();
    final performanceFee = (json['performanceFee'] as num?)?.toDouble();
    return _legacyCostPeriods(ter, performanceFee);
  }

  static List<FundCostPeriod> _legacyCostPeriods(
    double? ter,
    double? performanceFee,
  ) {
    final periods = <FundCostPeriod>[];
    if (ter != null) {
      periods.add(
        FundCostPeriod(
          concept: FundCostConcept.ter,
          ratePercent: ter,
          basis: FundCostRateBasis.annualBalance,
          treatment: FundCostTreatment.includedInNav,
        ),
      );
    }
    if (performanceFee != null) {
      periods.add(
        FundCostPeriod(
          concept: FundCostConcept.performance,
          ratePercent: performanceFee,
          basis: FundCostRateBasis.positiveProfit,
          treatment: FundCostTreatment.unknown,
        ),
      );
    }
    return periods;
  }
}

class ScrapeResult {
  final FundData? data;
  final AppError? error;
  final bool isResolved;
  final FundSource? source;

  ScrapeResult({this.data, this.error, this.isResolved = false, this.source});

  String? get errorMessage => error?.message;
}

enum FundSource {
  cnmv,
  local,
  ecb,
  morningstar,
  yahoo,
  //queFondos,
  //finantialTimes,
}

FundSource fundSourceFromIsinSource(String source) {
  if (source == 'CNMV/SIL' || source == 'CNMV/FI') {
    return FundSource.cnmv;
  }
  if (source == 'fondos.json' || source == 'fondos_armonizados.json') {
    return FundSource.local;
  }
  if (source == 'ECB/IFS') {
    return FundSource.ecb;
  }
  if (source == 'Yahoo' || source.startsWith('Yahoo/')) {
    return FundSource.yahoo;
  }
  if (source == 'Morningstar' || source.startsWith('Morningstar/')) {
    return FundSource.morningstar;
  }
  throw ArgumentError('Fuente de ISIN desconocida: $source');
}

FundSearchMatch withResolvedSource(
  FundSearchMatch match,
  IsinResult resolution,
) {
  return FundSearchMatch(
    isin: resolution.isin,
    symbol: match.symbol,
    name: match.name,
    source: fundSourceFromIsinSource(resolution.source),
  );
}

class FundSearchMatch {
  final String? isin;
  final String symbol;
  final String name;
  final FundSource source;

  const FundSearchMatch({
    required this.isin,
    required this.symbol,
    required this.name,
    this.source = FundSource.yahoo,
  });
}
