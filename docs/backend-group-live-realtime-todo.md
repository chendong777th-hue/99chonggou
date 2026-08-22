# 群直播 — 后端配合待办（状态同步 / 低延迟播放）

> 状态：**待后端排期**  
> 背景：已去掉 `group_live_scheduled` / `started` / `ended` 等生命周期 IM；客户端 UI 改以 **REST 为真相源**，**TCP 为在线实时主路径**  
> 客户端 API 前缀：`/group-live/api/v1`（见 `GroupLiveApi`）  
> 关联：[backend-mobile-realtime-todo.md](./backend-mobile-realtime-todo.md)

---

## 0. 目标与边界

### 0.1 要解决什么

| 用户感知 | 后端需保证 |
|----------|------------|
| 群聊顶栏出现/消失直播入口 | 场次创建、改期、撤销、关播后 **在线端秒级可见** |
| **群聊 Tab 会话列表显示「直播中 / 有直播」** | **批量索引 API（兜底）+ TCP 增量（在线）** |
| 「等待推流」→「正在直播」 | **仅 CSS 确认有流后** 才进入 `LIVE` |
| 关播后播放器/顶栏收起 | 结束态权威、及时广播 |
| 观看延迟 ≤1s | `play-info` 返回 WebRTC（快直播 LEB），FLV/HLS 作兜底 |

### 0.2 不在本文范围

- **打赏飘屏**：继续 IM `live_tip`（未改）
- **视频流本身**：走腾讯云 CSS / CDN，不经业务 TCP
- **推流地址 / 播放地址**：仍 REST 下发，**不要**塞进 TCP 正文（签名、体积、权限）

### 0.3 总方案（三层）

| 层 | 责任 | 后端 | 客户端（现状/计划） |
|----|------|------|---------------------|
| ① 实时主路径 | 在线秒级 UI | TCP `group_changed` + `group_live_changed` | 待接：聊天顶栏 + **会话列表徽标** |
| ② 写操作即时反馈 | 操作者 UI 不闪 | 写 API 响应体返回完整 `GroupLiveSession` | 已接：预约/关播用响应更新 |
| ③ 补偿 / 离线 | 漏推、杀进程、回前台 | `GET .../live/current`（单群）+ **`GET .../me/live-index`（列表）** + **ETag/304** | 进群拉 `current`；**群 Tab 拉 live-index** |

**结论：TCP 非硬性依赖，但 P0 强烈建议做；无 TCP 时客户端只能高频轮询 `live-index` / `current`，成本高、体验差。**

> 会话列表专文：[group-live-conversation-list-client.md](./group-live-conversation-list-client.md)

---

## 1. P0 — 状态机与权威读接口

### 1.1 场次状态机（与 CSS 对齐）

| status | 含义 | 何时写入 | 客户端 UI |
|--------|------|----------|-----------|
| `SCHEDULED` | 已预约 | `authorize` 成功 | 顶栏「待开播」 |
| `AUTHORIZED` | 到点可推流 | 定时任务 / 到点任务 | 顶栏 + 主播可看 push-info |
| `LIVE` | 确认有流 | **腾讯云推流回调 / CSS 流状态** 后 | 顶栏 + 观众可调 play-info |
| `ENDED` | 已结束 | stop / revoke / 过期 / 断流策略 | 隐藏顶栏 |
| `BANNED` | 封禁结束 | admin ban | 隐藏 + 提示 |

**硬规则：**

1. **禁止**在 OBS 点击推流前就把 DB 置为 `LIVE`（避免假开播、`play-info` 404）。
2. `ENDED` / `BANNED` 必须写 `endReason`（见 §1.3）。
3. 同一 `groupId` 同时最多一个 **active slot**（`SCHEDULED` | `AUTHORIZED` | `LIVE`）。

### 1.2 `GET /groups/{groupId}/live/current`（轮询 / 补偿专用）

**响应尽量小、固定：**

