# 移动端性能 & 实时性 — 后端待办

> 状态：待后端排期  
> 受众：自建 IM / Push / 业务 API  
> 客户端可先独立做的优化见：[frontend-mobile-perf-realtime-todo.md](./frontend-mobile-perf-realtime-todo.md)  
> 已有专项（请直接按该文改，勿重复发明）：[backend-group-tip-offline-push.md](./backend-group-tip-offline-push.md)

---

## 0. 为何需要后端

客户端侧会话削峰、好友 Difference、群 Entity/成员/通知 changes 已较完整。  
审计后仍偏弱、且**客户端无法单独修干净**的，主要是：

1. 加群申请 / 邀请待审的**秒级多端同步**  
2. 群 tip **离线推送正文**（锁屏显示 `group_tip`）  
3. 钱包余额 / 订单状态的**实时事件**  
4. **群直播场次状态**（已去生命周期 IM，需 TCP + `current`）→ 见 **[backend-group-live-realtime-todo.md](./backend-group-live-realtime-todo.md)**

另有两项「加强项」，非阻塞但建议一并排期。

---

## 1. P0 — 群 tip 离线推送正文

| 项 | 内容 |
|----|------|
| 优先级 | **P0**（用户感知强、客户端已带齐字段） |
| 专文 | **[backend-group-tip-offline-push.md](./backend-group-tip-offline-push.md)**（以该文为准） |
| 现象 | 锁屏/通知栏正文为字面量 `group_tip`，而非「张三邀请李四加入群组」 |
| 根因方向 | Push 映射误用 `businessID`，未用 Custom `data.previewAbstract` |
| 客户端现状 | App Custom：`businessID=group_tip`，含完整 **`previewAbstract`**；自建 Push 开启时 IM `disablePush: true` |
| 后端必做 | `businessID == group_tip` 时 body/alert = `previewAbstract`（空则按 action 拼装）；**禁止**把 `group_tip` 当正文 |
| 验收 | 设管理员/邀请加人等离线通知 body = 完整中文 tip，≠ `group_tip` |

---

## 2. P0 — 加群申请 / 邀请审批实时

| 项 | 内容 |
|----|------|
| 优先级 | **P0** |
| **正式契约** | **[group-join-invite-client.md](./group-join-invite-client.md)** §5–§6（以该文为准） |
| 现象 | 管理员多端、申请人侧状态若未接 TCP，会偏 REST |
| 客户端现状 | REST `approve/reject` + `GET /me/join-applications`；TCP action 名已在 `GroupSyncService` 白名单 |
| 服务端 TCP | 挂在 **`group_changed`** 下，**不是**独立 `join_application_changed` event |

| action | 推送给 | 客户端应做 |
|--------|--------|------------|
| `join_application_pending` | 群主/管理员 | 刷新待审列表 / 红点 |
| `join_application_handled` | 全部管理员 ∪ 申请人 ∪ 邀请被邀请人 | 刷新/移除待审；勿只给申请人推 |
| `member_added` | 全员 | 成员增量（已有） |
| `group_join_option_changed` | 全员 | 刷新 join-options |

**勿再**：系统 Push / 系统号 C2C / 客户端发 `INVITE_RESULT` / 依赖 IM `onApplicationProcessed`。

### 2.1 `join_application_handled` detail（摘自正式文档）

见 [group-join-invite-client.md](./group-join-invite-client.md) §5 JSON 示例（`applicationId` / `status` / `operatorUserId` / `updatedAt` 等）。

### 2.2 验收

| # | 场景 | 期望 |
|---|------|------|
| 1 | 管理员 A 同意，管理员 B 在线 | B 秒级更新申请状态（`join_application_handled`） |
| 2 | 新待审产生 | 管理员收到 `join_application_pending` |
| 3 | 邀请待审通过 | 相关方 + 全员 `member_added` 一致 |

---

## 3. P1 — 钱包余额 / 订单实时

| 项 | 内容 |
|----|------|
| 优先级 | **P1** |
| 现象 | 订单详情 / 余额多靠进页 refresh；红包过期等仅部分 TCP（`red_packet_changed` 主要服务发包人） |
| 客户端挂点 | `WalletOrderEvents.notifyRecord` / `notifyBalance`；红包 `RedPacketRealtimeSyncService` |
| 建议 | 统一业务事件（TCP 或高优推送），例如： |

### 3.1 建议事件（草案，可协商）

| event / action | 含义 | 客户端预期 |
|----------------|------|------------|
| `wallet_balance_changed` | 余额变动 | `notifyBalance` |
| `wallet_order_changed` | 某订单状态变 | `notifyRecord`（带 `orderId`） |
| 现有 `red_packet_changed` | 保持；与钱包事件职责划分清楚 | 不重复刷爆 |

### 3.2 最低字段

- `orderId` / `currency` / `balance`（若方便）/ `updatedAt`  
- 鉴权：仅推给订单当事人  

### 3.3 验收

充值/兑换/红包退回后，**不打开详情页**也能在记录列表或余额入口看到更新（或角标/总线已刷新）。

---

## 4. P2 — 加强项（非阻塞）

### 4.1 群 Entity TCP 带齐 seq 与展示字段

- 参考：[group-entity-incremental-sync-client.md](./group-entity-incremental-sync-client.md)、[backend-group-entity-seq-sync-todo.md](./backend-group-entity-seq-sync-todo.md)  
- `group_changed.detail` 尽量带 **`seq`** + 完整 `groupName` / `avatarUrl`  
- 避免客户端游标与展示依赖二次 REST  

### 4.2 好友申请 TCP 投递可靠性

- 客户端将改为：TCP ready 时停高频轮询  
- 后端需保证好友申请相关 realtime 事件**少丢、可重连补偿**（与现有 `friend_*` / 申请事件对齐）  
- 重连后客户端仍会 Difference/补偿拉；服务端勿假定「只推一次」

---

## 5. 明确不要求后端做的（前端自负）

- 入站气泡揭示节奏  
- 好友 15s→健康时停轮询的策略  
- Header 头像 skip  
- 邀请后 `syncForGroup` 延迟从 3s 改为 500ms  
- Profile 下 ChatOpenPerf  

---

## 6. 建议排期

| 顺序 | 项 | 说明 |
|------|----|------|
| 1 | §1 tip 离线 Push | 专文已写清，改动面小、收益大 |
| 2 | §2 加群审批 TCP | 补齐最大实时缺口 |
| 3 | 群直播 TCP + current/304 | [backend-group-live-realtime-todo.md](./backend-group-live-realtime-todo.md) |
| 4 | §3 钱包事件 | 可与支付/红包迭代绑在一起 |
| 5 | §4 加强项 | 有余力再做 |

客户端 §2 / §3 事件名与字段**定稿后**再开前端解析 PR，避免半套协议。

---

## 7. 联系与联调

- 联调时抓：TCP 原始 JSON、Push 落库 body、对应 REST 申请单 ID  
- 客户端日志关键字：`GroupInviteDiag`、`FriendRealtime`、`group_tip`、`previewAbstract`
