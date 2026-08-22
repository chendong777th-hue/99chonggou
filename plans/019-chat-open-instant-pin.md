# 计划 019：打开聊天即时贴底（不要从底往上浮）

## 状态

- **优先级**：P1
- **工作量**：S
- **风险**：低
- **依赖**：无
- **类别**：UX / 性能手感
- **状态**：已完成（2026-08-22）

## 原因

进聊天时历史会**从底部滑上来**。原因：`Opacity=0` 测量之后，软/强制贴底用了 `animateTo`（默认 `inboundScrollFollowMode.smooth`），首批可见帧是滚到位的。

## 修复

1. `_commitHistoryOpenRevealReady`：在 `_historyOpenRevealPainted = true` **之前**调用 `_pinScrollToBottomImmediate()`。
2. `_scrollToBottomTarget`：未绘制 / 初始沉降（2.5s）/ 揭示后微窗（500ms）期间用 jump。
3. Bootstrap 结束：用 `_pinScrollToBottomImmediate()`，不要软调度 pin。

## 验证

```bash
flutter test test/chat_open_instant_pin_contract_test.dart
```

## STOP

- 沉降后不要关掉现场入站平滑跟随。
- 没有测过的 jump-first 路径时，不要去掉 Opacity 门禁。
