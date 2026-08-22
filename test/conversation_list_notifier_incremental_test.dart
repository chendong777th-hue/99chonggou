import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_flicker_log.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimConversation _conversation({
  required String id,
  int unread = 0,
  bool pinned = false,
  int orderkey = 0,
  String showName = 'Alice',
}) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: unread,
    isPinned: pinned,
    orderkey: orderkey,
    showName: showName,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationListNotifier incremental apply', () {
    late ConversationListNotifier notifier;
    var notifyCount = 0;
    late VoidCallback listener;

    setUp(() {
      ConversationLocalStore.instance.debugOwnerUserId = 'test_user';
      notifier = ConversationListNotifier.instance;
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_a', orderkey: 200),
        _conversation(id: 'c2c_b', orderkey: 100),
      ]);
      notifyCount = 0;
      listener = () {
        notifyCount++;
      };
      notifier.addListener(listener);
    });

    tearDown(() {
      notifier.removeListener(listener);
      notifier.clearSession();
      ConversationLocalStore.instance.debugOwnerUserId = null;
    });

    test('applyConversationsFromStore updates unread and notifies', () async {
      final structureBefore = notifier.structureRevision;
      final contentBefore = notifier.contentRevision;
      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_a', unread: 2, orderkey: 200)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifier.conversations.first.unreadCount, 2);
      expect(notifyCount, 1);
      expect(notifier.structureRevision, structureBefore);
      expect(notifier.contentRevision, contentBefore + 1);
    });

    test('same fingerprint upsert does not notify', () async {
      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_a', orderkey: 200)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifyCount, 0);
    });

    test('deletedIds removes conversation', () async {
      final structureBefore = notifier.structureRevision;
      await notifier.applyConversationsFromStore(
        upserted: const [],
        deletedIds: const ['c2c_a'],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        notifier.conversations.map((e) => e.conversationID).toList(),
        ['c2c_b'],
      );
      expect(notifyCount, 1);
      expect(notifier.structureRevision, structureBefore + 1);
    });

    test('new conversation is inserted in sorted order', () async {
      final structureBefore = notifier.structureRevision;
      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_c', orderkey: 300)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(
        notifier.conversations.map((e) => e.conversationID).toList(),
        ['c2c_c', 'c2c_a', 'c2c_b'],
      );
      expect(notifyCount, 1);
      expect(notifier.structureRevision, structureBefore + 1);
    });

    test('suppress notify batches until endSuppressNotify', () async {
      notifier.beginSuppressNotify();
      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_a', unread: 1, orderkey: 200)],
      );
      expect(notifyCount, 0);

      notifier.endSuppressNotify();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifyCount, 1);
    });

    test('pin silent then reorders once with scroll hint', () async {
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: true,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
        listScrollOffset: 0,
      );

      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_a',
        'c2c_b',
      ]);
      expect(notifier.conversations[1].isPinned, isTrue);
      // 静默阶段不 notify，避免双闪。
      expect(notifyCount, 0);
      expect(notifier.isDeferringPinReorderForTest, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_b',
        'c2c_a',
      ]);
      expect(notifyCount, 1);
      expect(notifier.isDeferringPinReorderForTest, isFalse);
      final hint = notifier.takePinReorderScrollHint();
      expect(hint, isNotNull);
      expect(hint!.conversationID, 'c2c_b');
      expect(hint.fromIndex, 1);
      expect(hint.toIndex, 0);
      expect(hint.movedUp, isTrue);
      expect(hint.scrollMode, ConversationPinScrollMode.keepViewport);
    });

    test('unpin paints then reorders', () async {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_b', pinned: true, orderkey: 100),
        _conversation(id: 'c2c_a', orderkey: 200),
      ]);
      notifyCount = 0;

      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: false,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
      );

      expect(notifier.conversations[0].isPinned, isFalse);
      expect(notifyCount, 0);
      expect(notifier.isDeferringPinReorderForTest, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_a',
        'c2c_b',
      ]);
      expect(notifyCount, 1);
      expect(notifier.isDeferringPinReorderForTest, isFalse);
    });

    test('aligned second pin apply skips deferred and notify', () async {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_b', pinned: true, orderkey: 100),
        _conversation(id: 'c2c_a', orderkey: 200),
      ]);
      notifyCount = 0;

      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: false,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifyCount, 1);
      expect(notifier.isDeferringPinReorderForTest, isFalse);
      final structureAfterFirst = notifier.structureRevision;
      final orderAfterFirst =
          notifier.conversations.map((e) => e.conversationID).toList();
      notifyCount = 0;

      // 模拟写库回写：目标与当前已一致，不应再 schedule / notify。
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: false,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
      );
      expect(notifier.isDeferringPinReorderForTest, isFalse);
      expect(notifyCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifyCount, 0);
      expect(notifier.structureRevision, structureAfterFirst);
      expect(
        notifier.conversations.map((e) => e.conversationID).toList(),
        orderAfterFirst,
      );
    });

    test('already-pinned still paints then reorders', () async {
      notifier.conversations[1].isPinned = true;
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: true,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
        listScrollOffset: 0,
      );

      expect(notifyCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifier.conversations.first.conversationID, 'c2c_b');
      expect(notifyCount, 1);
    });

    test('pin while scrolled keeps viewport and reorders', () async {
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: true,
        forceDeferred: true,
        reorderDelay: const Duration(milliseconds: 40),
        listScrollOffset: 1800,
      );

      expect(notifier.conversations[1].isPinned, isTrue);
      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_a',
        'c2c_b',
      ]);
      expect(notifyCount, 0);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_b',
        'c2c_a',
      ]);
      expect(notifyCount, 1);
      final hint = notifier.takePinReorderScrollHint();
      expect(hint, isNotNull);
      expect(hint!.scrollMode, ConversationPinScrollMode.keepViewport);
      expect(hint.movedUp, isTrue);
    });

    test('pin realtime default reorders and notifies immediately', () async {
      notifyCount = 0;
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: true,
        listScrollOffset: 0,
      );
      expect(notifier.conversations.map((e) => e.conversationID).toList(), [
        'c2c_b',
        'c2c_a',
      ]);
      expect(notifier.conversations.first.isPinned, isTrue);
      expect(notifier.isDeferringPinReorderForTest, isFalse);
      expect(notifyCount, greaterThan(0));
    });

    test('recvOpt local updates fingerprint and notifies', () async {
      notifyCount = 0;
      final before = ConversationListNotifier.conversationUiFingerprint(
        notifier.conversations.first,
      );
      notifier.applyRecvOptLocally(
        conversationID: 'c2c_a',
        recvOpt: 2,
      );
      final after = ConversationListNotifier.conversationUiFingerprint(
        notifier.conversations.first,
      );
      expect(notifier.conversations.first.recvOpt, 2);
      expect(after, isNot(before));
      expect(notifyCount, greaterThan(0));
    });

    test('virtual hydrate reflects recvOpt immediately', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_a', orderkey: 2),
        _conversation(id: 'c2c_b', orderkey: 1),
      ]);
      notifier.applyRecvOptLocally(conversationID: 'c2c_a', recvOpt: 2);
      final at = notifier.conversationAtTypeIndex(1, 0);
      expect(at, isNotNull);
      expect(at!.recvOpt, 2);
    });

    test('virtual hydrate reflects pin reorder immediately', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_a', orderkey: 2),
        _conversation(id: 'c2c_b', orderkey: 1),
      ]);
      notifier.applyPinnedWithDeferredReorder(
        conversationID: 'c2c_b',
        isPinned: true,
      );
      final head = notifier.conversationAtTypeIndex(1, 0);
      expect(head, isNotNull);
      expect(head!.conversationID, 'c2c_b');
      expect(head.isPinned, isTrue);
    });

    test('virtual hydrate reflects lastMessage immediately', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_a', orderkey: 1),
        _conversation(id: 'c2c_b', orderkey: 2),
      ]);
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 99,
        'message_msg_id': 'msg_new',
        'message_is_from_self': true,
        'message_status': 2,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = 'msg_new';
      message.timestamp = 99;
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_a',
        message: message,
      );
      final typedIndex = notifier.typeIndexOfConversationId(1, 'c2c_a');
      expect(typedIndex, isNotNull);
      final typed = notifier.conversationAtTypeIndex(1, typedIndex!);
      expect(typed, isNotNull);
      expect(typed!.lastMessage?.msgID, 'msg_new');
    });

    test('apply_store unread reaches virtual hydrate', () async {
      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_a', unread: 5, orderkey: 200)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final idx = notifier.typeIndexOfConversationId(1, 'c2c_a');
      expect(idx, isNotNull);
      expect(notifier.conversationAtTypeIndex(1, idx!)?.unreadCount, 5);
    });

    test('inbound lastMessage bumpUnread updates unread with preview', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_a', unread: 2, orderkey: 1),
      ]);
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 50,
        'message_msg_id': 'msg_in',
        'message_is_from_self': false,
        'message_status': 2,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = 'msg_in';
      message.timestamp = 50;
      message.isSelf = false;
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_a',
        message: message,
        bumpUnread: true,
      );
      final row = notifier.conversations.first;
      expect(row.lastMessage?.msgID, 'msg_in');
      expect(row.unreadCount, 3);
    });

    test('already-hot lastMessage patch skips structure bump', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_hot', unread: 1, orderkey: 200),
        _conversation(id: 'c2c_old', unread: 0, orderkey: 100),
      ]);
      final structureBefore = notifier.structureRevision;
      final contentBefore = notifier.contentRevision;
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 250,
        'message_msg_id': 'msg_hot',
        'message_is_from_self': false,
        'message_status': 2,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = 'msg_hot';
      message.timestamp = 250;
      message.isSelf = false;
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_hot',
        message: message,
        bumpUnread: true,
      );
      expect(
        notifier.conversations.map((c) => c.conversationID).toList(),
        ['c2c_hot', 'c2c_old'],
      );
      expect(notifier.structureRevision, structureBefore);
      expect(notifier.contentRevision, contentBefore + 1);
      expect(notifier.conversations.first.unreadCount, 2);
      expect(notifier.conversations.first.lastMessage?.msgID, 'msg_hot');
    });

    test('colder lastMessage patch reorders and bumps structure', () {
      notifier.setConversationsForTest([
        _conversation(id: 'c2c_hot', unread: 0, orderkey: 200),
        _conversation(id: 'c2c_old', unread: 0, orderkey: 100),
      ]);
      final structureBefore = notifier.structureRevision;
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 300,
        'message_msg_id': 'msg_old_now_hot',
        'message_is_from_self': false,
        'message_status': 2,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = 'msg_old_now_hot';
      message.timestamp = 300;
      message.isSelf = false;
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_old',
        message: message,
      );
      expect(notifier.conversations.first.conversationID, 'c2c_old');
      expect(notifier.structureRevision, structureBefore + 1);
      expect(notifier.conversations.first.lastMessage?.msgID, 'msg_old_now_hot');
    });

    test('lastMessage local does not shrink conversation window', () {
      final many = <V2TimConversation>[
        for (var i = 0; i < 30; i++)
          _conversation(id: 'c2c_$i', orderkey: 100 - i),
      ];
      notifier.setConversationsForTest(many);
      final before = notifier.conversations.length;
      final message = V2TimMessage.fromJson(<String, dynamic>{
        'message_server_time': 999,
        'message_msg_id': 'm_keep',
        'message_is_from_self': true,
        'message_status': 2,
        'message_custom_str': '',
        'message_risk_type_identified': 0,
        'message_sender_group_member_info': <String, dynamic>{},
        'message_group_at_user_array': <String>[],
      });
      message.msgID = 'm_keep';
      message.timestamp = 999;
      notifier.applyLastMessageLocally(
        conversationID: 'c2c_10',
        message: message,
      );
      expect(notifier.conversations.length, before);
    });

    test('forceAdmitIds inserts C2C when type floor is full and row is cold',
        () async {
      final filled = <V2TimConversation>[
        for (var i = 0; i < 40; i++)
          _conversation(id: 'c2c_old_$i', orderkey: 1000 + i),
      ];
      notifier.setConversationsForTest(filled);

      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_new_friend', orderkey: 1)],
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_new_friend'),
        isFalse,
      );

      await notifier.applyConversationsFromStore(
        upserted: [_conversation(id: 'c2c_new_friend', orderkey: 1)],
        forceAdmitIds: const {'c2c_new_friend'},
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(
        notifier.conversations.any((c) => c.conversationID == 'c2c_new_friend'),
        isTrue,
      );
    });
  });
}
