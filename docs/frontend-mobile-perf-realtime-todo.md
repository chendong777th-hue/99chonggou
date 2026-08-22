# 移动端性能 & 实时性 — 前端修改清单

> 状态：进行中（客户端 Phase A/B 已按清单落地，待真机回归）  
> 范围：**仅客户端**，不依赖后端发版即可落地  
> 关联审计：会话旁 Canvas `mobile-perf-realtime-audit`  
> 后端配合项见：[backend-mobile-realtime-todo.md](./backend-mobile-realtime-todo.md)

### 落地进度（2026-08-14）

| 项 | 状态 |
|----|------|
| 2.1 入站揭示自适应 | 已做（UIKit enqueue 按队列自适应 + 纯函数单测） |
| 2.2 好友申请轮询门禁 | 已做（60s + `isRealtimeReady` 跳过 + authOk 多播补偿） |
| 2.3 Header skip 短路 | 已做（skip 不改 changed；Profile 才打日志） |
| 2.4 成员 sync 延迟 | 已做（3s/1s → 500ms） |
| 2.5 resume 审批防抖刷新 | 已做（1s 防抖） |
| 2.6 ChatOpenPerf Profile | 已做（`isEnabled`） |
| 2.7 tip 映射核对 | 已确认 `previewAbstract` 优先；锁屏字面量仍靠后端 |

---

## 1. 目标

| 目标 | 说明 |
|------|------|
| 降「假延迟」 | 群聊/单聊连发时，入站气泡不要故意一条条拖太久 |
| 降耗电/请求 | 好友申请在 TCP 正常时不要 15s 轮询 |
| 减空跑 | Header 头像 local-newer skip 路径不要多余 rebuild |
| 提成员体感 | 邀请/补成员后权威人数对齐更快（仍保留 cooldown 防双拉） |
| 可观测 | Profile 下可开进聊天耗时探针 |

**非目标（本清单不做）**

- 大改 `ConversationPerfFlags` 滑动窗/写库节奏  
- Presence 心跳协议重做  
- LiveKit / CallKit 音频（另案）  
- 钱包 UI、伪造未约定的 TCP 事件解析  

---

## 2. 改动项

### 2.1 入站消息揭示自适应（P1）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/chat.dart`（`TIMUIKitChatConfig`）；必要时最小改 `third_party/.../tui_chat_global_model.dart` |
| 现状 | `inboundChunkRevealMaxChunk: 1`，`inboundChunkRevealIntervalMs: 160` |
| 改法 | 按待揭示队列长度自适应：`≤2 → chunk1/160ms`；`3–8 → chunk3/160ms`；`≥9 → chunk6/80ms` |
| 可测 | 纯函数 `inboundRevealParams(queueLen)` + `test/inbound_chunk_reveal_params_test.dart` |
| 降级 | 若动态接入成本过高：静态改为 MaxChunk=`3`、Interval=`100`，交付注明折中 |

### 2.2 好友申请轮询：TCP 健康时跳过（P1）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/services/friend_realtime_service.dart`、`lib/src/services/friend_request_notice_service.dart` |
| 现状 | `Timer.periodic(15s)` 无条件拉申请 |
| 改法 | ① 增加 `FriendRealtimeService.isRealtimeReady`（running 且已连接且未 authFailed）② 周期改为 **60s**，`isRealtimeReady==true` 时跳过 poll ③ `ensureRunning` 首次、`resumed`、`onAuthOk` 仍立即补偿拉取 |
| 可测 | `shouldPollFriendRequests(realtimeReady:)` 单测 |

### 2.3 Chat Header 头像 skip 短路（P2）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/chat.dart`（`_logGroupHeaderAvatarSource` / `conversation_model_update_skipped_local_newer` 调用链） |
| 现状 | Profile 下大量 skip 日志；需确认 skip 后无多余 `setState`/整页 notify |
| 改法 | local-newer 判定后立即 return；保持「本地较新优先」语义；日志仍仅 `kProfileMode` |

### 2.4 邀请/补成员后 sync 延迟缩短（P2）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/api/group_member_api.dart` |
| 现状 | `added` 后 `syncForGroup` 延迟 **3s**；`heal_already_member` **1s** |
| 改法 | 均改为 **500ms**；热路径仍 `unawaited`；保留 membership snapshot cooldown |

### 2.5 回前台加群申请列表防抖刷新（P2）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/services/group_join_application_service.dart`（及 lifecycle 挂接处，如 `FriendRequestNoticeService.onAppLifecycleChanged`） |
| 现状 | resume 有群通知 bootstrap，审批列表实时性偏 REST |
| 改法 | `resumed` 时对 `GroupJoinApplicationService.refresh(force: true, syncMembership: false)` **1s 内最多一次** |
| 注意 | **不要**解析未上线的 TCP 事件名（等后端契约） |

### 2.6 ChatOpenPerf Profile 可开（P2）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/services/chat_open_perf_log.dart` |
| 现状 | `enabled = false` |
| 改法 | `enabled \|\| (kProfileMode && enabledInProfile)`，`enabledInProfile` 默认 `true`；Release 默认仍关 |

### 2.7 tip 推送文案映射核对（P2，只读/小补）

| 项 | 内容 |
|----|------|
| 文件 | `lib/src/utils/notification_push_text.dart` 等 OfflinePush 构建路径 |
| 改法 | 确认 `businessID=group_tip` 优先用 `previewAbstract`；缺则补映射一行 |
| 说明 | **锁屏仍显示 `group_tip` 字面量时，主因在后端 Push**，见后端文档 |

---

## 3. 建议实现顺序

1. 2.1 入站自适应 + 单测  
2. 2.2 好友轮询门禁 + 单测  
3. 2.4 成员 sync 延迟  
4. 2.5 resume 审批刷新防抖  
5. 2.3 Header 短路  
6. 2.6 / 2.7 观测与核对  

---

## 4. 验证

| # | 场景 | 期望 |
|---|------|------|
| 1 | 相关 `flutter test` | 全绿 |
| 2 | 群聊连发约 10 条 | 跟上速度优于 MaxChunk=1；非连发仍自然 |
| 3 | TCP 正常挂机 5min | 好友申请 HTTP 轮询 ≪ 每 15s 一次 |
| 4 | 断网/断 TCP 后 resume | 仍能补偿看到新申请 |
| 5 | 邀请进群 | 人数约 ≤1s 级对齐（允许 cooldown 特例） |

真机项无法跑时交付标 `NOT RUN`。

---

## 5. 回滚

| 项 | 回滚 |
|----|------|
| 入站 | MaxChunk=1，Interval=160 |
| 好友轮询 | 15s 且去掉 ready 门禁 |
| 成员 delay | 改回 3s / 1s |

---

## 6. 与后端文档关系

前端本清单合入后即可改善体感。下列能力**必须后端**才有完整实时性，前端只预留挂点、不提前解析：

- 加群审批 TCP  
- 群 tip 离线 Push 正文  
- 钱包余额/订单实时事件  

详见 [backend-mobile-realtime-todo.md](./backend-mobile-realtime-todo.md)。
