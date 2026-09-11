import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:investing/utils/app_error.dart';

void main() {
  test('clasifica errores de red como reintentables', () {
    final error = AppError.fromException(
      const SocketException('offline'),
      StackTrace.current,
    );

    expect(error.type, AppErrorType.network);
    expect(error.isRetryable, isTrue);
    expect(error.message, contains('conectar'));
  });

  test('clasifica timeouts como errores de red', () {
    final error = AppError.fromException(
      TimeoutException('timeout'),
      StackTrace.current,
    );

    expect(error.type, AppErrorType.network);
    expect(error.isRetryable, isTrue);
  });

  test('los errores de base de datos recomiendan backup', () {
    final error = AppError.database(cause: StateError('database failure'));

    expect(error.type, AppErrorType.database);
    expect(error.isRetryable, isFalse);
    expect(error.message, contains('backup'));
    expect(error.message, isNot(contains('database failure')));
  });
}
