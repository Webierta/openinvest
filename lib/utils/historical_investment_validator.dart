import '../models/historical_operation.dart';

class HistoricalInvestmentValidator {
  static void validateUpdate(
    List<HistoricalOperation> operations,
    HistoricalOperation updatedOperation,
  ) {
    // Comprobar que la secuencia original es válida.
    validate(operations);

    final index = updatedOperation.id != null
        ? operations.indexWhere(
            (operation) => operation.id == updatedOperation.id,
          )
        : operations.indexWhere(
            (operation) => operation.uid == updatedOperation.uid,
          );

    if (index == -1) {
      throw ArgumentError('La operación que se quiere actualizar no existe.');
    }

    if (operations[index].uid != updatedOperation.uid) {
      throw ArgumentError('No se puede cambiar el UID de una operación.');
    }

    if (operations[index].investmentUid != updatedOperation.investmentUid) {
      throw ArgumentError(
        'No se puede cambiar la inversión a la que pertenece una operación.',
      );
    }

    final updatedOperations = List<HistoricalOperation>.of(operations);
    updatedOperations[index] = updatedOperation;

    validate(updatedOperations);
  }

  static void validateDeletion(
    List<HistoricalOperation> operations,
    String operationUid,
  ) {
    // Comprobar que la secuencia original es válida.
    validate(operations);

    final remainingOperations = operations
        .where((operation) => operation.uid != operationUid)
        .toList();

    if (remainingOperations.length == operations.length) {
      throw ArgumentError('La operación que se quiere eliminar no existe.');
    }

    // Comprobar que la secuencia resultante sigue siendo válida.
    validate(remainingOperations);
  }

  static bool isClosed(List<HistoricalOperation> operations) {
    if (operations.isEmpty) return false;

    final orderedOperations = operations.asMap().entries.toList()
      ..sort((a, b) {
        final dateComparison = a.value.date.compareTo(b.value.date);
        return dateComparison != 0 ? dateComparison : a.key.compareTo(b.key);
      });

    final lastOperation = orderedOperations.last.value;

    return lastOperation.type == HistoricalOperationType.redemption ||
        lastOperation.type == HistoricalOperationType.transferOut;
  }

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
