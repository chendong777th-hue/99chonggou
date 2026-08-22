import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_system_notice_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

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
  Future<void>? _loading;

  int get readWatermarkMs => _readWatermarkMs;

  int get unreadCount => computeGroupNoticeUnreadCount(
        applications: GroupJoinApplicationService.instance.applications,
        notices: GroupSystemNoticeService.instance.notices,
        readWatermarkMs: _readWatermarkMs,
      );

  Future<void> ensureLoaded() {
    return _loading ??= _loadReadWatermark();
  }

  Future<void> _loadReadWatermark() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _readWatermarkMs = prefs.getInt(_storageKey()) ?? 0;
      _loaded = true;
      _mergeServerReadWatermark(notify: false);
      notifyListeners();
    } finally {
      _loading = null;
    }
  }

  void _onSourceDataChanged() {
    GroupNoticeFeedLog.log('unread_source_changed', extras: {
      'apps': GroupJoinApplicationService.instance.applications.length,
      'notices': GroupSystemNoticeService.instance.notices.length,
      'watermark': _readWatermarkMs,
      'loaded': _loaded,
    });
    _mergeServerReadWatermark(notify: true);
  }

  void _mergeServerReadWatermark({required bool notify}) {
    if (!_loaded) {
      return;
    }
    final serverRead = GroupSystemNoticeService.instance.lastReadAtMs;
    if (serverRead != null && serverRead > _readWatermarkMs) {
      _readWatermarkMs = serverRead;
      unawaited(_persistReadWatermark());
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
    await ensureLoaded();
    final ms = readAtMs ?? DateTime.now().millisecondsSinceEpoch;
    if (ms <= _readWatermarkMs) {
      return;
    }
    _readWatermarkMs = ms;
    await _persistReadWatermark();
    unawaited(GroupSystemNoticeService.instance.markRead(ms));
    notifyListeners();
  }

  Future<void> markReadUpToLatest() async {
    await ensureLoaded();
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
    _loading = null;
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

  String _storageKey() {
    final userId = ChatIdFormat.rawUserUid(
      serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ?? '',
    );
    if (userId.isEmpty) {
      return groupNoticeLastReadTimestampStorageKey;
    }
    return '${groupNoticeLastReadTimestampStorageKey}_$userId';
  }

  Future<void> _persistReadWatermark() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storageKey(), _readWatermarkMs);
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
