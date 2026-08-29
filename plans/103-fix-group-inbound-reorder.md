# Plan 103: 修复群消息乱序缓冲对连续 Seq 的确定性丢弃

> **Executor instructions**: 严格按步骤执行，先让回归测试能够编译并稳定复现，
> 再修改生产逻辑。禁止通过关闭乱序缓冲、延长 timeout 或直接放行全部消息规避。
> 命中 STOP 条件时停止并报告。完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart`
> 当前基于 dirty worktree；逐段核对下面的现场代码，禁止 reset、checkout 或覆盖他人修改。

## Status

- **Priority**: P0
- **Effort**: S
- **Risk**: MEDIUM
- **Depends on**: 092 Step 4 的生产接线；与 104 串行执行
- **Category**: bug / correctness / tests
- **Planned at**: commit `9f7c46e`, 2026-08-25（dirty worktree）

## Execution (2026-08-25)

- 代码与回归夹具已完成：`seq == expected`、timeout 后迟到/重复 ahead、bounded
  released ledger、activate/dispose 生命周期均已落地。
- 定向 `git diff --check` 通过；Flutter/Dart 测试、analyze 和 format 尚未取得可执行
  证据。当前工具链尝试写 `/Users/qiu/flutter/bin/cache/engine.stamp` 时被权限拒绝，
  沙箱外执行需操作员明确批准后重试。
- 浏览器/双账号与真机矩阵仍是发布门禁，不能仅凭源码完成声明。

## Why this matters

群聊首窗最新 Seq 为 100 时，`activate` 把 `_expectedSeq` 设为 101；`accept`
却先用 `seq <= _expectedSeq` 返回空列表，导致合法的第一条实时消息 101 被当作重复
消息丢弃，后面的 `seq == _expectedSeq` 正常分支永远不可达。这不是极端竞态，而是
每次激活后连续消息都会命中的确定性错误。

当前测试已经写出 `100 -> 101` 期望，但测试文件本身缺少必填 `elemType`，且含
`await` 的用例没有声明 `async`，所以高风险分支没有可执行保护。

## Current state

`inbound_reorder_buffer.dart` 当前核心逻辑：

```dart
_expectedSeq = newestSeq > 0 ? newestSeq + 1 : 0;

if (seq <= _expectedSeq) {
  return const [];
}

if (seq == _expectedSeq) {
  _expectedSeq = seq + 1;
  final contiguous = [msg];
  _drainContiguous(contiguous);
  return contiguous;
}
```

必须保持的语义是：`_expectedSeq` 表示“下一条尚未提交的 Seq”。因此只有
`seq < _expectedSeq` 是已越过的旧值；`seq == _expectedSeq` 必须提交并推进水位；
`seq > _expectedSeq` 才进入乱序等待。

另一个现存边界是 timeout：当前实现把 ahead 消息发布后清空 `_pending`，却没有记录
这些 Seq 已经发布。修复 equality 后必须用测试明确 timeout 后的迟到缺口和重复回调
如何推进，不能留下重复发布或反复 timeout。

## Baseline evidence

计划生成时执行：

`flutter test third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart`

沙箱内被 Flutter 写 `/Users/qiu/flutter/bin/cache/engine.stamp` 的权限阻塞；此前在可运行
环境中已确认测试还会因 `_msg()` 缺少 `elemType`、timeout 用例缺少 `async` 而编译失败。
执行者必须先修测试夹具并保存修复前的行为失败证据，不能把当前状态写成“测试通过”。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改，不覆盖无关文件 |
| Focused test | `flutter test third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart` | 全部通过 |
| Analyze | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart` | 相关文件无新增 error |
| Format | `dart format --output=none --set-exit-if-changed third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart` | exit 0 |
| Hygiene | `git diff --check -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart` | exit 0 |

## Scope

