import 'dart:convert';

import 'account_scoped_conversation_key.dart';

const String kOutgoingIdentitySchema = '99chat.outgoing.v1';

enum OutgoingMessageKind { text, image, video, audio, custom }

/// Cross-process and cross-platform identity for one outbound operation.
///
/// Only [toCloudCustomData] belongs in Tencent's cloudCustomData. Local file
/// paths, credentials, message bodies and page objects are deliberately absent.
class OutgoingIdentityContract {
  factory OutgoingIdentityContract({
    required AccountScopedConversationKey scope,
    required String operationId,
    required String clientCorrelationId,
    required OutgoingMessageKind messageKind,
    required String payloadFingerprint,
    required int createdAtMs,
    String? sdkLocalId,
    String? serverMsgId,
  }) {
    final operation = _requiredId(operationId, 'operationId');
    final correlation = _requiredId(
      clientCorrelationId,
      'clientCorrelationId',
    );
    final fingerprint = _requiredId(payloadFingerprint, 'payloadFingerprint');
    if (createdAtMs < 0) {
      throw ArgumentError.value(
          createdAtMs, 'createdAtMs', 'must be non-negative');
    }
    return OutgoingIdentityContract._(
      scope: scope,
      operationId: operation,
      clientCorrelationId: correlation,
      messageKind: messageKind,
      payloadFingerprint: fingerprint,
      createdAtMs: createdAtMs,
      sdkLocalId: _optionalId(sdkLocalId),
      serverMsgId: _optionalId(serverMsgId),
    );
  }

  const OutgoingIdentityContract._({
    required this.scope,
    required this.operationId,
    required this.clientCorrelationId,
    required this.messageKind,
    required this.payloadFingerprint,
    required this.createdAtMs,
    required this.sdkLocalId,
    required this.serverMsgId,
  });

  final AccountScopedConversationKey scope;
  final String operationId;
  final String clientCorrelationId;
  final OutgoingMessageKind messageKind;
  final String payloadFingerprint;
  final int createdAtMs;
  final String? sdkLocalId;
  final String? serverMsgId;

  Map<String, Object?> toCloudCustomData({String? businessCloudCustomData}) {
    final data = <String, Object?>{
      'schema': kOutgoingIdentitySchema,
      'operationId': operationId,
      'clientCorrelationId': clientCorrelationId,
      'messageKind': messageKind.name,
      'payloadFingerprint': payloadFingerprint,
      'createdAtMs': createdAtMs,
    };
    final business = businessCloudCustomData?.trim() ?? '';
    if (business.isNotEmpty) {
      // Preserve existing application metadata under a versioned outer
      // envelope instead of overwriting it with the correlation contract.
      data['business'] = business;
    }
    return data;
  }

  String encodeCloudCustomData({String? businessCloudCustomData}) => jsonEncode(
        toCloudCustomData(businessCloudCustomData: businessCloudCustomData),
      );

  static OutgoingIdentityContract? fromCloudCustomData(
    String? raw, {
    required AccountScopedConversationKey scope,
  }) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      if (map['schema'] != kOutgoingIdentitySchema) return null;
      final kindName = map['messageKind'] ?? map['messageType'];
      final kind = OutgoingMessageKind.values.firstWhere(
        (value) => value.name == kindName?.toString(),
        orElse: () => throw const FormatException('unknown message kind'),
      );
      final createdAtMs = _asInt(map['createdAtMs']);
      if (createdAtMs == null) return null;
      return OutgoingIdentityContract(
        scope: scope,
        operationId: map['operationId']?.toString() ?? '',
        clientCorrelationId: map['clientCorrelationId']?.toString() ?? '',
        messageKind: kind,
        payloadFingerprint: map['payloadFingerprint']?.toString() ?? '',
        createdAtMs: createdAtMs,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  OutgoingIdentityContract withFormalIdentity({
    String? sdkLocalId,
    String? serverMsgId,
  }) {
    return OutgoingIdentityContract(
      scope: scope,
      operationId: operationId,
      clientCorrelationId: clientCorrelationId,
      messageKind: messageKind,
      payloadFingerprint: payloadFingerprint,
      createdAtMs: createdAtMs,
      sdkLocalId: sdkLocalId ?? this.sdkLocalId,
      serverMsgId: serverMsgId ?? this.serverMsgId,
    );
  }

  bool matchesCandidate({
    required AccountScopedConversationKey candidateScope,
    required OutgoingMessageKind candidateKind,
    required String candidatePayloadFingerprint,
    String? candidateCorrelationId,
  }) {
    return scope == candidateScope &&
        messageKind == candidateKind &&
        payloadFingerprint == candidatePayloadFingerprint &&
        (candidateCorrelationId == null ||
            candidateCorrelationId == clientCorrelationId);
  }

  Map<String, Object?> toMetadataJson() => <String, Object?>{
        ...toCloudCustomData(),
        'ownerUserId': scope.ownerUserId,
        'conversationKey': scope.canonicalConversationId,
        'sdkLocalId': sdkLocalId,
        'serverMsgId': serverMsgId,
      };
}

String _requiredId(String value, String name) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty');
  }
  return normalized;
}

String? _optionalId(String? value) {
  final normalized = value?.trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
