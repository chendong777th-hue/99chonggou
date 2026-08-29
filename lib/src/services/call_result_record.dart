import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_bubble_direction.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

/// 通话结果来源，优先级：server > device > signaling。
/// 服务端（回调 / 最近通话）为权威源，可覆盖设备端本地推断。
enum CallResultSource { signaling, device, server }

enum CallSessionStatus { ringing, answered, rejected, canceled, missed, ended }

extension CallSessionStatusCodec on CallSessionStatus {
  String get wireName => name.toUpperCase();
  bool get isTerminal => index >= CallSessionStatus.rejected.index;
  int get rank {
    switch (this) {
      case CallSessionStatus.ringing:
        return 10;
      case CallSessionStatus.answered:
        return 20;
      case CallSessionStatus.rejected:
      case CallSessionStatus.canceled:
      case CallSessionStatus.missed:
        return 30;
      case CallSessionStatus.ended:
        return 40;
    }
  }

  static CallSessionStatus? parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'ringing':
      case 'calling':
        return CallSessionStatus.ringing;
      case 'answered':
      case 'connected':
        return CallSessionStatus.answered;
      case 'rejected':
      case 'reject':
        return CallSessionStatus.rejected;
      case 'canceled':
      case 'cancelled':
      case 'cancel':
        return CallSessionStatus.canceled;
      case 'missed':
      case 'timeout':
        return CallSessionStatus.missed;
      case 'ended':
      case 'hangup':
      case 'finished':
        return CallSessionStatus.ended;
      default:
        return null;
    }
  }
}

extension CallResultSourcePriority on CallResultSource {
  int get priority {
    switch (this) {
      case CallResultSource.server:
        return 2;
      case CallResultSource.device:
        return 1;
      case CallResultSource.signaling:
        return 0;
    }
  }
}

/// 单次通话结束后的权威结果（由 SDK onCallEnd 写入，展示层只读）。
class CallResultRecord {
  const CallResultRecord({
    required this.callId,
    required this.conversationId,
    required this.callerUserId,
    required this.operatorUserId,
    required this.peerUserId,
    required this.protocolType,
    required this.durationSec,
    required this.endedAtMs,
    this.isOutgoing,
    this.source = CallResultSource.device,
    this.mediaType = 'audio',
    this.status,
    this.roomName = '',
    this.startedAtMs = 0,
    this.acceptedAtMs = 0,
  });

  final String callId;
  final String conversationId;
  final String callerUserId;
  final String operatorUserId;
  final String peerUserId;
  final CallProtocolType protocolType;
  final int durationSec;
  final int endedAtMs;
  final bool? isOutgoing;
  final CallResultSource source;

  /// `audio` | `video` — used when rehydrating chat bubbles after restart.
  final String mediaType;
  final CallSessionStatus? status;
  final String roomName;
  final int startedAtMs;
  final int acceptedAtMs;

  CallSessionStatus get effectiveStatus =>
      status ?? _statusFromProtocol(protocolType);

  factory CallResultRecord.fromJson(Map<String, dynamic> json) {
    final protocolName = json['protocolType']?.toString().trim() ?? '';
    CallProtocolType protocolType = CallProtocolType.unknown;
    for (final value in CallProtocolType.values) {
      if (value.name == protocolName) {
        protocolType = value;
        break;
      }
    }
    if (protocolType == CallProtocolType.unknown) {
      protocolType = CallBubbleDirection.protocolTypeFromLocalReason(
            json['reasonName']?.toString() ?? '',
          ) ??
          CallProtocolType.cancel;
    }
    final media =
        (json['mediaType']?.toString() ?? 'audio').trim().toLowerCase();
    return CallResultRecord(
      callId: json['callId']?.toString().trim() ?? '',
      conversationId: json['conversationId']?.toString().trim() ?? '',
      callerUserId: CallUserId.normalizeCallUserId(
          json['callerUserId']?.toString() ?? ''),
      operatorUserId: CallUserId.normalizeCallUserId(
        json['operatorUserId']?.toString() ?? '',
      ),
      peerUserId:
          CallUserId.normalizeCallUserId(json['peerUserId']?.toString() ?? ''),
      protocolType: protocolType,
      durationSec: _asInt(json['durationSec']),
      endedAtMs: _asInt(json['endedAtMs']),
      isOutgoing: json['isOutgoing'] as bool?,
      source: _sourceFromName(json['source']?.toString()),
      mediaType: media == 'video' ? 'video' : 'audio',
      status: CallSessionStatusCodec.parse(json['status']) ??
          CallSessionStatusCodec.parse(json['phase']),
      roomName: json['roomName']?.toString() ?? '',
      startedAtMs: _asInt(json['startedAtMs'] ?? json['startedAt']),
      acceptedAtMs: _asInt(json['acceptedAtMs'] ?? json['acceptedAt']),
    );
  }