**In scope**：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart`
- `third_party/tencent_cloud_chat_uikit/test/inbound_reorder_buffer_test.dart`
- 仅当生命周期测试证明生产调用错误时，最小调整
  `tui_chat_global_model.dart` 中 buffer 的 activate/dispose 接线

**Out of scope**：云端补洞算法、C2C 排序、消息 writer、SDK 版本、UI gap marker、
历史分页、发送和已读。它们分别由 092、104、105、106 处理。

## Git workflow

- Branch: `codex/103-fix-group-inbound-reorder`
- 提交顺序：测试夹具可编译 -> 红测 -> 最小状态机修复 -> 生命周期/timeout 回归。
- 不 push、不合并，除非操作员明确要求。

## Steps

### Step 1: 修复测试夹具并保存红测

- `_msg()` 构造合法的 `V2TimMessage`，显式提供当前 SDK 模型要求的 `elemType`。
- 所有使用 `await` 的 test callback 声明 `async`；每个测试 `addTearDown(buffer.dispose)`，
  防止 Timer 泄漏污染后续测试。
- 先只修测试，不动生产逻辑。确认 `contiguous seq` 和乱序补齐用例因 101 被丢弃而失败。
- 使用 fake async 或 `Completer` 驱动 timeout，避免依赖 50/80ms 墙钟抖动；若现有测试
  工具不能无侵入使用 fake time，保留很短真实计时但增加明确的 teardown。

**Verify**：测试成功加载；至少 `100 -> 101` 稳定失败在 `hasLength(1)`，而不是编译失败。

### Step 2: 修正 next-expected 比较不变量

- 把旧消息判定收紧为 `seq < _expectedSeq`。
- 保留 `seq == _expectedSeq` 作为唯一连续提交入口，先推进水位，再按升序 drain。
- `seq <= 0`、未激活和非群调用继续直通；不从 msgID、timestamp 或正文推断 Seq。
- 注释必须与实际比较一致，删除“`seq <= expected` 都是重复”的错误说明。

**Verify**：`100 -> 101` 返回 101 并把 expected 推进到 102；`100 -> 100` 返回空。

### Step 3: 明确 timeout 后已发布 ahead Seq 的账本

当前 timeout 会发布 ahead 行以保证最新消息可见，同时触发云端补洞。状态机需要记住
本次已经发布的 ahead Seq，直到缺口补齐或 buffer reset：

- timeout 发布 103 后，迟到 101、102 各只发布一次；水位越过已发布的 103 到 104，
  不能再次发布 103，也不能为同一个缺口重复启动 timeout。
- 云端或 SDK 重复回调 103 必须在 buffer 或下游 writer 的明确身份门禁中只提交一次。
  若依赖下游 writer 去重，测试必须跨到该 writer 边界并证明，而不是只写注释。
- 记录集合必须受 `maxPending` 或连续水位裁剪约束，不能随长会话无界增长。
- 不允许 timeout 直接把 expected 跳到最大 ahead Seq 后面，因为这样会丢掉迟到的
  101、102；应在水位连续推进时跳过“已发布但尚未越过”的 Seq。

**Verify**：覆盖 timeout 后迟到、timeout 后重复 ahead、连续两次不同 gap 和
`maxPending` 强制 flush，均无重复、无无限 Timer、无无界账本。

### Step 4: 加固 activate/dispose 生命周期

- 新会话 activate 前取消旧 Timer 并清空 pending/已发布 ahead 状态。
- `dispose` 清空 conversation ID、expected、pending、ahead 和 Timer，并保持幂等。
- 同一会话重新 hydrate 时也必须根据新的 `newestSeq` 重建状态，不能携带旧窗口 gap。
- 核对 `tui_chat_global_model.dart` 的会话切换、`clearData` 和 buffer 替换路径；只有测试
  证明缺失时才修改接线。

**Verify**：A 会话 pending 后切 B，不触发 A 的 flush/catch-up；dispose 后消息直通；
重复 dispose 不抛错。

### Step 5: 完成组合回归

至少包含：

1. 未激活直通。
2. `100 -> 101`。
3. `100 -> 100` 旧值拒绝。
4. `100 -> 103 -> 101 -> 102`，最终输出 101、102、103 各一次。
5. timeout 发布 103 后 101、102 迟到，无重复 103。
6. `maxPending` 强制 flush。
7. activate A 后切 B、dispose、非法 Seq。

**Verify**：focused test、定向 analyze、format 和 diff check 全通过。

## Done criteria

- [ ] 合法的 `seq == expectedSeq` 不再被丢弃。
- [ ] 旧 Seq、连续 Seq、乱序 Seq 的三个分支互斥且可达。
- [ ] timeout 后的迟到缺口与重复 ahead 不会二次发布。
- [ ] pending/已发布账本有明确上限和释放时机。
- [ ] activate/dispose 不跨会话泄漏 Timer 或消息。
- [ ] 测试先红后绿，且不再有测试编译错误。
- [ ] 定向 analyze、format、diff check 通过。
- [ ] Scope 外无修改（计划索引除外）。

## STOP conditions

- 腾讯生产数据出现同一群同一 Seq 对应不同 msgID；保留两条并升级到协议调查，禁止按
  Seq 静默删掉其中一条。
- 修复需要关闭乱序缓冲或绕过 reconciliation writer。
- timeout 语义只能通过无界保存所有历史 Seq 才能成立。
- C2C 被接入该 buffer，或被迫使用 per-sender Seq 作为全局水位。
- focused test 连续两次失败且原因超出本计划 scope。

## Maintenance notes

评审时把 `_expectedSeq` 当作 first-uncommitted watermark，而不是“最近看到的 Seq”。
未来修改 timeout、最大缓冲数或群历史 hydrate 时，必须同时回归连续到达、乱序补齐、
timeout 后迟到和跨会话 dispose 四条路径。103 只保证入站排序状态机正确；云端返回是否
进入权威消息列表由 104 保证。
