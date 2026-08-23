# 实施计划

由 improve 技能于 2026-08-20 生成。早期计划（001–002）范围是**会话列表卡顿**。003–004 范围是 **主线程 RegExp / 聊天历史路径**。005 范围是 **通话气泡 / 历史分配 → GC**，依据 Instruments `docs/pro.md` 的 DartWorker 压力以及 `/how` 评审 C3。006 通过候选门禁削减链接/提及 RegExp 的**调用量**。007–008 针对剩余卡顿：**跨重建复用解析**，以及 Display 卡顿采集 `docs/pro.md` 显示主线程 `Interpret` 仍占 hitch 窗口后，**首帧推迟富化**。
计划 **009** 范围是**群 @我 跳转**：around-seq 窗口（复用搜索跳转原语）、落地后连续上下翻历史、经现有 `reloadNewestMessageWindow` 平滑回底。
计划 **010** 范围是入口 **「xxx条未读」**：重新启用舌尖、停止预加载整段未读栈、用已读游标 around-window（groupReadSequence / c2cReadTimestamp）跳到首条未读，连续性与回底契约同 009。
计划 **011–012** 范围是**暖恢复丢消息**：即使会话预览未超前，也在 `app_resumed`（及相关原因）允许 CLOUD_NEWER；并停止误标「恢复已满足」/ 武装跳过窗口，以免本地空拉后短路追新。
计划 **013–014** 范围是**对端昵称/头像陈旧**：本地缓存 prefer-local 合并会丢掉现场 IM 公开资料；SelfHosted 好友信息路径从不落 nick/face — 先修合并策略，再接线摄入事件。
计划 **015** 范围是**可见聊天发送者懒刷新资料**（群内沉默成员）：在消息列表构建时用带上限/TTL 的 `getUsersInfo`，**绝不**全群扇出。
计划 **016** 范围是**自定义相册开关闪白**：缩短 PhotoKit 初始化延迟、推迟 iOS 高清缩略图升级、取消与成功都要在 `endMediaPickerOverlay` 前 settle。
计划 **017** 范围是**图片很多的聊天打开卡顿**：停止整文件布局探测、气泡始终限制 `ResizeImage`/`cacheWidth`、打开沉降期短暂强制滚动档解码预算。
计划 **018** 范围是**发出图片双气泡**：swap 时收拢乐观行 + SDK 回执；用 outgoing stable id / path / localSeq 关联。
计划 **019** 范围是**打开聊天列表上浮**：揭示/沉降时用 jump 贴底，历史就地出现，而不是从底部滑上来。
计划 **020** 范围是**打开转场卡顿**：push 期间轻壳、push 前保证暖窗完整、打开/暖窗条数 **40→20**。
计划 **021** 范围是相册关闭后**媒体预览滚动解锁**。
计划 **022** 范围是 **Push 前 ViewportReady**：EntrySnapshot + 打开状态机；轻壳降级为 Ready 未命中时的回退（设计文档）。
计划 **023** 范围是**媒体预览返回闪一下**：媒体/相册/钱包 overlay 持有恢复时，跳过 Chat `activate` 的激进 overlay 恢复（`jumpTo` + `setState`）（保留 021 解锁）。
计划 **024** 范围是**全屏预览发糊**：只把 SDK ORIGIN 类型当升级目标；禁止 `hasResolvableOriginalUrl` / `resolveOriginal` 把 BIG/SMALL 当成「原图」（高 DPR 设备会卡在约 720 的 LARGE）。
计划 **025–026** 范围是**搜索跳转到历史中段后的滚动**：around-window 落地后释放内存抑制并允许在 `notShowLatest` 下连续 `loadLatest`，再拒绝不相接的最新合并，并加固未命中 → 回最近（来自 `/how` + `/improve` 2026-08-22）。
计划 **027** 范围是**长按消息菜单沉重**：用实色遮罩替换现场 `BackdropFilter` σ=22；复制/删除前先关菜单（删除仍确认，但在关闭之后）。
计划 **028** 范围是**通讯录 Tab 切换延迟**：`setState` 前不要 `await enterContactDataSource`；单飞合并，避免 Tab + 列表控件重复 Difference（`/how` 2026-08-22）。
计划 **029** 范围是 **LiveKit 全屏通话页顿挫**：用绘制快照门禁 `setState`；把铺满头像解码与视频纹理挂载错开（`/how` 2026-08-22）。
计划 **030–031** 范围是 027 之后**长按菜单打开残留成本**：限制/推迟气泡 `toImage`，让普通菜单先画再完成截图；关掉快捷反应条上残留的 `BackdropFilter`（`/how` + `/improve` 2026-08-22）。
计划 **032** 范围是**用 Time Profiler 栈 + 场景日志重采 Display 卡顿** — `docs/pro.md`（2026-08-22）只有 Display，不得据此再开代码计划（`/how` + `/improve` 2026-08-22）。
计划 **035** 范围是**用户资料页头像闪一下**：`loadData` await 前同步 `readCached` 种子、真实 URL 用中性 `Avatar` 占位、后端脸只填空（`/how` + `/improve` 2026-08-22）。
计划 **036** 范围是资料页 **Frame.onReportTimings 栈溢出**。
计划 **037–038** 范围是 `docs/pro-scenario.md` Probe dump 之后的**无损列表→聊天 RegExp 削减**：early-out + 手写解析 `msgId.c2cWireIdentity`（约 18ms），再可选修剪 `call_bubble.normalize`（约 1.7ms）（`/improve` 2026-08-22）。
计划 **039–042** 范围是同一场景日志之后的** RegExp 后无损打开路径**：序列化 Sqflite close/resume 竞态、首帧后再 GET 钱包订单卡、指纹跳过重复 `call_bubble.normalize`，再重采 Display 卡顿（`/improve` 2026-08-22）。
计划 **043** 范围是**底栏未读角标闪烁**：拒绝瞬时 `(0,0)` 聚合发布（空 owner / 未确认的 store 刷新），`clearSession` 仍立即生效（`/how` + `/improve` 2026-08-22）。
计划 **044** 范围是**置顶后继续翻旧历史**：`haveMoreData` 时成功上一页后释放同顶到达闩，用户不必先下滑约 320px 再上滑（`/how` + `/improve` 2026-08-22）。
计划 **045** 范围是**发送者看不见自己刚发出的消息**而对端能看见：别名安全的 force-pin、`setMessageList(replace:)` 保住在途自己消息、从陈旧内存窗发送时回最新端（`/how` + `/improve` 2026-08-22）。
计划 **046** 范围是**会话列表甩动空白直到重启**：`scroll_end` 时若视口在活动窗 ± 半径外则跳虚拟水合窗，即使 covered-skip 路径本会跳过也要 notify（`/how` + `/improve` 2026-08-22）。
计划 **047** 范围是 **iOS CallKit 被叫单通**：B 用系统来电接听（离线 VoIP）→ A 无声、B 能听见 A。麦克风发布门禁在已闩住的 `didActivate`；原生 fulfill Answer；超时推迟（不要吞超时后静默发布，不要挂断）（`/how` + `/improve` 2026-08-22）。
计划 **048** 是 047 残留：CallKit `_onAccept` 必须用 `keepAudioSession` dismiss（与 App 内接听相同）；CallKit 持有会话时跳过 LiveKit `setSpeakerphoneOn`；MethodChannel 事件丢失时查询/回放原生 `didActivate`（`/how` + `/improve` 2026-08-22）。
计划 **049** 范围是 **045 之后仍「当时看得见、再进没有」**：`replace: false` 的 20 条旧页与 160→120 内存窗会裁掉已 *SEND_SUCC* 的自己消息；暖调度用 `isActiveChat`（要 routeVisible）会在进页时灌窗；再进页暖跳过不认「lastMessage 不在列表」。依据 `docs/控制台输出.md` + `[OutgoingVisible]`（`/improve` 2026-08-22）。
计划 **050** 范围是 **049 之后历史仍被后台补旧改写**：分模型用裸 `rqwm8onw3j` 读空的 `messageListMap`，把 20 条旧页 `replace: false` 合进 `c2c_` 真窗；049 retain 把更旧的自己消息抬成 tip（`9` → `0` / `11111`）。依据 `docs/控制台输出.md` + `/how`（`/improve` 2026-08-22）。
计划 **051** 范围是 **050 之后最新约 20 条对、再往上不对**：C2C seq 按发送方编号，补旧仍按群 seq 裁脊柱 / `shouldMergeOlderPage`，合法上一页被拒或焊上另一截。依据 `docs/控制台输出.md` + `/how`（`/improve` 2026-08-22）。

