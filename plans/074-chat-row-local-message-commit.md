# Plan 074: 将发送回执收敛为行级消息更新

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 073（软依赖）；保持 018、045、049、053、060
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

多图或连续发送时，一条消息经历 optimistic、SDK 接管、上传完成和最终回执，当前仍可能复制整张消息列表并提升全局 revision。长历史下会重复排序、分区和气泡构建，导致发送期间持续掉帧。目标是稳定 identity 后只替换对应行；只有顺序变化或无法定位时才整表提交。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:6242` 创建/提交发送消息。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:7875` optimistic→SDK 接管使用 `setMessageList(... replace: true)`。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:7900` 最终回执仍可能再次整表替换。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:6512-6560` 已有内容签名去重，但调用前仍会复制/扫描列表。

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- 相关 `test/` 契约测试

**Out of scope**:

- SDK 消息 payload、上传协议、压缩质量
- 消息排序规则和内存窗口常量
- 失败重试语义、未读语义、通话消息语义

## Steps

### Step 1: 固化 outgoing stable identity

为 optimistic ID、SDK client ID、msgID、local path 建立单向映射，保证 adoption 和最终回执都能定位同一个行槽。无稳定 identity 时必须保留现有整表安全路径并记录诊断。

**Verify**: 现有双气泡、发送成功可见、媒体失败重试测试通过。

### Step 2: 增加行级替换 API

在 `TUIChatGlobalModel` 增加按 stable identity 替换单行的入口，行级更新只触发对应 row selector/revision；若消息时间或排序 key 改变，返回 `requiresFullCommit=true`，由调用方走现有 `setMessageList`。

**Verify**: 新增测试覆盖 identity 命中、未命中、排序改变、重复回执和撤回状态改变。

### Step 3: 接线 adoption 与 final receipt

将 7875/7900 的安全替换改为行级入口；上传进度继续使用现有局部通知。不得删除 `replace:true` 的保底路径，不能用时间戳猜测多图对应关系。

**Verify**: `flutter test test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart` → 全部通过；日志显示每张图片最多一次 full-list fallback。

## Done criteria

- [ ] 正常 optimistic→SDK→done 不提升全局消息列表 revision
- [ ] 双气泡、顺序、失败重试和自己消息可见性保持不变
- [ ] 无 stable identity 时安全回退整表，不丢消息
- [ ] 多图 N 张的 full-list commit 数量不再随 N 线性增长

## STOP conditions

- 无法同时保证 SDK msgID 与本地 optimistic identity 关联时停止。
- 行级更新导致分页锚点、未读或通话气泡改变时停止，不绕过测试。
- 需要修改 SDK 消息对象跨 isolate 时停止。

## Maintenance notes

任何新增 outgoing 消息类型必须声明 stable identity 和排序 key；review 时重点检查“未命中是否安全回退”和“回执是否幂等”。
