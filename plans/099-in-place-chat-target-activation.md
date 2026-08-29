# Plan 099: 复用已有聊天页并原地定位搜索消息，不再清空共享消息桶

> **Executor instructions**: 按顺序执行并运行所有验证。发现目标定位必须新建同会话
> route 或必须先清空全局消息列表时，停止并报告，不要保留两套并行语义。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/navigation/app_chat_route.dart lib/src/services/chat_history_refresh_bus.dart lib/src/services/external_chat_entry_service.dart lib/src/platform/route_handler.dart lib/src/chat.dart lib/src/search.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart test`

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: `080-message-commit-snapshot-prerequisite`（已完成）；可与 095 并行，但发布前必须完成 095 的 stale task 防护
- **Category**: bug / tech-debt
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Why this matters

普通打开已经能复用栈中的同会话 Chat route，但只要携带搜索 anchor，`openOrReuseAppChat` 就强制不复用。新 route 初始化又会在 `TIMUIKitChat` 中先 `removeMessageList(conversationID)`；旧 Chat route 仍在栈里并共享同一个 `TUIChatGlobalModel` 消息桶，因此新 route 会改变旧 route 的历史窗口。用户返回时可能看到消息窗口跳变、整屏重新加载、滚动位置丢失，且 late bootstrap 可能继续提交。

目标是 Telegram 式行为：同一 Navigator、同一 conversation 永远只有一个 Chat route；搜索结果只是发给现有 Chat session 的“定位命令”。定位加载期间保留当前消息画面，目标窗口成功后一次提交；失败时恢复原窗口状态，不出现空白墙。

## Current state

- `lib/src/navigation/app_chat_route.dart:224-230`：`canReuse = initFindingMsg == null && searchJumpAnchor == null`。
- 同文件 `:20`：registry 为每个 session 保存 `List<Route>`，且 lookup 与 push 之间没有预注册，两个入口可在同一事件循环各自 push。
- `lib/src/services/chat_history_refresh_bus.dart:14-76`：总线只保存 `lastConversationId/lastReason`，没有 typed target、request ID 或 generation。
- `lib/src/chat.dart:9037-9058`：Chat 已监听 refresh bus，但只能执行普通 history refresh。
- `third_party/.../tim_uikit_chat.dart:1887-1905`：搜索跳转设置 loading 后先 `removeMessageList`，再调用 `loadListForSpecificMessage`。
- `third_party/.../tui_chat_separate_view_model.dart:1025-1048` 已有 `_historyWindowGeneration`；`:1320-1332` 可把目标 around-window 一次提交，说明无需在请求前清空正式列表。
- `lib/src/platform/route_handler.dart:297-300`：外部入口在 helper 运行前先 pop 到 root，可能销毁本可复用的 Chat route。

## Commands you will need

- 定向分析：`flutter analyze lib/src/navigation/app_chat_route.dart lib/src/services/chat_history_refresh_bus.dart lib/src/services/external_chat_entry_service.dart lib/src/platform/route_handler.dart lib/src/chat.dart`，预期无新增 error。
- 路由/总线测试：`flutter test test/app_chat_route_session_reuse_test.dart test/chat_open_compile_test.dart test/conversation_refresh_bus_test.dart test/chat_lifecycle_generation_contract_test.dart test/mobile_async_commit_guard_test.dart`，预期全部通过。
- 历史定位测试：运行新建的 target activation 测试以及 `test/message_ordering_test.dart test/chat_history_recovery_coordinator_test.dart`。
- `git diff --check`，预期 exit 0。

## Scope

**In scope**：

- `lib/src/navigation/app_chat_route.dart`
- `lib/src/services/chat_history_refresh_bus.dart`
- `lib/src/services/external_chat_entry_service.dart`
- `lib/src/platform/route_handler.dart`（仅聊天入口 pop/push）
- `lib/src/chat.dart`（消费目标激活命令）
- `lib/src/search.dart` 与窄屏搜索入口（仅改为命令式打开）
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- 对应测试

**Out of scope**：消息排序/SDK 分页方向、未读清零、草稿、媒体发送、宽屏宿主（由 100 处理）、单 Sliver 改造、腾讯 SDK 升级。

## Git workflow

- 分支建议：`codex/099-in-place-chat-target`
- 提交拆分：typed activation → route reuse/registration → UIKit target transaction → callers/tests。
- 不推送、不合并，除非操作员明确要求。

## Steps

### Step 1: 建立 typed、latest-wins 的 ChatActivationRequest

在 `chat_history_refresh_bus.dart` 定义不可变请求，至少包含：

- canonical `conversationId`
- 单调递增 `requestId`
- `reason`
- 可选 `MessageAnchor targetAnchor`
- 请求类型（refresh / locateMessage / clearHistory），禁止继续靠字符串 reason 推断全部语义

总线发布 `ValueNotifier<ChatActivationRequest?>` 或等价 typed stream。保留现有 `requestRefresh` 兼容入口，但它必须构造 typed request。相同会话连续定位只允许最新 requestId 提交；不同会话不得互相覆盖。

为测试提供 reset；日志只记录 requestId、anchor stableKey 和数量，不记录消息正文。

**Verify**：新增 `test/chat_history_activation_bus_test.dart`，覆盖不同会话隔离、同会话 latest-wins、refresh 不丢 target、reset。

### Step 2: 让 route registry 在 push 时立即登记，并统一复用 anchor 打开

调整 `openOrReuseAppChat`：

1. 无论是否有 anchor，先查同 session route。
2. 找到 route：popUntil 到该 route；route current 后发布 locateMessage request；返回 `existing.popped`，保持 Navigator.push 完成契约。
3. 未找到：创建 route、`navigator.push(route)` 后立即在 helper 内登记（不要等页面 `didChangeDependencies`）；route 完成/失败时 unregister。presence widget 作为兜底，register 必须幂等。
4. Registry 对同 navigator/session 最终只暴露一个 active route；若发现两个，debug assert + 诊断，禁止静默取 `List.last`。

新增测试：两个同步调用同一会话（一个普通、一个 anchor）只产生一个 route；anchor 请求被现有 Chat 收到；复用 Future 只在 route 真正 pop 后完成。

**Verify**：`test/app_chat_route_session_reuse_test.dart` 新旧用例全部通过。

### Step 3: Chat session 消费目标定位命令并绑定 generation

在 `Chat` 的 refresh listener 中区分 locateMessage：

- canonical conversation 不匹配立即忽略。
- 捕获 `_chatOpenGeneration`、conversation ID、activation requestId 和 `_mobileCommitGuard` token。
- model 尚未 attach 时只保留该会话最新 pending request；model ready 后执行一次。
- 执行 `_activateMessageTarget(anchor)`；任何 await 后写状态前重新检查四个 token。
- 同一 anchor 重复点击可以高亮/滚动，但不得重新清空或创建 route。

普通 refresh/clearHistory 保持原语义。不要把 locateMessage 走 `_refreshChatHistoryLegacyFallback`。

**Verify**：测试 A→B 切会话、同会话连续点两个搜索结果、dispose 后晚到、model 延迟 ready；只有最新且属于当前 Chat 的请求可提交。

### Step 4: 把 around-window 加载改成“成功后交换”，删除预清空

移除 `tim_uikit_chat.dart` 搜索路径中的 `globalModel.removeMessageList(conversationID)`。在 `loadListForSpecificMessage` 内保留旧正式窗口直到 cloud/local around-window 已验证目标存在：

- 请求开始时只 bump `_historyWindowGeneration` 并设置临时 loading 状态。
- 使用局部变量构建/去重/排序新窗口；不得边拉边写正式 map。
- 成功且 generation/requestId 仍有效时，一次 `setMessageList(replace: true, applyMemoryWindow: false)`。
- 失败时恢复请求前的 `HistoryMessagePosition`、search status 和 `haveMore*`；旧消息窗口保持不变。
- 成功后由现有稳定 anchor/scroll 逻辑定位并高亮目标；不重建 Chat Widget。

不要改变 older/newer SDK 参数、C2C/群 seq 规则或目标缺失 ±20 的现有兼容规则。

**Verify**：测试请求期间 raw list 不变、成功只产生一次结构 revision、失败保留旧窗口、旧 generation 完成不提交、实时消息在定位期间不丢失。实时合并若需生产 single writer，接到计划 092，禁止在本计划新增第二 writer。

### Step 5: 删除外部入口的 root-pop 旁路

在 `route_handler.dart` 不再先 `Navigator.popUntil(route.isFirst)` 再判断聊天可见。拿到 conversation 后直接调用 `openOrReuseAppChat`；让 registry 决定 pop 到已有 Chat 或 push 新 Chat。只关闭明确属于外部入口且必须关闭的覆盖层，不清空整个导航栈。

**Verify**：构造 `home → chat A → profile/overlay`，外部入口再次打开 A，应回到原 Chat A；打开 B 才 push B。钱包/媒体 overlay 的既有保护测试保持绿色。

### Step 6: 收口所有移动端搜索入口

`search.dart`、`search_entry_narrow.dart`、联系人/群资料的 `openChatWithAnchor` 全部走统一 helper + typed target request；不得直接 new Chat route。新 route 首开仍允许通过构造参数带 anchor，已有 route 必须走 command。

**Verify**：`rg -n "Navigator\.(push|pushReplacement).*appChatRoute|removeMessageList\(conversationID\)" lib/src third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart` 的剩余命中逐项有明确非搜索理由。

## Done criteria

- [ ] 同 Navigator/同 session 的普通打开和 anchor 打开只存在一个 Chat route。
- [ ] 搜索定位发起后、目标窗口成功前，当前消息画面保持可见。
- [ ] 定位失败不清空、不替换旧窗口；定位成功只做一次正式窗口提交。
- [ ] stale request、旧 Chat、旧 history generation 均不能提交。
- [ ] 外部入口不再为了打开聊天 pop 到 root。
- [ ] 定向 tests/analyze 与 `git diff --check` 通过。

## STOP conditions

- `loadListForSpecificMessage` 无法在不改变 SDK 分页语义的情况下延迟提交。
- 实时消息与 around-window 只能通过丢弃其中一方解决；此时先完成计划 092 的 production writer wiring。
- 某入口业务上确实要求并存两个同会话 Chat route；必须由产品明确确认，不能自行保留例外。
- route registry 的立即登记会破坏 `pushReplacement/pushAndRemoveUntil`；将这两个直接调用记录为例外，不要擅改导航语义。
- 现场代码与摘录不一致且无法保留用户改动。

## Maintenance notes

以后“打开聊天”只表达 session 导航，“定位消息”只表达 session 内命令。任何新入口不得用新的 Chat route 承载同会话的搜索状态，也不得在异步请求开始时清空正式消息桶。