除非依赖另有说明，按下面顺序执行。每个执行者：开工前通读计划、遵守 STOP、完成后更新本表行。

本工作区可能**没有 `.git` 目录**。用各计划「当前状态」摘录对照现文件做漂移检查。不要 `git init`。不要 push。

## 执行顺序与状态

| 计划 | 标题 | 优先级 | 工作量 | 依赖 | 状态 |
|------|------|--------|--------|------|------|
| 001 | lastMessage 本地 patch 时跳过空操作排序 | P1 | S | — | 已完成 |
| 002 | 拆分 Feed listenables，内容 notify 跳过公告/签名工作 | P1 | M | 001 | 已完成 |
| 003 | 把主线程 RegExp 归到具体 Dart 调用点 | P1 | M | — | 已完成 |
| 004 | 静态化 msgID 与 markdown 预处理热路径上的临时 RegExp | P1 | S | — | 已完成 |
| 005 | 削减通话气泡历史路径上多余的 JSON 解码 / 分配 | P1 | M | — | 已完成 |
| 006 | 削减聊天文本热路径上的链接/提及 RegExp 调用 | P1 | M | 003,004 | 已完成 |
| 007 | 跨重建缓存链接/提及解析结果 | P1 | M | 006 | 已完成 |
| 008 | 首帧之后再做链接/提及富化 | P1 | M | 007（软） | 已完成 |
| 009 | 用 around-seq 窗口跳 @我；连续滚动 + 平滑回底 | P1 | M | — | 已完成 |
| 010 | 入口「xxx条未读」舌尖 → 已读游标 around-window 到首条未读 | P1 | L | 009 | 已完成 |
| 011 | 暖恢复：经 `shouldAllowCloudCatchUp` 允许 CLOUD_NEWER | P0 | S–M | — | 已完成 |
| 012 | 暖恢复：停止误标恢复已满足 / 单次重试短路 | P0 | M | 011（软） | 已完成 |
| 013 | 本地资料合并时优先远端非空对端昵称/头像 | P0 | S–M | — | 已完成 |
| 014 | 接线好友信息 / 消息 / 打开摄入，更新现场对端公开资料 | P0 | M | 013 | 已完成 |
| 015 | 对可见聊天发送者懒刷新公开资料（带上限/TTL） | P1 | M | 013–014 | 已完成 |
| 016 | 减轻自定义相册开关闪白（延迟 / 高清 / 关闭 settle） | P1 | M | — | 已完成 |
| 017 | 打开聊天时限制图片气泡解码成本（探测 + 限制 + 打开推迟） | P1 | M | — | 已完成 |
| 018 | 收拢发出图片双气泡（swap / stable-id 关联） | P0 | M | — | 已完成 |
| 019 | 打开聊天即时贴底（不要从底往上浮） | P1 | S | — | 已完成 |
| 020 | 轻壳 + 打开前暖窗完整（条数 20） | P0 | M | — | 已完成 |
| 021 | 媒体图库关闭后解锁聊天滚动 | P0 | S | — | 已完成 |
| 022 | Push 前 ViewportReady（Snapshot + 阶段机） | P0 | L | 020 | 已完成 |
| 023 | 媒体预览返回时跳过激进的 Chat overlay 恢复 | P0 | S | 021 | 已完成 |
| 024 | 全屏预览升级到真正的 ORIGIN（不是 BIG/SMALL） | P0 | M | — | 已完成 |
| 025 | 搜索跳转：around 落地后释放抑制并允许 loadLatest | P0 | M | — | 已完成 |
| 026 | 搜索跳转：连续最新合并 + 加固未命中回退 | P0 | M | 025 | 已完成 |
| 027 | 减轻长按菜单（实色遮罩 + 先关再干活） | P1 | M | — | 已完成 |
| 028 | 通讯录 Tab 即时切换（不 await enter + 单飞） | P0 | S–M | — | 已完成 |
| 029 | LiveKit 通话页：绘制门禁重建 + 错开重背景 | P0 | M | — | 已完成 |
| 030 | 更早/更便宜地打开消息菜单气泡 toImage | P1 | M | 027（软） | 已完成 |
| 031 | 关掉消息菜单反应条上的现场模糊 | P1 | S | — | 已完成 |
| 032 | 用 Time Profiler + 场景日志重采卡顿 | P0 | S–M | — | 待办 |
| 033 | 资料页打开 RegExpProbe + 列表→聊天 dump | P0 | S | — | 已完成 |
| 034 | 打开后错开 DeferredHyperlinkText 富化 | P0 | M | — | 已完成 |
| 035 | 停止用户资料页打开时头像闪一下 | P1 | M | — | 已完成 |
| 036 | 修复 Frame.onReportTimings 栈溢出（资料） | P0 | S | — | 已完成 |
| 037 | 无损削减 msgId.c2cWireIdentity RegExp（early-out + 解析） | P0 | M | — | 已完成 |
| 038 | 无损修剪 call_bubble.normalize（debugPrint + meta 路径） | P1 | S | 037 | 已完成 |
| 039 | 序列化 Sqflite close/resume（前台打开竞态） | P0 | M | — | 已完成 |
| 040 | 首帧聊天绘制后再 GET 钱包订单卡 | P0 | S–M | — | 已完成 |
| 041 | 指纹跳过重复的 call_bubble.normalize | P1 | S–M | 038 | 已完成 |
| 042 | RegExp 削减后重采 Display 卡顿（测量） | P0 | S–M | 037 | 待办 |
| 043 | 停止底栏未读角标闪烁（瞬时清零） | P0 | M | — | 已完成 |
| 044 | 置顶在顶部时继续加载更旧历史 | P0 | S–M | — | 已完成 |
| 045 | 发送者自己刚发出的消息必须留在屏幕上 | P0 | M | 018（保持绿） | 已完成 |
| 046 | 甩动空白后 settle 时跳会话列表水合窗 | P0 | S–M | — | 已完成 |
| 047 | CallKit 被叫麦克风门禁在 didActivate（不要静默超时） | P0 | M | — | 已完成 |
| 048 | CallKit dismiss+keepAudio；跳过扬声器；查询原生 activate | P0 | M | 047 | 已完成 |
| 049 | 已发送成功的自己消息不得被旧历史页 / 120 窗裁掉 | P0 | M | 045、018（保持绿） | 已完成 |
| 050 | 补旧历史按别名读窗，不得用 20 条旧页盖掉 newest tip | P0 | M | 049、018（保持绿） | 已完成 |
| 051 | C2C 补旧按 lastMsg / 时间接页，不得用群 seq 裁脊柱 | P0 | M | 050、049、018（保持绿） | 已完成 |

状态取值：待办 | 进行中 | 已完成 | 阻塞（附一行原因） | 否决

## 本轮新增计划（2026-08-23）

| 计划 | 标题 | 优先级 | 工作量 | 依赖 | 状态 |
|------|------|--------|--------|------|------|
| 052 | 建立聊天页主线程性能基线 | P0 | S–M | — | 进行中（等待真机 Profile） |
| 053 | 历史提交增量化并限制整表重建 | P0 | M | 052 | 待办 |
| 054 | 将媒体准备移出聊天页关键帧 | P1 | M | 052 | 待办 |
| 055 | 串行协调群名称/人数/公告刷新 | P1 | M | 052 | 待办 |

执行顺序：052 → 053；052 → 054；052 → 055。先完成 052 的真机 Profile 基线，再决定 053–055 的具体优化幅度。

## 依赖说明

