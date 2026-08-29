import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/utils/api_response_util.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';

import 'api_client.dart';

enum CallRecordFilter {
  all('all'),
  missed('missed');

  const CallRecordFilter(this.value);
  final String value;
}

class CallRecordItem {
  const CallRecordItem({
    required this.callId,
    required this.peerUserId,
    required this.peerName,
    required this.peerAvatar,
    required this.mediaType,
    required this.direction,
    required this.result,
    required this.durationSec,
    required this.occurredAt,
    this.callerUserId = '',
    this.calleeUserId = '',
    this.operatorUserId = '',
  });

  final String callId;
  final String peerUserId;
  final String peerName;
  final String peerAvatar;
  final String mediaType;
  final String direction;
  final String result;
  final int durationSec;
  final int occurredAt;

  /// 权威主叫（原始 userId），供聊天气泡判断谁发起。
  final String callerUserId;

  /// 权威被叫（原始 userId）。
  final String calleeUserId;

  /// 结束操作者（原始 userId）；answered / failed 等无明确操作者时为空。
  final String operatorUserId;

  bool get isOutgoing => direction.trim().toLowerCase() == 'outgoing';

  /// 转成权威 CallResultRecord（source=server），供聊天气泡消费。
  CallResultRecord? toCallResultRecord() {
    final id = callId.trim();
    if (id.isEmpty) {
      return null;
    }
    final protocol = CallResultRecord.protocolTypeFromServerResult(result);
    if (protocol == CallProtocolType.unknown) {
      return null;
    }
    final peer = peerUserId.trim().isNotEmpty
        ? peerUserId.trim()
        : (isOutgoing
            ? calleeUserId.trim()
            : (direction.trim().toLowerCase() == 'incoming'
                ? callerUserId.trim()
                : ''));
    return CallResultRecord.fromServer(
      callId: id,
      conversationId: peer.isEmpty ? '' : 'c2c_$peer',
      callerUserId: callerUserId,
      operatorUserId: operatorUserId,
      peerUserId: peer,
      result: result,
      durationSec: durationSec,
      occurredAtMs: occurredAt,
      isOutgoing: direction.trim().isEmpty ? null : isOutgoing,
      mediaType: mediaType,
    );
  }

  factory CallRecordItem.fromJson(Map<String, dynamic> json) {
    return CallRecordItem(
      callId: _asStringAny(json, const [
        'callId',
        'callID',
        'call_id',
        'id',
        'inviteId',
        'inviteID',
      ]),
      peerUserId: _asStringAny(json, const [
        'peerUserId',
        'peerUserID',
        'peerId',
        'peer_id',
        'userId',
        'userID',
        'targetUserId',
        'oppositeUserId',
      ]),
      peerName: _asStringAny(json, const [
        'peerName',
        'peerNickname',
        'peerNickName',
        'nickname',
        'nickName',
        'name',
      ]),
      peerAvatar: _asStringAny(json, const [
        'peerAvatar',
        'peerFaceUrl',
        'peerFaceURL',
        'faceUrl',
        'avatar',
        'avatarUrl',
      ]),
      mediaType: _asStringAny(json, const [
        'mediaType',
        'callMediaType',
        'type',
      ]),
      direction: _asStringAny(json, const [
        'direction',
        'callDirection',
        'resultType',
      ]),
      result: _asStringAny(json, const [
        'result',
        'callResult',
        'reason',
        'status',
      ]),
      durationSec: _asIntAny(json, const [
        'durationSec',
        'durationSeconds',
        'duration',
        'totalTime',
        'callDuration',
      ]),
      occurredAt: _asTimestampMsAny(json, const [
        'occurredAt',
        'timestamp',
        'time',
        'createdAt',
        'createTime',
        'updatedAt',
        'startTime',
        'beginTime',
      ]),
      callerUserId: _asStringAny(json, const [
        'callerUserId',
        'callerUserID',
        'caller_user_id',
        'callerId',
      ]),
      calleeUserId: _asStringAny(json, const [
        'calleeUserId',
        'calleeUserID',
        'callee_user_id',
        'calleeId',
      ]),
      operatorUserId: _asStringAny(json, const [
        'operatorUserId',
        'operatorUserID',
        'operator_user_id',
        'operatorId',
      ]),
    );
  }

  factory CallRecordItem.fromRealtimeEvent(FriendRealtimeEvent event) {
    return CallRecordItem.fromJson(<String, dynamic>{
      'callId': event.callId,
      'peerUserId': event.peerUserId,
      'peerName': event.peerNickname,
      'peerAvatar': event.peerAvatarUrl,
      'mediaType': event.mediaType,
      'direction': event.direction,
      'result': event.result,
      'durationSec': event.durationSec,
      'occurredAt': event.occurredAt,
      'callerUserId': event.callerUserId,
      'operatorUserId': event.operatorUserId,
    });
  }
}

class CallRecordPageResult {
  const CallRecordPageResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  final List<CallRecordItem> items;
  final int page;
  final int pageSize;
  final int total;

