# Plan 078: 收敛多媒体发送为唯一有界管线

## Status

- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: 077
- Category: perf / correctness
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

`tim_uikit_more_panel.dart:583-592` 当前进入自定义相册后直接转入 `_dispatchCustomGalleryTasks` 并返回，导致后方 058/059 的 optimistic placeholder、解码错峰和统一贴底代码不可达。两条发送链路并存会造成首个气泡延迟、重复 staging、重复滚动和双气泡风险。必须先选定一条主链路，再删除另一条，而不是继续叠加条件分支。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart:583-710` 保留旧 optimistic 路径但被 early return 绕过。
- `:996-1020` 使用 worker 队列发送 pending 图片；iOS 单 worker 是既定内存保护，不得直接提高并发。
- `tui_chat_separate_view_model.dart:6308` 批量插入占位；074 提供 stable identity 行级 adoption。
- PhotoKit/AssetEntity、FlutterImageCompress 和 SDK 对象不得跨 isolate；只允许纯 Dart 文件头或 metadata 计算移出主 isolate。

## Scope

In scope:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart`
- 相关媒体发送契约测试和 Profile 采集

Out of scope: 图片字节、压缩质量、上传协议、SDK worker 默认值、视频编码、群资料字段。

## Steps

1. 先用测试锁定唯一流程：选择→轻量占位→串行/有界 PhotoKit resolve→同 identity hydrate→有界压缩上传→一次最终更新。
2. 将 `gallery-task` 和旧 optimistic 路径合并为一个入口；删除不可达 legacy 分支和重复 staging。
3. 保留 058 placeholder、059 可视区域 decode admission 和单次布局稳定贴底；用户上滑时禁止强制贴底。
4. 保留 iOS 单 worker；只将稳定本地路径后的纯计算移入后台能力，平台对象不得跨 isolate。
5. 确保取消、切会话、权限拒绝、失败重试和部分成功都通过同一 identity 清理。

### 唯一主入口约束

同一批选择资源只能进入一个生产发送入口。`gallery-task` 与旧 optimistic 路径不得通过条件分支并存；迁移完成后必须删除不可达旧路径，或将其变成只供测试使用的纯适配层，不能再次创建 SDK 消息。PhotoKit、Flutter 插件和 SDK 对象不得跨 Dart isolate；只有稳定本地路径之后的纯 Dart metadata/header 计算可以移出主 isolate。

## Verification

- 图片 1/4/9 张、HEIC、iCloud 未下载、视频混选、取消、失败重试测试全部通过。
- 验证不出现双气泡、发送后自动可见、顺序稳定、图片字节和 payload 与改造前一致。
- 真机 Profile 对比 `placeholder_visible_ms`、`image_decode_ms`、`scroll_hitch`；首个占位不再等待全部 PhotoKit 导出。
- `rg -n "_dispatchCustomGalleryTasks|beginOptimisticImagePlaceholders"` 只保留一个生产入口。
- 新增契约测试断言同一批资源只产生一次 staging、一次 SDK message create、一次最终 identity 更新；失败时不得通过增加防抖或重试掩盖。

## STOP conditions

- 无法证明两条旧链路的行为等价；
- 需要提高 PhotoKit 并发或改变 iOS worker；
- 图片内容、压缩结果、上传 payload、顺序或失败语义变化；
- 真机出现内存峰值或消息重复。

## Maintenance notes

未来新增媒体类型必须接入同一 pipeline，不能在 UI 面板内再创建旁路发送循环。
