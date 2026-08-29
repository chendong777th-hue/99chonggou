# Plan 075: 错开多图解码并统一群资料快照

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: 073；保持 058、059、060、055
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

多图占位已经提前出现，但多张图片仍可能同帧解码、测量和贴底；群名/人数/公告/头像又可能由多个异步回调分批更新。两者都会造成 raster 峰值和连续 rebuild。目标是有界解码、一次稳定贴底、一次群资料快照提交。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart:620-710` 批量建立占位后进入逐图发送。
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart` 使用本地图片组件触发解码。
- `lib/src/chat.dart:5150-5180` 应用群资料快照。
- `lib/src/chat.dart:5231-5277` 群游戏/群详情结果可能造成多次状态提交。

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart`
- `lib/src/chat.dart`
- 相关媒体和群资料测试

**Out of scope**:

- 图片字节、压缩质量、上传协议、iOS worker=1
- 群资料权威优先级和业务字段
- 全屏媒体预览清晰度策略

## Steps

### Step 1: 建立可视区域解码预算

按 stable message identity 对首批可视图片设置有限并发；不可视图片保留尺寸占位，进入 viewport 后再解码。不得把 PhotoKit/FlutterImageCompress/SDK 对象跨 isolate。

**Verify**: 真机 Profile 对 1/4/9 张图片分别记录首帧 raster、hitch 和解码并发峰值。

### Step 2: 合并贴底与布局补偿

将多图占位后的贴底、settle 和高度补偿合并成一次有界请求；用户主动上翻时不得强制贴底。

**Verify**: 多图发送测试确认发送后自动可见、上翻位置不跳、无重复贴底日志。

### Step 3: 群资料快照一次提交

让群名、人数、公告、头像由同一 `GroupMetadataSnapshot` 比较后一次性应用；资料变化只刷新顶部区域，不调用消息列表整表提交。

**Verify**: 并发群资料响应只产生一次 UI 提交，旧 generation 不得覆盖当前群。

## Done criteria

- [ ] 多图首帧解码并发有明确上限
- [ ] 不可视图片不提前触发完整解码
- [ ] 多图发送只发生一次批量贴底
- [ ] 群资料字段一次性稳定更新
- [ ] 图片内容、尺寸、压缩、上传结果不变

## STOP conditions

- 真机证明降低解码并发会导致图片内容或预览时序改变时停止。
- 发现图片高度依赖完整原图尺寸时停止，不删除现有尺寸兜底。
- 群资料快照无法覆盖成员变更 generation 时停止。

## Maintenance notes

未来新增媒体元素必须接入统一解码预算；新增群资料字段必须进入快照和指纹，不能新增独立 `setState` 回调。
