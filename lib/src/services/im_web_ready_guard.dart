import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class ImWebReadyGuard {
  ImWebReadyGuard._();

  static final ImWebReadyGuard instance = ImWebReadyGuard._();

  Future<bool>? _waitingTask;

  Future<bool> wait({
    Duration timeout = const Duration(seconds: 12),
    Duration interval = const Duration(milliseconds: 350),
  }) {
    if (!kIsWeb) {
      return Future<bool>.value(true);
    }
    final running = _waitingTask;
    if (running != null) {
      return running;
    }
    final task = _waitCore(timeout: timeout, interval: interval);
    _waitingTask = task.whenComplete(() {
      if (identical(_waitingTask, task)) {
        _waitingTask = null;
      }
    });
    return _waitingTask!;
  }

  Future<void> runWhenReady(
    FutureOr<void> Function() action, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final ready = await wait(timeout: timeout);
    if (!ready) {
      return;
    }
    await action();
  }

  Future<bool> _waitCore({
    required Duration timeout,
    required Duration interval,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getLoginUser()
            .timeout(const Duration(milliseconds: 900));
        final userId = res.data?.trim() ?? '';
        if (res.code == 0 && userId.isNotEmpty) {
          return true;
        }
      } catch (_) {}
      await Future<void>.delayed(interval);
    }
    if (kDebugMode) {
      debugPrint('ImWebReadyGuard: IM web session is not ready before timeout');
    }
    return false;
  }
}
