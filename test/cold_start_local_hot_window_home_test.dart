import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';

/// 冷启动策略回归：原生有 token 时不应在启动图上把 conversationListBootstrapDone
/// 标成 true（否则 NativePostHome 会跳过会话 Stage1，列表只能靠杀进程重载）。
///
/// 实现见 [LoginCoordinator.restoreColdStartSession]：热窗 + pin 后即 goHome，
/// Snapshot/SDK/好友/群由 [NativePostHomeBootstrapQueue] 补齐。
void main() {
  test(
    'post-home conversation stage runs when bootstrapDone is still false',
    () {
      expect(
        ConversationSyncService.shouldSkipPostHomeConversationReset(
          conversationListBootstrapDone: false,
        ),
        isFalse,
      );
      expect(
        ConversationSyncService.shouldSkipPostHomeConversationReset(
          conversationListBootstrapDone: true,
        ),
        isTrue,
      );
    },
  );
}
