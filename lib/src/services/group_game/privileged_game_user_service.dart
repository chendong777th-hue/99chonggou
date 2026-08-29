import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/group_game_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_game/privileged_game_user_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 特权用户状态：登录/冷启动时读本地库立即展示 UI，后台刷新 `/me/game` 并回写。
class PrivilegedGameUserService {
  PrivilegedGameUserService._();

  static final PrivilegedGameUserService instance =
      PrivilegedGameUserService._();

  final ValueNotifier<bool> gameEnabled = ValueNotifier<bool>(false);

  String? _activeOwner;
  bool _hydrated = false;
  Future<GroupGameStatus>? _inflightRefresh;
  DateTime? _lastRefreshAt;
  static const Duration _refreshTtl = Duration(minutes: 5);

  bool get isPrivileged => gameEnabled.value;

  String _resolveOwner(String? userId) {
    return ChatIdFormat.rawUserUid(
      userId ?? PrivilegedGameUserStore.instance.currentOwnerUserId(),
    );
  }

  /// 登录成功或冷启动恢复会话后调用：先本地、后网络。
  Future<void> activateSession({String? userId}) async {
    final owner = _resolveOwner(userId);
    if (owner.isEmpty) {
      return;
    }
    final switchingUser = _activeOwner != null && _activeOwner != owner;
    _activeOwner = owner;

    if (!_hydrated || switchingUser) {
      final cached = await PrivilegedGameUserStore.instance.read(
        ownerUserId: owner,
      );
      _hydrated = true;
      _applyEnabled(cached ?? false, notify: true);
    }

    unawaited(refreshFromNetwork());
  }

  void clearSession() {
    _activeOwner = null;
    _hydrated = false;
    _inflightRefresh = null;
    _lastRefreshAt = null;
    _applyEnabled(false, notify: true);
  }

  /// 页面打开时可再触发一次后台刷新；有 in-flight 时复用同一请求。
  Future<GroupGameStatus> refreshFromNetwork() {
    final running = _inflightRefresh;
    if (running != null) {
      return running;
    }
    final lastRefresh = _lastRefreshAt;
    if (lastRefresh != null &&
        DateTime.now().difference(lastRefresh) < _refreshTtl) {
      return Future<GroupGameStatus>.value(
        GroupGameStatus(gameEnabled: gameEnabled.value),
      );
    }
    final task = _refreshFromNetworkCore();
    _inflightRefresh = task.whenComplete(() {
      if (identical(_inflightRefresh, task)) {
        _inflightRefresh = null;
      }
    });
    return _inflightRefresh!;
  }

  Future<GroupGameStatus> _refreshFromNetworkCore() async {
    try {
      final status = await GroupGameApi.instance.fetch();
      _lastRefreshAt = DateTime.now();
      final owner = _activeOwner ?? _resolveOwner(null);
      if (owner.isNotEmpty) {
        await PrivilegedGameUserStore.instance.write(
          ownerUserId: owner,
          gameEnabled: status.gameEnabled,
        );
        if (_activeOwner == owner) {
          _hydrated = true;
          _applyEnabled(status.gameEnabled, notify: true);
        }
      } else {
        _applyEnabled(status.gameEnabled, notify: true);
      }
      return status;
    } catch (_) {
      return const GroupGameStatus(gameEnabled: false);
    }
  }

  void _applyEnabled(bool enabled, {required bool notify}) {
    if (gameEnabled.value == enabled) {
      return;
    }
    if (notify) {
      gameEnabled.value = enabled;
    }
  }
}