- **051 → 050 / 049 / 018**：050 已让补旧按别名读窗、全表 `replace: true`。051 **不得**回退那套 commit，也不得改 049 retain / 018 correlate。C2C 只关 seq 接页（`useSeqContiguity: false` + peek trusted-all + `lastMsgSeq=-1`）。**不要**改群 `keepNewestContiguousSpine` 默认语义，**不要**改 `compareMessagesChronological`。通话气泡 `21→33` +1 **不在** 051。
- **050 → 049 / 018**：049 已让 `replace: false` 也 retain。050 **不得**回退 retain 谓词或关掉 `_fillTowardOlderHistory`。补旧 commit 必须用 `mergedAliasMessageList` 当 existing，写入已 merge 的全表（`replace: true`）。**不要**改 `_storageConversationId` 剥前缀（SDK 要裸 userID）。**不要**改 018 correlate。
- **049 → 045 / 018**：045 只保住 `replace: true` + previous 非空时的在途/更新自己行。049 **不得**回退 045 pin 别名或发送栈不 await `reloadNewest`。retain 必须继续把 018 已 swap 的占位当 covered。暖调度 skip 用 `matchesOpenConversation`，**不要**改 `isActiveChat` 的 routeVisible 语义，**不要** `hasOpenChat` 就跳过所有会话预热。
- **048 → 047**：先落地 047（闩 / 推迟 / 原生 Answer fulfill）。048 **不得**回退那些改动。`_onAccept` 成功必须像 `acceptFromUi` 一样调用 `dismissSystemCallKitForSession(keepAudioSession: true)`。仅在 CallKit **持有**会话时跳过 `setSpeakerphoneOn`；保留无轨道跳过。查询原生 activate — **不要**回放 `voipChangeAccept`。**不要**在 App 内接听 / 主叫上 await CallKit。
- **047**：与 044–046 独立。只做 iOS CallKit **被叫**麦克风门禁。**不要**在 `acceptFromUi` 或主叫 `_connectAndPublish` 上 await CallKit。activate 超时时 **不要**抛 `LiveKitPublishException`（会挂断本可恢复的通话）。**不要**改 `hasLiveCallAudioTracks` 的扬声器跳过（症状相反）。End/Mute 可以保留 8s `holdCallAction`；Answer 必须在 `configureAudioSession` 后 `fulfill`。
- **046**：与 044–045 独立。**不要**每个 Android 滚动帧都水合；**不要**放大 `virtualHydrateRadius` / 关掉虚拟列表。中滑 clamp + 拒绝传送保留。只有 `force`（scroll_end）可通过 `conversationVirtualHydrateShouldJumpWindow` 设置 `allowWindowJump`。
- **045**：与 044 独立。必须保持 **018** 双气泡测试为绿（`replace` 保留必须能把已 swap 的占位关联掉）。发送栈上 **不要** await `reloadNewest`；**不要**重改 C2C `isSelf` 镜像。贴底匹配必须用 `isSameConversationIdForHistory`，不能用字符串 `!=`。
- **044**：与 039–043 独立。没有新的滚动事件时 **不要**自动连锁翻页；**不要**改 `haveMoreData` / SDK `isFinished`；空批闩 + 320px 离顶作为重试保留。冷却 / 防抖 / `ignoreScroll` 保留。
- **043**：与 039–042 独立；随时可落地。不替代 042 的卡顿测量。
- **039 ∥ 040 ∥ 041**：037/038 之后可并行。若前台日志仍刷 `SqfliteClosedForBackground`，优先 **039**。
- **042**：测量门禁 — 若 039–041 同一周落地则之后再跑；否则现在采一份「RegExp 已完成」基线。
- **037 → 038（软）**：先落地无损 `msgId.c2cWireIdentity` early-out + 手写解析；再投入 `call_bubble.normalize` 前用 `[RegExpProbe]` 重测。若 037 后该点 ≪ 0.5ms，否决 038。（**038 已完成** — 剩余约 1ms 是 JSON/meta；见 041。）
- 001 → 002：仅内容的 lastMessage 更新不得在 Feed 拆分见效前顶结构（均已完成）。
- 003 ∥ 004：**可并行**（均已完成）。
- 006 依赖 003/004（已完成）。
- 005 ∥ RegExp 后续（已完成）。
- **007 → 008**：007 单独有助于滚动重建；008 有助于打开帧尖峰。优先 007。008 可在无 007 时交付，但若 007 已落地须保持其测试为绿。
- 在 007+008 之后，除非新的 Profile `[RegExpProbe]` dump 仍点名 `link.*`，**不要**改写 `urlReg` / 提及模式字符串。
- **009 ∥ 007–008**：与 RegExp 卡顿工作独立。不得再引入 `lastSeq - targetSeq` 无界向前加载。复用 `loadListForSpecificMessage` + 舌尖 `reloadNewestMessageWindow`。
- **010 → 依赖 009 模式**：入口首条未读跳转必须复用 around-window + 内存窗锚点 + 回底；**不得**在打开时预加载 `unreadCount+12` 或把 1 万条追进内存。
- **011 → 012**：先落地云端允许列表；再修满足条件 / `_recordRecoverySuccess` / 重试延迟。若 CLOUD_NEWER 仍被 `previewAhead` 卡住，单做 012 拉不到缺失的服务端消息。
- **013 → 014**：接线事件前合并必须接受远端 nick/avatar；若 `_preferLocal` 丢掉 IM 公开字段，单做 014 仍是空操作。两计划里 **备注仍走本地/SelfHosted**。
- **015 → 依赖 013–014**：可见发送者懒 `getUsersInfo` 走同一本地合并 + bus；**绝不**扇出到全部群成员（成本 ∝ 视口唯一发送者，不是群规模）。
- **016 ∥ 015**：相册闪白与资料刷新独立。打开时不要再引入 `PhotoManager.clearFileCache`。
- **017 ∥ 016**：打开图片解码与相册闪白独立。017 **不要**降低 `initialOpenFetchCount` 或改预取暖窗上限；**不要**用 `ScreenshotHelper.getImageSize` 做气泡布局。
- **018 ∥ 016–017**：双气泡修复只动消息列表身份。**不要**只靠时间戳合并同秒不同图；没有 stable id / 唯一 path 时 **不要** FIFO 猜多图占位。
- **019 ∥ 打开水合**：只在揭示/沉降时即时 jump；打开窗口之后保留平滑入站跟随。
- **020 ∥ 019**：轻壳把 TIMUIKitChat 推迟到路由沉降；预热目标是 `history_gate_content_ready_skip`。条数 **20** 是有意的（覆盖 017「不要为仅解码工作降低条数」）。
- **021 ∥ 媒体预览**：滚动解锁不得依赖气泡 `State.mounted`；`pushMediaPreview` 拥有 `restoreScrollAfterMediaPreview`。
- **022 → 020**：Ready 门禁的 Push 建立在暖窗 20 + 轻壳上；ViewportReady 未命中时轻壳才是**回退**。不要删除暖调度。Snapshot 是点击时从 `messageListMap` 派生，不是逐格复制。
- **023 → 021**：返回闪白修复 **不得**把滚动解锁搬回气泡 `mounted`；保持 `pushMediaPreview` → `restoreScrollAfterMediaPreview`。只软化媒体 overlay 的 Chat `route_reactivated` 激进恢复。
- **024 ∥ 017 / 023**：全屏清晰度是**源档 / ORIGIN 下载门禁**，不是气泡列表解码，也不是 Chat overlay 恢复。024 **不要**提高 `kChatBubbleImageDecodeMaxPx` 或去掉高图 `fitWidth`。
- **025 → 026**：先落地抑制释放 + 最新门禁；只有 `LoadDirection.latest` 在 `notShowLatest` 下真正跑起来，026 的连续合并才有意义。025 **不要**改 `_combineMessageList`。
- **025–026 ∥ 009/010**：复用 around-window + `_releaseSearchJumpMemoryWindowSuppress`；不要再引入无界 `lastSeq - targetSeq` 向前追。修搜索 `MessageAnchor` 落地时不要破坏 @我 / 入口未读的成功释放路径。
- **027 ∥ 菜单 UX**：与搜索跳转 / 相册计划独立。**不要**去掉删除确认；**不要**恢复现场 `BackdropFilter` σ=22；027 **不要**改写 `captureSnapshot` 打开路径。
- **028 ∥ 通讯录 Tab**：先画 Tab；保持本地优先 + Difference 同步，但 `setState` 前绝不 `await enterContactDataSource`。并发的 Tab + `ContactListWithPresence` enter 必须单飞。
- **029 ∥ LiveKit 通话页**：只做 UI 侧绘制快照门禁 + 重背景错开。**不要**全局静音 session `notifyListeners`；**不要**把视频层退回仅已连接；保留 `_exiting` 挂断路径。
- **030 ∥ 027 之后**：只动打开路径的 `toImage`。**不要**恢复全屏现场模糊；**可滚动**超长菜单仍可在插入前 await 截图；关闭时释放过期截图。
- **031 ∥ 027 残留**：只把反应条 `useBackdropBlur: false`。**不要**改操作菜单颜色或控制器遮罩。**030 ∥ 031** 顺序均可；只交一个时优先 030。
- **032 ∥ 挡住代码卡顿计划**：仅 Display 的 `docs/pro.md` 不得派生聊天/菜单「修复」计划。在任何 033+ 卡顿代码工作前，先落地 playbook + 带栈导出（或标阻塞等待真机）。