  factory CallRecordPageResult.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    final map = payload is Map<String, dynamic>
        ? payload
        : payload is Map
            ? Map<String, dynamic>.from(payload)
            : json;
    final rawItems = extractApiList(map, listKeys: const [
      'items',
      'records',
      'list',
      'content',
    ]);
    final items = rawItems
        .whereType<Map>()
        .map((e) => CallRecordItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return CallRecordPageResult(
      items: items,
      page: _asIntAny(map, const ['page', 'pageIndex', 'current']),
      pageSize: _asIntAny(map, const ['pageSize', 'size', 'limit']),
      total: _asIntAny(map, const ['total', 'totalCount', 'count']),
    );
  }
}

class DeleteCallRecordResult {
  const DeleteCallRecordResult({
    required this.ok,
    this.deleted,
  });

  final bool ok;
  final int? deleted;

  factory DeleteCallRecordResult.fromJson(Map<String, dynamic> json) {
    final payload = unwrapApiPayload(json);
    final map = payload is Map<String, dynamic>
        ? payload
        : payload is Map
            ? Map<String, dynamic>.from(payload)
            : json;
    return DeleteCallRecordResult(
      ok: map['ok'] as bool? ?? json['code'] == 0,
      deleted: map['deleted'] == null ? null : _asInt(map['deleted']),
    );
  }
}

class CallRecordApi {
  CallRecordApi._();

  static final CallRecordApi instance = CallRecordApi._();

  Dio get _dio => ApiClient.instance.dio;

  Future<CallRecordPageResult> fetchRecent({
    CallRecordFilter filter = CallRecordFilter.all,
    int page = 0,
    int pageSize = 20,
  }) async {
    final identity = SessionIdentityService.instance.capture();
    final res = await _dio.get(
      '/calls/recent',
      queryParameters: {
        'filter': filter.value,
        'page': page,
        'pageSize': pageSize > 50 ? 50 : pageSize,
      },
    );
    final raw = res.data;
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    final result = CallRecordPageResult.fromJson(map);
    // Best-effort: seed chat-bubble canonical cache from recent page.
    if (!_isCurrent(identity)) {
      return result;
    }
    for (final item in result.items) {
      final record = item.toCallResultRecord();
      if (record != null) {
        CallResultRepository.instance.save(record, identity: identity);
      }
    }
    return result;
  }

  bool _isCurrent(SessionIdentity identity) {
    if (identity.ownerUserId.isEmpty) {
      return true;
    }
    return SessionIdentityService.instance.isCurrent(identity);
  }

  /// GET /calls/{callId} —— 按 callId 拉取单条权威通话结果。
  /// 记录不存在 / 已软删返回 null（404 CALL_RECORD_NOT_FOUND）。
  Future<CallRecordItem?> fetchOne(String callId) async {
    final id = callId.trim();
    if (id.isEmpty) {
      return null;
    }
    try {
      final res = await _dio.get('/calls/${Uri.encodeComponent(id)}');
      final raw = res.data;
      final map = raw is Map<String, dynamic>
          ? raw
          : raw is Map
              ? Map<String, dynamic>.from(raw)
              : <String, dynamic>{};
      final payload = unwrapApiPayload(map);
      final data = payload is Map<String, dynamic>
          ? payload
          : payload is Map
              ? Map<String, dynamic>.from(payload)
              : map;
      final item = CallRecordItem.fromJson(data);
      return item.callId.isEmpty ? null : item;
    } on DioError catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<DeleteCallRecordResult> deleteOne(String callId) async {
    final res =
        await _dio.delete('/calls/recent/${Uri.encodeComponent(callId)}');
    final raw = res.data;
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return DeleteCallRecordResult.fromJson(map);
  }

  Future<DeleteCallRecordResult> deleteBatch(CallRecordFilter filter) async {
    final res = await _dio.delete(
      '/calls/recent',
      queryParameters: {'filter': filter.value},
    );
    final raw = res.data;
    final map = raw is Map<String, dynamic>
        ? raw
        : raw is Map
            ? Map<String, dynamic>.from(raw)
            : <String, dynamic>{};
    return DeleteCallRecordResult.fromJson(map);
  }
}

int _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

String _asStringAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
  }
  return '';
}

int _asIntAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _asInt(json[key]);
    if (value != 0) {
      return value;
    }
  }
  return 0;
}

int _asTimestampMsAny(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    final timestamp = _asTimestampMs(value);
    if (timestamp > 0) {
      return timestamp;
    }
  }
  return 0;
}

int _asTimestampMs(Object? raw) {
  if (raw == null) {
    return 0;
  }
  if (raw is int) {
    return raw > 0 && raw < 1000000000000 ? raw * 1000 : raw;
  }
  if (raw is num) {
    final value = raw.toInt();
    return value > 0 && value < 1000000000000 ? value * 1000 : value;
  }
  final text = raw.toString().trim();
  if (text.isEmpty) {
    return 0;
  }
  final numeric = int.tryParse(text);
  if (numeric != null) {
    return numeric > 0 && numeric < 1000000000000 ? numeric * 1000 : numeric;
  }
  return DateTime.tryParse(text)?.millisecondsSinceEpoch ?? 0;
}
