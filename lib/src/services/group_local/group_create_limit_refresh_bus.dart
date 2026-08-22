import 'package:flutter/foundation.dart';

/// 群解散等变动后通知建群页刷新 `/me/group-create-limits`（加入/创建额度）。
class GroupCreateLimitRefreshBus {
  GroupCreateLimitRefreshBus._();

  static final GroupCreateLimitRefreshBus instance =
      GroupCreateLimitRefreshBus._();

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void notifyRefresh() {
    revision.value++;
  }
}
