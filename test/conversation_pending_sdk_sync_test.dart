import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_pending_sdk_sync.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';

ConversationPendingSdkSync _request({
  required String reason,
  Set<int>? types,
  bool reset = false,
  bool force = false,
  bool loadAll = false,
  bool reloadEachPage = true,
  ConversationSdkDrainMode? mode,
}) {
  return ConversationPendingSdkSync(
    reason: reason,
    reset: reset,
    force: force,
    loadAllPages: loadAll,
    reloadUiEachPage: reloadEachPage,
    conversationTypes: types,
    drainMode: mode,
  );
}

void main() {
  group('ConversationPendingSdkSync', () {
    test('concurrent C2C and Group requests preserve both types', () {
      final c2c = _request(
        reason: 'visible_c2c',
        types: const <int>{ConversationType.V2TIM_C2C},
      );
      final group = _request(
        reason: 'visible_group',
        types: const <int>{ConversationType.V2TIM_GROUP},
      );

      final merged = c2c.mergePreferStronger(group);
      expect(
        merged.conversationTypes,
        <int>{ConversationType.V2TIM_C2C, ConversationType.V2TIM_GROUP},
      );
      expect(merged.requestsAllTypes, isFalse);
    });

    test('untyped request subsumes typed requests', () {
      final typed = _request(
        reason: 'typed',
        types: const <int>{ConversationType.V2TIM_GROUP},
      );
      final all = _request(reason: 'bootstrap');

      expect(typed.mergePreferStronger(all).requestsAllTypes, isTrue);
      expect(all.mergePreferStronger(typed).requestsAllTypes, isTrue);
    });

    test('merge keeps strongest flags and drain mode', () {
      final weak = _request(
        reason: 'weak',
        types: const <int>{ConversationType.V2TIM_C2C},
        mode: ConversationSdkDrainMode.singlePage,
      );
      final strong = _request(
        reason: 'sync_server_finish',
        types: const <int>{ConversationType.V2TIM_GROUP},
        reset: true,
        force: true,
        loadAll: true,
        reloadEachPage: false,
        mode: ConversationSdkDrainMode.backgroundContinue,
      );

      final merged = weak.mergePreferStronger(strong);
      expect(merged.reason, 'sync_server_finish');
      expect(merged.reset, isTrue);
      expect(merged.force, isTrue);
      expect(merged.loadAllPages, isTrue);
      expect(merged.reloadUiEachPage, isFalse);
      expect(merged.drainMode, ConversationSdkDrainMode.backgroundContinue);
    });
  });
}
