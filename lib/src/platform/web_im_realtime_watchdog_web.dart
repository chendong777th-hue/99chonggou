import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/platform/tim_web_script_loader.dart';
import 'package:tencent_cloud_chat_demo/src/platform/web_im_catch_up_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// Web：监听 `visibilitychange` / `focus`，切回前台时重绑 TIM 并补拉。
///
/// 浏览器后台会节流 WebSocket；有时推送静默但 REST/SDK 拉取仍可用。
/// 此看门狗不依赖 Flutter AppLifecycle（Web 上不完全可靠）。
class WebImRealtimeWatchdog {
  WebImRealtimeWatchdog._();

  static bool _started = false;
  static StreamSubscription<html.Event>? _visibilitySub;
  static StreamSubscription<html.Event>? _focusSub;
  static DateTime? _lastCatchUpAt;
  static const Duration _minInterval = WebImCatchUpPolicy.minInterval;

  static void start() {
    if (_started) {
      return;
    }
    _started = true;
    _visibilitySub = html.document.onVisibilityChange.listen((_) {
      if (html.document.hidden == true) {
        return;
      }
      unawaited(catchUpNow(reason: 'visibility'));
    });
    _focusSub = html.window.onFocus.listen((_) {
      unawaited(catchUpNow(reason: 'focus'));
    });
    if (kDebugMode) {
      debugPrint('WebImRealtimeWatchdog: started');
    }
  }

  static void stop() {
    _visibilitySub?.cancel();
    _focusSub?.cancel();
    _visibilitySub = null;
    _focusSub = null;
    _started = false;
  }

  static bool _isOpenConversationWindowEmpty() {
    final id = ActiveChatRegistry.instance.activeConversationId ?? '';
    if (id.isEmpty) {
      return false;
    }
    if (!ActiveChatRegistry.instance.hasVisibleMessages) {
      return true;
    }
    try {
      final list = serviceLocator<TUIChatGlobalModel>().rawMessageList(id);
      return list == null || list.isEmpty;
    } catch (_) {
      return true;
    }
  }

  static Future<void> catchUpNow({String reason = 'manual'}) async {
    final now = DateTime.now();
    final last = _lastCatchUpAt;
    final openEmpty = _isOpenConversationWindowEmpty();
    final throttled = WebImCatchUpPolicy.isThrottled(
      now: now,
      lastCatchUpAt: last,
      minInterval: _minInterval,
    );
    if (WebImCatchUpPolicy.shouldSkipFullCatchUp(
      now: now,
      lastCatchUpAt: last,
      openConversationEmpty: openEmpty,
      minInterval: _minInterval,
    )) {
      return;
    }

    TimWebScriptLoader.rebindRealtimeListeners();
    if (!LoginCoordinator.instance.state.isImReady) {
      if (kDebugMode) {
        debugPrint(
          'WebImRealtimeWatchdog: rebind only reason=$reason (im not ready)',
        );
      }
      return;
    }

    if (WebImCatchUpPolicy.shouldSessionCatchUpWhileThrottled(
      throttled: throttled,
      openConversationEmpty: openEmpty,
    )) {
      if (kDebugMode) {
        debugPrint(
          'WebImRealtimeWatchdog: session catchUp reason=$reason',
        );
      }
      unawaited(
        ImRecoveryService.instance.refreshForegroundChatIfNeeded(
          reason: 'web_session_$reason',
        ),
      );
      return;
    }

    _lastCatchUpAt = now;

    if (kDebugMode) {
      debugPrint('WebImRealtimeWatchdog: catchUp reason=$reason');
    }
    unawaited(
      ConversationSyncService.instance.syncFromSdk(
        reason: 'web_visibility_$reason',
        reset: true,
        drainMode: ConversationSdkDrainMode.foregroundLimited,
      ),
    );
    unawaited(
      ImRecoveryService.instance.refreshForegroundChatIfNeeded(
        reason: 'im_reconnected',
      ),
    );
  }
}
