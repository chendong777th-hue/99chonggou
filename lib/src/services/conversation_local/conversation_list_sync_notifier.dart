import 'package:flutter/foundation.dart';

class ConversationListSyncState {
  const ConversationListSyncState({
    this.isSyncing = false,
    this.hasSyncedOnce = false,
    this.isDraining = false,
  });

  final bool isSyncing;
  final bool hasSyncedOnce;

  /// 后台仍在按页补拉写库（不应用来触发会话列表整表数据重建以外的重逻辑）。
  final bool isDraining;

  ConversationListSyncState copyWith({
    bool? isSyncing,
    bool? hasSyncedOnce,
    bool? isDraining,
  }) {
    return ConversationListSyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      hasSyncedOnce: hasSyncedOnce ?? this.hasSyncedOnce,
      isDraining: isDraining ?? this.isDraining,
    );
  }
}

/// 会话列表同步态：与列表数据分离，避免同步标记变化触发整表重建。
class ConversationListSyncNotifier extends ChangeNotifier {
  ConversationListSyncNotifier._();

  static final ConversationListSyncNotifier instance =
      ConversationListSyncNotifier._();

  ConversationListSyncState _state = const ConversationListSyncState();

  ConversationListSyncState get state => _state;

  bool get isSyncing => _state.isSyncing;

  bool get hasSyncedOnce => _state.hasSyncedOnce;

  bool get isDraining => _state.isDraining;

  void setSyncing(bool value) {
    if (_state.isSyncing == value) {
      return;
    }
    _state = _state.copyWith(isSyncing: value);
    notifyListeners();
  }

  void setHasSyncedOnce(bool value) {
    if (_state.hasSyncedOnce == value) {
      return;
    }
    _state = _state.copyWith(hasSyncedOnce: value);
    notifyListeners();
  }

  void setDraining(bool value) {
    if (_state.isDraining == value) {
      return;
    }
    _state = _state.copyWith(isDraining: value);
    notifyListeners();
  }

  void clearSession() {
    if (!_state.isSyncing && !_state.hasSyncedOnce && !_state.isDraining) {
      return;
    }
    _state = const ConversationListSyncState();
    notifyListeners();
  }
}
