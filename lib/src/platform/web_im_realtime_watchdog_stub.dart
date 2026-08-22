import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/platform/tim_web_script_loader.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';

/// Non-web stub：无浏览器可见性事件。
class WebImRealtimeWatchdog {
  WebImRealtimeWatchdog._();

  static void start() {}

  static void stop() {}

  static Future<void> catchUpNow({String reason = 'manual'}) async {
    if (!kIsWeb) {
      return;
    }
    TimWebScriptLoader.rebindRealtimeListeners();
    if (!LoginCoordinator.instance.state.isImReady) {
      return;
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