```json
{
  "active": true,
  "session": {
    "liveSessionId": "uuid",
    "groupId": "m2MDQ4YN5CW",
    "status": "LIVE",
    "roomName": "今晚聊聊",
    "anchorUserId": "u123",
    "scheduledStartAt": "2026-08-18T10:00:00Z",
    "startedAt": "2026-08-18T10:03:12Z",
    "expireAt": "2026-08-18T12:00:00Z",
    "endedAt": null,
    "endReason": null,
    "version": 42
  }
}
```

无活跃场次：

```json
{ "active": false, "session": null }
```

**必做增强：**

| 项 | 说明 |
|----|------|
| `version` 或 `updatedAt` | 客户端去重；未变可不刷新 UI |
| **ETag / 304** | 例：`ETag: "live-v42"` 或 `X-Live-Revision: 42`；带 `If-None-Match` 返回 304 |
| 不含 push/play URL | 播放、推流仍走独立接口 |

**验收：**

- 304 时 body 为空，客户端 CPU/流量显著低于 200 全量 JSON。
- 关播后下一次 `current` 必为 `active: false`。

### 1.3 `endReason` 枚举（客户端已解析）

| 值 | 触发 |
|----|------|
| `NORMAL` | 正常结束 |
| `OWNER_STOP` | 主播/群主 stop |
| `ADMIN_STOP` | 管理员 stop |
| `DISCONNECT` | OBS 断流 / CSS 断流回调 |
| `SCHEDULE_EXPIRED` | 预约超时未推流 |
| `REVOKED` | 撤销预约 |
| `ADMIN_BAN` | 封禁 |

### 1.4 `GET /me/live-index`（会话列表 · 批量兜底 · **P0**）

**用途：** 群聊 Tab 会话列表展示「有直播 / 直播中」徽标；避免对列表里每个群各调一次 `.../live/current`。

**勿用 N 次 `current` 扫全表**——群多时浪费；本接口一次返回当前用户相关群的 **active slot** 全集。

```http
GET /group-live/api/v1/me/live-index
Authorization: Bearer …
If-None-Match: "live-index-v128"
```

**200 响应：**

```json
{
  "revision": 128,
  "updatedAt": "2026-08-18T10:05:00Z",
  "items": [
    {
      "groupId": "m2MDQ4YN5CW",
      "liveSessionId": "uuid-1",
      "status": "LIVE",
      "roomName": "今晚聊聊",
      "anchorUserId": "u123",
      "scheduledStartAt": "2026-08-18T10:00:00Z",
      "startedAt": "2026-08-18T10:03:12Z",
      "version": 42
    },
    {
      "groupId": "otherGroupId",
      "liveSessionId": "uuid-2",
      "status": "AUTHORIZED",
      "roomName": "周末场",
      "anchorUserId": "u456",
      "scheduledStartAt": "2026-08-18T11:00:00Z",
      "startedAt": null,
      "version": 7
    }
  ]
}
```

**304：** 任意条目未变则 304，body 为空（与 §1.2 同一套路）。

**收录规则（`items` 里有什么）：**

| status | 是否进 index | 列表 UI 建议 |
|--------|--------------|--------------|
| `LIVE` | ✅ | 「直播中」（高亮） |
| `AUTHORIZED` | ✅ | 「有直播」/ 待推流 |
| `SCHEDULED` | ✅ | 「待开播」 |
| `ENDED` / `BANNED` | ❌ | 不出现在 index |

**范围：** 仅返回 **当前登录用户所在群** 且存在 active slot 的条目。

**字段约束：**

| 字段 | 必填 | 说明 |
|------|------|------|
| `revision` | ✅ | **整表**单调递增；任一群场次变更即 +1 |
| `items[].groupId` | ✅ | 与 IM `groupID` 对齐 |
| `items[].liveSessionId` | ✅ | |
| `items[].status` | ✅ | §1.1 |
| `items[].version` | ✅ | 与 `current` / TCP `detail.version` **同源** |
| `items[].roomName` | 建议 | 列表副文案 |
| `items[].anchorUserId` | 建议 | 头像 |

**禁止：** index 中带 push/play URL。

