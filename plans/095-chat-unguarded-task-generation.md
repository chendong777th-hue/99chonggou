# Plan 095: 为聊天页所有写 UI/写状态的裸异步任务绑定会话 generation 与 commit token

> **Executor instructions**: 按步骤执行，每一步运行验证命令并确认预期结果后再进入下一步。任何 "STOP conditions" 中的情况出现时，停止并报告——不要自行发挥。完成后更新 `plans/README.md` 中本计划的状态行。
>
> **漂移检查（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/chat.dart lib/src/chat_page lib/src/services/chat_thermal_perf.dart lib/src/services/livekit_call_session.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart test`
> 若任何 in-scope 文件自本计划编写后有改动，先对照 "Current state" 摘录比对现场代码；不一致即 STOP。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: MED
- **Depends on**: 094（会话列表收口是独立轨道，可并行；本计划不依赖 094，但依赖 086 已提供的 `MobileAsyncCommitGuard` 原语）
- **Category**: bug / tech-debt
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

`lib/src/chat.dart` 有 60+ 处 `unawaited(...)` 裸异步任务，但 `_mobileCommitGuard.begin/canCommit` 只覆盖 3 处（`:9008` advancePage、`:9155-9162` 通话刷新、`:10014` advanceConversation）。大量网络回调晚到（如 `_loadPeerFaceUrl`、`_refreshGroupAvatarsFromProfileBusAsync`、`_applyGroupTipsOperatorPatches`、`_refreshSangongAdminRound`、`_recheckGroupNoticeUntilShown`）只靠 `mounted` 和 `_chatOpenGeneration` 部分拦截。切会话后旧群的网络结果可能把资料 patch 到新会话，或旧页的 setState 在 dispose 后执行。这正是计划 086 "所有提交必须绑定 conversation ID + generation"尚未全部落地的部分。本计划为**写 UI / 写 Store / 写 SDK 状态**的裸任务统一加上会话 generation 校验 + commit token，纯日志/统计类任务不加（避免无谓开销）。

## Current state

- `lib/src/chat.dart` — 聊天页主 State。现有防护原语：

```360:370:lib/src/chat.dart
  final ChatPostOpenScheduler _postOpenScheduler = ChatPostOpenScheduler();
  int _chatOpenGeneration = 0;
  final MobileAsyncCommitGuard _mobileCommitGuard = MobileAsyncCommitGuard();
```

```9006:9012:lib/src/chat.dart
    _mobileCommitGuard.advancePage();
    _chatOpenGeneration++;
    _postOpenScheduler.setActivity(ChatActivityState.disposed);
    _openLifecycle.resetForDispose();
    ChatThermalPerf.increment('page_disposed');
    _isDisposed = true;
    super.dispose();
