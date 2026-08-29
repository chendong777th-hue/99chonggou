# Plan 076: 收敛退出生命周期并缓存自定义消息解析

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: 073；保持 053、061–064
- **Category**: perf / correctness
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

聊天页退出后，群资料、成员、已读、历史和媒体任务仍可能回调；同时长历史重建会重复解析通话、转账、红包和群提示 JSON。目标是让所有异步任务受同一 conversation generation 控制，并按消息身份和 payload 缓存解析结果。

## Current state

- `lib/src/chat.dart` 多处异步群资料/成员任务使用局部 `mounted` 检查，但没有统一覆盖所有消息列表写入点。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:7395` 及聊天工具链存在重复 `jsonDecode`。
- `lib/utils/call_bubble_dedupe.dart` 已有部分通话去重缓存，可作为缓存边界范例。

## Scope

**In scope**:

- `lib/src/chat.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- 自定义消息解析工具及对应测试

**Out of scope**:

- 自定义消息最终展示语义
- 消息排序、SDK 历史来源、钱包业务协议
- 通话音频和 LiveKit 信令

## Steps

### Step 1: 统一 chat generation

进入/切换/退出时递增 generation；所有异步回调在 `mounted && generation == current && conversationID matches` 后才能更新 UI、消息列表或本地群资料。dispose 时取消 timer、请求 token 和未完成的局部任务。

**Verify**: 新增测试覆盖切换群聊、快速退出、旧请求晚到、重复回调。

### Step 2: 建立自定义消息解析缓存

缓存 key 必须包含消息 stable identity、custom payload hash 和解析版本；payload 改变或版本升级必须失效。缓存只能保存解析结果，不得缓存用户隐私正文到长期存储。

**Verify**: 相同消息多次 build 只解析一次；payload 改变、版本改变和不同会话不会错误复用。

### Step 3: 接入通话/钱包/群提示热路径

先接入历史重建和可视气泡路径，再测量 JSON 解析次数和 `history_merge_ms`，不改变 UI 文案和交互。

**Verify**: 现有通话气泡、钱包、红包、群提示测试通过；Profile 长历史解析耗时下降。

## Done criteria

- [ ] 旧页面异步回调不能修改当前页面
- [ ] dispose 后无消息列表/群资料写入
- [ ] 自定义 payload 相同的消息不重复解析
- [ ] 解析缓存不会跨会话或跨 payload 污染
- [ ] 展示文案和消息语义无变化

## STOP conditions

- 任何回调缺少可验证的 conversation identity 时停止。
- 解析结果包含不可安全缓存的临时 UI 状态时停止并报告。
- 发现缓存会改变钱包、通话或未读语义时停止。

## Maintenance notes

新增自定义消息类型必须声明解析版本和缓存 key；所有异步聊天任务必须经过 generation gate。
