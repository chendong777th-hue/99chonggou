# 会话列表架构：采用方案 A（腾讯 IM SDK 为真相源）

对齐《腾讯云_IM_Flutter_大规模会话列表_数据入库与同步方案》：  
**不再以自建 Conversation SQLite 作为主列表真相源**；UI 读内存 Store，自建库降级为 mirror / 业务扩展。

## 数据流（终态意图）

```text
腾讯 IM SDK 本地会话库
        │
        │ getConversationListByFilter(C2C | GROUP) 分页
        │ V2TIMConversationListener 增量
        ▼
ConversationTabStore（内存，按 Tab：已加载页 + nextSeq + finished）
        │
        ▼
ConversationListNotifier 桥接 → Virtual List（只建屏上 Cell）
```

开关：`ConversationPerfFlags.conversationListSdkPrimary`  
- `false`（默认）：legacy 读库 + `_typeHydrate` 虚拟列表（回滚安全）  
- `true`：上述 Store 主链

## 自建库还做什么

| 保留 | 不作为权威 |
|---|---|
| 分组 folder 成员 | unread / lastMessage / orderKey / isPinned（列表 UI） |
| 归档 id 集合（prefs） | 主列表整窗 reloadFromLocal |
| 角标聚合用的 mirror unread（过渡） | paced drain → apply_store 刷列表 |
| 业务 meta / 草稿等扩展 | hydrate 双写驱动 UI |

标志：`conversationSqliteListFieldsMirrorOnly == true`（语义约定；角标改挂 Store 后可停写）。

## 分期落地（本仓）

| Phase | 内容 |
|---|---|
| 0–1 | Flag + `ConversationTabStore` + Feed/Notifier 桥接 |
| 2 | Listener 先灌 Store；Sync paced/quiet 不再驱动 UI |
| 3 | TabStore 排除归档；分组仍在 UI 用成员 id 过滤 |
| 4 | sdkPrimary 下停 hydrate 双写、pendingUiApply 主列表帽 |

## 功能如何保留

- **单聊/群聊 Tab**：两套 filter + seq  
- **未读/预览/排序**：Listener + SDK orderKey → Store patch  
- **置顶**：`conversationPinTencentPrimary`  
- **免打扰**：SDK recvOpt + Store patch  
- **分组**：业务 FolderStore；列表数据来自 SDK，成员 id 过滤  
- **归档**：本地归档 id ∩ Store/SDK 列表  
- **大规模滑动**：Virtual List + Store `loadMore`，禁止一次拉完  

## 回滚

将 `conversationListSdkPrimary` 设回 `false` 即回到 legacy 读库路径；Phase 2–4 的 no-op 均挂在该开关上。
