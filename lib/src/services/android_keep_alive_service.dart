import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';

class AndroidKeepAliveService {
  AndroidKeepAliveService._();

  static final AndroidKeepAliveService instance = AndroidKeepAliveService._();
  static const MethodChannel _channel = MethodChannel('android_keep_alive');

  bool _started = false;
  Future<void>? _runningTask;

  Future<void> applyFromSettings(LocalSetting settings) async {
    if (!IMDemoConfig.androidKeepAliveEnabled || !Platform.isAndroid) {
      await stop(reason: 'disabled');
      return;
    }

    final shouldRun = settings.notifySystemMessage ||
        settings.notifyVoiceVideoCall ||
        settings.notifyCallQuickAnswerPopup;
    if (!shouldRun) {
      await stop(reason: 'notification_off');
      return;
    }
    await start(reason: 'settings');
  }

  Future<void> start({String reason = 'manual'}) {
    final running = _runningTask;
    if (running != null) return running;

    final task = _start(reason: reason);
    _runningTask = task.whenComplete(() {
      if (identical(_runningTask, task)) {
        _runningTask = null;
      }
    });
    return _runningTask!;
  }

  Future<void> ensureRunning({String reason = 'ensure'}) async {
    if (!Platform.isAndroid || !IMDemoConfig.androidKeepAliveEnabled) {
      return;
    }
    if (!_started) {
      await start(reason: reason);
      return;
    }
    final running = await isRunning();
    if (!running) {
      _started = false;
      await start(reason: '$reason-restart');
    }
  }

  Future<bool> isRunning() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _channel.invokeMethod<bool>('isRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _start({required String reason}) async {
    if (!Platform.isAndroid || _started) {
      return;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('start', <String, dynamic>{
        'reason': reason,
      });
      _started = ok ?? false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidKeepAlive: start failed ($e)');
      }
      _started = false;
    }
  }

  Future<void> stop({String reason = 'manual'}) async {
    if (!Platform.isAndroid) {
      return;
    }
    try {
      await _channel.invokeMethod<bool>('stop', <String, dynamic>{
        'reason': reason,
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AndroidKeepAlive: stop failed ($e)');
      }
    } finally {
      _started = false;
    }
  }
}
