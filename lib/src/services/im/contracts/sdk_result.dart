enum SdkResultStatus { success, failure, outcomeUnknown }

enum SdkErrorKind {
  none,
  invalidArgument,
  unauthenticated,
  permissionDenied,
  network,
  timeout,
  rateLimited,
  notFound,
  unsupported,
  sdk,
  unknown,
}

/// Typed result boundary. Business code branches on [status]/[errorKind],
/// never on localized SDK error text.
class SdkResult<T> {
  const SdkResult._({
    required this.status,
    required this.errorKind,
    required this.code,
    required this.resultDesc,
    required this.data,
    required this.requestId,
  });

  factory SdkResult.success({
    T? data,
    int? code,
    String? resultDesc,
    String? requestId,
  }) =>
      SdkResult._(
        status: SdkResultStatus.success,
        errorKind: SdkErrorKind.none,
        code: code,
        resultDesc: resultDesc,
        data: data,
        requestId: _optional(requestId),
      );

  factory SdkResult.failure({
    required SdkErrorKind errorKind,
    int? code,
    String? resultDesc,
    String? requestId,
  }) {
    if (errorKind == SdkErrorKind.none) {
      throw ArgumentError('failure requires a non-none errorKind');
    }
    return SdkResult._(
      status: SdkResultStatus.failure,
      errorKind: errorKind,
      code: code,
      resultDesc: resultDesc,
      data: null,
      requestId: _optional(requestId),
    );
  }

  factory SdkResult.outcomeUnknown({
    String? resultDesc,
    int? code,
    String? requestId,
  }) =>
      SdkResult._(
        status: SdkResultStatus.outcomeUnknown,
        errorKind: SdkErrorKind.unknown,
        code: code,
        resultDesc: resultDesc,
        data: null,
        requestId: _optional(requestId),
      );

  final SdkResultStatus status;
  final SdkErrorKind errorKind;
  final int? code;
  final String? resultDesc;
  final T? data;
  final String? requestId;

  bool get isSuccess => status == SdkResultStatus.success;
  bool get isFailure => status == SdkResultStatus.failure;
  bool get isOutcomeUnknown => status == SdkResultStatus.outcomeUnknown;

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        'status': status.name,
        'errorKind': errorKind.name,
        'code': code,
        'resultDesc': resultDesc,
        'requestId': requestId,
      };
}

String? _optional(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}
