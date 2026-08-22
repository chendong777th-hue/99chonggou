import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';

void main() {
  group('ChatUiStateStore conversation key alias', () {
    test('c2c_ prefix and bare uid share multi-select state', () {
      final store = ChatUiStateStore();
      store.setMultiSelect('peer_a', true);
      expect(store.isMultiSelect('peer_a'), isTrue);
      expect(store.isMultiSelect('c2c_peer_a'), isTrue);
      expect(store.isMultiSelect('C2Cpeer_a'), isTrue);

      store.setMultiSelect('c2c_peer_a', false);
      expect(store.isMultiSelect('peer_a'), isFalse);
      expect(store.isMultiSelect('c2c_peer_a'), isFalse);
    });

    test('group_ prefix and bare group id share multi-select state', () {
      final store = ChatUiStateStore();
      store.setMultiSelect('group_@TGS#_abc', true);
      expect(store.isMultiSelect('@TGS#_abc'), isTrue);
      expect(store.isMultiSelect('group_@TGS#_abc'), isTrue);
    });

    test('normalizeConversationKey strips known prefixes', () {
      expect(ChatUiStateStore.normalizeConversationKey('c2c_u1'), 'u1');
      expect(ChatUiStateStore.normalizeConversationKey('group_g1'), 'g1');
      expect(ChatUiStateStore.normalizeConversationKey('u1'), 'u1');
    });
  });
}