## 硬产品边界（全部计划）

**不要**改变以下行为：聊天记录*语义*（URL/提及的最终富化检测）、钱包、通话/LiveKit 音频、通讯录、动态、搜索**结果排序 / 查询 API**、归档**页**、置顶/免打扰/删除动作、未读**语义**、`ConversationPerfFlags.conversationListSdkPrimary`、或 UIKit 会话行布局 — 除非某计划明确列出行为变更。
计划 **025–026** 只可改 **跳转后历史分页 / 未命中回退**（around-window 落地后向最新端滚；连续性；误未命中舌尖倾倒）— 不是搜索索引或结果 UI 外壳。
计划 **028** 只可改 **通讯录首页 Tab 切换时机**（同步完成前先画）— 不是好友列表语义、Difference 协议或 AZ UI。
计划 **029** 只可改 **LiveKit 通话页重建/解码时机** — 不是通话音频、信令、CallKit 或早期视频预览产品策略。
计划 **030–031** 只可改 **长按菜单打开时机 / 反应条外壳合成** — 不是菜单项集合、删除确认策略或全屏遮罩（保持 027 实色）。超长可滚动菜单仍可在插入前 await 截图（030）。
计划 **032** 只可改 **文档 / 采集 playbook / `docs/pro*.md` 产物** — 不是 Flutter 或 UIKit 产品代码。
计划 **044** 只可改 **成功上一页后的聊天历史到顶闩** — 不是 `haveMoreData` 映射、倒序列表物理、短视口填充旁路或分页常量（120/320/520/160/320）。
计划 **045** 只可改 **发出贴底别名匹配**、**`setMessageList` replace 时保留在途/更新的自己行**、以及 **`haveMoreLatestData` 时 prepend → 不 await 的 `reloadNewestMessageWindow`** — 不是 C2C `isSelf` 改写、018 关联 key、044 分页、舌尖胶囊策略、钱包或通话气泡。
计划 **047** 只可改 **iOS CallKit 被叫音频门禁**：`didActivate` 闩、等待 ready/defer、原生 `CXAnswerCallAction` fulfill、activate 后重发本地麦 — 不是 App 内接听顺序、主叫加入、Android FCM、扬声器/听筒产品默认或 `keepAudioAcrossCallKitEnd`。
计划 **048** 只可改 **CallKit `_onAccept` dismiss+keepAudio**、**CallKit 持有音频时跳过 LiveKit 扬声器**、以及 **原生 activate 查询/回放** — 不是 App 内接听顺序、主叫加入、语音听筒默认、047 defer/fulfill，或挂断时不带 keepAudio 的 `endVoipCallKit`。
计划 **049** 只可改 **`setMessageList` 非 replace 也 retain**、**内存窗 trim 后补回 tip 自己消息**、**暖调度对打开会话禁止灌内存**、**预览 tip 不在列表则不 skip bootstrap / 拼 lastMessage** — 不是 018 关联、045 await reload、120/160 数值、会话列表 Feed 的 120 预算、C2C `isSelf`。
计划 **050** 只可改 **补旧 / peek commit 的 existing 读法**（`mergedAliasMessageList`）以及 **已 merge 全表用 `replace: true` 写入** — 不是剥前缀、049 retain 谓词、018 correlate、关掉往旧处补页、`call_bubble_normalize`。
计划 **051** 只可改 **C2C 旧页连续性**（`shouldMergeOlderPage`/`connects` 的 `useSeqContiguity`、peek C2C trusted-all、C2C `lastMsgSeq=-1`）— 不是群 seq 脊柱默认、050 commit、049 retain、018 correlate、通话气泡回灌、120/160。
计划 008 只允许 **一帧**未样式化的纯文本呈现。

## 重测门禁（操作员，不是代码计划）

**032 之后的权威 playbook：** `docs/perf-hitch-capture.md`（由计划 032 创建）。032 完成前，把下面当作最低标准：

1. 优先 **profile** 构建；挂 Instruments **Display Hitch + Time Profiler**。
2. 按 2026-08-22 Display 采集窗口填写 `docs/pro-scenario.md` 的 Cluster A（约 1.6–11s）和 Cluster D（约 27–31s）。
3. 导出不含 Dart/CPU 栈（`dart::` / `Interpret` / Time Profiler 最重栈文本）的采集，不得当作「可开代码计划」的依据。
4. 可选：脚本打开聊天时收集 `[ChatOpenPerf]` 日志。
5. 遗留说明（007/008 时代）：若栈仍点名链接/提及，历史打开的 RegExpProbe dump 仍有用。

## 评审 / 发现（2026-08-20 性能轮 — 以卡顿为主）

### 要做（新计划）

| # | 发现 | 计划 |
|---|------|------|
| A3 | `MessageHyperlinkTextCache` 只缓存 `LinkPreviewText` 工厂；`LinkText` 每次 build 仍跑 `allMatches` | 007 |
| A4 | 打开聊天一帧挂上很多文本气泡 → 同步解析卡顿 | 008 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| C5 | 把解析丢到 isolate | V2TimMessage / UIKit 类型别扭；先试 007/008 |
| C6 | 算法改写 `urlReg` | 需要 007 后的 Probe dump；产品敏感 |
| C4 | Impeller 文本图集 | 卡顿 profile 里是次要的 |

### 备忘

| # | 项 |
|---|-----|
| N1 | `call_bubble_normalize` 与尖峰相关，但主要是 JSON/去重（005） |
| N3 | 006 门禁仍必要；007 不得拆掉它们 |

### 驳回 / 否决（没有新证据不要重开）

- 把 `conversationListSdkPrimary` 翻成 true — 是迁移，不是卡顿修复。
- 为拆而拆 `lib/src/conversation.dart` — 技术债。
- 改写 Impeller / 去掉 `ClipRect` / 提高 cache extent — 层次不对。
- 没有 Probe 数据就盲目删弱提及/URL 正则。
- 只按 `msgID` 做解析缓存（文本编辑会陈旧）— 007 已否决。

## 已考虑并否决的发现（037 无损列表→聊天 RegExp）

| 发现 | 否决 / 推迟原因 |
|------|----------------|
| 再改写 `urlReg` / 链接富化 | Probe：`link.LinkText.scan` ≪ 0.1ms；034 已落地 |
| 把 `_isLikelyTencentSdkMsgId` 当主战场 | 约 0.09ms；除非与 037 共用一个小数位 helper 否则不动 |
| 只按 `msgID` 缓存整条 wire | 无损风险 — sender/ts/random 也重要；037 只允许 msgID→填充对缓存 |
| 打开时砍红包 GET | 作为 **RegExp** 发现：那是 IO，不是主线程 RegExp。在计划 **040** 里改为 **推迟**（不是砍掉） |
| 列表滚动头像 / 重建（旧 F4） | 不同场景；仅当 037 后仍有纯列表卡顿 |
| 主改 `msgId.isLikelySdk` | 037 后仍 ≪ 0.1ms；除非共用 helper 否则否决 |
| 把更多 RegExp 微优化当打开路径主杠杆 | Probe 头已没了；下一杠杆是 DB 竞态 / IO 推迟 / normalize 指纹（039–041） |

## 已考虑并否决的发现（039–042 RegExp 后无损）

| 发现 | 否决 / 推迟原因 |
|------|----------------|
| iOS `paused` 期间保持 DB 打开 | `0xdead10cc` 风险 — 039 必须序列化，不能跳过 close |
| 整段删掉订单卡刷新 | 产品正确性；040 只推迟安静刷新 |
| 在 isolate 上改写 `CallingMessageDataProvider` JSON | 爆炸半径大；先试指纹跳过（041） |
| 把列表→聊天怪到消息菜单 `toImage` / 模糊 | 场景不对（032 已分开） |

## 已考虑并否决的发现（045 发送者看不见自己发出）

