# Plan 105: 接通 Web 会话已读与消息回执并停止成功空操作

> **Executor instructions**: 严格按步骤执行，先建立 Web contract tests，再删除 UIKit
> 中的 Web early return。禁止只清本地 badge、伪造 `code: 0` 或吞掉 Web SDK 错误。
> 命中 STOP 条件时停止并报告。完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_sdk/lib/tencent_cloud_chat_sdk_web.dart third_party/tencent_cloud_chat_sdk/lib/web/manager/v2_tim_message_manager.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart test`
> 当前基于 dirty worktree；逐段核对下面的现场代码，禁止 reset、checkout 或覆盖他人修改。

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MEDIUM
- **Depends on**: 无；与 103/104 可独立开发，发布时联合 102 的未读水位回归
- **Category**: bug / web parity / tests
- **Planned at**: commit `9f7c46e`, 2026-08-25（dirty worktree）

## Execution (2026-08-25)

- 代码已完成：Web C2C/群 mark-read、message receipt get/send 均调用现有 SDK boundary；
  receipt ID 去空/去重；Web manager 的 non-zero、缺缓存消息和异常均返回明确失败，
  包括 `setMessageRead` 非零结果，不再伪装 `code: 0`。
- 定向 `git diff --check` 通过；Flutter/Dart contract tests、analyze 和 format 受
  `/Users/qiu/flutter/bin/cache/engine.stamp` 权限阻塞，待操作员批准沙箱外重试。
- Chrome browser test 与 Web/原生双账号矩阵尚未执行；按本计划要求保留 BLOCKED 发布门禁。

## Why this matters

Web 聊天页目前在三处返回“成功但什么也没做”或直接跳过：读取消息回执返回空数组、
发送消息回执返回 `code: 0`、群会话 mark-read 返回 `code: 0`，SeparateViewModel 还会在
调用 service 前跳过所有 Web 群已读。结果是页面本地可能显示已读或 badge 清零，但服务端
未读与另一端回执可能长期残留。

vendored Web SDK 已实现 `cleanConversationUnreadMessageCount`、
`markGroupMessageAsRead`、`getMessageReadReceipts` 和 `sendMessageReadReceipts`。问题是
UIKit 主动短路了这些能力，而且 Web manager 对部分非零返回仍转换成 success/empty。

## Current state

UIKit service 当前：

```dart
if (PlatformUtils().isWeb) {
  return V2TimValueCallback(code: 0, desc: '', data: const []);
}
...
if (PlatformUtils().isWeb) {
  return V2TimCallback(code: 0, desc: '');
}
```

SeparateViewModel 当前群分支：

```dart
if (PlatformUtils().isWeb) {
  return null;
}
```

但 Web facade 已有：

```dart
return await _v2timMessageManager.markGroupMessageAsRead(...);
return await _v2timMessageManager.getMessageReadReceipts(...);
return await _v2timMessageManager.sendMessageReadReceipts(...);
```

`cleanConversationUnreadMessageCount` 也会按 `group_`/`c2c_` conversation ID 路由到对应
Web API。因此修复应复用现有 public SDK boundary，不在 UIKit 直接调用 JS global。

## Baseline evidence

- `rg` 未找到现有 Web read reporting 行为测试。
- 当前工具环境无法运行 Flutter 测试：沙箱禁止 Flutter 更新
  `/Users/qiu/flutter/bin/cache/engine.stamp`，沙箱外自动审核服务又返回 503。
- 源码证据确认 Web SDK API 存在，但未在真实账号和当前腾讯 Web SDK 版本上做行为验证；
  计划把 browser matrix 设为发布门禁，不能只靠静态源码判断完成。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改，不覆盖无关文件 |
| Find no-ops | `rg -n "getMessageReadReceipts|sendMessageReadReceipts|markGroupMessageAsRead|PlatformUtils\(\)\.isWeb" third_party/tencent_cloud_chat_uikit/lib third_party/tencent_cloud_chat_sdk/lib` | 所有 Web 分支有明确契约 |
| VM/service tests | `flutter test test/web_read_reporting_contract_test.dart` | 全部通过 |
| Browser tests | `flutter test --platform chrome test/web_read_reporting_browser_test.dart` | 全部通过；Chrome 不可用则标记 BLOCKED |
| Analyze | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_sdk/lib/tencent_cloud_chat_sdk_web.dart third_party/tencent_cloud_chat_sdk/lib/web/manager/v2_tim_message_manager.dart` | 相关文件无新增 error |
| Format | `dart format --output=none --set-exit-if-changed <changed Dart files>` | exit 0 |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**：

