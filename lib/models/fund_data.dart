import 'package:flutter/material.dart';

import '../services/isin_resolver.dart';
import '../utils/app_error.dart';
import 'fund_cost.dart';

enum PricePointSource {
  manual,
  cnmv,
  yahoo,
  morningstar,
  queFondos,
  financialTimes,
  local,
  ecb,
}

class PricePoint {
  final DateTime date;
  final double price;
  final PricePointSource? source;

  PricePoint(this.date, this.price, {this.source});

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'price': price,
    if (source != null) 'source': source!.name,
  };

  factory PricePoint.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source'];

    return PricePoint(
      DateTime.parse(json['date']),
      (json['price'] as num).toDouble(),
      source: sourceName == null
          ? null
          : PricePointSource.values.firstWhere(
              (value) => value.name == sourceName,
            ),
    );
  }
}

// NOTE: Implementada nueva operación: traspaso entre fondos
enum OperationType { buy, sell, outTransfer, inTransfer }

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
    // NOTE: ajustado a OperationType.outTransfer y inTransfer
    //type: json['type'] == 'buy' ? OperationType.buy : OperationType.sell,
    type: switch (json['type'].toString()) {
      'buy' => OperationType.buy,
      'sell' => OperationType.sell,
      'outTransfer' => OperationType.outTransfer,
      'inTransfer' => OperationType.inTransfer,
      _ => OperationType.buy,
    },
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

  final FundSource? source;
  final FundSource? valuationSource;

  FundData({
    required String isin,
    required String symbol,
    required String name,
    required double lastValue,
    required String currency,
    required DateTime date,
    required List<PricePoint> history,
    List<FundOperation> operations = const [],
    double? alertMin,
    double? alertMax,
    double? ter,
    double? performanceFee,
    List<FundCostPeriod>? costPeriods,
    List<FundCostCharge> costCharges = const [],
    int? morningstarRating,
    DateTime? morningstarCheckedAt,
    DateTime? morningstarLastAttemptAt,
    FundSource? source,
    FundSource? valuationSource,
  }) : this._(
         isin: isin,
         symbol: symbol,
         name: name,
         lastValue: lastValue,
         currency: currency,
         date: date,
         history: history,
         operations: operations,
         alertMin: alertMin,
         alertMax: alertMax,
         ter: ter,
         performanceFee: performanceFee,
         costPeriods: costPeriods,
         costCharges: costCharges,
         morningstarRating: morningstarRating,
         morningstarCheckedAt: morningstarCheckedAt,
         morningstarLastAttemptAt: morningstarLastAttemptAt,
         source: source,
         valuationSource: valuationSource,
         syncHistory: true,
       );

  FundData._({
    required this.isin,
    required this.symbol,
    required this.name,
    required this.lastValue,
    required this.currency,
    required this.date,
    required List<PricePoint> history,
    required List<FundOperation> operations,
    required this.alertMin,
    required this.alertMax,
    required this.ter,
    required this.performanceFee,
    required List<FundCostPeriod>? costPeriods,
    required List<FundCostCharge> costCharges,
    required this.morningstarRating,
    required this.morningstarCheckedAt,
    required this.morningstarLastAttemptAt,
    required this.source,
    required this.valuationSource,
    required bool syncHistory,
  }) : history = syncHistory
           ? _syncHistory(history, lastValue, date)
           : List.unmodifiable(history),
       operations = List.unmodifiable(operations),
       costPeriods = List.unmodifiable(
         costPeriods ?? _legacyCostPeriods(ter, performanceFee),
       ),
       costCharges = List.unmodifiable(costCharges);

  factory FundData.fromPersistence({
    required String isin,
    required String symbol,
    required String name,
    required double lastValue,
    required String currency,
    required DateTime date,
    required List<PricePoint> history,
    List<FundOperation> operations = const [],
    double? alertMin,
    double? alertMax,
    double? ter,
    double? performanceFee,
    List<FundCostPeriod>? costPeriods,
    List<FundCostCharge> costCharges = const [],
    int? morningstarRating,
    DateTime? morningstarCheckedAt,
    DateTime? morningstarLastAttemptAt,
    FundSource? source,
    FundSource? valuationSource,
  }) {
    return FundData._(
      isin: isin,
      symbol: symbol,
      name: name,
      lastValue: lastValue,
      currency: currency,
      date: date,
      history: history,
      operations: operations,
      alertMin: alertMin,
      alertMax: alertMax,
      ter: ter,
      performanceFee: performanceFee,
      costPeriods: costPeriods,
      costCharges: costCharges,
      morningstarRating: morningstarRating,
      morningstarCheckedAt: morningstarCheckedAt,
      morningstarLastAttemptAt: morningstarLastAttemptAt,
      source: source,
      valuationSource: valuationSource,
      syncHistory: false,
    );
  }

  // Asegura que lastValue esté en history y sea el punto más reciente para esa fecha
  static List<PricePoint> _syncHistory(
    List<PricePoint> history,
    double lastValue,
    DateTime date,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final synced = List<PricePoint>.from(history);

    if (lastValue <= 0) {
      synced.sort((a, b) => a.date.compareTo(b.date));
      return synced;
    }

    final existingIdx = synced.indexWhere(
      (p) =>
          p.date.year == normalizedDate.year &&
          p.date.month == normalizedDate.month &&
          p.date.day == normalizedDate.day,
    );

    if (existingIdx == -1) {
      synced.add(PricePoint(normalizedDate, lastValue));
    } /* else {
      final existingPoint = synced[existingIdx];

      synced[existingIdx] = PricePoint(
        existingPoint.date,
        lastValue,
        source: existingPoint.source,
      );
    } */

    synced.sort((a, b) => a.date.compareTo(b.date));
    return synced;
  }

  FundData copyWith({
    String? isin,
    String? symbol,
    String? name,
    double? lastValue,
    String? currency,
    DateTime? date,
    List<PricePoint>? history,
    List<FundOperation>? operations,
    double? alertMin,
    double? alertMax,
    double? ter,
    double? performanceFee,
    List<FundCostPeriod>? costPeriods,
    List<FundCostCharge>? costCharges,
    int? morningstarRating,
    DateTime? morningstarCheckedAt,
    DateTime? morningstarLastAttemptAt,
    FundSource? source,
    FundSource? valuationSource,
  }) {
    final nextLastValue = lastValue ?? this.lastValue;
    final nextDate = date ?? this.date;

    final nextHistory = () {
      final updatedHistory = List<PricePoint>.from(history ?? this.history);

      if (lastValue != null) {
        final normalizedDate = DateTime(
          nextDate.year,
          nextDate.month,
          nextDate.day,
        );

        final existingIndex = updatedHistory.indexWhere(
          (point) =>
              point.date.year == normalizedDate.year &&
              point.date.month == normalizedDate.month &&
              point.date.day == normalizedDate.day,
        );

        if (existingIndex == -1) {
          updatedHistory.add(PricePoint(normalizedDate, nextLastValue));
        } else if (history == null) {
          final existingPoint = updatedHistory[existingIndex];

          updatedHistory[existingIndex] = PricePoint(
            existingPoint.date,
            nextLastValue,
            source: existingPoint.source,
          );
        }
      }

      updatedHistory.sort((a, b) => a.date.compareTo(b.date));

      return updatedHistory;
    }();

    //return FundData(
    return FundData._(
      isin: isin ?? this.isin,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      lastValue: nextLastValue,
      currency: currency ?? this.currency,
      date: nextDate,
      history: nextHistory,
      operations: operations ?? this.operations,
      alertMin: alertMin ?? this.alertMin,
      alertMax: alertMax ?? this.alertMax,
      ter: ter ?? this.ter,
      performanceFee: performanceFee ?? this.performanceFee,
      costPeriods: costPeriods ?? this.costPeriods,
      costCharges: costCharges ?? this.costCharges,
      morningstarRating: morningstarRating ?? this.morningstarRating,
      morningstarCheckedAt: morningstarCheckedAt ?? this.morningstarCheckedAt,
      morningstarLastAttemptAt:
          morningstarLastAttemptAt ?? this.morningstarLastAttemptAt,
      source: source ?? this.source,
      valuationSource: valuationSource ?? this.valuationSource,
      syncHistory: false,
    );
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
    'source': source?.name,
    'valuationSource': valuationSource?.name,
  };

  bool get hasValidIsin =>
      RegExp(r'^[A-Z]{2}[A-Z0-9]{9}[0-9]$').hasMatch(isin.toUpperCase());

  PricePoint? pointByDate(DateTime fecha) {
    if (history.isEmpty) return null;

    return history.cast<PricePoint?>().firstWhere(
      (point) =>
          point != null &&
          point.date.year == fecha.year &&
          point.date.month == fecha.month &&
          point.date.day == fecha.day,
      orElse: () => null,
    );
  }

  /* double? priceForDate(DateTime fecha) {
    if (history.isEmpty) return null;

    return history
        .cast<PricePoint?>()
        .firstWhere(
          (point) =>
              point != null &&
              point.date.year == fecha.year &&
              point.date.month == fecha.month &&
              point.date.day == fecha.day,
          orElse: () => null,
        )
        ?.price;
  } */

  static FundSource? _fundSourceFromJson(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final source in FundSource.values) {
      if (source.name == value) return source;
    }
    return null;
  }

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
    source: _fundSourceFromJson(json['source'] as String?),
    valuationSource: _fundSourceFromJson(json['valuationSource'] as String?),
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
  //final FundSource? valuationSource;

  ScrapeResult({
    this.data,
    this.error,
    this.isResolved = false,
    this.source,
    //this.valuationSource,
  });

  String? get errorMessage => error?.message;
}

enum FundSource {
  cnmv(name: 'CNMV', badgeLabel: 'CNMV', color: Color(0xFFA50A37)),
  local(name: 'Local', badgeLabel: 'LOCAL', color: Colors.teal),
  ecb(name: 'ECB', badgeLabel: 'ECB', color: Colors.deepPurpleAccent),
  morningstar(
    name: 'Morningstar',
    badgeLabel: 'MORNINGSTAR',
    color: Colors.orangeAccent,
  ),
  yahoo(name: 'Yahoo', badgeLabel: 'YAHOO', color: Colors.blueAccent),
  queFondos(name: 'QueFondos', badgeLabel: 'QUEFONDOS', color: Colors.green),
  financialTimes(
    name: 'Financial Times',
    badgeLabel: 'FT',
    color: Colors.brown,
  );

  const FundSource({
    required this.name,
    required this.badgeLabel,
    required this.color,
  });

  final String name;
  final String badgeLabel;
  final Color color;
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
