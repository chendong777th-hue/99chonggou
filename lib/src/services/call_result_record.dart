import 'package:tencent_cloud_chat_demo/src/utils/call_user_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/call_bubble_direction.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

/// 通话结果来源，优先级：server > device > signaling。
/// 服务端（回调 / 最近通话）为权威源，可覆盖设备端本地推断。
enum CallResultSource { signaling, device, server }

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
    final media = (json['mediaType']?.toString() ?? 'audio').trim().toLowerCase();
    return CallResultRecord(
      callId: json['callId']?.toString().trim() ?? '',
      conversationId: json['conversationId']?.toString().trim() ?? '',
      callerUserId:
          CallUserId.normalizeCallUserId(json['callerUserId']?.toString() ?? ''),
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
      protocolType: CallBubbleDirection.protocolTypeFromLocalReason(reasonName) ??
          CallProtocolType.cancel,
      durationSec: durationSec < 0 ? 0 : durationSec,
      endedAtMs: endedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      isOutgoing: isOutgoing,
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
      };

  static int _asInt(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