**验收：**

| # | 场景 | 期望 |
|---|------|------|
| 1 | 50 群、2 个 LIVE | index 仅 2 条；304 可用 |
| 2 | LIVE→ENDED | 下次 index 无该群；`revision` 递增 |
| 3 | 非成员 | 该群 never 出现在 index |

---

## 2. P0 — TCP 实时（UI 状态通知）

### 2.1 挂载方式

与群成员、加群审批一致：**不新建独立 event**，挂在现有 TCP 通道：

```text
event:   group_changed
action:  group_live_changed
groupId: {群 ID}
```

**推送对象：** 该群 **全体在线成员**（与 `member_added` 同范围；若产品要求仅群成员则同群成员集合）。

**禁止再发：** `group_live_scheduled` / `group_live_started` / `group_live_ended` 等 IM 生命周期卡片。

### 2.2 触发时机（每条状态变更各推一次）

| 业务动作 | 期望 `detail.status` | 备注 |
|----------|----------------------|------|
| 预约成功 | `SCHEDULED` | 写库后立即推 |
| 改期 / 改名 | 保持当前 status | `roomName` / `scheduledStartAt` 更新 |
| 到点可推流 | `AUTHORIZED` | 定时任务 |
| CSS 确认推流 | `LIVE` | **唯一**进入 LIVE 的自动路径 |
| 主播/管理员 stop | `ENDED` | 调 `DropLiveStream`，不发 IM |
| 撤销预约 | `ENDED` + `REVOKED` | |
| 超时未推流 | `ENDED` + `SCHEDULE_EXPIRED` | |
| 断流超时 | `ENDED` + `DISCONNECT` | 策略可配置 grace period |
| admin ban | `BANNED` / `ENDED` + `ADMIN_BAN` | 调 `ForbidLiveStream` |

### 2.3 `detail` 最低字段

```json
{
  "liveSessionId": "uuid",
  "status": "LIVE",
  "version": 42,
  "roomName": "今晚聊聊",
  "anchorUserId": "u123",
  "scheduledStartAt": "2026-08-18T10:00:00Z",
  "startedAt": "2026-08-18T10:03:12Z",
  "endedAt": null,
  "endReason": null
}
```

| 字段 | 必填 | 说明 |
|------|------|------|
| `liveSessionId` | ✅ | |
| `status` | ✅ | 见 §1.1 |
| `version` | ✅ | 单调递增，与 `current.session.version` 同源 |
| `roomName` | 建议 | 顶栏展示 |
| `anchorUserId` | 建议 | 头像/权限 |
| `endReason` | ENDED/BANNED 时 ✅ | |

**勿在 TCP 中带：** `rtmpServer`、`streamKey`、`playUrl`、`webrtcPlayUrl`（权限 + 过期 + 体积）。

### 2.4 会话列表 index 同步（与 §1.4 联动）

TCP `group_live_changed` 除更新单群状态外，客户端会用来 **patch 本地 `live-index` 缓存**：

| TCP `detail.status` | 客户端 index 操作 |
|---------------------|-------------------|
| `SCHEDULED` / `AUTHORIZED` / `LIVE` | upsert 该 `groupId` |
| `ENDED` / `BANNED` | 从 index **remove** 该 `groupId` |

**后端要求：**

1. 每次推 TCP 时，`detail.version` 必须与 DB 一致；若整表 `revision` 有维护，可在 TCP `detail` **可选**带 `indexRevision`（客户端可用来决定是否全量拉 index）。
2. 关播 / 撤销后 **必须**推一条 ENDED（或 BANNED），以便列表立即去掉徽标——不能仅靠客户端轮询。

### 2.5 客户端预期行为（供联调）

1. 收到 TCP → merge 本地 snapshot（`version` 回退则忽略）；**同时 patch `live-index`  map**。
2. `status` 变 `LIVE` 且用户正在观看 → 调 `play-info`（WebRTC）。
3. `ENDED` / `BANNED` / `active` 等价 → 关播放器、收顶栏、**会话列表去徽标**。
4. TCP 丢失时靠 `live-index`（列表）与 `current`（单群）+ ETag 补偿（§1.2、§1.4）。

