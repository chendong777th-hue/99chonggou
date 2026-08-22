import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_entry_settings_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';

/// 登录后恢复群通知（审批 + 系统通知），并挂载 REST 刷新。
class GroupNoticeBootstrap {
  GroupNoticeBootstrap._();

  static DateTime? _lastNetworkRefreshAt;
  static const Duration _networkRefreshCooldown = Duration(seconds: 3);
  static const Duration fallbackPollInterval = Duration(seconds: 3);
  static Timer? _fallbackPollTimer;
  static Future<void>? _fallbackPollInFlight;

  static Future<void> install({bool refreshApplications = true}) async {
    await GroupNoticeUnreadService.instance.ensureLoaded();
    await GroupNoticeEntrySettingsService.instance.ensureLoaded();
    _startFallbackPolling();
    if (!refreshApplications) {
      return;
    }
    await refreshFromNetwork(force: true);
  }

  static void _startFallbackPolling() {
    if (_fallbackPollTimer?.isActive == true) {
      return;
    }
    _fallbackPollTimer = Timer.periodic(fallbackPollInterval, (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
        return;
      }
      if (_fallbackPollInFlight != null) {
        return;
      }
      late final Future<void> task;
      task = refreshFromNetwork().catchError((_) {}).whenComplete(() {
        if (identical(_fallbackPollInFlight, task)) {
          _fallbackPollInFlight = null;
        }
      });
      _fallbackPollInFlight = task;
    });
  }

  /// Logout/session replacement must stop the account-scoped fallback poll.
  static void stopFallbackPolling() {
    _fallbackPollTimer?.cancel();
    _fallbackPollTimer = null;
    _fallbackPollInFlight = null;
    _lastNetworkRefreshAt = null;
  }

  /// TCP 重连 / 应用回前台等场景下，通过 REST 补齐离线期间遗漏的群通知。
  /// 系统通知走 inbox 游标增量；加群审批仍全量 refresh。
  static Future<void> refreshFromNetwork({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastNetworkRefreshAt != null &&
        now.difference(_lastNetworkRefreshAt!) < _networkRefreshCooldown) {
      return;
    }
    _lastNetworkRefreshAt = now;
    await GroupNoticeUnreadService.instance.ensureLoaded();
    await GroupNoticeEntrySettingsService.instance.ensureLoaded();
    await Future.wait([
      GroupJoinApplicationService.instance.refresh(
        force: true,
        syncMembership: false,
      ),
      GroupNoticeIncrementalSyncService.instance.sync(
        reason: 'group_notice_bootstrap',
      ),
    ]);
  }
}
