import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalSystemNotificationService {
  LocalSystemNotificationService._();

  static final LocalSystemNotificationService instance =
      LocalSystemNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('app_system_notification');

  FutureOr<void> Function(Map<String, dynamic> payload)? _onNotificationTap;
  bool _tapBridgeInitialized = false;

  Future<bool> showChatMessage({
    required String title,
    required String body,
    String? conversationID,
    String? ext,
    String? avatarUrl,
    int? notificationId,
    String? msgKey,
    String? threadId,
  }) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'showChatNotification',
        <String, dynamic>{
          'title': title,
          'body': body,
          'conversationID': conversationID ?? '',
          'ext': ext ?? '',
          if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
            'avatarUrl': avatarUrl.trim(),
          if (notificationId != null) 'notificationId': notificationId,
          if (msgKey != null && msgKey.trim().isNotEmpty)
            'msgKey': msgKey.trim(),
          if (threadId != null && threadId.trim().isNotEmpty)
            'threadId': threadId.trim(),
        },
      );
      return result ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalSystemNotification: show failed ($e)');
      }
      return false;
    }
  }

  Future<bool> setAppBadge(int count) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            "setAppBadge",
            <String, dynamic>{"count": count < 0 ? 0 : count},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelNotification(int notificationId) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }
    try {
      await _channel.invokeMethod<void>('cancelNotification', {
        'notificationId': notificationId,
      });
    } catch (_) {}
  }

  Future<int> clearDeliveredImChatNotifications({String? threadId}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return 0;
    }
    try {
      final count = await _channel.invokeMethod<int>(
        'clearImChatNotifications',
        <String, dynamic>{
          if (threadId != null && threadId.trim().isNotEmpty)
            'threadId': threadId.trim(),
        },
      );
      return count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> initializeTapBridge({
    required FutureOr<void> Function(Map<String, dynamic> payload)
        onNotificationTap,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    _onNotificationTap = onNotificationTap;
    if (_tapBridgeInitialized) {
      await _consumePendingTap();
      return;
    }
    _tapBridgeInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onNotificationClicked') {
        return;
      }
      final payload = _normalizePayload(call.arguments);
      if (payload.isEmpty) {
        return;
      }
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(payload);
      }
    });
    await _consumePendingTap();
  }

  Future<void> consumePendingTap() async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await _consumePendingTap();
  }

  Future<void> _consumePendingTap() async {
    try {
      final payload = await _channel
          .invokeMapMethod<String, dynamic>('consumeNotificationClick');
      final normalized = _normalizePayload(payload);
      if (normalized.isEmpty) {
        return;
      }
      final handler = _onNotificationTap;
      if (handler != null) {
        await handler(normalized);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalSystemNotification: consume tap failed ($e)');
      }
    }
  }

  Map<String, dynamic> _normalizePayload(dynamic raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }
    final normalized = <String, dynamic>{};
    raw.forEach((key, value) {
      if (key == null) {
        return;
      }
      normalized[key.toString()] = value;
    });
    return normalized;
  }

  Future<void> cancelAll() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      await _channel.invokeMethod<bool>('cancelAll');
    } catch (_) {}
  }
}
