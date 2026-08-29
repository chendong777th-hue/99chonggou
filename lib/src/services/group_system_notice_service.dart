import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_notice_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_feed_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services_implements.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 群系统通知（设/撤管理员、转让群主），REST + TCP 驱动。
class GroupSystemNoticeService extends ChangeNotifier {
  GroupSystemNoticeService._();

  static final GroupSystemNoticeService instance = GroupSystemNoticeService._();

  static const int _maxDismissedKeys = 500;

  List<GroupSystemNoticeItem> _notices = const [];
  bool _loading = false;
  int? _lastReadAtMs;
  int _unreadCount = 0;
  Set<String> _dismissedNoticeIds = <String>{};
  bool _dismissedNoticeIdsLoaded = false;
  String _dismissedNoticeOwner = '';
  int _sessionClearGeneration = 0;

  List<GroupSystemNoticeItem> get notices =>
      List<GroupSystemNoticeItem>.unmodifiable(_notices);

  bool get isLoading => _loading;

  int? get lastReadAtMs => _lastReadAtMs;

  int get unreadCount => _unreadCount;

  Future<Set<String>> _loadDismissedNoticeIds({
    bool force = false,
    String? ownerUserId,
    SessionIdentity? identity,
    int? clearGeneration,
  }) async {
    final owner = ChatIdFormat.rawUserUid(
      ownerUserId ??
          serviceLocator<CoreServicesImpl>().loginUserInfo?.userID ??
          '',
    );
    if (_dismissedNoticeIdsLoaded && !force && _dismissedNoticeOwner == owner) {
      return _dismissedNoticeIds;
    }
    final prefs = await SharedPreferences.getInstance();
    if (identity != null &&
        !_isCurrentRefresh(
            identity, clearGeneration ?? _sessionClearGeneration)) {
      return _dismissedNoticeIds;
    }
    final stored =
        prefs.getStringList(_dismissedStorageKeyForOwner(owner)) ?? const [];
    _dismissedNoticeIds = stored
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    _dismissedNoticeIdsLoaded = true;
    _dismissedNoticeOwner = owner;
    return _dismissedNoticeIds;
  }

  String _dismissedStorageKeyForOwner(String owner) {
    if (owner.isEmpty) {
      return 'groupSystemNoticeDismissedIds';
    }
    return 'groupSystemNoticeDismissedIds_$owner';
  }

