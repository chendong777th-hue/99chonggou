WeChat-style message animation override package

Changes:
- WeChat message entrance duration: 240ms
- Message starts 16px below its final position
- Opacity changes from 0.82 to 1.0
- Uses easeOutCubic without bounce or scaling
- Existing-message list push duration: 240ms
- Telegram mode keeps its original input-anchor animation

Files included:
1. third_party/tencent_cloud_chat_uikit/lib/ui/widgets/chat_message_enter_animation.dart
2. third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart

How to test:
1. Back up the two files with the same paths in the project.
2. Copy the package's third_party folder into the project root.
3. Allow the files to be overwritten.
4. Run:
   flutter clean
   flutter pub get
   flutter run

Recommended checks:
- Send and receive one-line and multi-line text.
- Send images, voice messages, stickers, files, and wallet cards.
- Send several messages quickly.
- Receive messages while viewing old history.
- Retry a failed message.

Rollback:
Restore the two backed-up source files.

The original project source was not modified when this package was generated.
