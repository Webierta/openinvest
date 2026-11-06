import '../models/historical_operation.dart';

class HistoricalInvestmentValidator {
  static void validate(List<HistoricalOperation> operations) {
    if (operations.isEmpty) {
      throw ArgumentError('La inversión debe tener operaciones.');
    }

    final investmentUid = operations.first.investmentUid;

    if (operations.any(
      (operation) => operation.investmentUid != investmentUid,
    )) {
      throw ArgumentError(
        'Todas las operaciones deben pertenecer a la misma inversión.',
      );
    }

    final operationUids = operations.map((operation) => operation.uid).toSet();

    if (operationUids.length != operations.length) {
      throw ArgumentError('Todas las operaciones deben tener un UID único.');
    }

    final orderedOperations = operations.asMap().entries.toList()
      ..sort((a, b) {
        final dateComparison = a.value.date.compareTo(b.value.date);
        return dateComparison != 0 ? dateComparison : a.key.compareTo(b.key);
      });

    final firstOperation = orderedOperations.first.value;

    final isEntry =
        firstOperation.type == HistoricalOperationType.subscription ||
        firstOperation.type == HistoricalOperationType.transferIn;

    if (!isEntry) {
      throw ArgumentError(
        'La primera operación debe ser una entrada de capital.',
      );
    }

    final lastOperation = orderedOperations.last.value;

    final isExit =
        lastOperation.type == HistoricalOperationType.redemption ||
        lastOperation.type == HistoricalOperationType.transferOut;

    if (!isExit) {
      throw ArgumentError(
        'La última operación debe ser una salida de capital.',
      );
    }
  }
}
