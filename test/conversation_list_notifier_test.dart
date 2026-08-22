import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_feed/conversation_feed_ui.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';

V2TimConversation _conversation({
  required String id,
  int unread = 0,
  bool pinned = false,
  int orderkey = 0,
  String showName = 'Alice',
  String faceUrl = 'https://example.com/a.png',
  String draftText = '',
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    isPinned: pinned,
    orderkey: orderkey,
    showName: showName,
    faceUrl: faceUrl,
    draftText: draftText,
  );
}

void main() {
  group('ConversationListNotifier.listsEqualForUi', () {
    test('identical snapshots are equal', () {
      final list = [
        _conversation(id: 'c2c_a', orderkey: 100),
      ];
      expect(ConversationListNotifier.listsEqualForUi(list, list), isTrue);
      expect(
        ConversationListNotifier.listsEqualForUi(list, List.from(list)),
        isTrue,
      );
    });

    test('different orderkey is not equal', () {
      final left = [
        _conversation(id: 'c2c_a', orderkey: 100),
      ];
      final right = [
        _conversation(id: 'c2c_a', orderkey: 200),
      ];
      expect(ConversationListNotifier.listsEqualForUi(left, right), isFalse);
    });

    test('different unread count is not equal', () {
      final left = [_conversation(id: 'c2c_a', unread: 0)];
      final right = [_conversation(id: 'c2c_a', unread: 3)];
      expect(ConversationListNotifier.listsEqualForUi(left, right), isFalse);
    });

    test('different order is not equal', () {
      final left = [
        _conversation(id: 'c2c_a'),
        _conversation(id: 'c2c_b'),
      ];
      final right = [
        _conversation(id: 'c2c_b'),
        _conversation(id: 'c2c_a'),
      ];
      expect(ConversationListNotifier.listsEqualForUi(left, right), isFalse);
    });

  });

  group('ConversationListNotifier.zeroUnreadLocally', () {
    late ConversationListNotifier notifier;

    setUp(() {
      notifier = ConversationListNotifier.instance;
      notifier.setConversationsForTest([
        _conversation(id: 'group_g1', unread: 4),
      ]);
    });

    test('notifies when unread drops from positive to zero', () {
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.zeroUnreadLocally('group_g1');
      expect(notifyCount, 1);
      expect(notifier.conversations.first.unreadCount, 0);
    });

    test('does not notify when unread already zero in memory', () {
      final shared = notifier.conversations.first;
      shared.unreadCount = 0;
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.zeroUnreadLocally('group_g1');
      expect(notifyCount, 0);
      notifier.zeroUnreadLocally('group_g1');
      expect(notifyCount, 0);
    });
  });

  group('ConversationListNotifier.applyShowNameLocally', () {
    late ConversationListNotifier notifier;

    setUp(() {
      notifier = ConversationListNotifier.instance;
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_alice', showName: 'Alice'),
      ]);
    });

    test('updates showName and notifies for fingerprint refresh', () {
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.applyShowNameLocally(
        conversationID: 'c2c_alice',
        showName: '备注名',
      );
      expect(notifyCount, 1);
      expect(notifier.conversations.first.showName, '备注名');
      expect(
        ConversationListNotifier.conversationUiFingerprint(
          notifier.conversations.first,
        ),
        contains('备注名'),
      );
    });

    test('does not notify when showName unchanged', () {
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.applyShowNameLocally(
        conversationID: 'c2c_alice',
        showName: 'Alice',
      );
      expect(notifyCount, 0);
    });
  });

  group('ConversationListNotifier.applyPeerDisplayNameFromStore', () {
    late ConversationListNotifier notifier;

    setUp(() {
      DisplayNameStore.instance.clear(notify: false);
      notifier = ConversationListNotifier.instance;
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_alice', showName: 'Alice'),
      ]);
    });

    tearDown(() {
      DisplayNameStore.instance.clear(notify: false);
    });

    test('updates showName from Store and notifies', () {
      DisplayNameStore.instance.setC2C('alice', '新备注', notify: false);
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.applyPeerDisplayNameFromStore('alice', busRevision: 1);
      expect(notifyCount, 1);
      expect(notifier.conversations.first.showName, '新备注');
    });

    test('same busRevision is applied only once', () {
      DisplayNameStore.instance.setC2C('alice', '新备注', notify: false);
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);
      notifier.applyPeerDisplayNameFromStore('alice', busRevision: 7);
      notifier.applyPeerDisplayNameFromStore('alice', busRevision: 7);
      expect(notifyCount, 1);
    });

    test('fingerprint includes DisplayNameStore fragment', () {
      final conv = _conversation(id: 'c2c_alice', showName: 'Alice');
      final before = ConversationListNotifier.conversationUiFingerprint(conv);
      DisplayNameStore.instance.setC2C('alice', 'Store名', notify: false);
      final after = ConversationListNotifier.conversationUiFingerprint(conv);
      expect(before, isNot(after));
      expect(after, contains('Store名'));
      expect(
        conversationFeedRowSlotNeedsRebuild(
          nextFingerprint: after,
          currentFingerprint: before,
          nextThemeToken: null,
          currentThemeToken: null,
        ),
        isTrue,
      );
    });
  });
}
