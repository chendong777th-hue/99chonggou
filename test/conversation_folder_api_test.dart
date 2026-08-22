import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_folder_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';

void main() {
  test('ConversationFolderDto parses mixed members; fromDto uses shared scope',
      () {
    final dto = ConversationFolderDto.fromJson(<String, dynamic>{
      'folderId': 'f1',
      'name': '业务',
      'scope': 'c2c',
      'sortOrder': 2,
      'updatedAt': 100,
      'members': [
        <String, dynamic>{
          'chatType': 'c2c',
          'peerId': 'user_a',
          'updatedAt': 90,
        },
        <String, dynamic>{
          'chatType': 'group',
          'peerId': '@TGS#abc',
        },
      ],
    });
    expect(dto.folderId, 'f1');
    expect(dto.name, '业务');
    expect(dto.scope, 'c2c');
    expect(dto.sortOrder, 2);
    expect(dto.members.length, 2);
    expect(dto.members.first.peerId, 'user_a');

    final folder = ConversationFolder.fromDto(dto);
    expect(folder.scope, ConversationFolder.sharedScope);
    expect(folder.conversationIds.contains('c2c_user_a'), isTrue);
    expect(folder.conversationIds.any((id) => id.startsWith('group_')), isTrue);
  });

  test('replace json round-trip keeps members with scope=all', () {
    final dto = ConversationFolderDto(
      folderId: 'f2',
      name: '交易所',
      scope: ConversationFolder.sharedScope,
      sortOrder: 0,
      members: const [
        ConversationFolderMemberRef(chatType: 'group', peerId: '@TGS#x'),
        ConversationFolderMemberRef(chatType: 'c2c', peerId: 'u1'),
      ],
    );
    final json = dto.toReplaceJson();
    expect(json['folderId'], 'f2');
    expect(json['scope'], 'all');
    expect(json['members'], isA<List>());
    expect((json['members'] as List).length, 2);
  });

  test('ConversationFolderMutationResult treats missing ok as true', () {
    final missing = ConversationFolderMutationResult.fromJson(
      <String, dynamic>{'folderId': 'f1', 'count': 1},
    );
    expect(missing.ok, isTrue);

    final rejected = ConversationFolderMutationResult.fromJson(
      <String, dynamic>{'ok': false, 'folderId': 'f1', 'count': 0},
    );
    expect(rejected.ok, isFalse);

    final accepted = ConversationFolderMutationResult.fromJson(
      <String, dynamic>{'ok': true, 'folderId': 'f1', 'count': 2},
    );
    expect(accepted.ok, isTrue);
  });
}
