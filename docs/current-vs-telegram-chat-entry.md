# 当前项目与 Telegram 会话列表进入聊天页的架构对比

> 文档日期：2026-08-25  
> 对比范围：当前项目移动端普通单聊/群聊，与 Telegram iOS 官方客户端的会话打开和首屏历史消息链路。  
> 不包含：搜索跳转、定位指定消息、论坛话题、年龄验证等特殊打开模式。

## 1. 结论摘要

两套实现最本质的区别，不是“谁不需要加载消息”，而是“谁控制聊天页首帧”。

- 当前项目（已完成第一阶段对齐）：列表页先乐观修改状态，然后立即进入或复用 Chat route；首窗预热在后台与转场竞速，真实 `TIMUIKitChat` 从首帧开始保持稳定。
- Telegram：先找到或创建稳定的 ChatController，聊天背景、消息 historyNode 和输入区属于同一个稳定节点；历史消息通过响应式 history view 增量进入该节点。

因此，当前项目更像一次跨多个状态所有者的分阶段交接；Telegram 更像同一聊天控制器和同一历史视图的连续状态变化。

当前项目原先在 cold 打开时存在 push 前等待和轻壳到重体的二次挂载。2026-08-25 已移除这两个边界；剩余主要风险集中在多层消息权威、已读确认和 Sliver 增量提交。

### 1.1 2026-08-25 对齐状态

已实现：

- `prepareForOpen` 改为后台竞速，不再阻塞页面转场。
- 首帧固定挂载真实 `TIMUIKitChat`，移除轻壳到重体的 remount。
- history gate 不再使用整页 `AbsorbPointer`，输入区和页面框架在冷加载期间保持响应。
- 同一个 Navigator 中已存在相同 conversation 的 Chat route 时优先复用并 pop 返回。
- 单聊和群聊使用带类型的独立 session key，禁止相同裸 ID 串会话。

仍需继续收敛：

- warm/bootstrap/UIKit/SDK 历史提交的唯一权威和版本规则。
- 已读状态的 SDK 确认与旧快照拒绝规则。
- Sliver 消息更新的稳定 ID 增量 transition。

## 2. 证据边界

本文把结论分成三类：

1. **当前项目源码事实**：来自当前仓库实际调用链。
2. **Telegram 官方源码事实**：来自 Telegram iOS 官方仓库 `master` 分支。
3. **架构推断**：根据两套已确认实现推导出的风险和体验差异，会明确使用“可能”“更容易”等措辞。

不能仅根据当前引用资料断言 Telegram 的所有已读确认时序，也不能声称 Telegram 不会发生列表或渲染异常。

## 3. 当前项目进入聊天页的实际流程

### 3.1 总体流程

```text
点击会话
  ↓
本地乐观清除未读
  ↓
预热消息、头像和首屏窗口
  ↓
后台启动 prepareForOpen（最多约 400ms，不 await）
  ├───────────────┐
  ↓               ↓
进入或复用 Chat route   后台 warm 首窗
  ↓
首帧固定挂 TIMUIKitChat
  ↓
open-history gate
  ↓
复用 prepared history / UIKit 本地或云端补历史
  ↓
historyReady → interactive → enriched
```

### 3.2 列表点击与导航前准备

移动端点击最终进入：

- `lib/src/conversation.dart:2955`：`_handleOnConvItemTaped`
- `lib/src/services/chat_open_viewport_coordinator.dart:85`：`prepareForOpen`
- `lib/src/navigation/app_chat_route.dart:10`：`appChatRoute`

点击后依次发生：

1. 检查 `conversationID` 和 `_openingConversationID`。
2. 调用 `clearLocalForOpenFast` 乐观清除本地未读显示。
3. touch 历史消息 warm cache，预热头像等资源。
4. 设置当前选中的 conversation。
5. 通过 `unawaited` 启动 `ChatOpenViewportCoordinator.prepareForOpen`。
6. 立即调用 `openOrReuseAppChat` 开始页面转场。
7. warm 任务最多运行约 400ms，结果继续写入同一 conversation 消息桶。

这意味着，首屏预热仍然保留，但不会延迟用户点击后的导航反馈。

`_openingConversationID` 现在阻止一次导航期间的所有第二次点击；`AppChatRouteRegistry` 负责同一 Navigator 内相同 conversation route 的复用。

### 3.3 稳定 Chat route 与首帧真实聊天树

路由配置位于：

- `lib/src/navigation/app_chat_route.dart:26`
- `lib/src/navigation/route_visibility_host.dart:92`

关键配置包括：

- `allowSnapshotting: false`
- `routeVisibilityDeferredFrames: 1`
- `RepaintBoundary(child: Chat(...))`

Chat 页首帧稳定挂载由以下代码实现：