| 发现 | 否决 / 推迟原因 |
|------|----------------|
| 改写 `_normalizeInboundC2cDirection` / `isSelf` 镜像 | 真有边角，但对端可见 + 发送者缺失已能用 pin 未命中 / replace 冲掉 / 陈旧窗解释；C2C 爆炸半径大 |
| `isChatListUserScrolling` 时停止取消 force-pin | 手指按下必须赢；相册残留已在 `endMediaPickerOverlay` 清掉 |
| `sendMessage` 前 await `reloadNewestMessageWindow` | 会拖住对端已经依赖的线路发送 |
| 改 018 `_swapOutgoingMessage` / 关联 key | 双气泡已落地；045 保留必须关联掉，而不是重改 018 |

## 已考虑并否决的发现（043 角标闪烁）

| 发现 | 否决 / 推迟原因 |
|------|----------------|
| 角标上 Opacity / AnimatedSwitcher | 掩盖根因；应用图标角标仍共用聚合 |
| 从 `applyNotifiableDeltas` 粘住 0 | 用户读完最后未读后正当清零会被拖住 |
| 重建 BottomNavigationBar 复用一个 Stack | 次要；闪的是 sum→0→N，不是图标单独重挂 |
| 未读为 0 时去掉 `SizedBox.shrink()` | 留下空布局坑；产品行为不对 |

- 把 `conversationListSdkPrimary` 翻成 true：架构迁移，不是卡顿修复；爆炸半径大。
- 拆 `lib/src/conversation.dart`（约 6500 行）：技术债，落地两个性能赢点不需要。
- 去掉 `ClipRect` / 改 `itemExtent` / 提高 `conversationFeedCacheExtent`：视觉或内存回退；Raster 是次要的。
- 改写 `TIMUIKitLastMsg` 全局 `DisplayNameStore` 监听：动到 vendored UIKit 预览；推迟。
- 滚动时预取头像：可能增加解码/内存；本批不做。
- 丢掉 `apply_store` 48ms 合并：会提高重建率，与目标相反。
- 乐观未读 +1（工作树里已有）：正确性功能，不是本性能批；001/002 不得回退。

## 已考虑并否决的发现（009 @我 跳转）

- 为 @ 跳转关掉 `ChatMessageWindowPolicy`：用无界内存藏洞；否决 — 保持锚定裁剪 + 回最新。
- 只用夹紧的 seq 差追（不要 around-window）：仍是 O(距离)；否决，搜索跳转已用腾讯文档 around-seq 模式。
- 新的归档 around-seq HTTP API：超出范围；更旧边沿在 SDK roaming 结束后已有归档更旧分页。

## 已考虑并否决的发现（010 入口未读）

- 只把 `entryUnreadTongueEnabled=true` 打开、不改打开水合：1 万未读会挂起/OOM — 否决。
- 按页向前追直到 `unreadCount` 进内存：与 009 前 @我 同一失败类 — 大未读否决。
- 打开自动跳到首条未读：用户要的是舌尖 + 点击；也和「落在最新」预期打架 — 推迟。
- 发明新的归档「首条未读」RPC：超出范围；用 `V2TimConversation` 上已有的 `groupReadSequence` / `c2cReadTimestamp`。

## 评审 / 发现（2026-08-21 — 暖恢复丢消息）

聚焦正确性（不是九类审计）。症状：后台 → 前台且未杀进程会丢聊天消息；冷启动正常。

### 要做（新计划）

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| W1 | 恢复拉取用 `allowCloudPull: previewAhead` — 列表预览陈旧/未超前时暖恢复跳过 `V2TIM_GET_CLOUD_NEWER_MSG` | bug | 高 | S–M | 中 | `lib/src/chat.dart` 恢复调用 ≈8482；拉取 helper 7251+；契约期望 `shouldAllowCloudCatchUp` 在 `test/chat_foreground_resume_reconcile_contract_test.dart`，现码 chat.dart 无此符号 | 011 |
| W2 | `isRecoveryAlreadySatisfied` + `history_recovery_skip_preview_merge_warm` 在「有气泡 + !previewAhead」且无云端证据时标成功；为 `app_resumed` 武装 30s 跳过 | bug | 高 | M | 中 | `chat_history_recovery_satisfaction.dart`；chat.dart ≈8505–8545；coordinator `shouldSkipForegroundRecovery` | 012 |
| W3 | `hasVisible && !previewAhead` 时 `chatRecoveryRetryDelays` 只给一次尝试 — 本地空拉后没有第二次机会 | bug | 中 | S | 低 | `resume_foreground_policy.dart` `chatRecoveryRetryDelays` | 012 |

### 方向（选项，不按 bug 排名）

| # | 建议 | 取舍 |
|---|------|------|
| D1 | 在 `paused` 持久化最后可见 msgID 供诊断 / 显式锚点 | 冷启动已 OK；暖路径已锚在可见 msgID — 相对 011 杠杆低 |
| D2 | 用 `_lastEnteredBackgroundAt` 做时间过滤强制追新 | SDK CLOUD_NEWER 基于 msgID；时间过滤要另一套 API — 优先 011 |
| D3 | 若 011+012 后追新仍被跳过，再看 `_loggedInSideEffectMinInterval`（12s） | 会增加恢复工作；仅当日志显示副作用从不跑 |

### 本轮已考虑并否决

- 把「用后台挂钟当历史 `since`」当主修复 — 否决；正确修复是从最后可见 msgID 允许 CLOUD_NEWER。
- 每个恢复原因都 `allowCloudPull: true`（含打开预览）— 否决；保持允许列表（`app_resumed` / 重连 / 同步）。
- 只改会话列表预览同步 — 否决；OS 挂起后预览可滞后，即使服务端已有消息。

### 本轮未审计

全仓安全、依赖、DX、钱包、LiveKit、RegExp 卡顿重测。011–012 是聚焦暖恢复正确性的一批。

## 评审 / 发现（2026-08-21 — 对端昵称/头像陈旧）

`/how`「对端改了头像/昵称，我们还显示旧的」之后的正确性轮。展示是本地优先；SDK 合并 + SelfHosted 好友信息跳过阻止现场公开资料更新缓存。

### 要做（新计划）

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| P1 | `mergeSdkRemotePreferLocal` / `UserInfo` 对 nick+avatar 用 `_preferLocal` — 本地非空永远压过现场 IM | bug | 高 | S–M | 中 | `user_profile_record.dart` ≈161–197；UI 先读 `readCached` | 013 |
| P2 | SelfHosted `onFriendInfoChanged` 在 `loadContactListData` 后返回，不 `saveUserInfo`/`saveFriendInfo` | bug | 高 | M | 中 | `tui_friendship_view_model.dart` ≈182–187 | 014 |
| P3 | 消息路径更新 `GroupMemberStore` 但不更新 `UserProfileLocalService`；会话脸优先本地 DB | bug | 中 | M | 低 | `_syncGroupMemberFromMessage`；`ConversationFaceUrl.resolve` | 014 |

### 方向（选项）

| # | 建议 | 取舍 |
|---|------|------|
| D1 | 后端推送 / presence 通道做资料版本 | 要服务端；013+014 可在无此条件下修客户端 |
| D2 | 气泡上永远显示消息快照 nick/face | 和「现场资料」产品打架；本地优先是有意的 |

### 已考虑并否决

- SelfHosted 下用 IM SNS 覆盖 **friendRemark** — 否决；本地备注为空表示已清除。
- 丢掉本地优先展示读取 — 否决；会闪并和离线打架；应修写入路径。

### 本轮未审计

全仓安全、依赖、DX、钱包、LiveKit（资料展示以外）。

## 评审 / 发现（2026-08-22 — 可见发送者懒刷新）

对端昵称/头像陈旧的后续：沉默**群**成员需要刷新，但不能全群 `getUsersInfo`。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| V1 | 沉默群成员从不走 014 消息 upsert；万人群进群全量拉取不安全 | bug/性能 | 中–高 | M | 中 | 014 消息路径；SDK `getUsersInfo` ≤100/批 | 015 |

### 否决

- 进群 / 全成员列表对所有人 `getUsersInfo` — O(群规模)，卡顿/流量。

## 评审 / 发现（2026-08-22 — 相册选择器闪白）