  Future<void> _saveDismissedNoticeIds(
    Set<String> ids, {
    required String ownerUserId,
    SessionIdentity? identity,
    int? clearGeneration,
  }) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty ||
        (identity != null &&
            !_isCurrentRefresh(
              identity,
              clearGeneration ?? _sessionClearGeneration,
            ))) {
      return;
    }
    final normalized = ids
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(_maxDismissedKeys)
        .toList(growable: false);
    _dismissedNoticeIds = normalized.toSet();
    _dismissedNoticeIdsLoaded = true;
    _dismissedNoticeOwner = owner;
    final prefs = await SharedPreferences.getInstance();
    if (identity != null &&
        !_isCurrentRefresh(
            identity, clearGeneration ?? _sessionClearGeneration)) {
      return;
    }
    await prefs.setStringList(_dismissedStorageKeyForOwner(owner), normalized);
  }

  bool _isDismissed(String noticeId) {
    final id = noticeId.trim();
    return id.isNotEmpty && _dismissedNoticeIds.contains(id);
  }

  List<GroupSystemNoticeItem> _filterDismissed(
    List<GroupSystemNoticeItem> notices,
  ) {
    if (_dismissedNoticeIds.isEmpty) {
      return notices;
    }
    return notices
        .where((item) => !_isDismissed(item.id))
        .toList(growable: false);
  }

  void _syncUnreadCount() {
    final watermark = _lastReadAtMs ?? 0;
    _unreadCount = _notices.where((item) => item.timestamp > watermark).length;
  }

  Future<void> refresh({bool force = false}) async {
    if (_loading && !force) {
      GroupNoticeFeedLog.log('service_refresh_skip', extras: {
        'force': force,
        'loading': _loading,
      });
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) {
      return;
    }
    final clearGeneration = _sessionClearGeneration;
    GroupNoticeFeedLog.log('service_refresh_begin', extras: {
      'force': force,
      'beforeCount': _notices.length,
    });
    _loading = true;
    notifyListeners();
    try {
      await _loadDismissedNoticeIds(ownerUserId: identity.ownerUserId);
      if (!_isCurrentRefresh(identity, clearGeneration)) {
        return;
      }
      final page = await GroupNoticeApi.instance.fetchMyGroupNotices(
        limit: 200,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) {
        return;
      }
      final next = _filterDismissed(
        page.items.map((item) => item.toUIKitNotice()).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp)),
      );
      final changed = !_sameNotices(_notices, next) ||
          _lastReadAtMs != page.lastReadAtMs ||
          _unreadCount != (page.unreadCount ?? _unreadCount);
      _notices = next;
      _lastReadAtMs = page.lastReadAtMs;
      if (page.unreadCount != null) {
        _unreadCount = page.unreadCount!;
      } else {
        _syncUnreadCount();
      }
      GroupNoticeFeedLog.log('service_refresh_done', extras: {
        'changed': changed,
        'count': _notices.length,
        'unread': _unreadCount,
        'lastReadAtMs': _lastReadAtMs,
      });
      if (changed) {
        notifyListeners();
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('GroupSystemNoticeService.refresh failed: $error\n$stack');
      }
      GroupNoticeFeedLog.log('service_refresh_failed', extras: {
        'error': '$error',
      });
    } finally {
      if (_isCurrentRefresh(identity, clearGeneration)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentRefresh(SessionIdentity identity, int clearGeneration) {
    return clearGeneration == _sessionClearGeneration &&
        SessionIdentityService.instance.isCurrent(identity);
  }

  void upsertFromDetail(Map<String, dynamic>? detail) {
    final record = GroupNoticeRecord.fromDetail(detail);
    if (record == null) {
      GroupNoticeFeedLog.log('service_upsert_detail_null', extras: {
        'detailKeys': detail?.keys.join(','),
      });
      return;
    }
    upsertNotice(record.toUIKitNotice());
  }

  void upsertNotice(GroupSystemNoticeItem notice) {
    if (notice.id.isEmpty || notice.groupID.isEmpty) {
      GroupNoticeFeedLog.log('service_upsert_skip_empty', extras: {
        'id': notice.id,
        'groupID': notice.groupID,
      });
      return;
    }
    if (_isDismissed(notice.id)) {
      GroupNoticeFeedLog.log('service_upsert_skip_dismissed', extras: {
        'id': notice.id,
        'groupID': notice.groupID,
      });
      return;
    }
    final before = _notices.length;
    final next = List<GroupSystemNoticeItem>.from(_notices)
      ..removeWhere((item) => item.id == notice.id)
      ..insert(0, notice)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _notices = next;
    _syncUnreadCount();
    GroupNoticeFeedLog.log('service_upsert', extras: {
      'id': notice.id,
      'groupID': notice.groupID,
      'type': notice.type.index,
      'ts': notice.timestamp,
      'before': before,
      'after': _notices.length,
      'unread': _unreadCount,
    });
    notifyListeners();
  }

  /// 增量/TCP 软删：本地移除并记入 dismissed，不打 DELETE API。
  Future<void> removeNoticeById(
    String noticeId, {
    bool markDismissed = true,
  }) async {
    final id = noticeId.trim();
    if (id.isEmpty) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    final clearGeneration = _sessionClearGeneration;
    if (markDismissed) {
      final dismissed = await _loadDismissedNoticeIds(
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) return;
      final nextDismissed = Set<String>.from(dismissed)..add(id);
      await _saveDismissedNoticeIds(
        nextDismissed,
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
    }
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    final before = _notices.length;
    _notices =
        _notices.where((item) => item.id.trim() != id).toList(growable: false);
    if (_notices.length != before || markDismissed) {
      _syncUnreadCount();
      notifyListeners();
    }
  }

  /// 远端已读水位（增量 `READ_WATERMARK`），不请求 PUT。
  void applyRemoteReadWatermark(int readAtMs) {
    if (readAtMs <= 0) {
      return;
    }
    final current = _lastReadAtMs ?? 0;
    if (readAtMs <= current) {
      return;
    }
    _lastReadAtMs = readAtMs;
    _syncUnreadCount();
    notifyListeners();
  }

  Future<void> markRead(int readAtMs) async {
    if (readAtMs <= 0) {
      return;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return;
    final clearGeneration = _sessionClearGeneration;
    try {
      await GroupNoticeApi.instance.markGroupNoticesRead(readAt: readAtMs);
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('GroupSystemNoticeService.markRead failed: $error\n$stack');
      }
    }
    if (!_isCurrentRefresh(identity, clearGeneration)) return;
    _lastReadAtMs = readAtMs;
    _syncUnreadCount();
    notifyListeners();
  }

  Future<bool> clearAllNotices() async {
    if (_notices.isEmpty) {
      return true;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return false;
    final clearGeneration = _sessionClearGeneration;
    final snapshot = List<GroupSystemNoticeItem>.from(_notices);
    try {
      try {
        await GroupNoticeApi.instance.deleteMyGroupNotices();
      } catch (error, stack) {
        if (kDebugMode) {
          debugPrint(
            'GroupSystemNoticeService.clearAllNotices api failed: $error\n$stack',
          );
        }
      }
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      final dismissed = await _loadDismissedNoticeIds(
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      final nextDismissed = Set<String>.from(dismissed)
        ..addAll(
          snapshot.map((item) => item.id.trim()).where((id) => id.isNotEmpty),
        );
      await _saveDismissedNoticeIds(
        nextDismissed,
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      _notices = const [];
      _syncUnreadCount();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteNotice(GroupSystemNoticeItem notice) async {
    final id = notice.id.trim();
    if (id.isEmpty) {
      _toastDeleteFailed();
      return false;
    }
    final identity = SessionIdentityService.instance.capture();
    if (identity.ownerUserId.isEmpty) return false;
    final clearGeneration = _sessionClearGeneration;
    try {
      try {
        await GroupNoticeApi.instance.deleteMyGroupNotice(id);
      } catch (error, stack) {
        if (kDebugMode) {
          debugPrint(
            'GroupSystemNoticeService.deleteNotice api failed: $error\n$stack',
          );
        }
      }
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      final dismissed = await _loadDismissedNoticeIds(
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      final nextDismissed = Set<String>.from(dismissed)..add(id);
      await _saveDismissedNoticeIds(
        nextDismissed,
        ownerUserId: identity.ownerUserId,
        identity: identity,
        clearGeneration: clearGeneration,
      );
      if (!_isCurrentRefresh(identity, clearGeneration)) return false;
      _notices = _notices
          .where((item) => item.id.trim() != id)
          .toList(growable: false);
      _syncUnreadCount();
      notifyListeners();
      _toastDeleteSuccess();
      return true;
    } catch (_) {
      _toastDeleteFailed();
      return false;
    }
  }

  void _toastDeleteSuccess() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '已删除',
      zhHant: '已刪除',
      en: 'Deleted',
      ja: '削除しました',
      ko: '삭제됨',
    ));
  }

  void _toastDeleteFailed() {
    ToastUtils.toast(AppI18n.current.t(
      zhHans: '删除失败，请稍后重试',
      zhHant: '刪除失敗，請稍後重試',
      en: 'Delete failed. Please try again.',
      ja: '削除に失敗しました。しばらくして再試行してください。',
      ko: '삭제에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    ));
  }

  void clearSession() {
    _sessionClearGeneration++;
    _notices = const [];
    _loading = false;
    _lastReadAtMs = null;
    _unreadCount = 0;
    _dismissedNoticeIds = <String>{};
    _dismissedNoticeIdsLoaded = false;
    _dismissedNoticeOwner = '';
    notifyListeners();
  }

  Future<void> clearForOwner(String? ownerUserId) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dismissedStorageKeyForOwner(owner));
    final currentOwner = ChatIdFormat.rawUserUid(
      SessionIdentityService.instance.capture().ownerUserId,
    );
    if (currentOwner == owner) {
      clearSession();
    }
  }

  bool _sameNotices(
    List<GroupSystemNoticeItem> oldList,
    List<GroupSystemNoticeItem> nextList,
  ) {
    if (oldList.length != nextList.length) {
      return false;
    }
    for (var i = 0; i < oldList.length; i++) {
      final oldItem = oldList[i];
      final nextItem = nextList[i];
      if (oldItem.id != nextItem.id ||
          oldItem.groupID != nextItem.groupID ||
          oldItem.type != nextItem.type ||
          oldItem.timestamp != nextItem.timestamp ||
          oldItem.operatorName != nextItem.operatorName ||
          oldItem.targetName != nextItem.targetName) {
        return false;
      }
    }
    return true;
  }
}