- `lib/src/chat.dart`：`_mountStableChatBody`
- `lib/src/chat.dart`：`build` 中直接构建 `TIMUIKitChat`
- `lib/src/navigation/app_chat_route.dart`：`AppChatRouteRegistry` 和 `openOrReuseAppChat`

warm 与 cold 均使用同一棵真实聊天树。区别只在于消息桶首帧是否已有可显示数据；不会再因为 cold miss 替换整棵页面结构。

### 3.4 open-history gate

首屏消息可见和可交互由以下逻辑继续控制：

- `lib/src/chat.dart:3984`：`_startOpenHistoryGate`
- `lib/src/chat.dart:4062`：`_runOpenHistoryGateWithTipsMerge`
- `lib/src/chat.dart`：`_wrapChatWithOpenHistoryGate`

主要限时等待包括：

- 历史首窗准备：最多约 1.2s。
- 本地群 tips 合并：最多约 400ms。
- geometry/layout ready：最多约 300ms。

完整 warm window 或确认空会话可以跳过 history gate；thin/cold 情况仍会等待首窗准备，用于 lifecycle 和 post-open 调度，但不再锁住整页交互。

### 3.5 三层历史消息初始化

当前普通打开链中，历史消息可能经过三层准备：

```text
ConversationHistoryWarmScheduler
             ↓
ChatHistoryPeekBootstrap
             ↓
TIMUIKitChat / Tencent SDK history load
```

关键位置：

- `lib/src/services/conversation_history_warm_scheduler.dart:634`
- `lib/src/services/chat_history_peek_bootstrap.dart:301`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart:1450`

UIKit 的初始加载大致遵循：

1. 等待 app 层正在执行的 open hydrate。
2. 尝试复用 prepared initial history。
3. 无法复用时调用 `hydrateInitialHistoryPeekStyle`。
4. 首窗仍不足时，再走本地或云端 older history。
5. 初始加载末尾执行 `markMessageAsRead(force: true)`。

### 3.6 当前消息渲染权威源

消息列表渲染时的直接内存权威源是：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:234`
- `TUIChatGlobalModel._messageListMap`

消息列表最终由以下文件中的 Flutter Sliver 渲染：

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat_history_message_list.dart`

但在 `_messageListMap` 外面，还存在 warm snapshot、首窗 bootstrap、SDK 本地/云端历史、display list cache、dedupe、merge 和 reconciliation。因此 `_messageListMap` 虽然是渲染直接来源，并不代表整个打开链只有一个状态所有者。

### 3.7 已读状态的三阶段处理

当前项目至少有三处已读动作：

1. 点击会话时：本地乐观清零。
2. Chat 可见后：调度 SDK unread clean。
3. UIKit 初始历史加载后：`markMessageAsRead(force: true)`。

相关代码：

- `lib/src/services/conversation_unread_clear_service.dart:373`
- `lib/src/chat.dart:8358`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart:2112`

返回会话列表后，还会执行 unread finalize、会话行 patch 和虚拟窗口 hydrate。这说明“用户看到未读归零”与“所有权威状态均确认已读”并不是同一个时刻。

## 4. Telegram iOS 的实际进入流程

### 4.1 总体流程

```text
点击会话
  ↓
读取 cached peer / forum 信息
  ↓
检查导航栈中是否已有同一 ChatController
  ├─ 有：复用并返回该控制器
  └─ 无：创建并 push
  ↓
稳定 ChatControllerNode 存在
  ↓
Postbox history view 输出 Loading / HistoryView
  ↓
同一 historyNode 增量 insert / delete / update
  ↓
滚动到边缘时 fill holes，并按方向预取
```

### 4.2 会话选择与控制器复用

Telegram 的 `ChatListController` 在选择会话时，会读取缓存的 peer/forum 数据，然后调用聊天导航逻辑：

- [Telegram ChatListController.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/ChatListUI/Sources/ChatListController.swift)

`navigateToChatController` 默认启用 `useExisting`，会反向查找导航栈中相同 peer/thread/subject 的 `ChatControllerImpl`：

- 找到：复用已有控制器，或 pop 到已有控制器。
- 未找到：创建新的 `ChatControllerImpl` 并 push。
- forum、年龄验证等特殊场景会先进行额外检查。

源码：

- [Telegram NavigateToChatController.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUI/Sources/NavigateToChatController.swift)

### 4.3 稳定聊天节点与加载占位

Telegram 的 `ChatControllerNode` 同时持有：

- 聊天背景。
- 消息 `historyNode`。
- 输入区域。
- 其他聊天页面子节点。

历史数据尚未就绪时，`ChatLoadingPlaceholderNode` 被放在背景上方；历史 ready 后占位节点淡出。它不是先构建一棵聊天轻壳，再用另一棵完整聊天树替换。

源码：

- [Telegram ChatControllerNode.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUI/Sources/ChatControllerNode.swift)

