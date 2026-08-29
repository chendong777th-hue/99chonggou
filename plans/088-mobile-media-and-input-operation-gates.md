# Plan 088: 收敛移动端媒体、输入框和高频操作的任务代次

> **Executor instructions**: 本计划依赖 086；不得改变正常输入法 composing、表情、草稿、图片/视频上传内容或失败重试语义。

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: 086、078、079
- **Category**: bug / performance / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Goal

让相册导出、媒体准备、压缩上传、草稿保存、键盘布局和输入法 composing 都按会话与任务代次提交。用户仍能正常输入中文拼音、表情、@、草稿、发送图片/视频和失败重试；旧任务只能清理临时资源，不能恢复旧气泡或旧草稿。

## Scope

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/tim_uikit_more_panel.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/utils/chat_media_send_utils.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/widgets/tim_uikit_text_field.dart`
- `lib/src/chat.dart`
- `lib/src/services/conversation_draft_service.dart`
- 相关媒体/IME/草稿测试

## Conflict policy

- 用户当前编辑内容和 composing 状态优先于任何异步草稿回写；
- 发送成功且 stable identity 已确认后，清草稿操作优先于旧 SDK 会话摘要；
- 图片占位优先于上传进度，SDK 回执只能接管同一 stable identity；
- 取消/切换会话后的旧上传回调丢弃，但必须执行文件清理。

## Verification

测试中文拼音未完成候选、表情、@、快速切会话、发送后草稿清除、多图/视频/取消/失败重试和页面退出；执行定向 `flutter test`、`git diff --check` 和真机回归。发现输入内容丢失、composing 被打断、媒体重复或草稿恢复时 STOP。