`/how`「打开相册选图会闪」之后的 UX 轮。移动聊天用自定义 `EditableAssetPicker`，不是系统 Photo Picker。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| G1 | `initializeDelayDuration: 250ms` → 打开时空壳再填网格 | UX | 高 | S | 中 | `editable_asset_picker.dart`；契约锁 250 | 016 |
| G2 | iOS 缩略图 HQ `_upgrade` 第二次 `setState` 锐度弹出 | UX | 中 | S | 低 | `asset_picker_edit_builder_delegate.dart` | 016 |
| G3 | 自定义取消/空选在 overlay 结束 notify 前跳过 `waitForPickerDismissSettle` | UX | 高 | S–M | 低 | more_panel `_runMediaTask` finally vs `_dispatchCustomPickedGalleryMedia` | 016 |

### 否决

- 改 pub-cache 里的 `AssetPickerPageRoute` — 超出范围；修它周围的时机。
- 打开时再开 `PhotoManager.clearFileCache` — 导致白缩略图（已有契约）。

## 评审 / 发现（2026-08-22 — 图片很多的聊天打开）

`/how`「进入带有大量图片的聊天对话页面很慢」之后的性能轮。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| I1 | 缺 meta 时气泡布局探测用 `ScreenshotHelper.getImageSize`（整 `readAsBytes` + `Image.memory`） | 性能 | 高 | S | 低 | `tim_uikit_chat_image_elem.dart` `_probeLocalImageLayout`；`screen_shot.dart` | 017 |
| I2 | `sourceIsThumb` 路径用空的 `cacheWidth`/`cacheHeight` 画 `FileImage` / `Image.file`（无界解码） | 性能 | 高 | S–M | 中 | `tim_uikit_chat_image_elem.dart` `decodeNativeThumb` | 017 |
| I3 | 打开贴底空闲跳过重解码推迟 → 很多气泡一起用 1920px 预算 | 性能 | 中–高 | S | 中 | `shouldSkipHeavyChatListPresentation`；`kChatBubbleImageDecodeMaxPx` | 017 |

### 否决

- 把降低 `initialOpenFetchCount`（40→15）当**解码**主修复 — 短列表 / 分页误「完整窗」风险；解码限制对图片卡顿杠杆更高。（**020** 后来为打开/暖转场降到 **20**，并保证完整 + 轻壳。）
- 本轮只按可见性绘制 — 空白瓷砖风险；017 不够再跟进。
- 提高预取暖条数 — 打开时更多解码争用，与目标相反。

## 评审 / 发现（2026-08-22 — 媒体预览返回闪一下）

`/how`「全屏预览下滑返回后消息列表闪一下」之后的 UX 轮。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| M1 | `ChatState.activate` 总是跑 `_recoverChatHistoryAfterOverlayReturn(route_reactivated)` → `jumpTo` 底 + `setState`，在 `opaque:false` 关闭下和 021 滚动恢复打架 | bug/UX | 高 | S | 低 | `lib/src/chat.dart` `activate` / recover；`deactivate` 已排除媒体 overlay | 023 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| M2 | `scrollLockedForOverlay` 切换时列表 Selector 重建 | 次要；先试 023 |
| M3 | 下滑关闭 Hero `scheduleRevealAll` 180ms 延迟 | 气泡局部；023 针对整表闪 |

### 否决

- 把滚动解锁搬回图片/视频 elem `mounted` — 回退 021。
- 对所有 overlay 删除 `_recoverChatHistoryAfterOverlayReturn` — 破坏资料/设置空白恢复（`return_from_*`）。
- 把预览路由透明度 / Hero 飞行当闪白主修复 — 层次不如 Chat recover。

## 评审 / 发现（2026-08-22 — 全屏预览发糊）

`/how`「不同机型/尺寸全屏预览发糊」之后的正确性轮。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| B1 | 全屏**沉降**后图仍软：升级把 BIG 当原图，`refreshOriginal` 返回同一 provider，ImageScreen 标 `_lowResolutionRefreshAttempted` 后不再重试 | bug | 高 | M | 中 | resolver + `image_screen.dart` `runRefresh` 中止 | 024 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| B2 | 提高 `imagePreviewDecodeScreenFactor` 或捏合缩放解到超过 1.45× | 次要；先修 ORIGIN — 1x 发糊是源限制 |
| B3 | 气泡可见时预取 ORIGIN | 带宽 / 电量；024 门禁正确后再做 |
| B4 | 高图 `fitWidth` 会放大不够屏宽的源 | 产品要高图贴边；清晰需要 ORIGIN 像素 |

### 否决

- 怪 017 气泡 `ResizeImage` / 提高 `kChatBubbleImageDecodeMaxPx` — 全屏用单独预览 resolver，不是气泡 provider。
- 把去掉高图 `BoxFit.fitWidth` 当发糊主修复 — 产品取舍不对；杠杆是 ORIGIN 升级。
- 把设备 GPU / Flutter 过滤质量当根因 — 差异跟物理像素预算 vs 约 720 LARGE。

## 评审 / 发现（2026-08-22 — 搜索跳转滚动 / 拼接）

`/how`「搜索跳转旧消息后滚动异常 / 与最新拼接」之后的正确性轮。计划直接写（`/improve 制定修复计划`）；默认选择 = 下面杠杆最高的 bug。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| S1 | `_onScrollToAnchor` 成功设 `SearchJumpStatus.success` 但从不 `_releaseSearchJumpMemoryWindowSuppress`（不像 `_onScrollToIndex` / `@我`） | bug | 高 | S | 低 | `tim_uikit_chat_history_message_list.dart` ≈9213–9231 vs ≈9283–9294 | 025 |
| S2 | `_shouldAttemptLatestHistoryLoad` 硬挡 `notShowLatest`，除非 `memoryWindowMissingNewer`，废掉 `_allowsLatestHistoryPagination` 的搜索跳转允许 | bug | 高 | M | 中 | 同文件 ≈5632–5674 | 025 |
| S3 | 分页 `loadChatRecord` 在 `isReadingHistory`（`notShowLatest`）时跳过所有 `LoadDirection.latest`，除非缺更新 — 模型空操作 UI 加载 | bug | 高 | S–M | 中 | `tui_chat_history_pagination_load.dart` ≈66–81；`isReadingHistory` ≈1960–1963 | 025 |
| S4 | `_combineMessageList` concat+sort 可能把不相接的最新批伪并进 around 窗 | bug | 高 | M | 中–高 | pagination_load ≈335–341，≈893–897 | 026 |
| S5 | 搜索未命中用 `messages.any(anchor.matches)` 再 `_fallbackToRecentHistory` — 比 around 加载 seqInt 成功更严 → 误舌尖倾倒 | bug | 中 | S | 低 | `tim_uikit_chat.dart` ≈1868–1906 vs 视图模型 around seq 匹配 | 026 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| S6 | 所有列表写入都盖 `_historyWindowGeneration` | 更广的竞态加固；025/026 先修用户可见落地路径 |
| S7 | 把 `initFindingMsg` 与 `searchJumpAnchor` 入口收成一个 API | 技术债；两者已调用 `loadListForSpecificMessage` |

### 否决

- 用从最新端无界向前追替换 around-window — 回退 009。
- 搜索落地后一次下完到最新的整段缺口 — 内存 / 产品成本。
- 把搜索 UI / 日期选择 / 关键词 API 当滚动修复的一部分 — 层次不对。

## 评审 / 发现（2026-08-22 — 长按消息菜单沉重）

`/how`「长按消息菜单复制/删除沉重」之后的性能/UX 轮。计划写作 `/improve plan`（027）。默认选择 = 下面 M1–M3。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| M1 | Telegram 菜单 + 旧 overlay 打开时用现场 `BackdropFilter` 模糊 σ=22 铺满；每次点菜单项拆卸都贵 | 性能 | 高 | S–M | 低 | `tim_uikit_telegram_message_context_controller.dart` ≈264–265；列表项 ≈3473–3474 | 027 |
| M2 | 复制路径调用 `onCloseTooltip` 后同一异步链立刻 `await Clipboard.setData` + toast（不让出帧）— 拆卸 + I/O 抢同一次点击 | 性能 | 中–高 | S | 低 | `tim_uikit_chat_message_tooltip.dart` ≈1127–1190 | 027 |
| M3 | 删除/撤回在模糊菜单 Overlay 仍在时就弹出确认；然后才关 | 性能 / UX | 高 | S–M | 中 | 同文件 ≈1059–1102 | 027 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| M4 | 打开时推迟 / 降采样 `captureSnapshot`（`toImage`） | **→ 已计划为 030**（2026-08-22 后续） |
| M5 | 缩短背景关闭反向（220ms）/ 320ms 守卫 | 影响误点保护；菜单项已硬关 |

