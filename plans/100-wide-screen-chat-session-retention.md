# Plan 100: 宽屏聊天按会话保留 State，并消除跨会话搜索目标残留

> **Executor instructions**: 先完成 099 的 typed target activation；本计划只改宽屏宿主如何
> 选择会话和投递目标，不复制第二套搜索加载逻辑。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/pages/cross_platform/wide_screen/conversation_and_chat.dart lib/src/pages/cross_platform/wide_screen/home_page.dart lib/src/search.dart lib/src/chat.dart test`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `099-in-place-chat-target-activation`
- **Category**: bug / perf
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Why this matters

宽屏端把 `conversationID + anchor` 放进 Chat key；同一会话只要搜索另一个目标就会销毁并重建整个 Chat State，输入框、滚动位置和异步 generation 都重新开始。普通会话点击在 `conversation_and_chat.dart:420-425` 只清 `pendingMessageAnchor`，没有清 `pendingTargetMessage`，所以会话 A 的搜索消息对象可能被带进会话 B。其余入口又分别手写清理字段，规则容易继续漂移。

完成后，同一会话的 anchor 变化不 remount Chat，只通过 099 的 activation request 原地定位；普通选择总是同时清 anchor/target；不同 conversation 仍有独立稳定 key，禁止共享 Chat State。

## Current state

- `lib/src/pages/cross_platform/wide_screen/conversation_and_chat.dart:73-84` 保存 `pendingMessageAnchor` 与 `pendingTargetMessage`。
- 同文件 `:420-425` 普通列表选择只清 anchor，遗漏 target。
- 同文件 `:570-591` 的 Chat key 为 `${conversationID}_${_messageJumpKey(anchor)}`，anchor 改变即 remount。
- 多个入口在 `:347-355`、`:463-470`、`:494-505`、`:547-558`、`:574-585` 重复编写 selection/clear 逻辑。

## Commands you will need

- 定向分析：`flutter analyze lib/src/pages/cross_platform/wide_screen/conversation_and_chat.dart lib/src/pages/cross_platform/wide_screen/home_page.dart lib/src/chat.dart`。
- 测试：运行新增宽屏 session 测试及 `flutter test test/chat_lifecycle_generation_contract_test.dart test/chat_page_controllers_test.dart test/chat_open_compile_test.dart`。
- `git diff --check`，预期 exit 0。

## Scope

**In scope**：

- `lib/src/pages/cross_platform/wide_screen/conversation_and_chat.dart`
- `lib/src/pages/cross_platform/wide_screen/home_page.dart`（仅 anchor 传递）
- `lib/src/chat.dart`（仅必要的 didUpdateWidget/session 激活接口）
- 对应测试

**Out of scope**：移动端 Navigator、SDK history 参数、未读、消息 writer、桌面布局尺寸、侧栏视觉、单 Sliver 改造、完整跨进程 UI 状态恢复。

## Git workflow

- 分支建议：`codex/100-wide-chat-session`
- 提交顺序：选择状态 reducer → 稳定 key → in-place target → tests。
- 不推送、不合并，除非操作员明确要求。

## Steps

### Step 1: 用一个选择方法统一会话/目标状态

在 `_ConversationAndChatState` 增加唯一入口（名称可按现有风格调整）：

```dart
void _selectChat(
  V2TimConversation conversation, {
  MessageAnchor? anchor,
  V2TimMessage? targetMessage,
})
```

该方法一次性设置 `currentConversation`、`pendingMessageAnchor`、`pendingTargetMessage`，并关闭 side profile。普通选择必须显式传 null/null；搜索选择传 anchor/target。把列表、归档、群申请、资料页、创建群、directToChat 的重复 setState 全部收口到该方法。

**Verify**：静态搜索 `currentConversation = conversation` 的生产写入点只剩初始化和该 reducer；每个普通入口测试都断言 anchor/target 同时为 null。

### Step 2: Chat key 只包含规范 session identity

复用 `appChatSessionKey` 或等价 canonical helper，把 Chat key 改为只依赖 conversation 类型 + canonical ID，不包含 anchor、target、搜索 requestId。不同 C2C/群裸 ID 必须隔离；同一 conversation anchor 变化必须保留相同 State identity。

不要把所有会话固定成同一个 key；那会让 A 的 Chat State 被 B 复用。

**Verify**：widget test 记录 Chat State identity：A 普通→A 搜索保持相同；A→B 必须不同；同裸 ID 的 C2C/群必须不同。

### Step 3: 同会话搜索通过 099 原地激活

当搜索选择命中当前 conversation：

- 不修改 Chat key，不依赖 didUpdateWidget 重建。
- 在 setState 完成后发布 `ChatActivationRequest.locateMessage`。
- 连续选择两个目标只允许后一个 requestId 提交。

当搜索选择不同 conversation：先切换 session，让新 Chat 首次 mount；可通过初始 props 或 model-ready 后 activation 完成第一次定位，但只能有一个执行路径，禁止 props 与 bus 各执行一次。

**Verify**：A 搜索 x→A 搜索 y 不触发 dispose/init；最终定位 y。A 搜索 x→B 普通不携带 x，B 从正常最新/未读窗口打开。

### Step 4: 保留会话级可恢复状态边界

本计划至少保证 route/widget 仍存活时保留：滚动窗口、输入文本、selection/cursor、reply/edit/multiselect 和输入面板状态不因 anchor 改变而丢失。真正切换 A→B 时允许 B 使用独立 State；若产品要求切回 A 恢复完整 UI，应先设计有界 `ChatSessionStateStore`（LRU 2–4 会话），不得把所有 Chat State 永久留在隐藏 IndexedStack 中。

**Verify**：同会话搜索前后输入文本和滚动 anchor 不变；目标定位只改变历史 location。A→B→A 的完整恢复若尚未实现，应明确标为后续，不伪造 DONE。

## Done criteria

- [ ] 普通选择任何会话都会同时清理 pending anchor 和 target。
- [ ] 同会话 anchor 改变不 remount Chat。
- [ ] 不同 conversation 与 C2C/群仍拥有不同 State identity。
- [ ] 同会话连续目标请求 latest-wins，跨会话不串 target。
- [ ] 定向 tests/analyze 与 `git diff --check` 通过。

## STOP conditions

- 099 尚未提供可复用的 typed target activation。
- 同一 conversation 的 `Chat.didUpdateWidget` 会因为非 anchor props 强制重新初始化，且无法在 Scope 内安全隔离。
- 必须把所有 Chat 放入无界 IndexedStack 才能保留状态。
- 改 key 导致 C2C 与群聊裸 ID 冲突。
- 现场代码与摘录不一致且无法保留用户改动。

## Maintenance notes

宽屏所有聊天选择入口必须经过同一个 reducer；key 只表示 session identity，不能编码一次性命令。需要恢复的 UI 状态应显式建模并设置 LRU 上限，不能靠偶然不 dispose。

