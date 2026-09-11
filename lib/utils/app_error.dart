import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

enum AppErrorType {
  network,
  database,
  busy,
  validation,
  notFound,
  remote,
  data,
  unknown,
}

class AppError implements Exception {
  final AppErrorType type;
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppError({
    required this.type,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  bool get isRetryable => type == AppErrorType.network;

  factory AppError.network({Object? cause, StackTrace? stackTrace}) => AppError(
    type: AppErrorType.network,
    message: 'No se pudo conectar. Comprueba tu conexión e inténtalo de nuevo.',
    cause: cause,
    stackTrace: stackTrace,
  );

  factory AppError.database({
    Object? cause,
    StackTrace? stackTrace,
  }) => AppError(
    type: AppErrorType.database,
    message:
        'No se pudo guardar el cambio. Haz un backup y reinicia la aplicación.',
    cause: cause,
    stackTrace: stackTrace,
  );

  factory AppError.busy() => const AppError(
    type: AppErrorType.busy,
    message:
        'Hay otra operación en curso. Espera un momento e inténtalo de nuevo.',
  );

  factory AppError.validation(String message) =>
      AppError(type: AppErrorType.validation, message: message);

  factory AppError.notFound(String message) =>
      AppError(type: AppErrorType.notFound, message: message);

  factory AppError.remote(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => AppError(
    type: AppErrorType.remote,
    message: message,
    cause: cause,
    stackTrace: stackTrace,
  );

  factory AppError.data(
    String message, {
    Object? cause,
    StackTrace? stackTrace,
  }) => AppError(
    type: AppErrorType.data,
    message: message,
    cause: cause,
    stackTrace: stackTrace,
  );

  factory AppError.fromException(
    Object error,
    StackTrace stackTrace, {
    AppErrorType type = AppErrorType.unknown,
  }) {
    if (error is AppError) return error;
    if (error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return AppError.network(cause: error, stackTrace: stackTrace);
    }
    return AppError(
      type: type,
      message: 'Ha ocurrido un error inesperado. Inténtalo de nuevo.',
      cause: error,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'AppError($type): $message';
}
