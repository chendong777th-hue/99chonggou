# Plan 079: 将聊天页初始化改为有界阶段预算

## Status

- Priority: P1
- Effort: M
- Risk: MED
- Depends on: 073, 076
- Category: perf / correctness
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

进入群聊会同时触发历史、群资料、成员、C2C 资料、已读、权限、通话历史和业务卡片。073/076 已增加阶段和 generation，但缺少统一的并发预算与超时观测，仍可能出现首帧资源竞争或后台回调堆积。目标是让首帧只依赖消息和输入框，其余任务按阶段、有界并发、可取消执行。

## Current state

- `lib/src/chat.dart` 已有 chatOpenGeneration、post-frame 分阶段调度和生命周期门禁。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` 在初始化和历史完成后仍会触发群资料、已读和成员相关异步工作。
- `lib/src/conversation.dart:880-886` 仍使用 `Future.wait` 同时刷新多个群 Tab 数据源；这属于列表页高频路径，必须与聊天页预算分开。

## Scope

In scope:

- `lib/src/chat.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- 聊天打开阶段测试、性能指标和任务调度器

Out of scope: SDK 历史 API、群资料字段权威、会话列表排序、输入法行为、通话音频。

## Steps

1. 定义 chat-open 状态机：Created→HistoryReady→Interactive→Enriched→Disposed；每阶段声明必需任务、并发上限和超时。
2. 首帧阶段禁止网络资料、头像高清解码、通话历史和业务卡片；这些任务进入可取消 enrichment 队列。
3. 同类任务按 conversation+generation 单飞，跨类别最多有限并发；页面退出、切会话和后台时取消未开始任务。
4. 为每阶段记录数量和耗时，不记录正文、用户 ID、群 ID 或 token；发布版默认关闭。
5. 用现有 073/076 generation 门禁所有状态写入，并补充超时后的可恢复状态。

### 主线程边界

`addPostFrameCallback` 只表示在当前帧绘制结束后运行，不等于后台线程。post-frame 回调中只能登记或启动可取消任务；不得同步解析大 JSON、扫描整表、读取大文件或执行图片解码。需要后台处理的内容必须使用已有安全的异步/原生能力，并在返回 UI 前检查 generation。

## Verification

- 首次安装、暖启动、长历史群、图片群、前后台恢复测试通过。
- 新增测试验证任务只执行一次、切会话旧任务不写 UI、超时不阻塞输入框。
- 现有 `chat_open_*`、生命周期和群资料测试全部通过。
- 真机 Profile 中首帧到可输入时间、`history_ready_ms`、`metadata_ms` 和键盘首帧 hitch 不回退。
- Profile/Timeline 证据显示 post-frame 回调自身不包含超过一帧的同步工作；`image_decode_ms`、`keyboard_layout_ms` 和首帧总耗时均有记录。

## STOP conditions

- 必须在首帧等待群资料或成员数据；
- 取消任务会改变未读、通话、钱包或群资料语义；
- 无法为异步回调提供 conversation+generation 门禁。

## Maintenance notes

所有新增聊天页初始化任务必须登记到状态机，不得在 `initState`、历史回调或 `didUpdateWidget` 中直接启动无预算 Future。
