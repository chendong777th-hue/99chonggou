import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';

void main() {
  test('archive lookup tokens cover group_ prefix forms', () {
    final tokens = archiveLookupTokensForConversationId('group_abc');
    expect(tokens.contains('group_abc'), isTrue);
    expect(conversationIdInArchivedLookup(tokens, 'group_abc'), isTrue);
  });

  test('buildArchiveLookupTokenSet expands multiple ids', () {
    final set = buildArchiveLookupTokenSet({
      'group_a',
      'c2c_u1',
    });
    expect(conversationIdInArchivedLookup(set, 'group_a'), isTrue);
    expect(conversationIdInArchivedLookup(set, 'c2c_u1'), isTrue);
  });
}
