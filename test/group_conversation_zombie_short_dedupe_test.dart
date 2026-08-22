import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';

void main() {
  const short = 'cJSFLQIM62CX';
  const full = '@TGS#_@TGS#cJSFLQIM62CX';

  test('preferredGroupConversationId does not rewrite c2c ids', () {
    expect(
      ChatIdFormat.preferredGroupConversationId('c2c_alice', 'c2c_alice'),
      'c2c_alice',
    );
  });

  test('preferredGroupId keeps bare short over误加成 full', () {
    expect(ChatIdFormat.preferredGroupId(short, full), short);
    expect(ChatIdFormat.preferredGroupId(full, short), short);
    expect(
      ChatIdFormat.preferredGroupConversationId(
        'group_$short',
        'group_$full',
      ),
      'group_$short',
    );
  });

  test('supersededBareShortConversationId from short is the full twin', () {
    expect(
      ChatIdFormat.supersededBareShortConversationId(short),
      'group_$full',
    );
  });

  test('collapseEquivalentGroupConversations drops full zombie', () {
    final shortConv = V2TimConversation(
      conversationID: 'group_$short',
      groupID: short,
      type: 2,
      lastMessage: null,
    );
    final fullConv = V2TimConversation(
      conversationID: 'group_$full',
      groupID: full,
      type: 2,
      lastMessage: null,
    );

    final collapsed = collapseEquivalentGroupConversations([
      shortConv,
      fullConv,
    ]);

    expect(collapsed.conversations, hasLength(1));
    expect(collapsed.conversations.single.conversationID, 'group_$short');
    expect(collapsed.conversations.single.groupID, short);
    expect(collapsed.obsoleteConversationIds, ['group_$full']);
  });

  test('collapse keeps bare short when no full twin', () {
    final shortConv = V2TimConversation(
      conversationID: 'group_$short',
      groupID: short,
      type: 2,
      lastMessage: null,
    );
    final collapsed = collapseEquivalentGroupConversations([shortConv]);
    expect(collapsed.conversations, hasLength(1));
    expect(collapsed.conversations.single.conversationID, 'group_$short');
    expect(collapsed.obsoleteConversationIds, isEmpty);
  });

  test('obsoleteGroupConversationTwinIds drops full when short exists', () {
    expect(
      ChatIdFormat.obsoleteGroupConversationTwinIds([
        'group_$short',
        'group_$full',
        'c2c_alice',
      ]),
      ['group_$full'],
    );
  });
}
