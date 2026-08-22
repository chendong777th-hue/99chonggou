import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/models/group_live_models.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// IM custom message helpers for group live (`businessID` prefix `group_live_*` / `live_tip`).
class GroupLiveMessageIds {
  GroupLiveMessageIds._();

  static const scheduled = 'group_live_scheduled';
  static const scheduleUpdated = 'group_live_schedule_updated';
  static const ready = 'group_live_ready';
  static const started = 'group_live_started';
  static const ended = 'group_live_ended';
  static const tip = 'live_tip';

  static const allCardIds = <String>{
    scheduled,
    scheduleUpdated,
    ready,
    started,
    ended,
  };
}

class GroupLiveImPayload {
  const GroupLiveImPayload({
    required this.businessId,
    required this.raw,
    this.liveSessionId = '',
    this.groupId = '',
    this.roomName = '',
    this.anchorUserId = '',
    this.status = GroupLiveStatus.unknown,
    this.scheduledStartAt,
    this.endReason,
    this.fromUserId = '',
    this.currency = '',
    this.amount = 0,
    this.memo = '',
  });

  final String businessId;
  final Map<String, dynamic> raw;
  final String liveSessionId;
  final String groupId;
  final String roomName;
  final String anchorUserId;
  final GroupLiveStatus status;
  final DateTime? scheduledStartAt;
  final GroupLiveEndReason? endReason;
  final String fromUserId;
  final String currency;
  final int amount;
  final String memo;

  bool get isCard => GroupLiveMessageIds.allCardIds.contains(businessId);

  bool get isTip => businessId == GroupLiveMessageIds.tip;

  factory GroupLiveImPayload.fromMap(Map<String, dynamic> map) {
    final businessId = map['businessID']?.toString().trim() ?? '';
    return GroupLiveImPayload(
      businessId: businessId,
      raw: map,
      liveSessionId: _str(map, const ['liveSessionId']),
      groupId: _str(map, const ['groupId']),
      roomName: _str(map, const ['roomName']),
      anchorUserId: _str(map, const ['anchorUserId']),
      status: GroupLiveStatus.parse(_str(map, const ['status'])),
      scheduledStartAt: _date(map['scheduledStartAt']),
      endReason: map['endReason'] == null
          ? null
          : GroupLiveEndReason.parse(map['endReason']?.toString()),
      fromUserId: _str(map, const ['fromUserId']),
      currency: _str(map, const ['currency']),
      amount: _int(map, const ['amount']),
      memo: _str(map, const ['memo']),
    );
  }
}

GroupLiveImPayload? parseGroupLivePayload(V2TimMessage message) {
  return parseGroupLivePayloadFromRaw(message.customElem?.data);
}

GroupLiveImPayload? parseGroupLivePayloadFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(decoded);
    final businessId = map['businessID']?.toString().trim() ?? '';
    if (businessId.isEmpty) {
      return null;
    }
    if (!GroupLiveMessageIds.allCardIds.contains(businessId) &&
        businessId != GroupLiveMessageIds.tip) {
      return null;
    }
    return GroupLiveImPayload.fromMap(map);
  } catch (_) {
    return null;
  }
}

bool isGroupLiveCardMessage(V2TimMessage message) {
  final payload = parseGroupLivePayload(message);
  return payload?.isCard ?? false;
}

String _str(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  return '';
}

int _int(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

DateTime? _date(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty || text == 'null') return null;
  return DateTime.tryParse(text);
}
