import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/push_focus_api.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

/// 聊天页 push-focus 生命周期：进入上报、离开清除、会话内每 60s 续期。
class PushFocusService {
  PushFocusService._();

  static final PushFocusService instance = PushFocusService._();

  static const Duration _renewInterval = Duration(seconds: 60);

  String? _activeFocusKey;
  String? _activeChatType;
  String? _activePeerOrGroupId;
  Timer? _renewTimer;
  Future<void>? _inFlight;

  void enterChat({
    required ConvType conversationType,
    required String peerOrGroupId,
  }) {
    if (kIsWeb) {
      return;
    }
    final id = peerOrGroupId.trim();
    if (id.isEmpty) {
      return;
    }
    final chatType = conversationType == ConvType.group ? 'group' : 'c2c';
    final focusKey = '$chatType:$id';
    if (_activeFocusKey == focusKey) {
      unawaited(_putFocus(reason: 'renew_same_chat'));
      return;
    }
    _activeFocusKey = focusKey;
    _activeChatType = chatType;
    _activePeerOrGroupId = id;
    _startRenewTimer();
    unawaited(_putFocus(reason: 'enter_chat'));
  }

  void leaveChat({
    String? chatType,
    String? peerOrGroupId,
  }) {
    if (kIsWeb) {
      return;
    }
    if (chatType != null && peerOrGroupId != null) {
      final key = '${chatType.trim()}:$peerOrGroupId.trim()';
      if (_activeFocusKey != null && _activeFocusKey != key) {
        return;
      }
    }
    _stopRenewTimer();
    if (_activeFocusKey == null) {
      return;
    }
    _activeFocusKey = null;
    _activeChatType = null;
    _activePeerOrGroupId = null;
    unawaited(_deleteFocus(reason: 'leave_chat'));
  }

  Future<void> clearOnLogout() async {
    _stopRenewTimer();
    _activeFocusKey = null;
    _activeChatType = null;
    _activePeerOrGroupId = null;
    await _deleteFocus(reason: 'logout');
  }

  void _startRenewTimer() {
    _renewTimer?.cancel();
    _renewTimer = Timer.periodic(_renewInterval, (_) {
      if (_activeFocusKey == null) {
        return;
      }
      unawaited(_putFocus(reason: 'periodic_renew'));
    });
  }

  void _stopRenewTimer() {
    _renewTimer?.cancel();
    _renewTimer = null;
  }

  Future<void> _putFocus({required String reason}) async {
    final chatType = _activeChatType;
    final id = _activePeerOrGroupId;
    if (chatType == null || id == null || id.isEmpty) {
      return;
    }
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return;
    }
    await _runExclusive(() async {
      try {
        await PushFocusApi.instance.putFocus(
          chatType: chatType,
          peerOrGroupId: id,
        );
        if (kDebugMode) {
          debugPrint(
            'PushFocus: PUT chatType=$chatType id=$id reason=$reason',
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PushFocus: PUT failed reason=$reason error=$e');
        }
      }
    });
  }

  Future<void> _deleteFocus({required String reason}) async {
    if (!ApiClient.isValidJwt(ApiClient.instance.token)) {
      return;
    }
    await _runExclusive(() async {
      try {
        await PushFocusApi.instance.deleteFocus();
        if (kDebugMode) {
          debugPrint('PushFocus: DELETE reason=$reason');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PushFocus: DELETE failed reason=$reason error=$e');
        }
      }
    });
  }

  Future<void> _runExclusive(Future<void> Function() action) async {
    final previous = _inFlight;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    final task = action();
    _inFlight = task;
    try {
      await task;
    } finally {
      if (identical(_inFlight, task)) {
        _inFlight = null;
      }
    }
  }
}
