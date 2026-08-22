Current-project WeChat message animation override

This package was generated from the current project files.
It does not contain or replace chat configuration, face-message, SDK, or
business-logic files.

Included files:
1. third_party/tencent_cloud_chat_uikit/lib/ui/widgets/chat_message_enter_animation.dart
2. third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart

Animation-only changes:
- WeChat entrance duration: 240ms
- Entrance vertical offset: 16px
- Entrance opacity: 0.82 to 1.0
- No bounce or scaling
- Existing-message list push duration: 240ms
- Telegram mode retains its existing behavior

Not modified:
- tim_uikit_chat_config.dart
- tim_uikit_chat_face_elem.dart
- Message sending or receiving logic
- Message loading and synchronization logic
- Stickers, wallet cards, calls, files, images, voice, or other features

Usage:
Copy the package's third_party directory into the project root and overwrite
the two matching files.

Rollback:
Restore the two original files.