### 2.6 验收

| # | 场景 | 期望 |
|---|------|------|
| 1 | 群友在线，主播 OBS 推流成功 | ≤3s 内顶栏变 LIVE（仅 TCP，不依赖 IM） |
| 2 | 群友在聊天页，管理员 stop | ≤3s 顶栏消失 |
| 3 | 人为丢弃 TCP，30s 内 poll `current` | UI 仍最终一致 |
| 4 | 同一 `version` 重复推 | 客户端不重复刷新 |
| 5 | 群 Tab 打开，另一群开播 | TCP 到达后列表 **≤3s** 出现徽标（无 index 全量拉也可） |
| 6 | 关播 TCP 丢失，60s 内 poll index | 徽标最终消失 |

---

## 3. P0 — 推流 / 播放接口

### 3.1 `GET /live/{liveSessionId}/push-info`

| 项 | 要求 |
|----|------|
| 权限 | 指定主播、群主、管理员（产品已定） |
| 时间 | **预约成功后即可返回**（不必等到点）；未到点也可展示 OBS 地址 |
| 响应 | `rtmpServer` + `streamKey`（或合并后的完整 RTMP URL 字段） |
| 过期 | `expiresAt` / URL 签名 `txTime` 明确；续期策略文档化 |

**错误码（客户端已处理）：**

- `LIVE_NOT_AUTHORIZED_YET` — 若仍保留未到点限制，需与产品一致；否则移除
- `LIVE_SESSION_EXPIRED`

### 3.2 `GET /live/{liveSessionId}/play-info`（低延迟 · pid 385180）

**仅 `status == LIVE` 时返回 200。**

```json
{
  "liveSessionId": "...",
  "roomName": "...",
  "anchorUserId": "...",
  "protocol": "webrtc",
  "latencyMode": "ultra-low",
  "playerSdk": "V2TXLivePlayer",
  "playUrl": "webrtc://live.99chat.vip/live/{streamId}?txSecret=...&txTime=...",
  "webrtcPlayUrl": "同上",
  "fallbackFlvUrl": "https://...flv",
  "fallbackHlsUrl": "https://...m3u8"
}
```

| 项 | 要求 |
|----|------|
| 主播放 | `webrtc://` 或 `trtc://`，客户端 `V2TXLivePlayer.startLivePlay` |
| 降级 | FLV → HLS；**不要**让 `playUrl` 变成 HTTPS HLS 冒充 WebRTC |
| 未 LIVE | `LIVE_NOT_LIVE` / 404，客户端显示「等待推流」 |
| streamId | 与 OBS 推流、`fallback*` 地址中的 stream 一致 |

**验收：**

- OBS 在推且 DB 为 LIVE 时，WebRTC URL 可播，端到端延迟通常 ≤1s。
- 停推后 play-info 或 CDN 失败，客户端降级 FLV/HLS（客户端已实现降级链）。

### 3.3 写接口响应

以下接口 **响应体必须含最新 `GroupLiveSession`**（含 `status` / `version`），便于操作者即时 UI，无需再等 TCP：

- `POST .../live/authorize`
- `PATCH .../live/schedule`
- `POST .../live/revoke`
- `POST .../live/stop`

---

## 4. P0 — 腾讯云 CSS 回调

| 回调 | 后端动作 |
|------|----------|
| 推流开始 / 流上线 | 校验 streamId → 置 `LIVE` → 写 `startedAt` → **TCP `group_live_changed`** |
| 推流中断 | 按策略：短时重连 grace → 仍无流则 `ENDED` + `DISCONNECT` + 断流 API |
| stop / ban | 调 `DropLiveStream` / `ForbidLiveStream`（已有）→ 更新 DB → TCP |

**注意：** 回调与 DB、`current.version`、TCP 同一事务或幂等键，避免重复回调导致 version 乱序。

---

## 5. P1 — 性能与运维

