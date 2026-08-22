/// 骰子气泡 playKey 变化时的动作（纯函数，便于单测）。
enum DicePlayKeyAction {
  /// 保持静帧，不重开 resolve。
  keepStill,

  /// 正在播 / 即将播：把已播标记迁到新 key，动画继续。
  keepAnimatingAndMigrate,

  /// 旧 key 已播完且当前静帧：只迁标记，不重播。
  keepStillAndMigrate,

  /// 新 key 尚未播过：重新判断是否开启动画。
  resolveMode,
}

class DicePlayKeyDecision {
  const DicePlayKeyDecision({
    required this.action,
    this.markKey,
  });

  final DicePlayKeyAction action;

  /// 需要写入已播集合的新 key；空则不写。
  final String? markKey;
}

/// 本地 id → 云端 msgID 时，不能因为旧 key 已标记就把进行中的动画切成静帧。
DicePlayKeyDecision decideDicePlayKeyUpdate({
  required String oldKey,
  required String newKey,
  required bool oldKeyPlayed,
  required bool newKeyPlayed,
  required bool isAnimatingOrStarting,
}) {
  final oldK = oldKey.trim();
  final newK = newKey.trim();

  if (newK.isEmpty) {
    return const DicePlayKeyDecision(action: DicePlayKeyAction.keepStill);
  }

  if (isAnimatingOrStarting) {
    return DicePlayKeyDecision(
      action: DicePlayKeyAction.keepAnimatingAndMigrate,
      markKey: newK,
    );
  }

  if (oldK.isNotEmpty && oldKeyPlayed) {
    return DicePlayKeyDecision(
      action: DicePlayKeyAction.keepStillAndMigrate,
      markKey: newK,
    );
  }

  if (newKeyPlayed) {
    return const DicePlayKeyDecision(action: DicePlayKeyAction.keepStill);
  }

  return const DicePlayKeyDecision(action: DicePlayKeyAction.resolveMode);
}