### 4.4 响应式历史窗口

Telegram `ChatHistoryListNode` 的已确认行为包括：

- 初始 `historyMessageCount = 44`。
- `chatHistoryViewForLocation` 输出 `Loading` 或 `HistoryView`。
- history view 被映射为 prepared/mapped list transition。
- transition 以 insert/delete/update 等增量形式进入现有列表。
- 接近历史边缘时移动 location、填补 holes。
- `prefetchManager` 根据滚动方向预取 earlier/later messages。

源码：

- [Telegram ChatHistoryListNode.swift](https://github.com/TelegramMessenger/Telegram-iOS/blob/master/submodules/TelegramUI/Sources/ChatHistoryListNode.swift)

## 5. 核心差异

### 5.1 导航开始时机

当前项目已经把首屏准备改为后台任务，点击后立即进入或复用 Chat route。400ms 只限制 warm 任务，不再限制导航开始时间。

Telegram 会完成必要的 peer/forum 前置检查，但不会把完整聊天历史窗口作为稳定聊天节点存在的必要条件；历史 loading 属于聊天节点内部状态。

### 5.2 页面和控制器复用

当前项目现在通过 `AppChatRouteRegistry` 按 `Navigator + conversation session key` 注册活动 Chat route：同一会话已在当前导航栈时，`openOrReuseAppChat` 会 pop 回已有 route；不存在时才创建新的 Chat route。搜索锚点属于新的导航 subject，目前仍保留独立 route，避免复用时丢失目标消息定位。

复用路径现在与 `Navigator.push` 保持同一完成语义：`openOrReuseAppChat` 返回已有 route 的 `popped` Future，只有聊天 route 真正退出后调用方才执行 leave finalize 和列表 hydrate，不再把 `popUntil` 完成误判为“用户已经离开聊天”。

Telegram 默认先检查导航栈并复用相同聊天控制器；当前项目已对齐普通会话打开，后续仍可补充“在已有 Chat State 内激活目标消息”的能力。

### 5.3 首帧结构

当前项目对齐后的 cold 路径：

```text
稳定 TIMUIKitChat → history/window 增量进入同一消息树
```

Telegram：

```text
稳定 ChatControllerNode
  └─ loading placeholder → history transitions
```

两者现在都以稳定聊天节点承接加载状态；当前项目仍需继续减少 Flutter/SDK 之间的多层消息提交边界。

### 5.4 首批历史消息

当前项目通过列表 warm、app bootstrap、UIKit hydrate 和 SDK history 多层协作得到首窗。

Telegram 从 Postbox/Engine 的响应式 history view 获得初始窗口，并持续用 list transition 更新。

### 5.5 状态所有权

当前项目相关状态分布在：

- `ConversationListNotifier`
- `ConversationLocalStore`
- `ConversationTabStore`
- `ConversationHistoryWarmScheduler`
- `ChatEntrySnapshot`
- `ChatHistoryPeekBootstrap`
- `TUIChatGlobalModel`
- Tencent SDK local/cloud history

Telegram 同样是复杂客户端，但聊天进入主轴更集中于稳定 ChatController、ChatControllerNode、Postbox/Engine history view 和 list transition。

“Telegram 的已读状态完全由同一数据图原子处理”不能由当前引用源码充分证明，只能作为架构方向推断。

### 5.6 消息列表更新方式

当前项目需要在多个 snapshot、merge、replace、dedupe 和 reconcile 阶段之间协调，最终交给 Flutter Sliver。

Telegram 将响应式 history view 映射为增量 list transition，并应用到同一个 historyNode。

### 5.7 交互开放时机

当前项目显式区分：

```text
created → historyReady → interactive → enriched
```

在 thin/cold 情况下，聊天树和输入区保持可交互；history gate 只作为历史准备与后续任务调度的生命周期信号。

Telegram 更接近“稳定节点先存在，placeholder 和 history transition 在节点内部变化”。

### 5.8 返回列表恢复

当前项目返回后还会：

- finalize unread/read 状态。
- patch 刚离开的会话。
- 恢复列表滚动锚点。
- 必要时重新 hydrate 虚拟会话窗口。

这使返回列表成为另一轮状态对账，而不只是简单 pop。

## 6. warm 与 cold 的体感差异

### 6.1 warm 命中

首窗已经准备完整时，当前项目可以首帧直接挂 `TIMUIKitChat`，体验会接近 Telegram：进入后立即看到可用消息列表。

### 6.2 cold 未命中

当前项目现在并行执行：

```text
route transition + 稳定聊天树首帧
                 ↘ 后台 warm/bootstrap/UIKit/SDK 历史提交
```

用户可能感受到：

- 网络或本地缓存很冷时，消息区可能短暂没有内容。
- 多层历史提交不稳定时，首屏仍可能重新定位。
- 输入区和页面导航不应再因为 history gate 被整体锁住。

Telegram 使用专用 placeholder；当前项目现阶段依赖 UIKit 自身加载表现。二者已经共享“同一聊天树持续 ready”的结构，但占位视觉仍可继续对齐。

## 7. 与当前异常的关系

### 7.1 未读清零后回弹

**强相关，但需要通过日志确认具体回写源。**

最可能的风险窗口是：

```text
列表本地 unread = 0
  ↓
SDK clean 尚未确认
  ↓
UIKit markMessageAsRead 尚未完成
  ↓
旧 SDK / LocalStore / 虚拟列表快照重新 hydrate
  ↓
旧 unread 覆盖本地乐观结果
```

进入聊天不是唯一原因，但三阶段已读和返回列表补水为旧状态回写提供了多个边界。

### 7.2 置顶对话没有保持顶部

**不是聊天进入链的直接原因。**

直接原因更可能位于：

- 置顶字段的权威来源不一致。
- 会话排序在某次 patch/hydrate 后只按时间重排。
- LocalStore、TabStore 与 UI 虚拟窗口对置顶字段的投影不同步。

返回聊天后的列表 patch/hydrate 可能触发或暴露该问题，但不能据此认定导航逻辑是根因。

### 7.3 RenderSliverMultiBoxAdaptor 异常

**聊天打开链更像放大器，直接根因仍在消息列表提交和 child identity。**

直接风险包括：

- snapshot/merge/replace 后 item identity 不稳定。
- 重复消息 ID 或重复 Key。
- prepend/replace 后 `findChildIndexCallback` 与真实列表不一致。
- itemCount 与当前不可变数据快照不同步。
- child 已留在 Sliver 链中，但对应 layoutOffset/geometry 不再有效。

cold 打开时已不再发生轻壳到重体挂载；bootstrap 首窗、UIKit 初始 hydrate 和 older history 补齐仍可能在短时间产生多次提交，因此 Sliver 提交风险尚未完全消除。

分页 prepend/reveal 路径已经把稳定消息 Key 提升到 `SliverChildBuilderDelegate` 的直接 child；`Opacity`、测量和 reveal wrapper 不再遮蔽 child identity。剩余风险主要是整窗 replace、多写入者，以及消息在已读/未读两个 Sliver 之间迁移。

## 8. 建议的收敛方向

### P0：稳定聊天树优先（已完成第一阶段）

移动端路由开始后现在立即存在稳定的真实聊天树，已消除：

- push 前的 warm 阻塞等待。
- 轻壳到完整聊天树的 remount。
- history gate 对整页交互的锁定。
- route 复用后 Future 提前完成并误触发 leave finalize。
- 分页 reveal 外层 wrapper 丢失 Sliver 直接 child Key。

### P0：首窗消息建立唯一权威与版本规则

需要明确：

- warm snapshot 是否只能作为 seed。
- bootstrap、UIKit hydrate、SDK older load 的提交顺序。
- 每次提交对应的 conversation、generation 和 snapshot version。
- 旧 generation 的结果不得覆盖当前聊天。
- 更新优先采用稳定 ID 的增量 transition，避免整表 replace。

### P1：已读状态机统一并可观测

建议把已读生命周期明确为：

```text
localCleared
  → sdkCleanPending
  → sdkConfirmed
  → uikitMarked
  → listFinalized
```

每一步都应具有：

- conversationID。
- open generation。
- unread version 或事件时间。
- 幂等规则。
- 旧状态拒绝原因。

这样才能准确区分 unread 回弹来自 SDK 晚到、旧列表 hydrate，还是 UIKit/read finalize 时序。

## 9. 宽屏模式例外

当前项目宽屏通过 `onConversationChanged` 在右侧容器中切换 conversation：

- `lib/src/pages/cross_platform/wide_screen/conversation_and_chat.dart:408`

它不会走移动端的 `prepareForOpen + Navigator.push`，结构上更接近稳定容器切换，但仍不等同于 Telegram 的导航栈 ChatController 复用机制。

## 10. 后续验证建议

如果要继续判断应该从哪一层改，建议为一次进聊生成统一 `openGeneration`，至少记录以下时间点：

```text
tap
localUnreadCleared
prepareForOpenStart / End / Timeout
routePushStart
chatFirstFrame
heavyBodyMounted
firstHistoryCommitted
historyGateReleased
sdkReadConfirmed
routePopped
conversationListFinalized
```

同时记录每次消息提交的：

- conversationID。
- generation。
- source（warm/bootstrap/UIKit/local/cloud/reconcile）。
- previousCount、incomingCount、nextCount。
- message ID signature。
- 是否 prepend、replace 或 incremental transition。

这些数据可以把“视觉上进入页面”和“消息首窗真正可交互”分开测量，并直接关联 unread 回弹及 Sliver 异常发生在哪次提交之后。