- UIKit `message_service_implement.dart` 的会话已读、读取/发送消息回执
- `tui_chat_separate_view_model.dart` 的 Web 群已读调用、频控和错误策略
- vendored Web SDK facade/manager 中只与这些 API 的错误传播有关的修正
- 可见消息回执触发的 Web contract/browser tests 和双账号验收

**Out of scope**：本地会话列表 read barrier（102）、群成员已读列表 UI 重设计、
未读锚点、消息同步/排序、腾讯 SDK 升级、服务端套餐开通、Telegram UI 复制。

## Git workflow

- Branch: `codex/105-enable-web-read-reporting`
- 提交顺序：Web contract 红测 -> 群会话 mark read -> receipt API -> 错误传播 -> browser matrix。
- 不 push、不合并，除非操作员明确要求。

## Steps

### Step 1: 固定三类已读语义，禁止互相替代

在测试和注释中明确：

1. `markC2CMessageAsRead/markGroupMessageAsRead` 清服务端会话未读。
2. `sendMessageReadReceipts` 上报具体可见消息的已读回执。
3. `getMessageReadReceipts` 读取发送消息的回执统计。

本地会话行 badge 清零不是上述任一 SDK 调用的成功证据。消息回执 capability 关闭时可以
明确 skip，但必须由现有 `_canUseReadReceipt`/群属性决定，不能以 `isWeb` 作为能力判断。

**Verify**：contract test 对三种调用分别计数，任何一种都不能由另一种调用“代替通过”。

### Step 2: 接通 Web 群会话 mark-read

- 删除 SeparateViewModel 的 Web `return null`，让 Web 和原生共用滚动期间 defer、最小间隔、
  `-10113` backoff、`6014` 登录重试和 group-not-exist 处理。
- 删除 service `markGroupMessageAsRead` 的 Web success no-op，复用现有
  `_startGroupRead` single-flight 和 conversation manager
  `cleanConversationUnreadMessageCount(group_<id>, 0, 0)`。
- 确认 Web facade 对 `group_` 和 SDK 原始 group ID 的规范化只做一次；普通群、community
  `@TGS#` ID 不得被 `replaceAll` 破坏。
- 空 group ID 仍返回本地参数错误或明确 no-op policy；不能发送畸形 conversation ID。

**Verify**：两个并发 mark-read 合并；期间新消息会触发一次 trailing clean；Web SDK
返回非零时 VM 不更新 `_lastGroupMarkReadAtMs` 为成功时间。

### Step 3: 接通 Web 消息级 receipt APIs

- 删除 service `getMessageReadReceipts` 和 `sendMessageReadReceipts` 的 Web 空实现，统一调用
  `TencentImSDKPlugin.v2TIMManager.getMessageManager()`。
- 保留 service 的 callback/error hook，使 Web 与原生错误都进入同一诊断边界。
- 输入 message ID 去空、去重并保持稳定顺序；空列表在 service 层明确返回参数 no-op，
  不调用 JS `findMessage(null)`。
- 某个 ID 在 Web SDK 本地找不到时，定义部分失败策略：不得把缺失 ID 变成 JS undefined
  后把整批伪装成功。优先返回明确 error，并让上层等待下一次可见/缓存同步触发。

**Verify**：可见消息批次只发送一次；重复 ID 不重复上报；读回执数据原样映射
`msgID/readCount/unreadCount/groupID/userID`。