### 否决

- 用系统 `PopupMenu` 替换 Telegram 抽出气泡菜单 — 产品回退。
- 一键删除不确认 — 安全 / 产品边界。
- 没有 Instruments 证据就为「好看」恢复 σ=22 软模糊 — 已知卡顿源。

## 评审 / 发现（2026-08-22 — 通讯录 Tab 切换延迟）

`/how`「从其他底栏切到通讯录偏慢」之后的性能轮。计划写作 `/improve plan`（028）。默认选择 = 下面 C1–C2。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| C1 | `_switchHomeTab` 在 `setState` 前 **await** `enterContactDataSource` — Tab 绘制被水合 +（常常）Difference + `refreshUIKitLists` 堵住 | 性能 | 高 | S | 中 | `home_page.dart` ≈1257–1285 | 028 |
| C2 | 去掉 await 后 Tab enter + `ContactListWithPresence` postFrame enter 可能竞态 — 需要单飞合并 | 性能 / 正确性 | 中 | S | 低 | `friend_request_notice_service.dart` ≈137–151；`contact_list_with_presence.dart` ≈115–121 | 028 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| C3 | 首帧消息后空闲预热 `_getContactPage()` | 只砍首次访问构建；次于绘制前 await |
| C4 | 拆水合（短 await）与网络（总后台） | 全不 await + 骨架已够；增加 API 面 |

### 否决

- Tab 进入时删掉 Difference / refresh — 新鲜度回退。
- 冷启动预建全部五个 Tab — 抵消懒 `_visitedTabs` 的赢点。
- 只把水合 await 到 setState 前当唯一修复 — 每次切换仍堵在 SQLite；优先全不 await + 骨架。

## 评审 / 发现（2026-08-22 — LiveKit 通话页顿挫）

`/how`「音视频通话相关页面顿挫卡顿」之后的性能轮。计划写作 `/improve plan`（029）。默认选择 = 下面 V1–V2。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| V1 | `LiveKitCallPage._onSession` 每次 session notify 都 `setState` | 性能 | 高 | M | 中 | `livekit_call_page.dart` ≈208–228 | 029 |
| V2 | 进入淡出结束（180ms）就启用重 `CachedNetworkImage` 背景，与视频纹理挂载重叠 | 性能 | 高 | S–M | 低 | ≈147–153，≈456–491；导航进入 180ms | 029 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| V3 | 把 `LiveKitCallSession` 拆成 chrome vs 媒体 ChangeNotifier | 更大改写；UI 绘制门禁是更便宜的第一刀 |
| V4 | 推迟 `VideoTrackRenderer` 到 `connected` | 回退空白预览修复（`livekit_call_video_layer`） |
| V5 | `RecentCallsPage` 网络 + `getUsersInfo` 列表卡顿 | 另一表面；全屏页之后再做 |

### 否决

- 仅已连接才出视频层 — 已知产品回退（相机已开仍空白）。
- 非零挂断反向转场拖纹理 — 导航已否决（`exitTransitionDuration = 0`）。
- 为音频路径静音 session notify — 危及 CallKit / 铃声 / 接听顺序。

## 评审 / 发现（2026-08-22 — 027 之后菜单打开残留）

`/how`「还有哪些区域可以优化」→ 要做 O1/O2 之后的性能轮。计划写作 `/improve`（030–031）。默认选择 = 下面 O1–O2。027 关闭/遮罩工作已完成且必须保持绿。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| O1 | 长按打开在 Overlay 插入前 **await** `captureSnapshot`/`toImage`；直到 4096 clamp 都用满设备 DPR | 性能 | 高 | M | 中 | `tim_uikit_chat_history_message_list_item.dart` ≈1341–1407；controller `captureSnapshot` ≈82–102；README 027 **M4** | 030 |
| O2 | 反应 `_FrostedTooltipShell` 漏了 `useBackdropBlur: false` → 默认现场模糊 σ=26 | 性能 | 中 | S | 低 | `tim_uikit_mobile_telegram_message_menu.dart` ≈525–537，≈589–603 vs 操作菜单 ≈474 | 031 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| O3 | `RecentCallsPage` `getUsersInfo` + 重建卡顿 | 029 V5；另一表面 |
| O4 | 把 `_historyWindowGeneration` 扩到所有列表写入 | S6 正确性加固；不是打开菜单卡顿 |
| O5 | 通讯录 Tab 空闲预热 | 028 C3；次于绘制前 await（已完成） |
| O6 | 大群远端成员页抽干 | 展示完成的本地缓存已修；网络成本另算 |
| O7 | 链接解析 isolate / `urlReg` 改写 | 007/008 后需要新的 RegExpProbe |
| O8 | 把相册 `maxItems` 提到超过 500 | 内存产品取舍 |

### 否决

- 恢复全屏现场模糊来藏抽出弹出 — 抵消 027。
- 永远对所有气泡跳过截图 — 丢掉 Telegram 抽出 UX。
- 再开列表 ORIGINAL 预取 — 和 017/024 解码策略打架。
- 本批交付 O3–O8 — 同一菜单表面上杠杆低于 O1/O2。

## 评审 / 发现（2026-08-22 — Display 卡顿 `docs/pro.md`）

`/how`「分析 docs/pro.md 掉帧」之后的性能轮。
**`/improve` 默认选择 = 仅 R1**（032）。仅凭此文件的代码修复被**否决**（没有 Dart/CPU 栈）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| R1 | `docs/pro.md` 只有 Display Hitch（`expensive app update(s)`）；无法归因符号；不得派生代码计划 | 性能 / dx | 高 | S–M | 低 | `docs/pro.md` L1–50 hitch 表；`rg` 找不到 `dart::`/`Interpret`/`Time Profiler` | 032 |

### 考虑（不计划 — 需要栈或另一表面）

| # | 项 | 为何暂缓 |
|---|------|----------|
| R2 | Cluster A（约 1.6–11s）= 打开聊天 / 水合 | 说得通；没有 Time Profiler + 场景则**未证实** |
| R3 | Cluster D（约 30.9s，150ms）= 菜单/媒体/重 setState | 说得通；**未证实** |
| R4 | 约 36s 处 567ms 表面 + 约 34ms commit | 第二列 ≈33ms；不要当成 567ms 主线程忙 |
| R5 | RecentCallsPage / 通讯录预热 / 群远端抽干 | 先前 Consider 项；与本次采集正交 |

### 否决

- 「根据这份 pro.md」写打开聊天或菜单代码计划 — 没有栈；有撤销 017–031 的风险。
- 把每个 ≥100ms Surface 间隔当主线程热点。
- 仅凭 Display hitch 恢复现场模糊 / 列表 ORIGINAL 预取。

## 评审 / 发现（2026-08-22 — 用户资料头像闪一下）

`/how`「进入用户详细资料页有时候头像这些会闪一下」之后的 UX 轮。
**`/improve` 默认选择 = U1**（035）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| U1 | 资料打开闪默认头 / 加载：没有同步 `readCached` 种子；`Avatar` placeholder=`defaultAvatar()`；enrich 覆盖已可用的脸 | bug / UX | 高 | M | 中 | `tui_profile_view_model.dart` `loadData`；`avatar.dart` L131；`user_profile.dart` `_applyBackendProfile` | 035 |

### 考虑（不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| U2 | 从会话经 `ProfilePageNav.openUserProfile` 传 `seedFaceUrl` | 有助冷桥；调用点更多；035 同步种子覆盖暖对端 |
| U3 | 聊天→资料 Hero 头像 | 更大 UX 变更；消灭默认头闪不需要 |

### 否决

- 让 `mergeImPublicProfile` 把 IM `faceUrl` 拷到托管资料 — 和 `im_public_profile_merge_test` / 013 托管脸规则打架。
- 完全关掉 `didGetFriendInfo` enrich — 丢掉 nick/备注/后端填充。

## 评审 / 发现（2026-08-22 — 置顶历史停滞）

