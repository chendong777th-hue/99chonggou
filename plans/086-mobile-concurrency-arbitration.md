# Plan 086: 建立移动端统一竞态仲裁与安全提交协议

> **Executor instructions**: 本计划只解决状态竞争，不改变正常业务功能、SDK 历史来源、分页方向、UI 布局、通话产品策略或接口协议。先执行漂移检查；发现当前状态与本文不符时停止并报告。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 080、077、079；保持 065、072、078、083、085 的既有语义
- **Category**: bug / tech-debt / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

移动端同时存在 SDK 事件、网络请求、本地 SQLite、页面回调、定时器和 post-frame 任务。当前各链路已有局部 generation/debounce，但没有统一规则决定“哪个结果可以提交、哪个结果必须丢弃”，因此会出现旧消息、旧群名、旧草稿、重复通话气泡和前后台恢复回写。目标是建立明确的仲裁协议：保留权威且仍属于当前会话/账号/操作代次的结果；丢弃过期、重复、低权威或无法证明归属的结果。

## Current state

- 聊天消息提交：`third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` 与 `tui_chat_global_model.dart` 已有 commit result、stable identity、历史窗口保护；不得回退这些保护。
- 通话：`lib/src/services/livekit_call_session.dart` 有 `_sessionGen`、`_finalizing`；`voice_output_route_service.dart` 已有路由单飞，但音频恢复、结束回调和气泡刷新仍是多入口。
- 会话列表：`lib/src/services/conversation_local/conversation_sync_service.dart`、`conversation_local_store.dart`、`conversation_refresh_bus.dart` 仍并存 SDK、SQLite、Bus、置顶/草稿/群资料覆盖线。
- 聊天页：`lib/src/chat.dart` 已有 `_chatOpenGeneration` 和生命周期调度；所有新增提交必须绑定 conversation ID、页面 generation 和账号 generation。
- 测试命令：`flutter test`、`flutter analyze`；README 明确全量 analyze 存在历史遗留问题，新增代码不得引入新的 analyzer error。

## 仲裁规则（必须实现并测试）

### 1. 账号/页面/会话代次优先

结果只有同时满足 `authGeneration == currentAuthGeneration`、`pageGeneration == currentPageGeneration`、`conversationId == activeConversationId` 才能写 UI。退出登录、切换账号、离开页面、切换会话时递增对应代次；旧任务只能完成后台清理，不能写状态。

### 2. 权威来源优先级

同一字段冲突时按以下顺序保留：

1. 用户刚完成的明确本地操作（发送、撤回、删除、手动切换扬声器/听筒）；
2. SDK 明确事件或已确认回执；
3. 当前请求返回的云端详情/历史；
4. 本地 SQLite 仅作首次占位或离线兜底；
5. 会话 `showName`、旧 preview、旧缓存只作最终兜底。

低权威结果不得覆盖高权威结果，即使它更晚到达。

### 3. 同一操作的 latest-wins

搜索、资料刷新、前后台恢复、音频路由、群详情请求使用 operation generation：同一操作只保留最新目标，旧请求结果丢弃。例外是消息历史分页：前后分页结果必须按窗口合并，不能简单 latest-wins。

### 4. 不同操作的安全合并

消息发送/撤回/删除/回执不能互相覆盖：

- 结构变化（插入、删除、重排）优先于普通状态变化；
- 撤回/删除优先于发送进度；
- 已确认 SDK 回执只能接管同 stable identity 行；
- 无法唯一匹配 stable identity 时丢弃行级优化并回退现有安全整表提交，不猜 FIFO。

### 5. 重复事件幂等

通话气泡、媒体消息、群资料快照、会话 mutation 必须具备稳定 key。重复事件只更新已有对象，不新增第二个对象。没有稳定 key 时禁止自动合并，保留原始结果并记录诊断。

## Scope

**In scope**

- 新增一个纯 Dart `MobileAsyncCommitGuard`/等价模块及单元测试；
- 接入 `chat.dart`、消息提交协调器、会话 RefreshBus/SyncService、LiveKit call session 与 call-bubble 写入入口；
- 为搜索/群资料/媒体任务复用同一代次校验 API；
- 增加冲突矩阵、过期结果计数和测试工具。

**Out of scope**

- 不修改腾讯 IM SDK 历史接口、分页参数或消息语义；
- 不修改服务端协议、接口字段、删除语义或多端同步能力；
- 不改变图片质量、上传 payload、音频默认策略、通话 UI 布局；
- 不删除现有安全 fallback，除非新 guard 已有等价测试覆盖。

## Steps

### Step 1: 先补行为契约测试

覆盖账号切换、页面退出、会话切换、旧请求晚到、同 stable identity 重复事件、历史前后分页合并、删除/撤回优先级、通话结束回调重复、音频路由 latest-wins。

**Verify**: `flutter test test/mobile_async_commit_guard_test.dart test/chat_lifecycle_generation_contract_test.dart` → 全部通过。

### Step 2: 接入消息和媒体提交

所有消息 mutation 先取得 guard token；提交前校验 token。无法唯一匹配时使用现有安全整表路径，不得丢消息或猜测替换。

**Verify**: 运行已有历史分页、消息身份、媒体双气泡、删除撤回和编译测试 → 全部通过。

### Step 3: 接入会话列表与群资料

RefreshBus 改为携带 conversation ID/reason/generation 的事件对象；旧事件不得覆盖新 mutation。群资料只允许快照提交，SQLite/showName 仅占位或兜底。

**Verify**: 新增会话 mutation/群资料冲突测试；验证置顶、归档、免打扰、删除、群名/头像/人数/公告不闪回。

### Step 4: 接入通话结束与音频恢复

同一 callId 的结束、仓库变化、历史刷新只允许一次气泡正式插入；音频 recovery 单飞，旧 generation 不得恢复已结束通话。

**Verify**: 通话生命周期、CallKit gate、音频路由和 call-bubble 幂等测试全部通过。

### Step 5: 真机回归门禁

验证首次安装、后台恢复、快速切账号、快速切会话、连续发图、删除/撤回、多设备通话、蓝牙接入/断开。若出现消息丢失、顺序变化、草稿丢失、群资料错配、媒体双气泡或无声，立即停止后续优化。

## Done criteria

- [ ] 所有可提交异步结果绑定账号/页面/会话代次；
- [ ] 同一 stable identity 不产生第二个消息或通话气泡；
- [ ] 旧请求不能覆盖用户明确操作或 SDK 已确认结果；
- [ ] 历史分页仍按窗口合并，不被 latest-wins 破坏；
- [ ] 相关定向测试通过，`git diff --check` 通过；
- [ ] 无 Scope 外文件修改。

## STOP conditions

- 无法唯一识别消息/通话/媒体 stable identity；
- 需要改变 SDK 历史来源或服务端协议；
- 新 guard 会导致未读、排序、分页、草稿、通话音频或媒体 payload 变化；
- 测试无法证明旧结果被丢弃而非误删有效结果。

## Maintenance notes

以后新增任何 `unawaited`、Timer、post-frame、SDK listener 或网络回调，必须声明其 operation kind、stable key、generation 和冲突优先级；没有这些信息不得直接写 UI、SQLite 或正式消息列表。