### Step 4: 修复 Web manager 的错误吞并

当前 manager 在底层 non-zero 时有两处返回 success/empty：

- `getMessageReadReceipts` 返回 success 空数组。
- `sendMessageReadReceipts` 返回 success 空数组。

改为保留底层 code/desc 或转换成项目统一的 non-zero callback；异常走
`CommonUtils.returnError*`。只有真实 `res.code == 0` 才返回成功。不要把“不支持/未开通”
和“当前没有回执”混为一谈。

如果 Web JS SDK 只提供字符串错误而无数值 code，定义稳定的 non-zero adapter code，
并保留脱敏 desc 用于诊断；不要新增 UI toast 风暴。

**Verify**：fake JS 分别返回 0、非 0、throw、findMessage missing，Dart callback 的
code/data 与 policy 一致，非 0 不会被 service 当成功。

### Step 5: 保持生命周期、频控和 generation 安全

- Web visibility/focus、滚动、route dispose 后的 deferred Timer 必须检查当前 chat
  generation/conversation ID，不能把 A 群已读发给 B 群。
- receipt 仍只在行可见阈值满足、用户未滚动且 capability 开启时发送；不要因为接通 Web
  API 改为“打开页面就把所有历史逐条 receipt”。
- SDK 未登录采用既有有限重试；不新增无界 Timer。
- 日志只记录 conversation/message hash、批次数、code 和 attempt，不记录完整 ID/正文。

**Verify**：A 群排队后切 B、滚动中、后台再前台、dispose 四种场景无串会话调用。

### Step 6: 浏览器与跨端验收

自动 browser test 至少覆盖 facade 路由、success/error mapping、single-flight/trailing clean
和 receipt batch。随后用两个真实账号执行：

1. Web 打开有未读的 C2C，刷新页面和另一端后服务端未读保持 0。
2. Web 打开有未读的群聊，刷新和另一端后群未读保持 0。
3. Web 接收方让一条群消息可见超过阈值，发送方 Web/原生能看到回执变化。
4. Web SDK 未登录、频控、无权限/未开通时返回明确失败并有限重试，不伪成功。
5. 快速切群、滚动历史和后台恢复不串会话、不批量误读不可见消息。

**Verify**：Chrome 自动测试及真实双账号矩阵通过。Chrome/账号/套餐能力缺失时计划状态
必须是 BLOCKED，不得仅凭 unit test 标记完成。

## Done criteria

- [ ] Web C2C/群会话已读调用真实 SDK，不再 success no-op。
- [ ] Web get/send message receipts 调真实 SDK。
- [ ] capability 判断基于业务/SDK 能力，不以平台一刀切。
- [ ] Web manager 非零返回和异常不会被转换为成功空数据。
- [ ] single-flight、trailing clean、频控和 generation guard 在 Web 保持成立。
- [ ] 自动 unit/browser tests 通过。
- [ ] 双账号 Web/原生矩阵证明服务端未读与回执跨端一致。
- [ ] 定向 analyze、format、diff check 通过。
- [ ] Scope 外无修改（计划索引除外）。

## STOP conditions

- 当前 Tencent Web SDK/套餐明确不支持目标 receipt API；记录 code/版本/能力并由产品决定
  降级，禁止返回伪成功。
- Web facade 的 conversation ID 契约与 UIKit canonical ID 无法无损映射。
- 修复需要绕过 SDK 直接操作私有 JS 对象或复制一套 read state。
- 自动调用会把未进入可见区的历史消息全部标为已读。
- 出现跨会话 Timer、无限 6014/-10113 重试或 unread 回弹。
- Chrome/真实账号验证不可用；保留 BLOCKED，不宣称跨端闭环。

## Maintenance notes

Web 不是“默认不支持”的同义词。新增平台分支前先检查 vendored facade/manager 的实际
能力，并把 unsupported 表达为 non-zero capability result。会话已读、本地 badge 和消息
receipt 是三套契约，未来改动必须分别测试，不能用其中一套的 UI 结果证明另一套成功。
