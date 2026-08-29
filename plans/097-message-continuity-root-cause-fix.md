# 计划 097：本地优先 + 云端补空洞 — 消息连续性根治方案

## 目标

**不允许出现**：多端不同步、漏消息、消息重复、消息空洞。

## SDK 权威能力（决策依据）

| SDK 能力 | 来源 | 本方案如何利用 |
|---|---|---|
| `lastMsg` 游标天然无重复（返回不含 lastMsg 本身）| [Flutter 文档](https://cloud.tencent.com/document/product/269/75323) | 分页游标始终用 `lastMsg`，不用 `lastMsgSeq` |
| C2C `seq` 按发送方编号，无全局连续性 | 文档明确 `lastMsgSeq` 仅群聊可用 | C2C 不用 seq 做连续性判断 |
| `CLOUD` API 内部先拉本地再拉云端，自动合并去重 | SDK 文档 | C2C 始终用 CLOUD API（SDK 已合并本地+云端）|
| SDK 本地消息有断层时通过漫游自动补全 | [消息存储文档](https://cloud.tencent.com/document/product/269/3571) | `haveMoreData` 接入 `missingOlder` 后 SDK 补全可工作 |
| SDK 自动修复弱网发送状态 | [消息问题](https://cloud.tencent.com/document/product/269/32486) | 发送失败时信任 SDK 漫游修复 |
| SDK 自动分页补全（无效消息过多时最多 3 次）| 文档 | 不过度干预 SDK 内部分页 |
| `findMessages` 查本地（含已删除/已撤回）| 文档 | 空洞检测时用 `findMessages` 确认是否真缺失 |

## 三条铁律

1. **SDK 是唯一权威**：消息是否存在、顺序、状态以 SDK 返回为准。应用层不做 seq 连续性判断，不做时间窗邻接检查。
2. **合并即去重**：任何两段消息合并都经过 `dedupeMessages`（已有），不新增旁路。去重 key 群聊用 `gseq:groupID:seq`，C2C 用 `msg:msgID`，无 msgID 的用 `outgoingStableID`。
3. **空洞可见可补**：合并后检测空洞并插入可见标记，不隐藏。用户滚到标记附近或空闲时自动触发云端补拉。

---

## 第一部分：消息来源全景与统一处理矩阵

### 消息来源清单

| 来源 | 触发时机 | SDK API / 回调 | 当前处理 |
|---|---|---|---|
| S1 首屏打开 | 进聊天页 | `CLOUD_OLDER` 或 peek local+cloud | `setMessageList(replace:true)` |
| S2 上翻旧历史 | 滚到顶部 | `LOCAL_OLDER` → 空洞 → `CLOUD_OLDER` | `_combineMessageList` |
| S3 下拉最新 | 滚到底部 | `CLOUD_NEWER` | `canPrependNewerBatch` 门禁 |
| S4 实时入站 | SDK 推送 | `onRecvNewMessage` | `_applyInboundMessageBatch` |
| S5 暖恢复 | 后台→前台 | `LOCAL_NEWER` + `CLOUD_NEWER` | LOCAL 短路 CLOUD |
| S6 搜索跳转 | 搜索/日期 | around-window `CLOUD` | `loadListForSpecificMessage` |
| S7 @me 跳转 | 群@点击 | around-seq `CLOUD` | `_onScrollToIndexBySeq` |
| S8 未读入口 | 舌尖点击 | around-seq `CLOUD` | `_jumpToFirstUnreadAroundWindow` |
| S9 乐观发送 | 用户发消息 | `createXxxMessage` + `sendMessage` | `_prependOutgoingMessage` |
| S10 SDK 回执 | 发送回调 | sendMessage 回调 | `_swapOutgoingMessage` |
| S11 撤回 | 撤回操作 | `onRecvMessageRevoked` | 状态更新 |
| S12 多端同步 | 其他设备操作 | `onRecvNewMessage(isSelf=true)` | 同 S4 |

### 统一处理矩阵

| 场景 | 拉取策略 | 合并策略 | 去重 | 空洞处理 |
|---|---|---|---|---|
| S1 首屏 | C2C: `CLOUD_OLDER`；群: peek local→cloud | `setMessageList(replace:true)` | SDK 内部合并 | 合并后检测 |
| S2 上翻旧历史 | 群: `LOCAL_OLDER`→空洞→`CLOUD_OLDER`；C2C: `CLOUD_OLDER` | msgID 重叠检查后合并 | `dedupeMessages` | 检测并标记 |
| S3 下拉最新 | `CLOUD_NEWER`（SDK 合并本地+云端）| msgID 重叠检查后 prepend | `dedupeMessages` | 检测并标记 |
| S4 实时入站 | 无拉取（SDK 推送）| upsert 到列表尾 | `messagesCorrelateForDedup` | 无空洞风险 |
| S5 暖恢复 | **LOCAL_NEWER + CLOUD_NEWER（不短路）** | 两者结果合并后 upsert | `dedupeMessages` | 合并后检测 |
| S6 搜索跳转 | `CLOUD` around-window | `setMessageList(replace:true, applyMemoryWindow:false)` | `dedupeMessages` | 落地后双向补 |
| S7 @me 跳转 | `CLOUD` around-seq | 同 S6 | `dedupeMessages` | 落地后双向补 |
| S8 未读入口 | `CLOUD` around-seq | 同 S6 | `dedupeMessages` | 落地后双向补 |
| S9 乐观发送 | 无拉取 | prepend 到列表头 | `outgoingStableID` 关联 | 无空洞风险 |
| S10 SDK 回执 | 无拉取 | 同位替换乐观行 | `messagesCorrelateForDedup` | 无空洞风险 |
| S11 撤回 | 无拉取 | 状态更新 | msgID 精确匹配 | 无空洞风险 |
| S12 多端同步 | 无拉取（SDK 推送）| 同 S4 | `dedupeMessages` | 无空洞风险 |

---

## 第二部分：分场景详细方案

### 场景 1：首屏打开

```
打开聊天页
  → C2C: CLOUD_OLDER(count=20, lastMsg=null)
    // SDK 内部先拉本地再拉云端，自动合并去重
  → 群: peek LOCAL_OLDER(count=20) → 如果本地 >= 20 直接用
         → 如果本地 < 20 或空 → CLOUD_OLDER(count=20)
  → setMessageList(replace: true, applyMemoryWindow: true)
  → 合并后执行空洞检测（见第四部分）
  → markInitialHistoryLoaded
```

**C2C 始终用 CLOUD API 的理由**：C2C seq 无全局连续性，本地优先无 seq 优势；SDK CLOUD API 内部已合并本地+云端，不增加额外网络开销。

**群聊 peek 的理由**：群 seq 有全局连续性，本地 SQLite 里的群历史通常完整（SDK 漫游写入），peek 可避免网络往返；本地不足时 fallback 到 CLOUD。

### 场景 2：上翻旧历史（最频繁的分页操作）

```
用户上翻到顶部
  → pagination.previousPaginationInFlight 检查
  → 获取锚点：oldestSdkPaginationAnchor(内存列表)
    // 禁止用 tip/合成消息做锚点（已有 tipLikeId 检查）
  → 群: LOCAL_OLDER(count=20, lastMsg=锚点)
    → 返回空 → 检查是否 invalidAnchor
      → 是 → 修复锚点，重试
      → 否 → haveMoreData 暂设 false，30s 后可重试
         → 尝试 CLOUD_OLDER（SDK 合并本地+云端）
           → 仍空 → archiveOlderExhausted = true
    → 返回非空 → 合并到列表
  → C2C: CLOUD_OLDER(count=20, lastMsg=锚点)
    // SDK 内部合并本地+云端
    → 返回空 → haveMoreData = false（30s 后可重试）
    → 返回非空 → 合并到列表
  → 合并策略（见第三部分）：
    → msgID 重叠检查（不做 seq 检查）
    → _combineMessageList → dedupeMessages → sort
    → commit_rejected_shrink 守卫（已有）
    → setMessageList(replace: true, applyMemoryWindow: false)
      // 上翻时不裁剪内存窗口，保留已见消息
  → 合并后执行空洞检测（见第四部分）
```

**关键变化**：
- 删除 `canPrependNewerBatch` 的 seq `+1` 检查（此门禁只影响 latest 方向，但 previous 方向本来就没有，这里保持不变）
- `previous` 方向增加 msgID 重叠检查（而非无检查直接 concat+sort）
- C2C 上翻从 LOCAL 改为 CLOUD（SDK 已合并本地+云端）

### 场景 3：下拉最新 / 回到底部

```
用户下拉到接近底部
  → _shouldAttemptLatestHistoryLoad 检查
    // notShowLatest 时允许（SearchJumpLatestGate 已修复）
  → CLOUD_NEWER(count=20, lastMsg=内存列表 newest)
    // SDK 内部先拉本地再拉云端，自动合并
  → 返回结果：
    → 空 → isFinished? haveMoreLatestData=false : 保持 true
    → 非空 → 合并检查：
      → msgID 重叠检查（不做 seq 检查）
      → 如果 incoming oldest msgID == existing newest msgID → overlap，合并
      → 如果 incoming oldest timestamp < existing newest timestamp → 方向错误，拒绝
      → 否则 → 信任 SDK lastMsg 游标，允许合并
    → 合并后 prepend 到列表头
    → setMessageList(replace: true, applyMemoryWindow: true, memoryWindowPreferLatest: true)
  → 合并后执行空洞检测
```

**关键变化**：
- 删除 `canPrependNewerBatch` 的 seq `+1` 检查
- 删除 120s 时间窗检查
- 拒绝时推进锚点到 incoming oldest（避免卡边）
- C2C 直接用 CLOUD_NEWER（SDK 已合并本地+云端，不需要先 LOCAL_NEWER）

### 场景 4：实时入站消息

```
SDK onRecvNewMessage(newMsg)
  → _applyInboundMessageBatch(convID, [newMsg])
  → _shouldDeferIncomingToVisibleList 检查：
    → 非活跃会话 → _scheduleInactiveInboundPresentationCommit（延迟提交）
    → 活跃会话 + 在底部 → 直接 upsert
    → 活跃会话 + 读历史中 → 缓冲到 bufferedMessages
      → 用户回到底部时 flushDeferredIncomingMessages
  → upsert 路径：
    → dedupeMessages([newMsg, ...list])
    → messagesCorrelateForDedup 关联检查
    → 如果是 isSelf=true（多端同步）→ 关联到乐观发送行（如果有）
    → bumpMessageListRevision → notifyListeners
```

**无变化**：当前实时入站路径的 dedup 和 buffer 机制是正确的。唯一需要确保的是 `bufferedMessages` 的 flush 不被遗漏（见场景 8）。

### 场景 5：暖恢复（后台→前台）— P0 修复核心

```
后台→前台
  → shouldSkipForegroundRecovery 检查（30s 跳过窗）
    → im_reconnected 永不跳过（已有）
    → app_resumed / connect_success 在 30s 窗内可能跳过
  → shouldAllowCloudCatchUp 检查
    → app_resumed → true
    → previewAhead → true（列表预览已超前）
  → _pullLatestMessagesFromAnchor：
    → 解析锚点：
      → _resolveLatestPullAnchorId → _latestRealVisibleMessageId
      → 如果全是合成消息 → 从 SDK 重新拉取最新一屏，取真实消息做锚点
      → 锚点为空 → refreshCurrentHistoryList 全量重拉
    → LOCAL_NEWER(count=20, lastMsg=锚点)
      → 有变更？记录 localChanged = true
      → **不 return！继续执行**
    → if allowCloudPull:
      → CLOUD_NEWER(count=20, lastMsg=锚点)
        → 有变更？记录 cloudChanged = true
    → return {
        changed: localChanged || cloudChanged,
        didAttemptCloud: allowCloudPull && 锚点有效
      }
  → 调用点：
    → changed=true → _recordRecoverySuccess → return
    → changed=false → isRecoveryAlreadySatisfied(
        cloudCatchUpRequired: shouldAllowCloudCatchUp && !previewAhead,
        cloudCatchUpAttempted: result.didAttemptCloud  // 传事实
      )
      → true → 标成功 → 武装 30s 跳过窗
      → false → 继续 preview-merge / 重试
```

**关键变化**：
1. LOCAL_NEWER 不短路 CLOUD_NEWER
2. `cloudCatchUpAttempted` 传事实不传意图
3. 合成锚点回退到 SDK 重新拉取
4. `im_reconnected` 不被 2s 合并窗丢弃（见场景 9）

### 场景 6：搜索跳转

```
用户搜索消息 → 点击结果
  → loadListForSpecificMessage(msgID 或 seq)
  → _beginHistoryWindowReplace（generation++）
  → setMemoryWindowSuppressed(conv, true)
  → CLOUD around-window:
    → 群: lastMsgSeq=target.seq → CLOUD_OLDER + CLOUD_NEWER
    → C2C: lastMsgID=target.msgID → CLOUD_OLDER + CLOUD_NEWER
  → setMessageList(replace: true, applyMemoryWindow: false)
  → 落地后释放 suppress：
    → _releaseSearchJumpMemoryWindowSuppress（已有）
    → setSearchJumpStatus(success)
  → 落地后双向补：
    → 向下填：CLOUD_NEWER(lastMsg=window newest) → 补到最新端
    → 向上填：LOCAL_OLDER(lastMsg=window oldest) → 空洞 → CLOUD_OLDER
  → position 设为 awayTwoScreen（不是 notShowLatest）
  → haveMoreLatestData 从 SDK isFinished 取（不强制 true）
```

**关键变化**：
- `haveMoreLatestData` 不强制 true，从 SDK `isFinished` 取
- 落地后 position 设为 `awayTwoScreen`（不是 `notShowLatest`），允许 latest 分页
- 向下填的连续性检查用 msgID 重叠（不用 seq `+1`）

### 场景 7：@me 跳转

同场景 6，锚点用 seq。落地后双向补同场景 6。

**@me 的 seq 跳转是群聊特有**，群 seq 有全局连续性，around-seq 是正确的。但落地后向下填到最新端的连续性检查仍用 msgID 重叠（不用 seq `+1`），因为中间可能有删除/撤回导致 seq 不连续。

### 场景 8：未读入口

```
用户点击 "xxx条未读" 舌尖
  → _jumpToFirstUnreadAroundWindow(firstUnreadSeq)
  → loadListForSpecificMessage(seq: firstUnreadSeq)
  → 同场景 6 的 around-window + 落地后双向补
  → position 设为 awayTwoScreen
  → haveMoreLatestData 从 SDK isFinished 取
```

### 场景 9：抑制门串联 — 修复

```
抑制门规则（修订后）：
  ┌──────────────────────────────────────────────────┐
  │ app_resumed    │ 2s 合并窗内可被 coalesce        │
  │ connect_success│ 2s 合并窗内可被 coalesce        │
  │ im_reconnected │ **永不 coalesce**（真实断线重连）│
  └──────────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────────┐
  │ 30s 跳过窗：                                     │
  │ app_resumed / connect_success / sync_server_finish│
  │   → 30s 内有成功恢复 → 可跳过                     │
  │ im_reconnected                                    │
  │   → **永不跳过**                                  │
  └──────────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────────┐
  │ 12s loggedInSideEffect 门：                       │
  │ app_resumed → 可被抑制                            │
  │ im_reconnected → **不经过此门**（走 refreshForeground│
  │   ChatIfNeeded 直接路径）                         │
  └──────────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────────┐
  │ 3s afterOnline 门：                              │
  │ app_resumed → 可被抑制                            │
  │ im_reconnected → 降级为 1s                        │
  └──────────────────────────────────────────────────┘
```

### 场景 10：乐观发送

```
用户发送消息
  → createXxxMessage → 获得SDK messageInfo
  → _prependOutgoingMessageForConversation（乐观 UI）
  → _sendMessage（SDK 发送）
  → SDK 回调：
    → 成功 → _swapOutgoingMessage（用 stableID 关联乐观行，替换为 SDK 权威行）
    → 失败 → 乐观行状态改为 SEND_FAIL
      → SDK 漫游修复：后续拉取历史时 SDK 自动覆盖失败状态（弱网实际成功）
  → canCommit 失败时（P0-6 修复）：
    → 乐观行状态改为 SEND_FAIL（不 return null）
    → 标记 localCustomData: {'guard_dropped': true}
    → 显示失败 + 重试按钮
```

### 场景 11：媒体预览返回 / 资料页返回

```
媒体预览返回：
  → isMediaPreviewOverlayOpen → activate() 跳过（已有防护）
  → restoreScrollAfterMediaPreview 恢复滚动
  → finishScrollAfterMediaPreview：
    → 清除锁状态
    → 纠正 position：
      → position.pixels <= minScrollExtent + 80 → bottom
      → 否则 → awayTwoScreen
    → **不持久化 notShowLatest**（修复 P1-9）

资料页返回：
  → activate() → route_reactivated
  → 检查 pagination.previousPaginationInFlight：
    → true → 不 jumpTo + setState，只恢复 routeVisible
    → 等待在途分页完成或 2s 超时后贴底
    → false → 正常贴底刷新
```

---

## 第三部分：合并与去重规则

### 合并入口（所有路径统一）

所有 `setMessageList` 调用都经过以下管道：

```
incoming + previous(内存现有)
  → collectUncorrelatedInFlightOutgoing（保留在途自己消息，已有）
  → dedupeMessages（统一去重，已有）
    → 群聊: gseq:groupID:seq
    → C2C: msg:msgID
    → 无 msgID: outgoingStableID 或 sender|timestamp|seq|elemType|random
  → sortMessagesNewestFirst（统一排序，已有）
    → 群: seq 降序
    → C2C: timestamp 降序（seq 不参与排序）
  → restoreUncorrelatedInFlightOutgoing（trim 后插回在途，已有）
  → applyMemoryWindow（裁剪，按方向决定是否裁剪）
  → 空洞检测（新增，见第四部分）
```

### 邻接检查（修订后，极简）

```
合并两段消息时：
  1. 如果两段有 msgID 重叠 → 允许合并（dedupe 处理重叠）
  2. 如果两段无 msgID 重叠：
     a. 群聊：检查 seq 是否有交集或连续
        - 有交集 → 允许
        - 无交集但时间方向正确（incoming 更旧/更新）→ 允许（信任 SDK lastMsg 游标）
        - 时间方向错误 → 拒绝
     b. C2C：只检查时间方向
        - incoming 时间方向正确 → 允许（信任 SDK lastMsg 游标）
        - 时间方向错误 → 拒绝
  3. 不做 seq +1 严格检查
  4. 不做 120s 时间窗检查
  5. 拒绝时推进锚点到 incoming 的 oldest/newest（避免卡边）
```

---

## 第四部分：空洞检测与补全

### 检测时机

每次 `setMessageList` 合并完成后、`applyMemoryWindow` 之前。

### 检测规则

```
遍历合并后的列表（newest-first，index 0 = newest）：
  for i in 0..list.length-2:
    msg_a = list[i]      // 较新
    msg_b = list[i+1]    // 较旧

    // 跳过本地注入消息（tip/分割线/合成消息）
    if isLocalInjectedMessage(msg_a) || isLocalInjectedMessage(msg_b):
      continue

    // 群聊：seq 断层检测
    if 群聊:
      seq_a = messageSeq(msg_a)
      seq_b = messageSeq(msg_b)
      if seq_a > 0 && seq_b > 0 && seq_a - seq_b > 1:
        // 可能是删除/撤回，先用 findMessages 确认
        missing_seqs = [seq_b+1 .. seq_a-1]
        // findMessages 只查本地，无法确认云端删除
        // 直接标记空洞，补拉时 SDK 返回空则确认无消息
        _markGap(upperIndex=i, lowerIndex=i+1,
                 upperMsgID=msg_a.msgID, lowerMsgID=msg_b.msgID,
                 missingSeqs=missing_seqs)

    // C2C：时间间隔检测
    if C2C:
      ts_a = msg_a.timestamp ?? 0
      ts_b = msg_b.timestamp ?? 0
      if ts_a > 0 && ts_b > 0 && ts_a - ts_b > 300:  // 5分钟
        _markGap(upperIndex=i, lowerIndex=i+1,
                 upperMsgID=msg_a.msgID, lowerMsgID=msg_b.msgID,
                 missingTimeRange=(ts_b, ts_a))
```

### 标记插入

```
_markGap(upperIndex, lowerIndex, upperMsgID, lowerMsgID, ...):
  → 在 upperIndex 和 lowerIndex 之间插入 gap_marker：
    V2TimMessage(
      msgID: 'gap_${upperMsgID}_${lowerMsgID}',
      elemType: 11,  // 复用时间分割线 UI
      timestamp: (ts_a + ts_b) ~/ 2,
      status: V2TIM_MSG_STATUS_LOCAL_IMPORTED,
      localCustomData: jsonEncode({
        'gapMarker': true,
        'upperMsgID': upperMsgID,
        'lowerMsgID': lowerMsgID,
        'missingSeqs': missingSeqs,  // 群聊
        'missingTimeRange': [ts_b, ts_a],  // C2C
      }),
    )
  → gap_marker 在列表中可见（显示"正在检查缺失消息..."）
  → 异步触发补拉（见下方）
```

### 补拉触发

```
// 两种触发时机：
// 1. 标记插入后立即异步触发（低优先级）
// 2. 用户滚到 gap_marker 附近时高优先级触发

_fillGap(gapMarker):
  upperMsgID = gapMarker.localCustomData['upperMsgID']
  lowerMsgID = gapMarker.localCustomData['lowerMsgID']

  // 从空洞上沿往下拉（更旧方向）
  upperMsg = findMessages([upperMsgID])  // 查本地
  if upperMsg != null:
    CLOUD_OLDER(count=20, lastMsg=upperMsg)
    → 合并到列表
    → dedupeMessages 处理重叠

  // 从空洞下沿往上拉（更新方向）
  lowerMsg = findMessages([lowerMsgID])
  if lowerMsg != null:
    CLOUD_NEWER(count=20, lastMsg=lowerMsg)
    → 合并到列表
    → dedupeMessages 处理重叠

  // 补拉完成后：
  → 重新检测空洞是否仍在
  → 空洞已填 → 移除 gap_marker
  → 空洞仍在（SDK 确认无消息）→ 移除 gap_marker，标记 gap_resolved
    → gap_resolved 不再显示"正在检查"
```

### 空洞补拉的并发控制

```
_gapFillInFlight = Set<String>()  // gap marker ID 集合

_fillGap(gapMarker):
  gapId = gapMarker.msgID
  if _gapFillInFlight.contains(gapId):
    return  // 已在补拉中
  _gapFillInFlight.add(gapId)
  
  try:
    ... 补拉逻辑 ...
  finally:
    _gapFillInFlight.remove(gapId)
```

---

## 第五部分：多端一致性保障

### 问题来源

用户在设备 A 发消息/撤回/已读，设备 B 需要同步。SDK 通过 `onRecvNewMessage(isSelf=true)` 推送多端同步事件。

### 保障规则

| 多端操作 | SDK 推送 | 处理 |
|---|---|---|
| A 发消息 → B 收到 | `onRecvNewMessage(isSelf=true)` | `dedupeMessages` 用 `outgoingStableID` 关联到 B 上的乐观行（如果有）；无乐观行则新增 |
| A 撤回 → B 收到 | `onRecvMessageRevoked(msgID)` | 按 msgID 精确匹配，状态改为 `LOCAL_REVOKED` |
| A 已读 → B 收到 | `onRecvC2CReadReceipt` | 更新已读游标 |
| A 删除会话 → B 收到 | `onConversationChanged` | 会话列表更新 |
| A 发消息 B 未在聊天页 | `onRecvNewMessage` | `_scheduleInactiveInboundPresentationCommit` 延迟提交 |

### 多端去重的关键

`dedupeMessages` 的 `messagesCorrelateForDedup` 已处理多端同步去重：
- A 的乐观发送行有 `outgoingStableID`
- B 收到的 `onRecvNewMessage(isSelf=true)` 有相同 `outgoingStableID`
- `messagesCorrelateForDedup` 用 `outgoingStableID` 关联 → 同位替换，不新增气泡

**保障措施**：
- `outgoingStableID` 必须在 `createXxxMessage` 时生成并写入 `localCustomData`
- B 端收到多端同步消息时，先查 `outgoingStableID` 索引，匹配到则替换，匹配不到则新增
- 不依赖时间戳去重（多端时钟可能不同步）

### 暖恢复与多端一致性

暖恢复时 `CLOUD_NEWER` 会拉到其他设备发送的消息（SDK 漫游）。这些消息通过 `dedupeMessages` 与本地已有消息去重：
- 如果 B 端已有乐观行 → `outgoingStableID` 关联替换
- 如果 B 端无乐观行 → 新增
- `CLOUD_NEWER` 返回的消息和本地 `LOCAL_NEWER` 返回的消息如果有重叠 → `msg:msgID` 去重

---

## 第六部分：haveMoreData 与内存窗口

### haveMoreData 修订

```dart
bool get haveMoreData =>
    _pagination.haveMoreData ||
    globalModel.memoryWindowMissingOlder(conversationID);

bool get haveMoreLatestData =>
    _pagination.haveMoreLatestData ||
    globalModel.memoryWindowMissingNewer(conversationID);
```

- 内存窗口裁剪掉较旧端 → `haveMoreData = true` → 用户上翻时 UI 提供"加载更多"
- 上翻触发 `loadChatRecord(previous)` → SDK 从内存窗口的 oldest `lastMsg` 拉更旧 → 裁掉的消息被 SDK 重新返回

### 空批次闩锁可重置

```dart
// 空批次时
if (mergedMessages.isEmpty) {
  // 不设 archiveOlderExhausted
  if (!invalidAnchor) {
    pagination.haveMoreData = false;
    pagination.lastEmptyBatchAt = DateTime.now();  // 新增
  }
  return false;
}

// 用户再次上翻时
if (pagination.haveMoreData == false &&
    pagination.lastEmptyBatchAt != null &&
    DateTime.now().difference(pagination.lastEmptyBatchAt!) > Duration(seconds: 30)) {
  // 30s 后允许重试
  pagination.haveMoreData = true;
  pagination.lastEmptyBatchAt = null;
}
```

---

## 第七部分：媒体发送回滚

### canCommit 失败时回滚

```dart
// 图片发送路径（6661 行）/ 视频发送路径（6792 行）
if (!_mediaCommitGuard.canCommit(mediaToken)) {
  // 不 return null
  // 回滚乐观 UI 为失败状态
  globalModel.updateMessageStatus(
    effectiveConvID,
    clientId,
    MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL,
  );
  globalModel.setMessageLocalCustomData(
    effectiveConvID,
    clientId,
    jsonEncode({'guard_dropped': true}),
  );
  return null;  // 不调用 _sendMessage
}
return _sendMessage(...);
```

### MessageCommitCoordinator flush 修订

```dart
void flush() {
  _flushScheduled = false;
  final batches = _pending.entries.toList(growable: false);
  // 不先 clear，逐个检查
  for (final entry in batches) {
    if (!_commitGuard.canCommit(entry.value.commitToken)) {
      // 不从 _pending 移除；通知 UI 回滚
      onStaleDrop?.call(
        MessageStaleDrop(
          conversationID: entry.key,
          generation: entry.value.generation,
          mutations: entry.value.byIdentity.values.toList(),
        ),
      );
      continue;
    }
    _pending.remove(entry.key);  // 确认可提交后才移除
    // ... 正常 flush
  }
}
```

---

## 第八部分：inbound coalescer 注销清理

```dart
// clearData 修订
void clearData() {
  // 先 flush 所有缓冲消息
  _inboundBatchCoalescer.flushAll();
  _inboundChunkReveal.flushAll();
  _revealAllInboundProjection();
  // 等待 flush 完成（同步）
  // 然后清空状态
  _messageListMap.clear();
  // ...
}
```

`flushAll` 同步执行所有缓冲消息的 `_flushInboundMessageBatch`，确保 SDK 推送的消息被写入 `messageListMap` 后再清空。虽然 `messageListMap` 会被清空，但 SDK 内部 SQLite 已持久化这些消息，下次登录可拉取。

---

## 第九部分：SDK 能力边界 vs 自建能力

基于 [Flutter SDK 文档](https://cloud.tencent.com/document/product/269/75323)、[Android&iOS 文档](https://cloud.tencent.com/document/product/269/75321)、[消息存储文档](https://cloud.tencent.com/document/product/269/3571)、[消息属性文档](https://cloud.tencent.com/document/product/269/75313)、[消息问题文档](https://cloud.tencent.com/document/product/269/32486)、[会话文档](https://cloud.tencent.com/document/product/269/75366) 的完整对照。

### SDK 已提供（直接利用，不自建）

| SDK 能力 | 文档来源 | 本方案如何利用 |
|---|---|---|
| 群聊 `seq` 服务端生成、群内严格递增唯一 | [消息属性](https://cloud.tencent.com/document/product/269/75313)：群聊消息的 seq 由服务器生成，在当前群里的严格递增且唯一的 | 入站 gap 检测的"pts"（见第十部分），替代 Telegram 的 pts |
| C2C `seq` 本地生成、无全局连续性 | 同上：单聊消息的 seq 由本地生成，不能保证严格递增且唯一 | C2C 不做 seq gap 检测，靠暖恢复 CLOUD_NEWER 不短路覆盖 |
| `lastMsg` 游标天然无重复（返回不含 lastMsg 本身）| [Flutter 文档](https://cloud.tencent.com/document/product/269/75323) | 分页游标始终用 lastMsg，不用 lastMsgSeq |
| CLOUD API 内部先拉本地再拉云端，自动合并去重 | [文档](https://cloud.tencent.com/document/product/269/75323)：SDK 先从本地拉取，再从云端拉取，过滤无效消息，合并返回 | C2C 始终用 CLOUD API，不重复自建合并逻辑 |
| SDK 内部断层检测+漫游补全 | [消息存储文档](https://cloud.tencent.com/document/product/269/3571)：如果本地消息存在断层，会通过漫游消息补全 | 我们的应用层检测是 SDK 检测的补充（SDK 只在 CLOUD API 调用时检测，不在 onRecvNewMessage 时检测） |
| SDK 自动分页补全（无效消息过多时最多 3 次）| 文档：当云端历史消息中无效的消息过多，SDK 最多触发 3 次自动分页 | 差距过大判定用（返回 >= 60 条且未完 → differenceTooLong） |
| `findMessages` 查本地（含已删除/已撤回状态）| [消息操作文档](https://cloud.tencent.com/document/product/269/75346) | 空洞确认时用 |
| `filterMessagesAfterHistoryClear` | 已在归档路径使用 | 空洞检测前先过滤清空边界 |
| SDK 自动修复弱网发送状态 | [消息问题](https://cloud.tencent.com/document/product/269/32486)：SDK 在后续拉取漫游历史时自动覆盖失败状态 | 发送失败时信任 SDK 漫游修复 |
| `onConversationChanged` 回调携带 lastMessage + orderKey | [会话文档](https://cloud.tencent.com/document/product/269/75366) | 会话列表预览同步用 |

### SDK 未提供（自建能力）

| 需要的能力 | SDK 有平替吗 | 自建方案 | 参考来源 |
|---|---|---|---|
| 入站 seq gap 检测（onRecvNewMessage 时）| **没有**（SDK 不在推送时做检测）| 用 SDK 的群 seq 字段做应用层比较 | Telegram pts；[腾讯云开发者社区 IM 时序设计](https://developer.cloud.tencent.com/article/2672234) |
| 0.5s 乱序缓冲窗 | **没有** | 自己的 `_reorderBuffer` + Timer | Telegram 0.5s wait；腾讯云开发者社区"短时等待+超时拉取" |
| `differenceTooLong` 全量重置 | **没有** | 用返回条数 >= 60 且 isFinished=false 判定 → refreshCurrentHistoryList | Telegram differenceTooLong |
| 空洞检测 + gap_marker | **没有** | 自己遍历列表检测 seq/时间 gap，插入标记 | Telegram 后台修复（透明） |
| 补拉触发与并发控制 | **没有** | 自己的 `_gapFillInFlightByConv` | — |
| 暖恢复 LOCAL+CLOUD 不短路 | **没有**（SDK 的 LOCAL/CLOUD 是两个独立 API）| 修改 `_pullLatestMessagesFromAnchor` | — |
| 媒体发送 canCommit 失败回滚 | **没有** | 修改乐观发送路径 | — |
| 抑制门串联降级 | **没有** | 修改 recovery coordinator | — |

---

## 第十部分：实时入站丢包检测（群聊 seq gap 检测）

### 背景

Telegram 在每次入站时通过 pts 算术 `local_pts + pts_count == incoming_pts` 立即发现 gap。我们方案之前只在分页合并后做事后空洞检测，如果 `onRecvNewMessage` 推送本身丢包，要到用户上翻/下拉时才发现。

腾讯云 IM SDK 的群聊 `seq` 是服务端生成、群内严格递增唯一的——这就是我们的"pts"。

### 检测规则

```
群聊 onRecvNewMessage(newMsg):
  local_newest_seq = 内存列表中最新一条 SDK 消息的 seq（跳过本地注入消息）
  local_newest_msgID = 同上消息的 msgID

  if newMsg.seq <= local_newest_seq:
    // 已存在或更旧 → 丢弃（天然去重）
    return

  if newMsg.seq == local_newest_seq + 1:
    // 连续 → 直接入列
    _upsertIncomingMessageBatch(convID, [newMsg])
    return

  if newMsg.seq > local_newest_seq + 1:
    // seq gap！有消息可能在推送中丢了
    // 先缓冲 newMsg（见第十一部分 0.5s 窗），不立即入列
    _reorderBuffer[convID].add(newMsg)
    _reorderBuffer[convID].startTimer(500ms)
    return
```

### C2C 特殊处理

C2C 的 seq 本地生成、无全局连续性，**无法做入站 gap 检测**。C2C 的丢包靠暖恢复 `CLOUD_NEWER` 不短路覆盖（方案第二部分场景 5 已修复）。

### 与 SDK 内部检测的关系

SDK 文档说 `CLOUD` API 调用时"如果本地消息存在断层，会通过漫游消息补全"。但 SDK 只在 CLOUD API 被调用时检测，不在 `onRecvNewMessage` 时检测。我们的入站 seq gap 检测填补了这个空白——推送时就能发现，不需要等用户触发分页。

---

## 第十一部分：0.5s 乱序缓冲窗

### 背景

Telegram 检测到 pts gap 时不立即补拉，等待 0.5s——因为缺失的 update 可能只是被服务端重排序，稍后会到达。腾讯云开发者社区的 [IM 时序设计文章](https://developer.cloud.tencent.com/article/2672234) 也描述了同样的"短时等待 + 超时拉取"模式。

### 实现

```dart
class InboundReorderBuffer {
  final List<V2TimMessage> pendingMessages = [];
  Timer? _timer;
  int _expectedSeq;
  final void Function(List<V2TimMessage>) _onFlush;
  final void Function(int anchorSeq) _onGapTimeout;

  void add(V2TimMessage msg) {
    pendingMessages.add(msg);
    _timer ??= Timer(const Duration(milliseconds: 500), _onTimeout);
  }

  /// 尝试排出已连续的消息（gap 被后续到达的消息填补时）
  List<V2TimMessage> drainContiguous(int localNewestSeq) {
    if (pendingMessages.isEmpty) return const [];
    pendingMessages.sort((a, b) =>
        (int.tryParse(a.seq ?? '') ?? 0)
            .compareTo(int.tryParse(b.seq ?? '') ?? 0));
    final drainable = <V2TimMessage>[];
    var expected = localNewestSeq + 1;
    while (pendingMessages.isNotEmpty &&
           (int.tryParse(pendingMessages.first.seq ?? '') ?? -1) == expected) {
      drainable.add(pendingMessages.removeAt(0));
      expected++;
    }
    if (pendingMessages.isEmpty) {
      _timer?.cancel();
      _timer = null;
    }
    return drainable;
  }

  void _onTimeout() {
    // 500ms 超时，gap 没被填
    // 先入列缓冲的消息（用户先看到）
    _onFlush(pendingMessages);
    // 异步补拉缺失的
    _onGapTimeout(_expectedSeq);
    pendingMessages.clear();
    _timer = null;
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

// 分会话管理
final Map<String, InboundReorderBuffer> _reorderBuffersByConv = {};
```

### 触发流程

```
群聊 onRecvNewMessage:
  if newMsg.seq > local_newest_seq + 1:
    buffer.add(newMsg)
    // 等 500ms

  // 500ms 内如果缺失的消息到达（seq == local_newest_seq + 1）:
  → drainContiguous 把连续的消息全部排出入列
  → 如果 buffer 空了 → 取消定时器

  // 500ms 超时:
  → 先入列缓冲的消息（用户看到新消息，可能有 gap）
  → 异步 CLOUD_NEWER(lastMsg=内存列表 newest, count=20)
    → SDK 返回缺失的消息
    → dedupeMessages 去重
```

### 仅群聊生效

C2C 的 seq 无全局连续性，不做乱序缓冲。C2C 消息直接入列，依赖时间戳排序。

---

## 第十二部分：差距过大全量重置（differenceTooLong 等价）

### 背景

Telegram 在客户端落后太多时，服务端返回 `differenceTooLong` + 新的 pts，客户端重置整个会话状态从头重新拉取。这防止了"追了半天也没追上"的死循环。

### SDK 能力

腾讯云 IM SDK 没有 `differenceTooLong` 等价信号。但 SDK 的 CLOUD API 最多内部触发 3 次自动分页。如果 3 次后仍不够 count，说明历史确实很长或无效消息（已删除/已撤回）过多。

### 判定规则

```
暖恢复 CLOUD_NEWER 返回后:
  if result.messageList.length >= 60  // 3 × count(20)
     && !result.isFinished:
    // 差距过大
    → 放弃逐页追
    → refreshCurrentHistoryList()（全量重置）
      // 从最新端重新拉取一屏
    → setMessageList(replace: true, applyMemoryWindow: true,
                      memoryWindowPreferLatest: true)
    → 丢弃旧内存窗口
    → _recordRecoverySuccess()
    → return

  // 正常情况：逐页合并
  → dedupeMessages 合并
  → setMessageList(replace: true, ...)
```

### 仅暖恢复路径生效

**限制范围**：differenceTooLong 全量重置**只在暖恢复路径**使用，不在上翻/下拉路径使用。

理由：上翻时用户正在浏览历史，全量重置会丢失浏览位置和已加载的窗口。暖恢复时用户不在浏览历史（刚从后台回来），重置只影响内存窗口不影响用户当前操作。

上翻时如果 `CLOUD_OLDER` 返回 >= 60 条且 `isFinished = false`，说明这段历史极长。不重置，标记 `haveMoreData = true` 让用户继续翻。下拉时同理，不重置，继续逐页填。

---

## 第十三部分：空洞检测优化

### 优化 1：gap_marker UI 体验 — 透明修复

**原方案**：gap_marker 作为可见分割线插入列表，显示"正在检查缺失消息..."。

**优化**：参照 Telegram 的透明修复理念：

```
标记插入后:
  → 不插入可见 UI 元素（只在列表 metadata 中标记 gap）
  → 立即异步触发补拉（不等用户滚到附近）
  → 补拉完成前列表在那个位置显示一个小的 loading indicator（半径 12px 的 CircularProgressIndicator）
  → 补拉完成或确认无消息 → 移除标记，用户几乎无感知
  → 只有补拉失败（网络错误）时才显示"部分消息加载失败，点击重试"的可见分割线
```

### 优化 2：聊天记录清空边界

空洞检测前先检查 `filterMessagesAfterHistoryClear`：

```
空洞检测前:
  → 调用 filterMessagesAfterHistoryClear(conversationID, messages: 当前列表)
  → 如果检测到的空洞跨越 historyClear 边界:
    → 不标记为 gap
    → 接受为"清空后的正常断开"
  → gap_marker 只在 historyClear 边界之后的空洞才触发
```

已有 API：`ArchiveHistoryProvider.filterMessagesAfterHistoryClear`（归档补拉路径已使用）。

### 优化 3：C2C 空洞检测自适应阈值

**原方案**：C2C 用 `timestamp 间隔 > 300s（5分钟）` 做空洞检测。太粗糙。

**优化**：自适应阈值：

```
C2C 空洞检测:
  → 计算现有列表中相邻消息的最大时间间隔 max_internal_gap
  → 如果 incoming 批次和 existing 批次之间的时间间隔 > max_internal_gap × 3:
    → 标记为空洞
  → 否则:
    → 接受为正常间隔（不同聊天活跃度不同）

  → 如果 max_internal_gap == 0（列表只有 1 条消息）:
    → 用默认阈值 3600s（1小时）
```

### 优化 4：空洞检测性能 — 只遍历接缝处

**原方案**：每次 `setMessageList` 合并后遍历整个列表（120 条 → 120 次比较）。

**优化**：

```
空洞检测只遍历合并接缝处:
  → 找到 incoming 批次和 existing 批次的交界点
  → 只遍历交界点附近 ±5 条消息
  → 只有以下情况才全量遍历:
    a. replace: true 且列表完全替换（首屏/搜索跳转/全量重置）
    b. 列表长度变化 > 50（大量新增）
    c. 暖恢复后的合并
```

### 优化 5：补拉并发控制 — 分会话 + 同时上限

```dart
// 分会话控制 + 同一会话最多 2 个 gap 补拉同时执行
final Map<String, Set<String>> _gapFillInFlightByConv = {};
static const int _maxConcurrentGapFillPerConv = 2;

void _fillGap(String convID, V2TimMessage gapMarker) {
  final inflight = _gapFillInFlightByConv.putIfAbsent(convID, () => {});
  final gapId = gapMarker.msgID ?? '';
  if (inflight.contains(gapId)) return;       // 同一 gap 不重复
  if (inflight.length >= _maxConcurrentGapFillPerConv) return; // 同会话最多 2 个
  inflight.add(gapId);
  try {
    // ... 补拉逻辑 ...
  } finally {
    inflight.remove(gapId);
  }
}
```

**同会话最多 2 个 gap 补拉同时执行的理由**：
- 防止列表中多个空洞同时触发补拉，发起过多 CLOUD 请求
- SDK 的 3 次自动分页限制是全局的，过多并发请求可能消耗限制
- 2 个并发足以覆盖最常见的场景（一个向上补 + 一个向下补）
- 被限流的 gap_marker 保持 loading 状态，待现有补拉完成后自动触发

---

## 第十四部分：空洞检测与补全（修订版）

综合第十至十三部分，空洞检测修订为：

### 检测时机

1. **合并后**：`setMessageList` 合并完成后、`applyMemoryWindow` 之前（只遍历接缝处，见优化 4）
2. **入站时**（群聊）：`onRecvNewMessage` 时 seq gap 检测（见第十部分）
3. **全量替换时**：首屏/搜索跳转/全量重置后全量遍历

### 检测规则（修订）

```
遍历列表（newest-first）:
  for i in 0..list.length-2:
    msg_a = list[i]      // 较新
    msg_b = list[i+1]    // 较旧

    // 跳过本地注入消息
    if isLocalInjectedMessage(msg_a) || isLocalInjectedMessage(msg_b):
      continue

    // 跳过已标记的 gap_marker
    if isGapMarker(msg_a) || isGapMarker(msg_b):
      continue

    // 群聊：seq 断层检测
    if 群聊:
      seq_a = messageSeq(msg_a)
      seq_b = messageSeq(msg_b)
      if seq_a > 0 && seq_b > 0 && seq_a - seq_b > 1:
        // 先检查是否跨越 historyClear 边界（优化 2）
        if crossesHistoryClearBoundary(convID, msg_b, msg_a):
          continue  // 清空后的正常断开
        _markGap(convID, upperIndex=i, lowerIndex=i+1, ...)

    // C2C：自适应时间间隔检测（优化 3）
    if C2C:
      ts_a = msg_a.timestamp ?? 0
      ts_b = msg_b.timestamp ?? 0
      max_internal_gap = 计算现有列表最大内部间隔
      threshold = max_internal_gap > 0 ? max_internal_gap * 3 : 3600
      if ts_a > 0 && ts_b > 0 && ts_a - ts_b > threshold:
        if crossesHistoryClearBoundary(convID, msg_b, msg_a):
          continue
        _markGap(convID, upperIndex=i, lowerIndex=i+1, ...)
```

### 标记插入（修订）

```
_markGap(convID, upperIndex, lowerIndex, ...):
  → 在 upperIndex 和 lowerIndex 之间插入 gap_marker:
    V2TimMessage(
      msgID: 'gap_${upperMsgID}_${lowerMsgID}',
      elemType: 11,
      timestamp: (ts_a + ts_b) ~/ 2,
      status: V2TIM_MSG_STATUS_LOCAL_IMPORTED,
      localCustomData: jsonEncode({
        'gapMarker': true,
        'upperMsgID': upperMsgID,
        'lowerMsgID': lowerMsgID,
        'missingSeqs': missingSeqs,       // 群聊
        'missingTimeRange': [ts_b, ts_a], // C2C
        'status': 'loading',              // loading | resolved | failed
      }),
    )
  → UI 渲染:
    → status=loading: 显示小 loading indicator（不插入整条分割线）
    → status=resolved: 移除标记
    → status=failed: 显示"部分消息加载失败，点击重试"
  → 立即异步触发补拉（不等用户滚到附近）
```

### 补拉触发（修订）

```
_fillGap(convID, gapMarker):
  // 并发控制（分会话，优化 5：同一 gap 不重复 + 同会话最多 2 个并发）
  if _gapFillInFlightByConv[convID]?.contains(gapId):
    return
  if _gapFillInFlightByConv[convID]?.length >= 2:
    return  // 保持 loading 状态，待现有补拉完成后自动触发
  _gapFillInFlightByConv.putIfAbsent(convID, () => {}).add(gapId)

  try:
    upperMsg = findMessages([upperMsgID])
    lowerMsg = findMessages([lowerMsgID])

    // 从空洞上沿往下拉（更旧方向）
    if upperMsg != null:
      CLOUD_OLDER(count=20, lastMsg=upperMsg)
      → dedupeMessages 合并

    // 从空洞下沿往上拉（更新方向）
    if lowerMsg != null:
      CLOUD_NEWER(count=20, lastMsg=lowerMsg)
      → dedupeMessages 合并

    // 补拉完成后重新检测
    if 空洞已填:
      移除 gap_marker
    elif SDK 确认无消息（返回空 + isFinished）:
      移除 gap_marker（gap_resolved）
    else:
      gap_marker.status = 'failed'  // 显示重试

  finally:
    _gapFillInFlightByConv[convID]?.remove(gapId)
```

---

## 执行顺序

```
Phase 1（P0 根治，可并行）：
  1A. 删除 seq 邻接门禁 → 信任 SDK lastMsg 游标
  1B. 暖恢复 LOCAL_NEWER 不短路 CLOUD_NEWER + cloudCatchUpAttempted 传事实
  1C. 媒体发送 canCommit 失败回滚

Phase 2（入站 seq gap 检测，依赖 1A）：
  2A. 群聊 onRecvNewMessage seq gap 检测（第十部分）
  2B. 0.5s 乱序缓冲窗 InboundReorderBuffer + 生命周期安全（第十一/十六部分）

Phase 3（空洞检测，依赖 1A + 2A）：
  3A. 实现空洞检测（优化 4 只遍历接缝处）
  3B. gap_marker 插入 + 透明修复 UI（优化 1）
  3C. 空洞补拉触发 + 分会话并发控制（优化 5）+ 用户分页竞争防护（第十七部分）
  3D. 聊天清空边界过滤（优化 2）
  3E. C2C 自适应空洞阈值 + 上限下限（优化 3 + 风险 1 缓解）

Phase 4（内存窗口，依赖 1A）：
  4A. haveMoreData 接入 missingOlder
  4B. 空批次闩锁可重置

Phase 5（差距过大重置，依赖 1B）：
  5A. differenceTooLong 判定 + 全量重置（仅暖恢复路径，第十二部分）

Phase 6（C2C 加固，依赖 1A + 1B）：
  6A. C2C lastMessage 校验机制（第十五部分）
  6B. C2C 上翻 peek LOCAL → 空洞 → CLOUD（第十五部分）

Phase 7（抑制门，依赖 1B）：
  7A. im_reconnected 不被 coalesce
  7B. 3s 门对 im_reconnected 降级

Phase 8（生命周期，独立）：
  8A. scrollLockedForOverlay 解锁后纠正 position
  8B. activate() 从资料页返回时分页在途检查
  8C. reset 前 flush pendingRealtime

Phase 9（coalescer 注销，独立）：
  9A. cancelAllSilently 改为 flushAll
```

## 第十五部分：C2C 消息正确性加固

### 背景

C2C 的 seq 本地生成、无全局连续性，无法像群聊那样用 seq 做入站 gap 检测。C2C 的消息正确性当前依赖三个环节：SDK 漫游服务器（90 天兜底，见第十九部分）、暖恢复 CLOUD_NEWER 不短路（方案已修复）、用户触发 CLOUD API 时 SDK 内部补全。

但有一个盲区：`onRecvNewMessage` 推送本身丢包时，C2C 无法立即发现。用户如果不操作（不下拉、不上翻、不退出重进），消息会一直不在列表里，直到下次操作时才补全。

### C2C lastMessage 校验机制（pts 替代）

SDK 的 `onConversationChanged` 回调携带 `lastMessage`。如果会话列表的 `lastMessage` 更新了但 `onRecvNewMessage` 没有到达对应消息，说明推送丢包了。

```
onConversationChanged(conversation):
  if conversation 是 C2C 且是当前活跃会话:
    conv_last_msg = conversation.lastMessage
    local_newest_msg = 内存列表中最新一条 SDK 消息

    if conv_last_msg != null && local_newest_msg != null:
      if conv_last_msg.msgID != local_newest_msg.msgID:
        // 会话的 lastMessage 不是内存列表的最新消息
        // 说明有消息推送丢了
        // 异步触发 CLOUD_NEWER 补拉
        if !_c2cCatchUpInFlight[convID]:
          _c2cCatchUpInFlight[convID] = true
          CLOUD_NEWER(count=20, lastMsg=local_newest_msg)
            → SDK 返回缺失的消息
            → dedupeMessages 去重合并
            → _c2cCatchUpInFlight[convID] = false
```

**为什么这能工作**：
- `onConversationChanged` 是 SDK 的会话级回调，不依赖 `onRecvNewMessage` 推送通道
- 如果消息到达了服务端（存入漫游），`onConversationChanged` 会更新 `lastMessage`
- 如果 `onRecvNewMessage` 丢包但 `onConversationChanged` 到达，说明消息在服务端但推送通道丢了
- 这时 CLOUD_NEWER 能从漫游拉到缺失的消息

**并发控制**：`_c2cCatchUpInFlight` 防止 `onConversationChanged` 高频触发时重复补拉。

**不适用于群聊**：群聊已有 seq gap 检测（第十部分），不需要 lastMessage 校验。且群聊的 `onConversationChanged` 可能由其他事件触发（群成员变动等），lastMessage 变化不代表消息丢失。

### C2C 上翻优化：peek LOCAL 然后空洞检测补 CLOUD

**原方案**：C2C 上翻用 CLOUD_OLDER（SDK 合并本地+云端）。

**问题**：每次上翻都触发 SDK 的本地+云端两次查询，即使本地有数据也要等网络往返。弱网下增加延迟。

**优化**：C2C 上翻改为 peek 模式（和群聊一致）：

```
C2C 上翻:
  → LOCAL_OLDER(count=20, lastMsg=锚点)
    → 返回 >= count 条 → 直接用（快，无网络）
    → 返回 < count 条或空 → CLOUD_OLDER（SDK 合并本地+云端）
  → 合并后空洞检测
  → 如果检测到空洞 → CLOUD_OLDER 补拉
```

**理由**：C2C 的本地 SQLite 通常有完整的近期历史（SDK 漫游写入）。大部分上翻可以走 LOCAL（快），只有本地不足或有空洞时才走 CLOUD。

**与暖恢复的区别**：暖恢复必须 CLOUD_NEWER 不短路（因为后台期间推送可能未落盘）；上翻可以用 LOCAL 优先（因为历史消息已经在本地 SQLite）。

### C2C 消息正确性总结

| 路径 | 机制 | 正确性保障 |
|---|---|---|
| 实时入站 | `onRecvNewMessage` 直接入列 | SDK 推送到达即显示 |
| 入站丢包 | **lastMessage 校验**（本部分新增）| `onConversationChanged` 到达但消息不在列表 → CLOUD_NEWER 补拉 |
| 暖恢复 | LOCAL_NEWER + CLOUD_NEWER 不短路 | 场景 5 已修复 |
| 下拉 | CLOUD_NEWER（SDK 合并本地+云端）| SDK 内部补全 |
| 上翻 | peek LOCAL → 空洞 → CLOUD_OLDER | 本部分优化 |
| 首屏 | CLOUD_OLDER | SDK 合并本地+云端 |
| 漫游存储 | SDK 漫游服务器（套餐决定，推荐 90 天，见第十九部分）| 90 天兜底，超出走归档 |
| 弱网发送失败 | SDK 漫游修复 | SDK 自动覆盖 |

**C2C 最终保障**：即使在最坏情况下（推送丢包 + 用户不操作 + socket 不断），SDK 心跳 2 分钟一次感知断连 → 触发 `im_reconnected`（不被抑制）→ CLOUD_NEWER 补全。**漫游窗口内不会永久丢失**。

---

## 第十六部分：InboundReorderBuffer 生命周期安全

### 生命周期规则

```
1. 初始化时机：
   → 只在 markInitialHistoryLoaded(convID) 之后激活
   → 首屏历史未加载完前，buffer 不激活（_expectedSeq 不可靠）

2. _expectedSeq 初始化：
   → markInitialHistoryLoaded 时，取内存列表中最新 SDK 消息的 seq
   → _expectedSeq = 该 seq + 1
   → 如果列表为空 → _expectedSeq = 0，buffer 不激活直到首条消息到达

3. 会话切换：
   → 用户切换会话时，dispose 旧会话的 buffer
   → 新会话的 buffer 在其 markInitialHistoryLoaded 后初始化

4. 退出聊天页：
   → dispose 所有 buffer
   → 不跨聊天页生命周期保留

5. 首条消息：
   → 如果 _expectedSeq == 0 且收到首条消息
   → 直接入列，不缓冲
   → 设 _expectedSeq = first_msg.seq + 1（群聊）

6. 非群聊消息：
   → C2C / 系统消息不经过 buffer，直接入列
   → buffer 只处理群聊且 seq > 0 的消息

7. 撤回/删除消息：
   → 撤回和删除不影响 buffer 的 _expectedSeq
   → _expectedSeq 只追踪连续递增的最大 seq，不回退

8. 多条消息同时到达（批量推送）：
   → 批量消息先按 seq 排序
   → 逐条检查连续性
   → 连续的部分直接入列
   → gap 后的消息缓冲
```

### 边界情况处理

```
// 群消息 seq == 0 或 null（极端异常）
if newMsg.seq == null || newMsg.seq <= 0:
  // 不做 gap 检测，直接入列（SDK 应该不会返回 seq=0 的群消息）
  _upsertIncomingMessageBatch(convID, [newMsg])
  return

// _expectedSeq 溢出（群 seq 很大）
// seq 是 uint64，Dart int 是 64 位，不会溢出

// buffer 满（极端情况：gap 后大量消息涌入）
if _reorderBuffer[convID].pendingMessages.length > 50:
  // 防止内存无限增长
  // 先入列所有缓冲消息，立即触发 CLOUD_NEWER 补拉
  _onTimeout()
```

---

## 第十七部分：空洞补拉与用户分页的竞争防护

### 竞争场景

空洞补拉触发 `CLOUD_OLDER` / `CLOUD_NEWER`，用户同时上翻/下拉也触发 `CLOUD_OLDER` / `CLOUD_NEWER`。两者可能用同一个 `lastMsg` 锚点请求 SDK，SDK 返回相同结果，`dedupeMessages` 去重没问题但浪费 SDK 请求（且消耗 SDK 的 3 次自动分页限制）。

### 防护机制

```
// 统一分页请求去重
final Set<String> _inFlightHistoryRequestKeys = {};

// gap 补拉前检查
_fillGap(convID, gapMarker):
  requestKey = 'gap_older_${gapMarker.upperMsgID}'
  if _inFlightHistoryRequestKeys.contains(requestKey):
    return  // 用户分页或另一个 gap 补拉已在使用同一锚点
  _inFlightHistoryRequestKeys.add(requestKey)

  try:
    result = await CLOUD_OLDER(count=20, lastMsg=upperMsg)
    → 合并
  finally:
    _inFlightHistoryRequestKeys.remove(requestKey)

// 用户分页前检查（loadChatRecord 已有 historyLoadingKeys 去重）
// gap 补拉和用户分页共享同一套 request key 规则
// 如果 gap 补拉的 requestKey 和用户分页的 requestKey 相同
// → 用户分页的 historyLoadingKeys 已包含 → gap 补拉跳过
```

### 共享 requestKey 规则

gap 补拉的 requestKey 格式与 `loadChatRecord` 的 `_historyRequestKey` 格式对齐：
```
gap_older = 'older_${lastMsgID}_${count}'
gap_newer = 'newer_${lastMsgID}_${count}'
```

如果用户分页已用同一 lastMsgID 发起请求，`historyLoadingKeys` 已包含该 key → gap 补拉跳过，等待用户分页结果。用户分页完成后 `historyLoadingKeys` 移除该 key → gap 补拉可以执行（如果 gap 仍在）。

### gap 补拉优先级

```
gap 补拉优先级低于用户分页：
  → 用户正在上翻/下拉时，gap 补拉推迟
  → 用户停止滚动后，gap 补拉才执行
  → 防止 gap 补拉的网络请求抢占用户操作的网络带宽
```

---

## 第十八部分：风险分析与缓解措施

### 风险 1：C2C 空洞检测自适应阈值可能误判或漏判

**风险**：C2C 用"时间间隔 > 内部最大间隔 × 3"做空洞检测。活跃对话中对方恰好 5 分钟没说话，内部最大间隔可能 30 秒 → 90 秒阈值 → 5 分钟 > 90 秒 → 误标记为空洞。不活跃对话中 3 天没说话但内部最大间隔也 3 天 → 9 天阈值 → 漏判。

**缓解**：
- 自适应阈值增加上限和下限：
  - 下限：阈值最小 600s（10 分钟），低于此不标记
  - 上限：阈值最大 86400s（1 天），高于此才标记
- 即使误标记为空洞，补拉返回空后自动移除标记（gap_resolved），用户无感知
- 配合第十五部分的 lastMessage 校验，C2C 不依赖空洞检测作为唯一发现手段

### 风险 2：C2C 暖恢复窗口期的重复请求

**风险**：暖恢复 CLOUD_NEWER 正在执行时，用户下拉刷新可能触发重复 CLOUD_NEWER 请求，消耗 SDK 的 3 次自动分页限制。

**缓解**：
- `loadChatRecord` 已有 `historyLoadingKeys` 去重（相同 requestKey 的请求被跳过）
- 暖恢复的 CLOUD_NEWER 和用户下拉的 CLOUD_NEWER 用相同的 lastMsg 锚点 → 相同 requestKey → 用户下拉被跳过
- 暖恢复完成后用户下拉用更新后的锚点 → 不同 requestKey → 正常执行

### 风险 3：C2C 推送丢包 + 用户不操作 = 延迟发现

**风险**：C2C 的 `onRecvNewMessage` 推送丢包且用户不操作，消息不会立即出现在列表里。

**缓解**：
- 第十五部分的 lastMessage 校验：`onConversationChanged` 到达但消息不在列表 → 立即 CLOUD_NEWER 补拉
- SDK 心跳 2 分钟感知断连 → `im_reconnected` → CLOUD_NEWER 补全
- 漫游 90 天窗口内不会永久丢失
- **最终一定会被发现**，只是不是"立即"发现

### 风险 4：0.5s 乱序缓冲窗可能造成群聊消息显示延迟

**风险**：高频群聊（每秒多条消息）中，seq gap 时 500ms 内消息不显示。

**缓解**：
- buffer 只缓冲 gap 之后的那一条消息（`newMsg.seq > expected`），gap 之前的消息正常显示
- 500ms 超时后缓冲的消息立即入列（用户先看到），然后异步补拉
- 最坏情况：用户看到一条消息延迟 500ms 显示，补拉后填充中间的 gap
- 缓冲消息 > 50 条时强制 flush（防止内存无限增长）

### 风险 5：differenceTooLong 误判

**风险**：群聊有大量删除/撤回消息，SDK 3 次自动分页返回 >= 60 条有效消息但 `isFinished=false`，误触发全量重置。

**缓解**：
- 全量重置只在暖恢复路径生效（第十二部分已限制范围）
- 暖恢复时用户不在浏览历史，重置只影响内存窗口
- 全量重置后 `setMessageList(replace: true)` 用 SDK 最新一屏替换，不丢数据
- 如果重置后列表条数比之前少 → 触发 `commit_rejected_shrink` 守卫（已有）→ 拒绝替换

### 风险 6：gap 补拉与用户分页竞争

**风险**：空洞补拉和用户上翻/下拉同时请求 SDK，浪费请求或消耗 SDK 分页限制。

**缓解**：第十七部分的共享 requestKey 去重 + gap 补拉低优先级推迟。

### 风险 7：InboundReorderBuffer 的 _expectedSeq 初始化不正确

**风险**：首屏历史未加载完时 buffer 激活，_expectedSeq 不可靠。

**缓解**：第十六部分的 8 条生命周期规则，确保 buffer 只在 `markInitialHistoryLoaded` 后激活。

### 风险 8：删除 seq 邻接门禁后异常 SDK 返回产生重复

**风险**：SDK 返回与现有列表完全不相交的批次，如果消息没有 msgID 可能重复。

**缓解**：
- `dedupeMessages` 的 fallback key 是 `sender|timestamp|seq|elemType|random`
- SDK 的 `random` 字段是每条消息唯一的，即使没有 msgID 也能去重
- 群聊用 `gseq:groupID:seq` 去重，seq 严格递增唯一
- C2C 用 `msg:msgID` 去重，C2C 消息的 msgID 在服务端唯一

### 风险 9：C2C 上翻 peek LOCAL 性能影响

**风险**：C2C 上翻 peek LOCAL 后 CLOUD 补全，比纯 LOCAL 多一次网络请求。

**缓解**：
- 大部分上翻走 LOCAL（本地 SQLite 有完整近期历史），不触发 CLOUD
- 只有 LOCAL 返回 < count 或空时才 CLOUD
- 空洞检测触发 CLOUD 补拉是异步的，不阻塞用户滚动
- 弱网下 LOCAL 返回足够时不需要等 CLOUD

### 风险 10：方案复杂度本身的风险

**风险**：14 个部分 + 多个新机制，每个新机制可能引入新 bug。

**缓解**：
- 每个 Phase 独立提交、可独立回滚
- 验证契约 18 项（见下方），每个新机制有定向测试
- Phase 1（P0 根治）不引入新机制，只删除有害门禁和修复已有 bug
- Phase 2-3 的新机制（InboundReorderBuffer、空洞检测）有独立测试验证
- 真机 Profile 30-60 分钟长驻回归覆盖所有路径
- 出现任何消息顺序/未读/草稿/媒体/通话/排序语义回归时立即停止

每个 Phase 完成后必须通过：

1. **定向回归**：涉及的所有现有测试保持绿
2. **空洞检测测试**：构造非相邻 SDK 页，验证 gap_marker 插入而非隐藏
3. **C2C seq 测试**：C2C per-sender seq 不连续，验证合法批次不被误拒
4. **暖恢复测试**：LOCAL_NEWER 部分命中 + CLOUD_NEWER 有剩余，验证两者都执行
5. **媒体发送测试**：advanceConversation 在 async prep 期间，验证乐观 UI 回滚为失败
6. **抑制门测试**：app_resumed + 500ms 后 im_reconnected，验证 im_reconnected 不被丢弃
7. **多端一致性测试**：A 发消息 B 有乐观行，验证 outgoingStableID 关联替换不新增气泡
8. **去重测试**：同一条消息从 LOCAL + CLOUD 两个路径到达，验证只出现一次
9. **入站 seq gap 测试**（Phase 2）：群聊 seq 101 和 103 到达但 102 缺失，验证 0.5s 后触发 CLOUD_NEWER 补拉 102
10. **乱序缓冲测试**（Phase 2）：群聊 seq 103 先到、102 后到（200ms 内），验证 102 到达后一起按序入列
11. **差距过大测试**（Phase 5）：暖恢复 CLOUD_NEWER 返回 >= 60 条且 isFinished=false，验证全量重置而非逐页追
12. **清空边界测试**（Phase 3D）：构造跨越 historyClear 边界的空洞，验证不误标记 gap_marker
13. **透明修复测试**（Phase 3B）：gap_marker 补拉期间用户看不到整条分割线，补拉完成后标记移除
14. **C2C lastMessage 校验测试**（Phase 6A）：onConversationChanged 到达但 onRecvNewMessage 丢包，验证 CLOUD_NEWER 补拉
15. **C2C peek 测试**（Phase 6B）：C2C 上翻 LOCAL 返回 >= count 不触发 CLOUD，返回 < count 才触发 CLOUD
16. **ReorderBuffer 生命周期测试**（Phase 2B）：首屏未加载完时 buffer 不激活；会话切换时旧 buffer dispose；缓冲 > 50 条强制 flush
17. **竞争防护测试**（Phase 3C）：gap 补拉和用户分页用同一 lastMsg 时，gap 补拉跳过，等待用户分页结果
18. **真机 Profile**：30-60 分钟长驻，连续上翻/下拉/搜索跳转/暖恢复/群聊连续接收/C2C 推送丢包，无消息丢失/重复/空洞

## 第十九部分：漫游存储兜底与套餐配置

### SDK 漫游存储时长对照

根据 [基础服务计费说明](https://cloud.tencent.com/document/product/269/81908)：

| 套餐包 | 默认漫游时长 | 可延长至 | 费用 |
|---|---|---|---|
| 体验版/开发版 | 7 天 | 不支持延长 | — |
| 专业版 | 7 天 | 30/90/180/360 天 | 90 天国内 500 元/月 |
| 旗舰版 | 30 天 | 90/180/360 天 | 90 天国内 500 元/月 |
| 企业版（推荐）| **90 天** | 180/360 天 | **90 天免费** |

### 90 天兜底的目标

将漫游存储配置为 **90 天**作为消息连续性的最终兜底层：

```
消息丢失后的恢复时间线：
  ┌──────────────────────────────────────────────────────┐
  │ 0s        推送丢包（onRecvNewMessage 未到达）          │
  │ ↓                                                    │
  │ 即时      群聊：seq gap 检测 → 0.5s 缓冲 → CLOUD_NEWER│
  │           C2C：lastMessage 校验 → CLOUD_NEWER        │
  │ ↓                                                    │
  │ 2 min     SDK 心跳超时 → im_reconnected → CLOUD_NEWER │
  │ ↓                                                    │
  │ 用户操作  下拉/上翻/退出重进 → CLOUD API → SDK 补全   │
  │ ↓                                                    │
  │ 90 天     漫游服务器兜底：CLOUD API 可拉到 90 天内消息│
  │ ↓                                                    │
  │ > 90 天   超出漫游窗口，不可恢复（需归档后端补拉）     │
  └──────────────────────────────────────────────────────┘
```

### 为什么选 90 天

1. **企业版免费**：90 天漫游在企业版免费，不增加成本
2. **覆盖极大多数离线场景**：用户极少连续 90 天不打开某个会话
3. **与归档后端衔接**：自建归档后端覆盖 90 天以上的历史（已有 `ArchiveHistoryProvider`），90 天漫游 + 归档 = 无时间上限的消息连续性
4. **SDK 补全可靠**：90 天内 CLOUD API 调用时 SDK 自动从漫游补全断层

### 配置要求

在腾讯云控制台配置：
- 路径：功能配置 → 登录与消息 → 历史消息存储时长配置
- 设置为 90 天（企业版免费）或付费延长至 90 天（专业版/旗舰版 500 元/月）
- 即刻生效，无需重新部署

### 与方案各层的关系

```
第一层（实时）：onRecvNewMessage 直接入列
  ↓ 丢包
第二层（即时检测）：群聊 seq gap / C2C lastMessage 校验 → CLOUD_NEWER 补拉
  ↓ 未发现
第三层（暖恢复）：后台→前台 → LOCAL_NEWER + CLOUD_NEWER 不短路
  ↓ 未触发
第四层（用户操作）：下拉/上翻 → CLOUD API（SDK 内部合并本地+云端+断层补全）
  ↓ 未操作
第五层（心跳兜底）：SDK 2 分钟心跳 → im_reconnected → CLOUD_NEWER
  ↓ socket 不断
第六层（漫游兜底）：90 天内任何时刻 CLOUD API 都能拉到缺失消息
  ↓ 超出 90 天
第七层（归档兜底）：自建归档后端（ArchiveHistoryProvider）补拉 90 天以上历史
```

七层防护中，漫游存储是第六层兜底。90 天窗口确保前五层都失败时，只要用户在 90 天内打开过聊天页，CLOUD API 就能拉到所有缺失消息。

- 不改变 SDK 版本、消息 wire payload、图片压缩参数、上传并发
- 不改变 `compareMessagesChronological` 的 C2C 时间戳排序逻辑
- 不改变 `keepNewestContiguousSpine` 群 seq 脊柱默认语义
- 不改变 018/045/049 的 stable identity 关联机制
- 不改变未读/草稿/置顶/免打扰/删除语义
- 不新增消息写入旁路、防抖或重复 fallback
- 任何消息顺序/未读/草稿/媒体/通话/排序语义回归时立即停止
