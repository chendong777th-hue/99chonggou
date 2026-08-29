# Plan 083: 修复会话列表切换后滚动失效

## Status

- Priority: P0
- Effort: M
- Risk: HIGH
- Depends on: 061, 063, 072
- Category: correctness / perf
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

用户反馈会话列表偶发完全不能滑动，但底部 Tab 仍可点击；切换 Tab 后返回，原列表仍不能滑动。这说明页面事件循环没有完全卡死，问题更可能是列表 ScrollPosition、FeedGate 切换、虚拟 hydrate 状态或 Slidable 手势状态未释放。当前 cached ListView 与 active Feed 都复用同一个 `_feedScrollController`，而 FeedGate 会在同步状态变化时切换两套树，存在生命周期交错风险。

## Current state

- `lib/src/widgets/conversation_feed/conversation_feed_sync_gate.dart` 根据同步状态在 cached feed 和 active feed 之间切换。
- `lib/src/conversation.dart:4338-4342` 的缓存列表与 `conversation_feed_body.dart:785-791` 的正式虚拟列表共享 `_feedScrollController`。
- `lib/src/widgets/conversation_feed/conversation_feed_body.dart:190-240` 使用 `isScrollingNotifier` 和 post-frame hydrate；失活/切换时需要清除 pending 状态。
- `lib/src/widgets/conversation_feed/lazy_conversation_slidable.dart` 和 `conversation_slidable.dart` 参与横向手势竞争。
- 当前不能通过强制 `jumpTo`、重建整个页面或放大 hydrate 窗口来伪造恢复。

## Scope

In scope:

- `lib/src/widgets/conversation_feed/conversation_feed_sync_gate.dart`
- `lib/src/widgets/conversation_feed/conversation_feed_body.dart`
- `lib/src/widgets/conversation_feed/lazy_conversation_slidable.dart`
- `lib/src/widgets/conversation_feed/conversation_slidable.dart`
- `lib/src/conversation.dart`
- 新增滚动冻结诊断和契约测试

Out of scope: 会话数据源、SDK 历史消息、会话排序、置顶/归档业务语义、消息列表聊天页。

## Steps

1. 先加入默认关闭、发布版不输出的诊断快照，记录 `ScrollController.positions.length`、offset、maxScrollExtent、ScrollActivity、isScrolling、TickerMode、routeVisible、FeedGate cached/active、pending hydrate 和 Slidable open 状态。
2. 为 FeedGate 明确 cached→active 的单一挂载顺序，确保同一 `_feedScrollController` 不同时绑定两个 ScrollPosition；切换时保留合法 offset，不复用失效 PageStorage 状态。
3. 在 Tab 失活、FeedGate 模式切换和 dispose 时清理 virtual hydrate 的 scheduled/pending 状态，并移除失效的 scroll listener。
4. 为 Slidable 增加 pointer cancel、页面失活和 Tab 切换时的强制关闭/释放，不得阻止纵向滚动手势。
5. 只有在确认 ScrollPosition 合法且没有活动拖拽时，才执行必要的 offset 恢复；禁止无条件 `jumpTo` 或全页面重建。

## Verification

- 新增测试覆盖：cached→active、active→cached、Tab 快速切换、滚动中切换、打开 Slidable 后切换、虚拟 hydrate pending 时切换、返回页面后继续拖动。
- 运行会话列表、虚拟 hydrate、Slidable 和生命周期定向测试，全部通过。
- 真机/Profile 验收：连续切换 Tab 50 次，列表仍可拖动；卡住时诊断显示 `positions.length == 1`、无残留 drag/ballistic activity、pending hydrate 可清理。
- `git diff --check` 通过。

## STOP conditions

- 发现需要修改会话数据源或排序才能恢复滚动；
- 必须放大虚拟 hydrate 窗口、禁用虚拟列表或强制整页重建；
- 无法区分 cached/active 两套列表的 ScrollPosition 所有权；
- 修复会改变用户当前滚动位置或编辑/滑动菜单语义。

## Maintenance notes

后续新增 Overlay、Tab、FeedGate 或滑动菜单时，必须声明其 pointer/ScrollPosition 生命周期；任何共享 ScrollController 的新列表都需要通过同一挂载门禁。