  /// 由服务端 result 字段（answered/missed/rejected/canceled/busy/failed）构建权威记录。
  factory CallResultRecord.fromServer({
    required String callId,
    required String conversationId,
    required String callerUserId,
    required String operatorUserId,
    required String peerUserId,
    required String result,
    required int durationSec,
    required int occurredAtMs,
    bool? isOutgoing,
    String mediaType = 'audio',
    CallSessionStatus? status,
    String roomName = '',
    int startedAtMs = 0,
    int acceptedAtMs = 0,
  }) {
    final media = mediaType.trim().toLowerCase();
    return CallResultRecord(
      callId: callId.trim(),
      conversationId: conversationId.trim(),
      callerUserId: CallUserId.normalizeCallUserId(callerUserId),
      operatorUserId: CallUserId.normalizeCallUserId(operatorUserId),
      peerUserId: CallUserId.normalizeCallUserId(peerUserId),
      protocolType: protocolTypeFromServerResult(result),
      durationSec: durationSec < 0 ? 0 : durationSec,
      endedAtMs: occurredAtMs > 0
          ? occurredAtMs
          : DateTime.now().millisecondsSinceEpoch,
      isOutgoing: isOutgoing,
      source: CallResultSource.server,
      mediaType: media == 'video' ? 'video' : 'audio',
      status: status ?? _statusFromServerResult(result),
      roomName: roomName,
      startedAtMs: startedAtMs,
      acceptedAtMs: acceptedAtMs,
    );
  }

  /// 服务端 result → 客户端展示用 protocolType。
  static CallProtocolType protocolTypeFromServerResult(String result) {
    switch (result.trim().toLowerCase()) {
      case 'answered':
        return CallProtocolType.hangup;
      case 'rejected':
        return CallProtocolType.reject;
      case 'canceled':
      case 'cancelled':
        return CallProtocolType.cancel;
      case 'busy':
        return CallProtocolType.lineBusy;
      case 'missed':
      case 'failed':
        return CallProtocolType.timeout;
      default:
        return CallProtocolType.unknown;
    }
  }

  static CallResultSource _sourceFromName(String? raw) {
    switch (raw?.trim()) {
      case 'server':
        return CallResultSource.server;
      case 'signaling':
        return CallResultSource.signaling;
      case 'device':
      default:
        return CallResultSource.device;
    }
  }

  factory CallResultRecord.fromCallEnd({
    required String callId,
    required String conversationId,
    required String callerUserId,
    required String operatorUserId,
    required String peerUserId,
    required String reasonName,
    required int durationSec,
    bool? isOutgoing,
    int? endedAtMs,
  }) {
    return CallResultRecord(
      callId: callId.trim(),
      conversationId: conversationId.trim(),
      callerUserId: CallUserId.normalizeCallUserId(callerUserId),
      operatorUserId: CallUserId.normalizeCallUserId(operatorUserId),
      peerUserId: CallUserId.normalizeCallUserId(peerUserId),
      protocolType:
          CallBubbleDirection.protocolTypeFromLocalReason(reasonName) ??
              CallProtocolType.cancel,
      durationSec: durationSec < 0 ? 0 : durationSec,
      endedAtMs: endedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      isOutgoing: isOutgoing,
      status: CallSessionStatusCodec.parse(reasonName),
    );
  }

