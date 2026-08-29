# Plan 096: 加固"活跃会话已读清理"与 SDK unread 回灌之间的窗口

> **Executor instructions**: 按步骤执行，每一步运行验证命令并确认预期结果后再进入下一步。任何 "STOP conditions" 中的情况出现时，停止并报告——不要自行发挥。完成后更新 `plans/README.md` 中本计划的状态行。
>
> **漂移检查（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local/conversation_unread_guard.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/foreground_chat_guard.dart lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_local_store.dart test`
> 若任何 in-scope 文件自本计划编写后有改动，先对照 "Current state" 摘录比对现场代码；不一致即 STOP。

## Status

- **Execution**: complete. `ConversationLocalStore` now owns a monotonic read
  barrier containing version, message identity, timestamp, Seq and order. A
  delayed SDK row is normalized before Coordinator admission and cannot revive
  unread in the same version; a provably newer message consumes the barrier at
  a higher version. Single and batch mark-read commits use the same version.
- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: 094（可选软依赖——若 094 已收口页面旁路，本计划的 read barrier 写入路径更干净；不阻塞）
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

SDK 的 `onConversationChanged` 携带的 `unreadCount` 与本地 read barrier（`readClearedLastMessageId`）是两套独立时钟。活跃会话的已读清理（`ForegroundChatGuard.isActiveConversation` → 未读强制 0）与 SDK unread patch 到达之间存在窗口：若 SDK patch 在本地已读锚点（`readClearedLastMessageId`）持久化完成前到达，`_isReadAnchorReplay` 的锚点匹配失败，SDK 的旧 unread 值会短暂入库，表现为"正在看的会话角标闪回"。现有 `lastMessageAdvanced` 防回跳只覆盖"消息前进"场景（SDK 领先本地时保留乐观 +1），不覆盖"消息未前进但 SDK unread 值回落"场景。本计划把"活跃会话强制 0"从**应用时点**的旁路修补，升级为**持久化时点**的 read barrier 同步语义：在写库前确保 read anchor 已就位，让 SDK 回灌被锚点挡住而不是靠时序碰运气。

## Current state

- `lib/src/services/conversation_local/conversation_unread_guard.dart` — 现有防护：

```13:45:lib/src/services/conversation_local/conversation_unread_guard.dart
  static int resolveForListApply({
    required String conversationId,
    required int existingUnread,
    required V2TimConversation incoming,
    V2TimMessage? existingLastMessage,
    String? ownerUserId,
  }) {
    final sdkUnread = _resolveUnread(
      conversationId,
      incoming,
    );
    if (sdkUnread > 0 &&
        _isReadAnchorReplay(
          conversationId: conversationId,
          incoming: incoming,
          ownerUserId: ownerUserId,
        )) {
      incoming.unreadCount = 0;
      return 0;
    }
```

```71:86:lib/src/services/conversation_local/conversation_unread_guard.dart
  static bool _isReadAnchorReplay({
    required String conversationId,
    required V2TimConversation incoming,
    String? ownerUserId,
  }) {
    final incomingId = incoming.lastMessage?.msgID?.trim() ?? '';
    if (incomingId.isEmpty) {
      return false;
    }
    final anchor = ConversationLocalStore.instance
        .readClearedLastMessageIdFor(
          conversationId,
          ownerUserId: ownerUserId,
        );
    return anchor != null && anchor.isNotEmpty && anchor == incomingId;
  }
```

- `lib/src/services/conversation_local/conversation_local_store.dart` — `readClearedLastMessageIdFor`（读取锚点）与写入锚点的 setter。写入时机由已读清理服务控制。
- `lib/src/services/foreground_chat_guard.dart` — `isActiveConversation`（当前活跃会话判定，未读强制 0 的入口）。
- `lib/src/services/conversation_unread_clear_service.dart` — 未读清理服务（若存在；执行器用 `rg -n "readClearedLastMessageId|clearUnread|markRead" lib/src/services` 确认实际文件名）。
- 相关测试：`test/conversation_unread_guard_test.dart`、`test/conversation_unread_merge_foreground_test.dart`、`test/conversation_unread_aggregate_test.dart`（若存在）。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| 差异检查 | `git diff --check` | exit 0 |
| 定向静态检查 | `flutter analyze lib/src/services/conversation_local/conversation_unread_guard.dart lib/src/services/foreground_chat_guard.dart lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_local_store.dart` | 无本计划新增 error |
| 锚点写入点确认 | `rg -n "readClearedLastMessageId|setReadClearedLastMessage|clearReadAnchor" lib/src` | 明确写入/读取锚点的全部位置 |
| 核心测试 | `flutter test test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart` | 全部通过 |
| 全量测试 | `flutter test` | 全部通过（基线失败须记录证据） |

## Scope

**In scope**（唯一允许修改的文件）：
- `lib/src/services/conversation_local/conversation_unread_guard.dart`
- `lib/src/services/foreground_chat_guard.dart`（仅若需暴露活跃会话的 lastMessage 快照）
- `lib/src/services/conversation_unread_clear_service.dart`（锚点写入时机，若文件存在）
- `lib/src/services/conversation_local/conversation_local_store.dart`（仅 read anchor 的读写辅助，若必须）
- 对应 `test/` 文件

**Out of scope**（禁止修改，即使看起来相关）：
- SDK unread 语义、`unreadCount` 的产品含义、会话列表角标 UI
- `ConversationPerfFlags` 与未读相关的性能开关
- 聊天页消息列表、历史分页、发送管线
- 置顶/归档/免打扰/草稿语义
- 腾讯 SDK 版本、wire payload

## Git workflow

- 分支：`advisor/096-unread-anchor-race`
- 每个逻辑单元一个可回滚提交；提交风格匹配仓库
- 不推送、不合并，除非操作员另行要求

## Steps

### Step 1: 先写行为契约测试（锁定窗口）

在修改前新增测试（扩展 `test/conversation_unread_guard_test.dart` 或新建 `test/conversation_unread_read_anchor_race_test.dart`），锁定：

1. 活跃会话已读清理后，SDK unread patch（同 lastMessage msgID）到达：必须被 read anchor 挡住，结果为 0。
2. 场景 1 但**锚点尚未持久化**（清理完成前 SDK patch 到达）：当前行为是未读闪现；新行为应是持久化时点保证锚点先就位，或 resolveForPersist 在锚点缺失时主动补写。
3. 消息前进（新消息 msgID ≠ 锚点）：SDK unread 正常生效（不误拦新消息）。
4. 非活跃会话：unread 透传 SDK 值，不受影响。

**Verify**: `flutter test test/conversation_unread_read_anchor_race_test.dart` → 新增测试暴露场景 2 的窗口（记录失败原因注释）；已有 `test/conversation_unread_guard_test.dart` 保持绿色。

### Step 2: 把锚点写入提前到"活跃会话已读清理"的同一事务边界

确认已读清理服务（`conversation_unread_clear_service.dart` 或等价位置）写入 `readClearedLastMessageId` 的时机。要求：

- 活跃会话进入前台/收到消息时，**在把 unread 清零写入 Store 的同一事务内**写 read anchor（用当前 lastMessage 的 msgID），使"清零"与"锚点"原子化；
- 若当前实现是先清 unread 后写 anchor（两个独立写），调整为同一事务或同一 await 链保证顺序；
- 保持"发送消息 / 收到新消息"场景下锚点正确更新（锚点应跟随最新 lastMessage）。

**Verify**: `flutter test test/conversation_unread_read_anchor_race_test.dart` 场景 2 通过；`rg -n "readClearedLastMessageId" lib/src` 的写入点收敛到已读清理服务的单一入口。

### Step 3: `resolveForPersist` 在锚点缺失时防御性处理

若 Step 2 后仍存在"SDK patch 先于锚点"的路径（如 SDK 回调早于本地清理事务提交），在 `resolveForPersist` 增加防御：

- 当 `ForegroundChatGuard.isActiveConversation(conversationId)` 为 true 且 incoming unread > 0 且锚点缺失时，**不立即清零**（避免与 SDK 语义打架），而是记录诊断 + 走 `lastMessageAdvanced` 既有防回跳逻辑；若 lastMessage 未前进，保留现有 unread（SDK 值）并由已读清理事务的锚点随后生效。
- 禁止"为了清零而清零"——若 SDK unread 是更新值（新消息），必须透传。

**Verify**: `flutter test test/conversation_unread_read_anchor_race_test.dart` 场景 2/3 通过；`flutter analyze` in-scope 文件无新增 error。

### Step 4: 验证活跃会话未读语义不回归

确认以下语义保持：

- 活跃会话列表侧未读强制 0（`_resolveUnread` 的 `ForegroundChatGuard.isActiveConversation` 分支不删）；
- 乐观 +1（`shouldOptimisticBumpUnread`）不被本计划改变；
- 读完最后未读后的正当清零不被拖住（Plan 043 语义）。

**Verify**: `flutter test test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart` 全部通过。

## Test plan

- 新建 `test/conversation_unread_read_anchor_race_test.dart`（Step 1），覆盖：锚点挡住 SDK 回灌、锚点缺失窗口、新消息不误拦、非活跃会话透传。
- 模式参考：`test/conversation_unread_guard_test.dart`（纯逻辑断言）、`test/conversation_unread_merge_foreground_test.dart`（前后台合并场景）。
- 回归：`test/conversation_unread_guard_test.dart`、`test/conversation_unread_merge_foreground_test.dart` 保持绿色。
- **Verify**: `flutter test test/conversation_unread_read_anchor_race_test.dart test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart` → 全部通过。

## Done criteria

机器可检查，全部成立：

- [x] `git diff --check` exit 0（本轮文件）
- [x] `flutter analyze`（in-scope 文件）无本计划新增 error
- [x] 上述测试全部通过
- [ ] `rg -n "readClearedLastMessageId" lib/src` 的写入点收敛到已读清理服务的单一事务入口（或记录明确理由的例外）
- [ ] 无 in-scope 列表之外的文件被修改（`git status`）
- [ ] `plans/README.md` 状态行已更新

## STOP conditions

出现以下任一情况停止并报告（不要自行发挥）：

- 现场代码与 "Current state" 摘录不一致（自 `9f7c46e` 后漂移），尤其 read anchor 的实际 API 名称/签名不同。
- 某步验证连续两次失败且合理修复后仍失败。
- 修复需要改变 SDK unread 语义或 `ForegroundChatGuard.isActiveConversation` 判定（产品边界）。
- 发现活跃会话已读清理的现有实现已经把锚点写入做成原子事务（说明竞态已被其他路径解决），此时停止并报告"无需修复"的证据。
- 新消息场景（lastMessage 前进 + unread>0）被误拦为 0（Plan 043/未读语义回归）。

## Maintenance notes

- 未来新增未读相关服务（如角标聚合、通知清理）时，读写 read anchor 必须复用已读清理服务的单一事务入口。
- 评审重点：锚点写入是否真的与清零原子；`resolveForPersist` 的防御分支是否引入新的"延迟清零"（应为一次性窗口修复，不是常驻语义）。
- 本计划完成后，R8 风险点应在真机回归矩阵中覆盖"正在聊天收到消息 + 快速切走再切回"场景。
- `conversation_unread_aggregate.dart` 的聚合刷新时机不在本计划范围；若真机发现聚合层另有竞态，单独立案。
