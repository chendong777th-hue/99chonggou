import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_connect_status_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/message_notification_banner.dart';

import 'im_recovery_service.dart';

enum NetworkReachability {
  online,
  offline,
  unknown,
}

class NetworkStatusService {
  NetworkStatusService._();

  static final NetworkStatusService instance = NetworkStatusService._();

  final ValueNotifier<NetworkReachability> status =
      ValueNotifier(NetworkReachability.unknown);

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  NetworkReachability? _lastReachability;
  DateTime? _lastRecoveryTriggerAt;

  static const Duration _recoveryMinInterval = Duration(seconds: 8);

  bool get isOnline => status.value == NetworkReachability.online;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final connectivity = Connectivity();
    _subscription = connectivity.onConnectivityChanged.listen(_applyResults);
    try {
      final initial = await connectivity.checkConnectivity();
      _applyResults(initial);
    } catch (_) {
      status.value = NetworkReachability.unknown;
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    // iOS 冷启动偶发返回空列表，不应判为离线。
    if (results.isEmpty) {
      status.value = NetworkReachability.unknown;
      return;
    }
    final online = results.any((item) => item != ConnectivityResult.none);
    final next = online
        ? NetworkReachability.online
        : NetworkReachability.offline;
    final previous = _lastReachability;
    _lastReachability = next;
    status.value = next;
    _syncConnectStatusWithNetwork(next);

    if (previous == NetworkReachability.offline &&
        next == NetworkReachability.online) {
      final lastTrigger = _lastRecoveryTriggerAt;
      final now = DateTime.now();
      if (lastTrigger == null ||
          now.difference(lastTrigger) >= _recoveryMinInterval) {
        _lastRecoveryTriggerAt = now;
        unawaited(
          ImRecoveryService.instance.afterOnline(reason: 'network_restored'),
        );
      }
    }
  }

  void _syncConnectStatusWithNetwork(NetworkReachability next) {
    final ctx = AppNavigator.context;
    if (ctx == null || !ctx.mounted) {
      return;
    }
    try {
      final settings = Provider.of<LocalSetting>(ctx, listen: false);
      if (next == NetworkReachability.offline) {
        ImConnectStatusService.markSocketDisconnected();
        settings.connectStatus = ConnectStatus.connecting;
        return;
      }
      if (next == NetworkReachability.online) {
        ImConnectStatusService.beginSocketHandshake();
        settings.connectStatus = ConnectStatus.connecting;
        unawaited(
          ImConnectStatusService.reconcileAfterNetworkOnline(
            ctx,
            gracePeriod: const Duration(seconds: 12),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
