import 'dart:convert';

/// TCP / Push `group_changed` 成员变动事件元数据（`changeEventId` / `occurredAt`）。
class GroupChangeEventMetadata {
  const GroupChangeEventMetadata({
    this.changeEventId,
    this.occurredAtMs,
    this.timelineRank,
  });

  final String? changeEventId;
  final int? occurredAtMs;
  final int? timelineRank;

  bool get hasChangeEventId =>
      changeEventId != null && changeEventId!.trim().isNotEmpty;

  int? get occurredAtSec {
    final ms = occurredAtMs;
    if (ms == null || ms <= 0) {
      return null;
    }
    return normalizeEventTimestampSec(ms);
  }

  static GroupChangeEventMetadata fromMaps({
    Map<String, dynamic>? topLevel,
    Map<String, dynamic>? detail,
  }) {
    final root = topLevel ?? const <String, dynamic>{};
    final nested = detail ?? const <String, dynamic>{};
    final changeEventId = _readString(root, const [
      'changeEventId',
      'change_event_id',
    ]);
    final occurredAtMs = _readTimestampMs(root, const [
          'occurredAt',
          'occurred_at',
        ]) ??
        _readTimestampMs(nested, const [
          'occurredAt',
          'occurred_at',
          'updatedAt',
          'updated_at',
        ]);
    final timelineRank = _readInt(root, const [
          'timelineRank',
          'timeline_rank',
        ]) ??
        _readInt(nested, const [
          'timelineRank',
          'timeline_rank',
        ]);
    return GroupChangeEventMetadata(
      changeEventId: changeEventId,
      occurredAtMs: occurredAtMs,
      timelineRank: timelineRank,
    );
  }

  static Map<String, dynamic> normalizePushPayload(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    out['memberUserIds'] = _decodeJsonValue(out['memberUserIds']);
    out['detail'] = _decodeJsonValue(out['detail']);
    final detail = out['detail'];
    if (detail is Map) {
      out['detail'] = Map<String, dynamic>.from(detail);
    }
    final members = out['memberUserIds'];
    if (members is List) {
      out['memberUserIds'] = members
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
    return out;
  }

  static int normalizeEventTimestampSec(int raw) {
    if (raw >= 1000000000000) {
      return raw ~/ 1000;
    }
    if (raw >= 1000000000) {
      return raw;
    }
    return (raw / 1000).ceil();
  }

  static int defaultTimelineRankForAction(String action) {
    switch (action.trim().toLowerCase()) {
      case 'member_added':
        return 30;
      case 'member_removed':
      case 'member_left':
        return 40;
      case 'member_muted':
      case 'member_unmuted':
      case 'group_mute_all_changed':
      case 'group_mute_all_on':
      case 'group_mute_all_off':
      case 'member_role_changed':
      case 'member_set_admin':
      case 'member_cancel_admin':
      case 'group_name_changed':
      case 'group_avatar_changed':
      case 'group_notice_changed':
        return 45;
      default:
        return 50;
    }
  }

  static int? readTimelineRankFromMessageLocalData(String? raw) {
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) {
        return null;
      }
      final rank = decoded['timelineRank'];
      if (rank is num) {
        return rank.toInt();
      }
    } catch (_) {}
    return null;
  }

  static int messageTimelineSortRank({
    required String? localCustomData,
    int fallback = 50,
  }) {
    return readTimelineRankFromMessageLocalData(localCustomData) ?? fallback;
  }

  static Object? _decodeJsonValue(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return value;
      }
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  static String? _readString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _parseInt(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static int? _readTimestampMs(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _parseInt(value);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return null;
  }

  static int? _parseInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString().trim());
  }
}