  factory CallResultRecord.fromSignaling({
    required String callId,
    required String action,
    String conversationId = '',
    String callerUserId = '',
    String calleeUserId = '',
    String peerUserId = '',
    String roomName = '',
    String mediaType = 'audio',
    bool? isOutgoing,
    int occurredAtMs = 0,
  }) {
    final status = _statusFromAction(action);
    final protocol = protocolTypeFromStatus(status);
    final eventAt =
        occurredAtMs > 0 ? occurredAtMs : DateTime.now().millisecondsSinceEpoch;
    return CallResultRecord(
      callId: callId.trim(),
      conversationId: conversationId.trim(),
      callerUserId: CallUserId.normalizeCallUserId(callerUserId),
      operatorUserId: '',
      peerUserId: CallUserId.normalizeCallUserId(peerUserId),
      protocolType: protocol,
      durationSec: 0,
      endedAtMs: status.isTerminal ? eventAt : 0,
      isOutgoing: isOutgoing,
      source: CallResultSource.signaling,
      mediaType: mediaType.trim().toLowerCase() == 'video' ? 'video' : 'audio',
      status: status,
      roomName: roomName.trim(),
      startedAtMs: status == CallSessionStatus.ringing ? eventAt : 0,
      acceptedAtMs: status == CallSessionStatus.answered ? eventAt : 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'callId': callId,
        'conversationId': conversationId,
        'callerUserId': callerUserId,
        'operatorUserId': operatorUserId,
        'peerUserId': peerUserId,
        'protocolType': protocolType.name,
        'durationSec': durationSec,
        'endedAtMs': endedAtMs,
        if (isOutgoing != null) 'isOutgoing': isOutgoing,
        'source': source.name,
        'mediaType': mediaType == 'video' ? 'video' : 'audio',
        'status': effectiveStatus.wireName,
        if (roomName.isNotEmpty) 'roomName': roomName,
        if (startedAtMs > 0) 'startedAtMs': startedAtMs,
        if (acceptedAtMs > 0) 'acceptedAtMs': acceptedAtMs,
      };

  static int _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  static CallSessionStatus _statusFromServerResult(String result) {
    if (result.trim().toLowerCase() == 'answered') {
      return CallSessionStatus.ended;
    }
    return CallSessionStatusCodec.parse(result) ?? CallSessionStatus.ended;
  }

  static CallSessionStatus _statusFromAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'invite':
        return CallSessionStatus.ringing;
      case 'accept':
        return CallSessionStatus.answered;
      case 'reject':
        return CallSessionStatus.rejected;
      case 'cancel':
        return CallSessionStatus.canceled;
      case 'timeout':
        return CallSessionStatus.missed;
      case 'hangup':
      case 'answered_elsewhere':
      default:
        return CallSessionStatus.ended;
    }
  }

  static CallProtocolType protocolTypeFromStatus(CallSessionStatus status) {
    switch (status) {
      case CallSessionStatus.ringing:
        return CallProtocolType.send;
      case CallSessionStatus.answered:
        return CallProtocolType.accept;
      case CallSessionStatus.rejected:
        return CallProtocolType.reject;
      case CallSessionStatus.canceled:
        return CallProtocolType.cancel;
      case CallSessionStatus.missed:
        return CallProtocolType.timeout;
      case CallSessionStatus.ended:
        return CallProtocolType.hangup;
    }
  }

  static CallSessionStatus _statusFromProtocol(CallProtocolType protocol) {
    switch (protocol) {
      case CallProtocolType.send:
        return CallSessionStatus.ringing;
      case CallProtocolType.accept:
        return CallSessionStatus.answered;
      case CallProtocolType.reject:
        return CallSessionStatus.rejected;
      case CallProtocolType.cancel:
        return CallSessionStatus.canceled;
      case CallProtocolType.timeout:
        return CallSessionStatus.missed;
      default:
        return CallSessionStatus.ended;
    }
  }
}