`/how`「上滑到顶部没有继续加载历史记录」之后的正确性轮。
**`/improve` 默认选择 = H1**（044）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| H1 | 成功 `loadPrevious` 后仍保持同顶闩；只有 `ScrollStart` 离顶 320px 才重置 | bug | 高 | S–M | 中 | `chat_list_pagination_ui_gate.dart` `finishPreviousLoadInFlight` + `loadPreviousTopReachResetPx`；列表 `_loadPrevious` 标记 + `_loadPreviousImpl` 在 `effectiveLoaded` 时保持闩 | 044 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| H2 | 仍在顶部附近时从 `finally` 自动连锁下一页 | 失控 / 橡皮筋爆发；044 靠继续手势 + 现有冷却 |
| H3 | 把 `loadPreviousTopReachResetPx` 320→160 | 不修停在顶；仍要离开边沿 |
| H4 | `haveMoreData` 为 false / `triedPreviousAfterNoMore` 停滞 | 另一 bug（SDK 结束 / 空窗）；日志 `schedule_previous_no_more` |

### 否决

- 整段删掉闩 — iOS 过滚 + prepend 补偿会爆发翻页（它存在的原因）。
- 每次 `ScrollUpdate` 设 `bypassTopReachConsumed: true` — 同样爆发风险；该旗标只给不可滚首屏填充。
- 本计划改 `haveMoreData` / 暖拉取条数 20。

## 评审 / 发现（2026-08-22 — 发送者看不见自己发出）

`/how`「自己发送的消息自己看不到，但是别人能看到」之后的正确性轮。
**`/improve` 默认选择 = S1**（045）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| S1 | 发送者气泡是本地优先；pin 用字符串 `!=`，`replace` 丢掉在途自己消息，从陈旧窗发送只 pin 到假底 | bug | 高 | M | 中 | `_onPinToBottomRequested` `convId != _conversationId()`；`setMessageList` `replace` 跳过 `previous`；`mergePeekWindowWithLiveMemory` 已保留 SENDING；prepend 从不调用 `reloadNewestMessageWindow` | 045 |
| F1 | 会话信息流虚拟列表：settle 水合从不跳窗；仅缓存 / covered-skip 常跳过 `notifyListeners`，甩动骨架直到进程重启 | bug | 高 | S–M | 中 | `_requestVirtualHydrateForFeedScroll` settle 调用没有 `allowWindowJump`；`_ensureTypeIndexHydratedImpl` clamp + `hydrate_page_skip_teleport` + 仅缓存返回；covered-skip 仅在 `!_slidingWindowUserExpanded` 时 notify | 046 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| S2 | C2C 入站 `isSelf` 翻转 → 离底缓冲 | 需要一条标错的回显；不要和保留/pin 混 |
| S3 | 键盘 / 短历史垫块盖住最新 | 布局，不是列表身份；045 后再核 |
| F2 | 卡住的 `isScrollingNotifier` 从不发 `scroll_end` | settle 不发生就无法 settle 跳窗；不要轮询 |
| F3 | 放大 `virtualHydrateRadius` / 关掉虚拟列表 | 内存/卡顿回退；046 是对准的门禁 |

### 否决

- 等 `onRecvNewMessage` 显示自己发送 — 己方发送经常没有回显。
- 全局关掉 `replace: true` — 预览 / 018 swap 依赖它。
- 每个 Android 滚动帧都水合会话信息流 — 已测为卡顿源（`virtualHydrateOnlyOnScrollSettle`）。
- 靠加大 `virtualHydrateMaxPerType` 藏甩动洞 — 修不了 PageStorage + 头种子不匹配；费 RAM。

## 评审 / 发现（2026-08-22 — CallKit 被叫单通）

`/how`「设备A无离线推送、设备B有；A打B语音、B系统接听 → A无声、B有声」之后的正确性轮。
**`/improve` 默认选择 = K1–K3**（047，一个计划）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| K1 | CallKit 等待在 completer 为空/`isCompleted` 时空操作，并**吞掉** 3s 超时再 `setMicrophoneEnabled(true)` — 静默本地轨 | bug | 高 | M | 中 | `livekit_voip_bridge.dart` `_waitForCallKitAudioReadyIfPending` ≈95–107；`_onAudioSessionActivated` 忽略空 completer ≈82–91；`publishLocalCallTracks` 等待后仍发布 | 047 |
| K2 | `_onAccept` 在可能的 `didActivate` **之后**才建 completer；无闩 — 后来等待挂起再超时 | bug | 高 | S | 低 | 同文件 `_onAccept` ≈345 vs activate 处理；冷启动 / PermissionGuard 缺口 | 047 |
| K3 | 原生 `CXAnswerCallAction` 若 Flutter 未 `completeAction`，`holdCallAction` **8s fail()** — 然后加入发布进死会话 | bug | 高 | S | 中 | `SelfHostedVoipCallKit.swift` `perform CXAnswerCallAction` ≈287–289；`holdCallAction` ≈378–389 | 047 |

### 考虑（本轮不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| K4 | Android FCM 来电单通 | 另一套栈；本复现是 iOS CallKit 被叫 |
| K5 | 拆 `LiveKitCallSession` chrome vs 媒体 notifier | 029 V3；与静默麦无关 |
| K6 | 引擎未就绪时 AppDelegate 通道队列收 `voipAudioSessionActivated` | **→ 已计划为 048**（047 残留） |

### 否决

- 在 `acceptFromUi` / 主叫 `_connectAndPublish` 里 await CallKit — App 内与 A 接 B 已能工作；再门禁增加延迟和新竞态。
- activate 超时抛 `LiveKitPublishException` — `acceptIncoming` 会挂断晚到 `didActivate` 仍可恢复的通话。
- 只把原生 hold 8s→20s — 更慢冷启动仍失败；configure 后 fulfill 才是正确的 Answer 契约。
- 改 `hasLiveCallAudioTracks` / 跳过 `setSpeakerphoneOn` — 那条是被叫**听不见远端**（与 A 无声 / B 能听见 A 相反）。
- 删掉 CallKit 或退回 TUICallKit — 超出范围。

## 评审 / 发现（2026-08-22 — 047 之后的 CallKit 残留）

`/how`「A打B、B系统接，047 后仍可能 A 没声、B 有声」之后的后续。
**默认选择 = K7–K8**（048，一个计划；依赖 047 已完成）。

### 要做

| # | 发现 | 类别 | 影响 | 工作量 | 风险 | 证据 | 计划 |
|---|------|------|------|--------|------|------|------|
| K7 | CallKit `_onAccept` 不 `dismissSystemCallKit(keepAudio: true)`；`_ensureCallAudioRoute` 随后在 CallKit 仍持有 `playAndRecord` 时 `setSpeakerphoneOn` | bug | 高 | M | 中 | `livekit_voip_bridge.dart` `_onAccept` 成功 ≈384–398 vs `acceptFromUi` ≈300–306；`livekit_call_session.dart` `_ensureCallAudioRoute` ≈636–659 | 048 |
| K8 | `voipAudioSessionActivated` 是生 `invokeMethod`，无挂起队列 / 原生查询 — 事件丢失则 047 闩永不置位 | bug | 高 | S–M | 低 | `AppDelegate.swift` ≈790–794 vs `pendingNotificationTap` ≈986–991；047 只从 `_onAudioSessionActivated` 重发 | 048 |

### 考虑（不计划）

| # | 项 | 为何暂缓 |
|---|------|----------|
| K9 | 回放丢失的 `voipChangeAccept` | 双重 `acceptIncoming`；本症状查 activate 就够 |
| K4 | Android FCM 单通 | 仍是另一套栈 |

### 否决

- 去掉 `hasLiveCallAudioTracks` 扬声器跳过 — 任何轨道前仍需要；048 **再加** CallKit 持有跳过。
- CallKit 成功路径上不带 keepAudio 的 `endVoipCallKit` — 会在活房间上 `setActive(false)`。
- 在 `acceptFromUi` / 主叫上 await CallKit — 047 的否决仍成立。

## 已考虑并否决的发现（051 C2C 旧页）

| 发现 | 否决 / 推迟原因 |
|------|----------------|
| 关掉 `_fillTowardOlderHistory` | 050 已禁止；用户仍要上滑更早历史 |
| 改 `compareMessagesChronological` 再用 C2C seq | 排序已经对；错的是接页门禁 |
| 改群 `keepNewestContiguousSpine` 默认 | 群短云页必须继续丢月份级旧本地 |
| 本计划修进页 `21→33` 通话气泡回灌 | 另案；051 只修 20 条下面的 SDK 旧页 |
| C2C `conversationID` 改回带 `c2c_` | 050 已否决；SDK/归档要裸 userID |