### 5.1 轮询频率建议（给客户端契约，后端只需 304）

| 客户端场景 | 建议 poll 间隔 | 接口 |
|------------|---------------|------|
| **群聊 Tab 可见**（会话列表） | **30–60s** | **`GET /me/live-index` + ETag** |
| 单群聊天页顶栏 active | 15–30s | `GET .../live/current` + ETag |
| 单群观看中 / LIVE | 30–60s（关播检测） | `current` + ETag |
| 无 active / 离开 Tab | 不 poll | — |
| App 后台 | 不 poll | — |

### 5.2 监控 / 日志

- 每场 `liveSessionId` 状态迁移日志（含 `version`）
- CSS 回调延迟（推流到 `LIVE` 写入）
- play-info 错误率（NOT_LIVE / 签名过期）

### 5.3 Licence（客户端 SDK ≥10.7）

直播 Licence **不需**经业务 API 下发（可选 P2）；当前客户端用 `--dart-define=TENCENT_LIVE_LICENCE_*`。若改为 bootstrap 下发，单独开字段，勿与 play URL 混放。

---

## 6. P2 — 可选增强

| 项 | 说明 |
|----|------|
| SSE / 长轮询 | 仅当 TCP 覆盖不足时；优先 TCP |
| 离线 Push | 开播提醒（非 UI 必需；注意与 `live_tip` 区分） |
| IM 摘要 | 会话 lastMsg 展示「群直播进行中」— 需产品定稿（与列表徽标独立） |
| `POST /me/live-index/check` | 仅校验一批 `groupId` 是否有 active（极长列表按需；默认不用） |

---

## 7. 明确不做

1. ~~生命周期 IM 卡片~~（已废弃）
2. TCP / Push 携带完整 push-info / play-info
3. 用 IM 代替 TCP 做在线状态同步
4. 客户端轮询 `play-info` 判断有没有直播（应用 `current` + TCP）

---

## 8. 排期建议

| 优先级 | 项 | 阻塞 |
|--------|-----|------|
| **P0** | CSS 回调 → `LIVE` / `DISCONNECT` 状态机 | 假开播、播放 404 |
| **P0** | `play-info` WebRTC 字段（385180） | 低延迟观看 |
| **P0** | TCP `group_live_changed` | 在线 UI 实时（含**会话列表**） |
| **P0** | **`GET /me/live-index` + ETag/304** | **群 Tab 直播徽标兜底** |
| **P0** | `current` + ETag/304 | 单群聊天页补偿 |
| **P0** | push-info 预约后即可拿地址 | 主播 OBS 配置 |
| **P1** | 监控 + endReason 完整 | 排障 |
| **P2** | Push 开播提醒 | 体验增强 |

---

## 9. 联调清单

1. 抓 TCP 原始 JSON：`group_changed` + `group_live_changed` + `version`
2. 对比同时刻 `GET .../live/current` 与 TCP `detail` 一致
3. OBS 推流 → 记录 CSS 回调时间 → DB `LIVE` → TCP 到达时间
4. stop → `active: false` + TCP ENDED + play-info 失败
5. WebRTC URL 真机播放 + FLV/HLS 降级
6. 群 Tab：`live-index` 条数与 TCP 增量一致；关播后 index 与列表 UI 同步

---

## 10. 客户端对接状态（供后端知悉）

| 能力 | 状态 |
|------|------|
| REST `current` / 写接口 | 已接 |
| `play-info` WebRTC + 降级 | 已接（`live_flutter_plugin`） |
| TCP `group_live_changed` | **待接**（顶栏 + 会话列表） |
| **`GET /me/live-index`** | **待后端 + 客户端待接** |
| 分档轮询 + 304 | **待接** |
| IM 生命周期卡片 | 已废弃（仅 `live_tip` 保留） |

客户端专文：[group-live-conversation-list-client.md](./group-live-conversation-list-client.md)（列表徽标）；[group-live-realtime-client.md](./group-live-realtime-client.md)（TCP + 轮询，待写）。
