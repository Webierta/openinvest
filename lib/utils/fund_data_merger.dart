import '../models/fund_data.dart';
import '../models/fund_cost.dart';

/// Combina dos representaciones del mismo fondo, por ejemplo,
/// al importar una cartera.
///
/// `source` identifica el origen persistente del fondo.
/// `valuationSource` identifica la fuente de su valoración más reciente.
class FundDataMerger {
  const FundDataMerger._();

  static FundData merge(FundData existing, FundData incoming) {
    final uniqueOps = <String, FundOperation>{};

    for (final op in existing.operations) {
      final key =
          '${op.date.toIso8601String()}_${op.type}_${op.units}_${op.price}';
      uniqueOps[key] = op;
    }

    for (final op in incoming.operations) {
      final key =
          '${op.date.toIso8601String()}_${op.type}_${op.units}_${op.price}';
      uniqueOps[key] = op;
    }

    final mergedOps = uniqueOps.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final uniquePeriods = <String, FundCostPeriod>{};
    for (final period in [...existing.costPeriods, ...incoming.costPeriods]) {
      uniquePeriods[period.uid] = period;
    }

    final uniqueCharges = <String, FundCostCharge>{};
    for (final charge in [...existing.costCharges, ...incoming.costCharges]) {
      uniqueCharges[charge.uid] = charge;
    }

    // Fusiona ambos historiales por día. Si hay dos valores para el mismo
    // día, prevalece el del fondo entrante.

    final historyByDay = <String, PricePoint>{};

    String dayKey(DateTime date) =>
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    for (final point in existing.history) {
      historyByDay[dayKey(point.date)] = point;
    }

    for (final point in incoming.history) {
      historyByDay[dayKey(point.date)] = point;
    }

    final incomingIsNewer = incoming.date.isAfter(existing.date);
    final valuationFund = incomingIsNewer ? incoming : existing;

    // En el día de valoración prevalece la valoración seleccionada.
    // Para el resto de las fechas se conserva la política de fusión
    // del historial: el punto entrante sustituye al existente.
    final valuationDayKey = dayKey(valuationFund.date);
    final valuationPoint = historyByDay[valuationDayKey];

    if (valuationPoint != null) {
      historyByDay[valuationDayKey] = PricePoint(
        valuationPoint.date,
        valuationFund.lastValue,
      );
    }

    final mergedHistory = historyByDay.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return FundData(
      isin: existing.isin,
      symbol: incoming.symbol.isNotEmpty ? incoming.symbol : existing.symbol,
      name: incoming.name.isNotEmpty ? incoming.name : existing.name,
      currency: incoming.currency.isNotEmpty
          ? incoming.currency
          : existing.currency,
      lastValue: valuationFund.lastValue,
      date: valuationFund.date,
      history: mergedHistory,
      operations: mergedOps,
      costPeriods: uniquePeriods.values.toList(),
      costCharges: uniqueCharges.values.toList(),
      alertMin: incoming.alertMin ?? existing.alertMin,
      alertMax: incoming.alertMax ?? existing.alertMax,
      ter: incoming.ter ?? existing.ter,
      performanceFee: incoming.performanceFee ?? existing.performanceFee,
      morningstarRating:
          incoming.morningstarRating ?? existing.morningstarRating,
      morningstarCheckedAt:
          incoming.morningstarCheckedAt ?? existing.morningstarCheckedAt,
      morningstarLastAttemptAt:
          incoming.morningstarLastAttemptAt ??
          existing.morningstarLastAttemptAt,
      source: existing.source ?? incoming.source,
      valuationSource:
          valuationFund.valuationSource ??
          incoming.valuationSource ??
          existing.valuationSource,
    );
  }
}
