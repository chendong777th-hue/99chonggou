import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_request_notice_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_badge_unread_utils.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/core_services.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// 将桌面图标角标同步为与 App 内 Tab 角标一致的总未读数。
class AppBadgeSyncService {
  AppBadgeSyncService._();

  static final AppBadgeSyncService instance = AppBadgeSyncService._();

  AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  bool _listenersAttached = false;
  int? _lastSyncedCount;

  void setLifecycle(AppLifecycleState state) {
    _lifecycle = state;
  }

  bool get _isBackground =>
      _lifecycle == AppLifecycleState.paused ||
      _lifecycle == AppLifecycleState.hidden ||
      _lifecycle == AppLifecycleState.detached;

  void ensureListenersAttached() {
    if (_listenersAttached) {
      return;
    }
    _listenersAttached = true;
    void onUnreadSourcesChanged() {
      if (_isBackground) {
        unawaited(syncBadgeIfNeeded(reason: 'unread_source_changed'));
      }
    }

    ConversationListNotifier.instance.addListener(onUnreadSourcesChanged);
    archivedConversationC2cIDsNotifier.addListener(onUnreadSourcesChanged);
    archivedConversationGroupIDsNotifier.addListener(onUnreadSourcesChanged);
    GroupNoticeUnreadService.instance.addListener(onUnreadSourcesChanged);
    GroupNoticeEntrySettingsService.instance
        .addListener(onUnreadSourcesChanged);
    FriendRequestNoticeService.instance.pendingApplicationCount
        .addListener(onUnreadSourcesChanged);
  }

  Future<void> syncForForeground({String reason = 'foreground'}) async {
    if (kIsWeb || !PlatformUtils().isMobile) {
      return;
    }
    _lastSyncedCount = 0;
    try {
      await TIMUIKitCore.getInstance().setOfflinePushStatus(
        status: AppStatus.foreground,
      );
      if (kDebugMode) {
        debugPrint('AppBadgeSync: foreground reason=$reason');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppBadgeSync: foreground failed reason=$reason error=$e');
      }
    }
  }

  Future<void> syncForBackground({String reason = 'background'}) async {
    if (kIsWeb || !PlatformUtils().isMobile) {
      return;
    }
    await syncBadgeIfNeeded(reason: reason, force: true);
  }

  Future<void> syncBadgeIfNeeded({
    required String reason,
    bool force = false,
  }) async {
    if (kIsWeb || !PlatformUtils().isMobile || !_isBackground) {
      return;
    }
    final count = AppBadgeUnreadUtils.totalAppBadgeUnreadCount();
    if (!force && count == _lastSyncedCount) {
      return;
    }
    _lastSyncedCount = count;
    try {
      await TIMUIKitCore.getInstance().setOfflinePushStatus(
        status: AppStatus.background,
        totalCount: count,
      );
      if (kDebugMode) {
        debugPrint('AppBadgeSync: background reason=$reason count=$count');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AppBadgeSync: background failed reason=$reason error=$e');
      }
    }
  }
}
