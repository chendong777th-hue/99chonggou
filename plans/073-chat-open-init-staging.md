# Plan 073: 分阶段执行聊天页初始化

> **Executor instructions**: 先阅读本计划全文。只修改 Scope 内文件；发现当前代码与 Current state 不一致时停止并报告。

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

进入群聊时，IM 登录、历史、群详情、禁言、成员、群游戏和三公配置可能在同一窗口并发完成，多个回调分别触发 UI 更新。结果是首帧竞争、重复请求和首屏掉帧。目标是保留首屏消息语义，只把非首屏资料任务移到 SDK 首次历史提交和首帧之后。

## Current state

- `lib/src/chat.dart:5024-5059` 先读本地群资料占位。
- `lib/src/chat.dart:5150-5161` 刷新群资料并应用快照。
- `lib/src/chat.dart:5231-5260` 的 `_loadGroupGameStatus` 使用 `Future.wait` 同时请求群游戏状态、三公权限、三公配置和群详情。
- `lib/src/chat.dart:1304-1358` 进入群聊时刷新禁言状态。
- 三公 `403` 是可选权限结果，不能阻塞聊天首帧。

## Scope

**In scope**:

- `lib/src/chat.dart`
- `test/` 中新增聊天初始化时序单测或契约测试

**Out of scope**:

- 腾讯 IM SDK 历史分页语义、分页数量和排序
- 群资料字段优先级
- 三公后端接口协议
- 输入框、键盘、媒体上传

## Steps

### Step 1: 建立初始化阶段状态机

将进入群聊任务分成 `sdkReady/historyReady`、`localMetadataReady`、`backgroundEnrichment` 三阶段。首阶段只等待当前 IM 会话可用和 SDK 历史；本地资料占位可在首帧同步应用；群成员、禁言、群游戏和三公配置必须通过 `unawaited` 的受控单飞任务在首帧后执行。每个任务检查 conversation generation 和 `mounted`。

**Verify**: `flutter test test/chat_open_*test.dart` → 新增时序测试全部通过。

### Step 2: 合并群游戏请求完成通知

保留现有缓存秒开，但把 `_loadGroupGameStatus` 的多个 `setState` 合并为一次快照提交；三公 403 只更新“无权限/未配置”状态，不触发聊天页失败态。

**Verify**: `flutter test test/group_game*test.dart test/chat_open_*test.dart` → 通过且无重复请求断言失败。

### Step 3: 添加首帧指标

记录 `chat_open_sdk_ready_ms`、`chat_open_history_ready_ms`、`chat_open_metadata_ms`、`chat_open_background_enrichment_ms`，只记录耗时、数量和阶段，不记录正文、用户 ID、群 ID 或 token。

**Verify**: `git diff --check`；Profile 日志中每次打开最多一条各阶段完成记录。

## Done criteria

- [ ] 首帧不等待三公/成员/禁言等非首屏任务
- [ ] 同一群聊 generation 只有一个资料刷新任务
- [ ] 页面切换后旧任务不能 `setState` 或写消息列表
- [ ] 现有群名、人数、公告、未读和历史语义测试通过
- [ ] Profile 首帧主线程耗时不高于基线，且无消息缺失

## STOP conditions

- 若 SDK 历史必须依赖群详情才能建立 conversation ID，停止并报告，不改变 ID 解析。
- 若三公状态参与消息发送权限而非仅 UI 入口，停止并报告，不延后该请求。
- 若需要修改 UIKit vendor 文件才能完成阶段状态机，停止并拆出新计划。

## Maintenance notes

以后新增进入群聊网络任务必须明确属于首帧阻塞阶段还是后台 enrichment 阶段，并接入同一 generation 取消机制。
