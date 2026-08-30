import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_coordinator.dart';
import 'package:tencent_cloud_chat_demo/src/services/login_state.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/read_receipt_outbox_recovery_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im/outgoing_outbox_recovery_service.dart';
import 'package:tencent_cloud_chat_sdk/enum/login_status.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

/// 根据 IM SDK 长连接回调同步 UI 连接状态。
///
/// 冷启动 / 回前台 / 网络恢复进入首页后先展示连接中，直到 SDK 再次上报成功或
/// 确认已在线并满足本次握手的最短展示时长（800ms–2s）。
class ImConnectStatusService extends ChangeNotifier {
  ImConnectStatusService._();

  static final ImConnectStatusService instance = ImConnectStatusService._();

  static const Duration _handshakeVisibleMin = Duration(milliseconds: 800);
  static const Duration _handshakeVisibleMax = Duration(seconds: 2);
  static final Random _handshakeRandom = Random();

  bool _sdkSocketConnected = false;
  bool _handshakePending = false;
  /// 曾连上后断线：下次 onConnectSuccess 必须补拉会话/前台历史。
  bool _needsHistoryCatchUp = false;
  DateTime? _handshakeStartedAt;
  Duration _handshakeMinVisible = _handshakeVisibleMin;
  Timer? _handshakeTimer;

  /// 本次进程是否已收到过 IM SDK [onConnectSuccess]（含登录阶段）。
  static bool get socketConnectedThisLaunch => instance._sdkSocketConnected;

  /// UI 是否可认为 IM 长连接已就绪。
  ///
  /// Web 与原生一致：必须以真实 [onConnectSuccess] / 断线回调为准。
  /// 旧逻辑 `kIsWeb || …` 会把断线后的 WebSocket 仍当成已连接，漏消息且不补拉。
  static bool get isSocketReady =>
      instance._sdkSocketConnected && !instance._handshakePending;

  /// 是否处于冷启动 / 回前台 / 网络恢复后的连接握手展示周期。
  static bool get isHandshakePending => instance._handshakePending;

  /// 取出并清除「断线后需补历史」标记（供 connect_success 决定 recovery reason）。
  static bool consumeNeedsHistoryCatchUp() {
    final needs = instance._needsHistoryCatchUp;
    instance._needsHistoryCatchUp = false;
    return needs;
  }

  static void resetLaunchSession() {
    instance._resetHandshakeTimers();
    instance._sdkSocketConnected = false;
    instance._handshakePending = false;
    instance._needsHistoryCatchUp = false;
    instance._handshakeStartedAt = null;
    instance._handshakeMinVisible = _handshakeVisibleMin;
    instance.notifyListeners();
  }

  static void markSocketConnected() {
    instance._onSdkConnectSuccess();
  }

  static void markSocketDisconnected() {
    if (instance._sdkSocketConnected) {
      instance._needsHistoryCatchUp = true;
    }
    instance._sdkSocketConnected = false;
    instance.notifyListeners();
  }

  /// 冷启动 / 回前台 / 网络恢复：进入等待 IM 长连接握手周期。
  static void beginSocketHandshake({BuildContext? context}) {
    instance._beginHandshake(context: context);
  }

  /// 冷启动进首页：长连接尚未在 UI 层完成握手时保持「连接中」可见。
  static void applyForColdStartHome(BuildContext context) {
    if (!context.mounted) {
      return;
    }
    beginSocketHandshake(context: context);
  }

  static void onSdkConnecting({BuildContext? context}) {
    if (instance._sdkSocketConnected) {
      instance._needsHistoryCatchUp = true;
    }
    instance._sdkSocketConnected = false;
    if (!instance._handshakePending) {
      instance._handshakePending = true;
      instance._handshakeStartedAt = DateTime.now();
      instance._handshakeMinVisible = _pickHandshakeMinVisible();
    }
    _setConnectStatus(context, ConnectStatus.connecting);
    instance.notifyListeners();
  }

  static void onSdkConnectSuccess({BuildContext? context}) {
    instance._onSdkConnectSuccess(context: context);
  }

  void _onSdkConnectSuccess({BuildContext? context}) {
    _sdkSocketConnected = true;
    unawaited(
      ConversationUnreadClearService.recoverPendingReadOutbox().catchError(
        (Object error) => debugPrint(
          'recover conversation read outbox failed '
          'errorType=${error.runtimeType}',
        ),
      ),
    );
    unawaited(
      ReadReceiptOutboxRecoveryService.instance.recoverPending().catchError(
        (Object error) => debugPrint(
          'recover read receipt outbox failed '
          'errorType=${error.runtimeType}',
        ),
      ),
    );
    unawaited(
      OutgoingOutboxRecoveryService.instance.recoverPending().catchError(
        (Object error) => debugPrint(
          'recover outgoing outbox failed errorType=${error.runtimeType}',
        ),
      ),
    );
    if (_handshakePending) {
      _scheduleHandshakeComplete(context: context);
    } else {
      _setConnectStatus(context, ConnectStatus.success);
    }
    notifyListeners();
  }

  void _beginHandshake({BuildContext? context}) {
    _resetHandshakeTimers();
    _handshakePending = true;
    _handshakeStartedAt = DateTime.now();
    _handshakeMinVisible = _pickHandshakeMinVisible();
    _setConnectStatus(context, ConnectStatus.connecting);
    notifyListeners();

    if (_sdkSocketConnected) {
      _scheduleHandshakeComplete(context: context);
      return;
    }

    unawaited(_waitForSdkConnectSuccess(context: context));
  }

