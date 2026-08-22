class AppError {
  AppError({
    required this.code,
    required this.userMessage,
    this.retryable = false,
    String? diagnosticId,
    this.cause,
  }) : diagnosticId = diagnosticId ?? _newDiagnosticId();

  final String code;
  final String userMessage;
  final bool retryable;
  final String diagnosticId;
  final Object? cause;

  static String _newDiagnosticId() {
    return DateTime.now().toUtc().microsecondsSinceEpoch.toString();
  }

  @override
  String toString() => userMessage;
}

class AppException implements Exception {
  AppException(this.error);

  final AppError error;

  @override
  String toString() => error.userMessage;
}
