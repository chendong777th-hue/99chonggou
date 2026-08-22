import 'dart:async' show Completer, TimeoutException, unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/sangong_my_config_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_media_metadata_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/moments/moments_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/sqflite_lifecycle_guard.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_store.dart';

/// 生命周期到 SQLite 停写/关库的唯一入口，避免 Store 与 Guard 循环引用。
///
/// 事件串行处理：保证 `resumed` 一定发生在对应 pause 关库完成之后，避免
/// 前台 hydrate 撞上 `forbidOpen` 窗口。
class SqfliteLifecycleHost {
  SqfliteLifecycleHost._();

  static Future<void>? _chain;
  static Completer<void>? _closeInFlight;
  static Completer<void>? _openAllowed;
  static int _epoch = 0;

  static bool get _closeDatabasesOnPause {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  }

  /// 供 open 路径在撞上 [SqfliteClosedForBackground] 时等待：
  /// 1) 等在途关库结束；2) 再等 `resume()` 打开闸门（有超时）。
  static Future<bool> waitUntilOpenAllowed({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final pendingClose = _closeInFlight;
    if (pendingClose != null) {
      try {
        await pendingClose.future.timeout(timeout);
      } on TimeoutException {
        return SqfliteLifecycleGuard.instance.canOpenDatabase;
      }
    }
    if (SqfliteLifecycleGuard.instance.canOpenDatabase) {
      return true;
    }
    final waiter = _openAllowed ??= Completer<void>();
    try {
      await waiter.future.timeout(timeout);
    } on TimeoutException {
      return SqfliteLifecycleGuard.instance.canOpenDatabase;
    }
    return SqfliteLifecycleGuard.instance.canOpenDatabase;
  }

  static Future<void> handle(AppLifecycleState state) {
    final previous = _chain;
    final gate = Completer<void>();
    _chain = gate.future;
    unawaited(() async {
      try {
        if (previous != null) {
          await previous;
        }
        await _handleImpl(state);
      } finally {
        if (!gate.isCompleted) {
          gate.complete();
        }
        if (identical(_chain, gate.future)) {
          _chain = null;
        }
      }
    }());
    return gate.future;
  }

  static Future<void> _handleImpl(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
        _pauseWrites();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _pauseWrites();
        if (_closeDatabasesOnPause) {
          await _closeDatabases();
        }
        break;
      case AppLifecycleState.resumed:
        final pendingClose = _closeInFlight;
        if (pendingClose != null) {
          await pendingClose.future;
        }
        SqfliteLifecycleGuard.instance.resume();
        ConversationLocalStore.instance.resumeCoalesceAfterForeground();
        _signalOpenAllowed();
        break;
    }
  }

  static void _pauseWrites() {
    SqfliteLifecycleGuard.instance.pauseWrites();
    ConversationLocalStore.instance.pauseCoalesceForBackground();
  }

  static Future<void> _closeDatabases() async {
    final myEpoch = ++_epoch;
    final closeGate = Completer<void>();
    _closeInFlight = closeGate;
    SqfliteLifecycleGuard.instance.forbidOpen();
    // 新的关库周期：旧的 open-allowed waiters 不应在关库中途被误唤醒。
    _resetOpenAllowedWaiters();
    try {
      await ConversationLocalStore.instance.waitUntilUpsertWriteIdle(
        maxWait: const Duration(milliseconds: 250),
      );
      await Future.wait<void>(<Future<void>>[
        ConversationLocalStore.instance.closeIfOpen(),
        FriendLocalStore.instance.closeIfOpen(),
        GroupLocalStore.instance.closeIfOpen(),
        GroupMemberLocalStore.instance.closeIfOpen(),
        MessageMediaMetadataStore.instance.closeIfOpen(),
        MomentsLocalStore.instance.closeIfOpen(),
        RedPacketLocalStore.instance.closeIfOpen(),
        PushTokenUploadLocalStore.instance.closeIfOpen(),
        UserProfileLocalStore.instance.closeIfOpen(),
        SangongMyConfigStore.instance.closeIfOpen(),
        PrivilegedGameUserStore.instance.closeIfOpen(),
      ]);
    } finally {
      if (_epoch == myEpoch) {
        if (!closeGate.isCompleted) {
          closeGate.complete();
        }
        if (identical(_closeInFlight, closeGate)) {
          _closeInFlight = null;
        }
      } else if (!closeGate.isCompleted) {
        // 过期关库轮次：仍要放行等待方，避免永久挂起。
        closeGate.complete();
      }
    }
  }

  static void _signalOpenAllowed() {
    final waiter = _openAllowed;
    _openAllowed = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  static void _resetOpenAllowedWaiters() {
    final waiter = _openAllowed;
    _openAllowed = null;
    if (waiter != null && !waiter.isCompleted) {
      // 不 completeError：调用方会在 timeout / 二次检查 canOpen 后自行处理。
      waiter.complete();
    }
  }

  @visibleForTesting
  static void debugReset() {
    _chain = null;
    _closeInFlight = null;
    _openAllowed = null;
    _epoch = 0;
  }
}

void scheduleSqfliteLifecycle(AppLifecycleState state) {
  unawaited(SqfliteLifecycleHost.handle(state));
}
