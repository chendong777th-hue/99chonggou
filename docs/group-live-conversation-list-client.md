# 群直播 — 会话列表「直播中」客户端对接

> 状态：**待后端 `GET /me/live-index` + TCP 定稿后实现**  
> 后端契约：[backend-group-live-realtime-todo.md](./backend-group-live-realtime-todo.md) §1.4、§2.4  
> 目标：**群聊 Tab** 会话行展示直播状态；在线靠 TCP，离线/兜底靠 `live-index`

---

## 1. 产品表现

| 场次 status | 会话列表建议 |
|-------------|--------------|
| `LIVE` | 名称旁或副标题：**直播中**（粉红/红点，与 `GroupLiveTopBanner` 一致） |
| `AUTHORIZED` | **有直播** / 待推流 |
| `SCHEDULED` | **待开播**（可选，产品可只显示 LIVE） |

点击会话 → 进入群聊 → 现有顶栏 `GroupLiveTopBanner` / 观看流程不变。

---

## 2. 数据流（双通道）

```text
                    ┌─ TCP group_live_changed ──► patch 内存 Map<groupId, LiveIndexItem>
冷启 / 回前台 / 兜底 ─┤
                    └─ GET /me/live-index (ETag) ──► 全量替换 Map

ConversationList 渲染 ──► lookup Map[normalizeGroupId(groupID)]
```

**原则：**

- **在线：** TCP 增量 patch，不每条变更都拉 index
- **兜底：** 群 Tab 可见时 30–60s poll `live-index`（304 则跳过）
- **单群聊天页：** 仍用 `GET .../live/current`（已有），与 index 条目 `version` 对齐

---

## 3. 建议新增模块

| 模块 | 职责 |
|------|------|
| `GroupLiveIndexStore` | 内存 `Map<String, GroupLiveIndexItem>` + `revision` |
| `GroupLiveIndexSyncService` | `fetchIndex()`、`applyTcpDetail()`、ETag、`notifyListeners` |
| `GroupLiveApi.liveIndex()` | `GET /group-live/api/v1/me/live-index` |

**挂接点：**

| 时机 | 动作 |
|------|------|
| 登录 / `native_post_home` | `fetchIndex()` 一次 |
| App 回前台 | `fetchIndex()` |
| 群 Tab `Visibility` 可见 | 启动 30–60s timer → `fetchIndex()` |
| 群 Tab 不可见 / 后台 | 停 timer |
| `GroupSyncService` 收到 `group_live_changed` | `applyTcpDetail(detail)` |
| 写接口成功（authorize/stop 等） | 可选本地 patch（响应体 session） |

---

## 4. UI 挂接

**推荐：** `conversation.dart` 群 Tab 已有 `lastMessageAbstractBuilder: conversationListLastMessageAbstract`

扩展策略（二选一）：

1. **副标题前缀** — `[直播中] 最后一条消息…`（改动小）
2. **会话行 trailing 徽标** — 在 `TIMUIKitConversation` item 外包一层或 fork item 加 `LiveBadge`（更清晰）

`groupId` 取自 `conversation.groupID`，经 `ChatIdFormat.normalizeGroupId` 与 index 对齐。

---

## 5. TCP patch 伪代码

```dart
void applyTcpDetail(Map detail) {
  final groupId = detail['groupId']?.toString().trim() ?? '';
  final status = GroupLiveStatus.parse(detail['status']?.toString());
  final version = detail['version'] as int? ?? 0;
  if (groupId.isEmpty) return;

  if (!status.isActiveSlot) {
    _items.remove(groupId);
  } else {
    final prev = _items[groupId];
    if (prev != null && prev.version >= version) return;
    _items[groupId] = GroupLiveIndexItem.fromTcp(detail);
  }
  notifyListeners();
}
```

---

## 6. 与现有代码关系

| 已有 | 关系 |
|------|------|
| `GroupLiveChatState` | 单群聊天页；index 为 **多群** 列表专用，可共用 model 类型 |
| `GroupLiveTopBanner` | 进群后 UI；列表徽标独立 |
| `GroupSyncService` | 增加 `group_live_changed` 分支 → 调 `GroupLiveIndexSyncService` |

---

## 7. 验收

| # | 场景 | 期望 |
|---|------|------|
| 1 | 冷启动打开群 Tab | 30s 内看到已在播群的徽标（index 兜底） |
| 2 | 列表页停留，他群开播 | TCP 后 ≤3s 出现徽标 |
| 3 | 关播 | TCP 或下次 index 后徽标消失 |
| 4 | 304 | 无 UI 闪动、无多余 rebuild |

---

## 8. 实现顺序（客户端）

1. 等后端 `live-index` 联调环境  
2. `GroupLiveApi` + `GroupLiveIndexStore` + 冷启/回前台拉取  
3. 群 Tab 轮询 + ETag  
4. TCP patch（依赖 `group_live_changed`）  
5. 会话列表 UI 徽标/副标题  
