import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

const String groupNoticeLastReadTimestampStorageKey =
    'groupNoticeLastReadTimestamp';

/// 群通知未读计数（审批 + 系统通知），随 REST/TCP 数据变更实时更新。
class GroupNoticeUnreadService extends ChangeNotifier {
  GroupNoticeUnreadService._() {
    GroupJoinApplicationService.instance.addListener(_onSourceDataChanged);
    GroupSystemNoticeService.instance.addListener(_onSourceDataChanged);
  }

  static final GroupNoticeUnreadService instance = GroupNoticeUnreadService._();

  int _readWatermarkMs = 0;
  bool _loaded = false;
  String _loadedOwner = '';
  final Map<String, Future<void>> _loadingByOwner = <String, Future<void>>{};

  int get readWatermarkMs => _readWatermarkMs;

  int get unreadCount => computeGroupNoticeUnreadCount(
        applications: GroupJoinApplicationService.instance.applications,
        notices: GroupSystemNoticeService.instance.notices,
        readWatermarkMs: _readWatermarkMs,
      );

  Future<void> ensureLoaded() {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return Future<void>.value();
    }
    if (_loaded && _loadedOwner == identity.ownerUserId) {
      return Future<void>.value();
    }
    return _loadingByOwner[identity.ownerUserId] ??=
        _loadReadWatermark(identity);
  }

  Future<void> _loadReadWatermark(SessionIdentity identity) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      _readWatermarkMs =
          prefs.getInt(_storageKeyForOwner(identity.ownerUserId)) ?? 0;
      _loaded = true;
      _loadedOwner = identity.ownerUserId;
      _mergeServerReadWatermark(notify: false, identity: identity);
      notifyListeners();
    } finally {
      _loadingByOwner.remove(identity.ownerUserId);
    }
  }

  void _onSourceDataChanged() {
    GroupNoticeFeedLog.log('unread_source_changed', extras: {
      'apps': GroupJoinApplicationService.instance.applications.length,
      'notices': GroupSystemNoticeService.instance.notices.length,
      'watermark': _readWatermarkMs,
      'loaded': _loaded,
    });
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    _mergeServerReadWatermark(notify: true, identity: identity);
  }

  void _mergeServerReadWatermark({
    required bool notify,
    required SessionIdentity identity,
  }) {
    if (!_loaded ||
        _loadedOwner != identity.ownerUserId ||
        !SessionIdentityService.instance.isCurrent(identity)) {
      return;
    }
    final serverRead = GroupSystemNoticeService.instance.lastReadAtMs;
    if (serverRead != null && serverRead > _readWatermarkMs) {
      _readWatermarkMs = serverRead;
      unawaited(_persistReadWatermark(identity));
      if (notify) {
        notifyListeners();
      }
      return;
    }
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> markRead({int? readAtMs}) async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    await ensureLoaded();
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) {
      return;
    }
    final ms = readAtMs ?? DateTime.now().millisecondsSinceEpoch;
    if (ms <= _readWatermarkMs) {
      return;
    }
    _readWatermarkMs = ms;
    await _persistReadWatermark(identity);
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    unawaited(GroupSystemNoticeService.instance.markRead(ms));
    notifyListeners();
  }

  Future<void> markReadUpToLatest() async {
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    await ensureLoaded();
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) {
      return;
    }
    final latestMs = latestGroupNoticeTimestampMs(
      GroupJoinApplicationService.instance.applications,
      GroupSystemNoticeService.instance.notices,
    );
    if (latestMs <= 0) {
      return;
    }
    await markRead(readAtMs: latestMs);
  }

  void clearSession() {
    _readWatermarkMs = 0;
    _loaded = false;
    _loadedOwner = '';
    _loadingByOwner.clear();
    notifyListeners();
  }

  /// 注销：删除该账号群通知已读水位 prefs，并卸内存。
  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    clearSession();
    if (owner.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${groupNoticeLastReadTimestampStorageKey}_$owner');
  }

  String _storageKeyForOwner(String userId) {
    final owner = ChatIdFormat.rawUserUid(userId);
    if (owner.isEmpty) {
      return groupNoticeLastReadTimestampStorageKey;
    }
    return '${groupNoticeLastReadTimestampStorageKey}_$owner';
  }

  Future<void> _persistReadWatermark(SessionIdentity identity) async {
    if (!SessionIdentityService.instance.isCurrent(identity) ||
        _loadedOwner != identity.ownerUserId) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!SessionIdentityService.instance.isCurrent(identity)) return;
    await prefs.setInt(
      _storageKeyForOwner(identity.ownerUserId),
      _readWatermarkMs,
    );
  }
}

int normalizeGroupNoticeTimestampMs(int? timestamp) {
  if (timestamp == null || timestamp <= 0) {
    return 0;
  }
  return timestamp < 1000000000000 ? timestamp * 1000 : timestamp;
}

int latestGroupNoticeTimestampMs(
  List<V2TimGroupApplication> applications,
  List<GroupSystemNoticeItem> notices,
) {
  var latest = 0;
  for (final item in applications) {
    final ms = normalizeGroupNoticeTimestampMs(item.addTime);
    if (ms > latest) {
      latest = ms;
    }
  }
  for (final item in notices) {
    final ms = normalizeGroupNoticeTimestampMs(item.timestamp);
    if (ms > latest) {
      latest = ms;
    }
  }
  return latest;
}

int computeGroupNoticeUnreadCount({
  required List<V2TimGroupApplication> applications,
  required List<GroupSystemNoticeItem> notices,
  required int readWatermarkMs,
}) {
  final applicationUnreadCount = applications.where((item) {
    return normalizeGroupNoticeTimestampMs(item.addTime) > readWatermarkMs;
  }).length;
  final systemUnreadCount = notices.where((item) {
    return normalizeGroupNoticeTimestampMs(item.timestamp) > readWatermarkMs;
  }).length;
  return applicationUnreadCount + systemUnreadCount;
}
