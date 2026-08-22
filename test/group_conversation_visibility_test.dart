import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

void main() {
  group('group_conversation_visibility', () {
    test('does not hide before group list synced', () {
      expect(
        shouldHideNonMemberGroupConversation(
          conversationId: 'group_abc',
          groupListSyncedOnce: false,
          isJoinedGroup: (_) => false,
        ),
        isFalse,
      );
    });

    test('hides non-member group after sync', () {
      expect(
        shouldHideNonMemberGroupConversation(
          conversationId: 'group_abc',
          groupListSyncedOnce: true,
          isJoinedGroup: (_) => false,
        ),
        isTrue,
      );
    });

    test('keeps joined group after sync', () {
      expect(
        shouldHideNonMemberGroupConversation(
          conversationId: 'group_abc',
          groupId: 'abc',
          groupListSyncedOnce: true,
          isJoinedGroup: (id) => id == 'abc',
        ),
        isFalse,
      );
    });

    test('keeps a just-opened SDK group when membership snapshot misses it',
        () {
      final conversation = V2TimConversation(
        conversationID: 'group_m22YWQ3N5CN',
        type: 2,
        groupID: 'm22YWQ3N5CN',
      );
      expect(
        shouldShowConversationForMembership(
          conversation: conversation,
          groupListSyncedOnce: true,
          isJoinedGroup: (_) => false,
          hasActiveConversationEvidence: (id) => id == 'm22YWQ3N5CN',
        ),
        isTrue,
      );
    });

    test('c2c conversations always show', () {
      final conversation = V2TimConversation(
        conversationID: 'c2c_user1',
        type: 1,
        userID: 'user1',
      );
      expect(
        shouldShowConversationForMembership(
          conversation: conversation,
          groupListSyncedOnce: true,
          isJoinedGroup: (_) => false,
        ),
        isTrue,
      );
    });

    test('resolves group id from conversationID prefix', () {
      expect(
        resolveGroupIdFromConversation(conversationId: 'group_xyz'),
        'xyz',
      );
    });

    test('looksLikeC2cConversationId covers c2c_ and group_c2c_', () {
      expect(looksLikeC2cConversationId('c2c_peer1'), isTrue);
      expect(looksLikeC2cConversationId('group_c2c_peer1'), isTrue);
      expect(looksLikeC2cConversationId('group_m2ABC'), isFalse);
    });

    test('isForbiddenGroupStorageId rejects c2c_ as group id', () {
      expect(isForbiddenGroupStorageId('c2c_rqwm8onw3j'), isTrue);
      expect(isForbiddenGroupStorageId('group_c2c_rqwm8onw3j'), isTrue);
      expect(isForbiddenGroupStorageId(''), isTrue);
      expect(isForbiddenGroupStorageId('m2MDQ4YN5CW'), isFalse);
    });

    test('c2c_ forces non-group even when groupID/type polluted', () {
      final conversation = V2TimConversation(
        conversationID: 'c2c_peer1',
        type: 2,
        userID: 'peer1',
        groupID: 'c2c_peer1',
      );
      expect(isGroupConversation(conversation), isFalse);
      expect(
        resolveGroupIdFromConversation(
          conversationId: conversation.conversationID,
          groupId: conversation.groupID,
        ),
        '',
      );
      expect(
        shouldShowConversationForMembership(
          conversation: conversation,
          groupListSyncedOnce: true,
          isJoinedGroup: (_) => false,
        ),
        isTrue,
      );
    });

    test('group_ prefix still resolves as group', () {
      final conversation = V2TimConversation(
        conversationID: 'group_m2MDQ4YN5CW',
        type: 2,
        groupID: 'm2MDQ4YN5CW',
      );
      expect(isGroupConversation(conversation), isTrue);
      expect(
        resolveGroupIdFromConversation(
          conversationId: conversation.conversationID,
          groupId: conversation.groupID,
        ),
        'm2MDQ4YN5CW',
      );
    });
  });
}