```

```10013:10016:lib/src/chat.dart
    if (oldConversationID != newConversationID) {
      _mobileCommitGuard.advanceConversation();
      _beginChatOpenGeneration();
```

- `_isChatOpenGenerationCurrent` 是现有 generation 校验辅助（`chat.dart:448` 附近）：

```441:452:lib/src/chat.dart
  int _beginChatOpenGeneration() => ++_chatOpenGeneration;
  bool _isChatOpenGenerationCurrent(int generation) =>
      generation == _chatOpenGeneration &&
      mounted &&
      !_isDisposed;
```

（实际签名可能带 convId 变体——`_isChatOpenGenerationCurrent(generation, convId)` 在 :9161 使用。执行器以现场代码为准。）

- 已治理示例（必须保持）：`_onCallHistoryRefreshRequested`（:9144-9167）—— convId 比对 + generation + commit token 三重防护：

```9154:9166:lib/src/chat.dart
    final generation = _chatOpenGeneration;
    final commitToken = _mobileCommitGuard.begin(
      'call-history-refresh',
      key: convId,
    );
    _callBubbleRefreshTimer?.cancel();
    _callBubbleRefreshTimer = Timer(const Duration(milliseconds: 60), () {
      if (!_isChatOpenGenerationCurrent(generation, convId) ||
          !_mobileCommitGuard.canCommit(commitToken)) {
        return;
      }
      unawaited(_refreshChatHistoryAfterCallEnd());
    });
```

- 裸任务清单（非穷举，执行器须以 `rg -n "unawaited" lib/src/chat.dart` 全量扫描为准，分类后处理）：
  - 写 UI（setState / 状态字段）：`:648` `_syncPeerMessagePermission`、`:3083` `_loadPeerFaceUrl`、`:3084` `_loadPeerLocalProfile`、`:7460-7461`（同）、`:8853-8854`（同）
  - 网络晚到写资料/群状态：`:3159` `_refreshGroupAvatarsFromProfileBusAsync`、`:6589` `_applyGroupTipsOperatorPatches`、`:6579` `_loadGroupMemberCount`、`:6581` `_loadGroupNoticeBanner`
  - 定时/轮询类：`:6293`、`:6445` `_recheckGroupNoticeUntilShown`、`:6448` `_checkAndShowGroupNoticeIfNeeded`、`:6326` `_loadGroupGameStatus`
  - 发送/草稿类：`:8772` `_clearChatLocalDraftAfterSend`、`:8979`/`:9024` `_persistChatLocalDraft`（已有草稿 generation 防护，需确认与 `_chatOpenGeneration` 的组合）
  - 纯日志/统计类（**不加防护**）：`:5288` `SangongGameHttp.hydrateTenant`（若确认无 UI 写）、`ChatThermalPerf` 相关

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| 差异检查 | `git diff --check` | exit 0 |
| 定向静态检查 | `flutter analyze lib/src/chat.dart lib/src/chat_page` | 无本计划新增 error |
| 全量 unawaited 扫描 | `rg -n "unawaited" lib/src/chat.dart` | 清单与计划一致（或记录新增/消失项） |
| 核心测试 | `flutter test test/chat_lifecycle_generation_contract_test.dart test/chat_page_controllers_test.dart test/mobile_async_commit_guard_test.dart test/chat_thermal_perf_test.dart` | 全部通过 |
| 全量测试 | `flutter test` | 全部通过（基线失败须记录证据） |

## Scope

**In scope**（唯一允许修改的文件）：
- `lib/src/chat.dart`（裸任务加防护 + 辅助方法）
- `lib/src/chat_page/`（若辅助方法需外提）
- `lib/src/services/chat_thermal_perf.dart`（新增防护计数指标，可选）
- 对应 `test/` 文件

**Out of scope**（禁止修改，即使看起来相关）：
- 消息列表提交/历史分页/发送管线（那是 074/077/MessageStore 迁移范围）
- 会话列表 `conversation.dart` / `conversation_local/`（那是 093/094 范围）
- 通话/LiveKit 音频路由、CallKit 语义
- 腾讯 SDK 版本、wire payload、UIKit vendor 的 `tui_chat_global_model.dart` 内部（本计划只动 chat.dart 的调用点）
- 草稿产品行为（发送清草稿/恢复语义不变）
- UI 布局、动画、滚动物理

## Git workflow

- 分支：`advisor/095-chat-unguarded-tasks`
- 每个逻辑单元一个可回滚提交；提交风格匹配仓库
- 不推送、不合并，除非操作员另行要求

## Steps

### Step 1: 建立裸任务清单与分类

用 `rg -n "unawaited" lib/src/chat.dart` 全量扫描，把每个裸任务归类为：

- **A 类（写 UI / 写 Store / 写 SDK）**：必须加防护（目标：全部 A 类任务带 generation/token）。
- **B 类（纯日志 / 统计 / 无副作用）**：不加防护，记录理由。
- **C 类（已有独立 generation 防护，如草稿/通话）**：确认现有防护覆盖切会话场景，补 convId 比对若缺失。

在计划文件或 commit message 中附分类表。不得遗漏 A 类任务。

**Verify**: 分类表与 `rg -n "unawaited" lib/src/chat.dart` 输出一一对应；无未分类项。

### Step 2: 增加统一辅助方法

在 chat.dart 增加（或复用现有）统一辅助，模式参考 `_onCallHistoryRefreshRequested`：

```dart
/// 只有当前会话 + 当前 generation + guard 仍有效时才执行 task。
bool _runChatTaskBound(
  String key,
  FutureOr<void> Function() task, {
  bool requireSameConversation = true,
}) {
  final convId = _resolvedConversationID();
  final generation = _chatOpenGeneration;
  final commitToken = _mobileCommitGuard.begin(key, key: convId);
  if (!_isChatOpenGenerationCurrent(generation, convId)) {
    return false;
  }
  unawaited(() async {
    if (!_isChatOpenGenerationCurrent(generation, convId) ||
        !_mobileCommitGuard.canCommit(commitToken)) {
      ChatThermalPerf.increment('task_dropped_stale_generation');
      return;
    }
    await task();
  }());
  return true;
}
```

要求：
- 用 `_resolvedConversationID()` 做 convId 比对（与 `_onCallHistoryRefreshRequested` 一致，不用 `!=` 字符串比较）；
- 若任务内部又有异步链，任务体内在**写状态前**再次 `canCommit`（参考 `_draftWriteTail` 的模式）；
- `_mobileCommitGuard.begin` 的 operation key 用任务名，避免不同任务互相挤掉 operation generation。

**Verify**: `flutter analyze lib/src/chat.dart` 无新增 error；`flutter test test/mobile_async_commit_guard_test.dart` 通过。

### Step 3: 逐个迁移 A 类裸任务

按 Step 1 分类表逐个把 A 类 `unawaited(fn())` 改为 `unawaited(_runChatTaskBound('fn', fn))`（或等价）。优先级顺序：

1. 网络晚到写资料/群状态（`:3159`、`:6579`、`:6581`、`:6589`、`:6607` 等）——切会话风险最高；
2. 写 UI 的任务（`:648`、`:3083`、`:3084`、`:7460`、`:8853` 等）；
3. 定时/轮询类（`:6293`、`:6326`、`:6445`、`:6448` 等）；
4. 发送/草稿类（`:8772`、`:8979`、`:9024`）——确认与草稿 generation 组合后仍正确。

每个迁移独立验证（见 Test plan）。**禁止**一次性批量替换——必须逐任务确认语义（有的任务内部已自己校验 mounted，加双重校验无害但需确认不改变触发时机）。

**Verify**: 每批迁移后 `flutter test test/chat_lifecycle_generation_contract_test.dart test/chat_page_controllers_test.dart` 通过。

### Step 4: 验证切会话/切页场景的防护生效

新增测试（`test/chat_unguarded_task_generation_test.dart` 或扩展 `test/chat_lifecycle_generation_contract_test.dart`）：

1. 打开会话 A，触发 `_loadPeerFaceUrl` 类任务，立即切到会话 B：A 的网络结果不得写 B 的 UI/资料。
2. dispose 后旧任务执行：`_isChatOpenGenerationCurrent` 返回 false，setState 不执行（无 mounted 异常）。
3. 同一任务连续触发两次：后一次 generation/token 使前一次失效（latest-wins）。
4. 草稿任务（`:8979`/`:9024`）与发送清草稿交错：语义与 Plan 065 保持一致（不回归）。

**Verify**: `flutter test test/chat_unguarded_task_generation_test.dart` → 全部通过；`flutter test test/chat_lifecycle_generation_contract_test.dart test/chat_page_controllers_test.dart test/chat_thermal_perf_test.dart` 全部通过。

## Test plan

- 新建 `test/chat_unguarded_task_generation_test.dart`（Step 4），覆盖：切会话隔离、dispose 后不执行、latest-wins、草稿不回归。
- 模式参考：`test/chat_lifecycle_generation_contract_test.dart`（现有 generation 契约测试）、`test/mobile_async_commit_guard_test.dart`（guard 行为断言）。
- 回归：`test/chat_page_controllers_test.dart`、`test/chat_thermal_perf_test.dart`、`test/chat_open_init_staging_contract_test.dart` 保持绿色。
- **Verify**: `flutter test test/chat_unguarded_task_generation_test.dart test/chat_lifecycle_generation_contract_test.dart test/chat_page_controllers_test.dart test/chat_thermal_perf_test.dart test/chat_open_init_staging_contract_test.dart` → 全部通过。

## Done criteria

机器可检查，全部成立：

- [ ] `git diff --check` exit 0
- [ ] `flutter analyze lib/src/chat.dart lib/src/chat_page` 无本计划新增 error
- [ ] 分类表中所有 A 类任务已迁移（`rg -n "unawaited\([^_]" lib/src/chat.dart` 的命中全部属于 B 类或已注释理由的 C 类）
- [ ] 新增生成测试与全部回归测试通过
- [ ] 无 in-scope 列表之外的文件被修改（`git status`）
- [ ] `plans/README.md` 状态行已更新

## STOP conditions

出现以下任一情况停止并报告（不要自行发挥）：

- 现场代码与 "Current state" 摘录不一致（自 `9f7c46e` 后漂移），尤其 `_isChatOpenGenerationCurrent` 签名或 `_resolvedConversationID` 语义变化。
- 某步验证连续两次失败且合理修复后仍失败。
- 迁移某任务后发现它**必须**在切会话后仍执行（如跨会话共享的全局刷新），说明任务归属 B 类需重分类——报告而非强行加防护。
- 需要修改 UIKit vendor 文件或 SDK 才能完成（超出 chat.dart 调用点范围）。
- 草稿/发送链路迁移后出现"草稿未保存"或"发送清草稿失效"（Plan 065 语义回归）。

## Maintenance notes

- 未来新增任何 `unawaited` / Timer / post-frame / SDK listener 回调，若写 UI 或写状态，必须用 `_runChatTaskBound` 或等价辅助，并附 operation key + convId + generation。
- 评审重点：A 类任务是否全迁移；是否存在"双重防护但触发时机改变"的隐蔽行为变化；`ChatThermalPerf` 计数是否在 release 下保持零开销。
- 本计划与 086 的完成标准衔接：086 要求"所有可提交异步结果绑定账号/页面/会话代次"，本计划补的是聊天页页面级；账号级（`advanceAuth`）仍有 gap（见 R10），单独立案。
- 通话气泡/媒体/撤回的既有 guard（018/045/049/053/060/085）不得回退；本计划只加页面级任务防护。