  Future<void> _waitForSdkConnectSuccess({BuildContext? context}) async {
    const pollInterval = Duration(milliseconds: 150);
    const maxWait = Duration(seconds: 12);
    final deadline = DateTime.now().add(maxWait);
    while (DateTime.now().isBefore(deadline)) {
      if (!_handshakePending) {
        return;
      }
      if (_sdkSocketConnected) {
        _scheduleHandshakeComplete(context: context);
        return;
      }
      await Future<void>.delayed(pollInterval);
    }
    if (!_handshakePending || _sdkSocketConnected) {
      return;
    }
    if (!await isImLoggedIn()) {
      return;
    }
    // Login state only proves authentication. It does not prove that the SDK
    // realtime socket is ready, so remain CONNECTING until onConnectSuccess.
    _setConnectStatus(context, ConnectStatus.connecting);
    notifyListeners();
  }

  void _scheduleHandshakeComplete({BuildContext? context}) {
    _resetHandshakeTimers();
    final started = _handshakeStartedAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(started);
    final remaining = _handshakeMinVisible - elapsed;
    if (remaining <= Duration.zero) {
      _completeHandshake(context: context);
      return;
    }
    _handshakeTimer = Timer(remaining, () {
      _completeHandshake(context: context);
    });
  }

  void _completeHandshake({BuildContext? context}) {
    if (!_handshakePending) {
      return;
    }
    _handshakePending = false;
    _handshakeStartedAt = null;
    _resetHandshakeTimers();
    if (_sdkSocketConnected) {
      _setConnectStatus(context, ConnectStatus.success);
    }
    notifyListeners();
  }

  void _resetHandshakeTimers() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
  }

  static Duration _pickHandshakeMinVisible() {
    const minMs = 800;
    const maxMs = 2000;
    final ms = minMs + _handshakeRandom.nextInt(maxMs - minMs + 1);
    return Duration(milliseconds: ms);
  }

  /// 网络恢复后兜底：仅在已收到 [onConnectSuccess] 时清除「连接中」。
  static Future<void> reconcileAfterNetworkOnline(
    BuildContext? context, {
    Duration gracePeriod = const Duration(milliseconds: 800),
  }) async {
    if (gracePeriod > Duration.zero) {
      await Future<void>.delayed(gracePeriod);
    }
    await _applySessionReadyConnectStatus(context);
  }

  static Future<void> _applySessionReadyConnectStatus(
    BuildContext? context,
  ) async {
    if (context == null || !context.mounted) return;
    if (!LoginCoordinator.instance.state.isImReady) {
      if (!await isImLoggedIn()) return;
    }
    try {
      final settings = Provider.of<LocalSetting>(context, listen: false);
      final uiStatus = settings.connectStatusForUi;
      if (uiStatus == ConnectStatus.failed) return;
      if (isSocketReady && !isHandshakePending) {
        if (uiStatus != ConnectStatus.success) {
          settings.connectStatus = ConnectStatus.success;
        }
        return;
      }
      if (!isHandshakePending) {
        beginSocketHandshake(context: context);
        return;
      }
      if (uiStatus != ConnectStatus.connecting) {
        settings.connectStatus = ConnectStatus.connecting;
      }
    } catch (_) {}
  }

  /// 冷启动进首页后兜底：登录已成功但 SDK 长时间未回调
  /// onConnectSuccess 时仍保持连接中，禁止伪造 socket ready。
  static Future<void> reconcileStaleConnectingAfterColdStart(
    BuildContext? context, {
    Duration gracePeriod = const Duration(seconds: 12),
  }) async {
    await Future<void>.delayed(gracePeriod);
    if (context == null || !context.mounted) return;
    if (isSocketReady && !isHandshakePending) return;
    try {
      if (!await isImLoggedIn()) return;
      instance._sdkSocketConnected = false;
      instance._handshakePending = true;
      _setConnectStatus(context, ConnectStatus.connecting);
      instance.notifyListeners();
    } catch (_) {}
  }

  static Future<bool> isImLoggedIn() async {
    if (kIsWeb) {
      return true;
    }
    try {
      final status = await TencentImSDKPlugin.v2TIMManager.getLoginStatus();
      if (status.code == 0 &&
          status.data == LoginStatus.V2TIM_STATUS_LOGINED) {
        return true;
      }
    } catch (_) {}
    final res = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final userId = res.data?.trim() ?? '';
    return res.code == 0 && userId.isNotEmpty;
  }

  /// 等待 IM SDK 登录完成（回前台/重连后补拉历史前调用）。
  static Future<bool> waitForImLoggedIn({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (kIsWeb) {
      return true;
    }
    if (await isImLoggedIn()) {
      return true;
    }
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await isImLoggedIn()) {
        return true;
      }
    }
    return isImLoggedIn();
  }

  /// 仅在 bootstrap 阶段且长连接已就绪时清除 stale 的「连接中」。
  static Future<void> syncToLocalSetting(BuildContext? context) async {
    if (context == null || !context.mounted) return;
    try {
      if (!await isImLoggedIn()) return;
      final phase = LoginCoordinator.instance.state.phase;
      final bootstrapPhase = phase == LoginPhase.imConnecting ||
          phase == LoginPhase.homeEnteredSyncingIm;
      if (!bootstrapPhase || !isSocketReady || isHandshakePending) return;

      final settings = Provider.of<LocalSetting>(context, listen: false);
      if (settings.connectStatus == ConnectStatus.connecting) {
        settings.connectStatus = ConnectStatus.success;
      }
    } catch (_) {}
  }

  static void _setConnectStatus(BuildContext? context, ConnectStatus status) {
    if (context == null || !context.mounted) return;
    try {
      Provider.of<LocalSetting>(context, listen: false).connectStatus = status;
    } catch (_) {}
  }

  @override
  void dispose() {
    _resetHandshakeTimers();
    super.dispose();
  }
}
