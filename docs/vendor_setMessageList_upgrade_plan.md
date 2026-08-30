# 第三方 UIKit `setMessageList` 残留升级预案

更新时间：2026-08-30 (IM-10 stage 0 + IM-11 stage 0 收口)

本文列出 `third_party/tencent_cloud_chat_uikit/lib/` 中所有 18 处 `setMessageList`
直接调用,以及升级 vendor 时必须按 `docs/im10_overlay_row_namespace.md` §2.5 收口的
路径。vendor 不能改,但升级时**必须**把全部命中替换为走
`MessageReconciliationWriter.commitMessageDelta(...)`,否则 IM-10 phase J 静态门禁
退出条件被破坏。

## 0. 不变量

UIKit 的 `setMessageList` 函数已经支持 `writerCommit` 参数
(`tui_chat_global_model.dart:9220` 接受 `MessageReconciliationWriterCommit?`),
但 17 个调用方均未传,默认走 legacy 回回路径。升级 vendor 时,必须把所有 17
个调用方改为传入 `writerCommit`,只剩 1 处为函数定义本身 (line 9200)。

## 1. 残留表 (vendor 升级时按此清单替换)

| # | 文件 | 行号 | 当前调用 | 升级动作 |
|---|---|---|---|---|
| 1 | tui_chat_global_model.dart | 521 | `return setMessageList(` | 传入 `writerCommit` |
| 2 | tui_chat_global_model.dart | 645 | `final result = setMessageList(` | 传入 `writerCommit` |
| 3 | tui_chat_global_model.dart | 1294 | `return setMessageList(` | 传入 `writerCommit` |
| 4 | tui_chat_global_model.dart | 5047 | `setMessageList(` | 传入 `writerCommit` |
| 5 | tui_chat_global_model.dart | 5154 | `setMessageList(` | 传入 `writerCommit` |
| 6 | tui_chat_global_model.dart | 5402 | `final commit = setMessageList(` | 传入 `writerCommit` |
| 7 | tui_chat_global_model.dart | 9200 | `MessageCommitResult setMessageList(` | **函数定义本身,保留** |
| 8 | tui_chat_separate_view_model.dart | 743 | `final commit = globalModel.setMessageList(` | 传入 `writerCommit` |
| 9 | tui_chat_separate_view_model.dart | 1332 | `globalModel.setMessageList(` | 传入 `writerCommit` |
| 10 | tui_chat_separate_view_model.dart | 1566 | `globalModel.setMessageList(` | 传入 `writerCommit` |
| 11 | tui_chat_separate_view_model.dart | 3496 | `globalModel.setMessageList(` | 传入 `writerCommit` |
| 12 | tui_chat_separate_view_model.dart | 3671 | `globalModel.setMessageList(` | 传入 `writerCommit` |
| 13 | tui_chat_separate_view_model.dart | 3992 | `globalModel.setMessageList(conversationID, messageList);` | 传入 `writerCommit` |
| 14 | tui_chat_separate_view_model.dart | 7311 | `globalModel.setMessageList(conversationID, currentHistoryMsgList);` | 传入 `writerCommit` |
| 15 | tui_chat_separate_view_model.dart | 8348 | `final commit = globalModel.setMessageList(convID, next, replace: true);` | 传入 `writerCommit` |
| 16 | tui_chat_separate_view_model.dart | 8373 | `globalModel.setMessageList(convID, list, replace: true);` | 传入 `writerCommit` |
| 17 | tui_chat_history_pagination_load.dart | 1251 | `model.globalModel.setMessageList(` | 传入 `writerCommit` |
| 18 | tim_uikit_chat.dart | 2065 | `globalModel.setMessageList(` | 传入 `writerCommit` |

## 2. 升级验收

升级 vendor 后,执行 `tool/im10_migration_scan.ps1` 应报告:

```
[lib/src] setMessageList hits : 0
[lib/src] messageListMap writes : 0
[third_party UIKit] setMessageList hits : 1   ← 只剩函数定义本身
[allowList] 0 entries (ADR §3.1)
[OK] lib/src setMessageList = 0, messageListMap writes = 0, allowList cleared.
```

如果 `[third_party UIKit] setMessageList hits > 1`,说明仍有调用方没传入
`writerCommit`,必须回去检查上面 17 行。

## 3. 升级顺序建议

1. **先 fork vendor patch**:在本地 `third_party/` 内修改,验证 lib/ 0 回归
2. **跑 `tool/im_gate.ps1`**:format + analyze + 12 个 IM 测试 + 静态门禁全 PASS
4. **跑全部 conversation 测试**:确认没有破坏 UIKit 集成
5. **跑 IM-04/IM-07 真实测试**:确认 Writer 接管 setMessageList 后消息渲染顺序正确
6. **真机验证**:Android/iOS 双端拉历史 + 实时消息 + 发送,确认无 UI 闪烁

## 4. 不要做的事

- 不要试图在 `lib/src/` 内"绕过" vendor 的 `setMessageList` 调用 (vendor 才是真实写入点)
- 不要改 UIKit 内部状态机 (chat_history_warm_scheduler 等依赖 UIKit 内部)
- 不要试图用 Dart typedef 拦截 `setMessageList` 调用 (运行时开销 + 不优雅)

## 5. 相关 ADR

- `docs/im10_overlay_row_namespace.md` §2.5 (残留表)
- `docs/腾讯IM重构_新窗口详细交接_2026-08-30.md` §14 (本轮完成项)
- `docs/99chat聊天全链路整改方案_v1.0_2026-08-30.md` 阶段 3 (Message Core 单写者)
