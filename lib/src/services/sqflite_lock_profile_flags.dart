/// SQLite 持锁/进后台诊断开关。过滤关键字：`[SqfliteLock]`
/// 收工后把 [enabled] 改回 `false`。
class SqfliteLockProfileFlags {
  SqfliteLockProfileFlags._();

  /// `true`：Release 真机也 `print` 打点；`false`：整类早退。
  static const bool enabled = false;
}
