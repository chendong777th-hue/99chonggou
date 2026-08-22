import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_folder_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await ConversationFolderStore.instance.clearSession();
  });

  tearDown(() async {
    await ConversationFolderStore.instance.clearSession();
  });

  test('sameFolderConversation keeps c2c and group with same peer distinct', () {
    expect(
      ConversationFolder.sameFolderConversation('c2c_x', 'group_x'),
      isFalse,
    );
    expect(
      ConversationFolder.sameFolderConversation('c2c_user1', 'c2c_user1'),
      isTrue,
    );
  });

  test('setMemberInFolders keeps a conversation in exactly one folder', () async {
    await ConversationFolderStore.instance.replaceAll(const [
      ConversationFolder(
        folderId: 'a',
        name: '业务',
        sortOrder: 0,
        members: {'c2c_user1': 10},
      ),
      ConversationFolder(
        folderId: 'b',
        name: '家人',
        sortOrder: 1,
        members: <String, int?>{},
      ),
    ]);

    await ConversationFolderStore.instance.setMemberInFolders(
      conversationId: 'c2c_user1',
      folderIds: const {'b'},
      memberUpdatedAt: 20,
    );

    expect(
      ConversationFolderStore.instance
          .folderById('a')!
          .containsConversationId('c2c_user1'),
      isFalse,
    );
    expect(
      ConversationFolderStore.instance
          .folderById('b')!
          .containsConversationId('c2c_user1'),
      isTrue,
    );
    expect(
      ConversationFolderStore.instance.folderIdsContaining('c2c_user1'),
      {'b'},
    );
  });

  test('setMemberInFolders does not remove sibling chatType with same peer',
      () async {
    await ConversationFolderStore.instance.replaceAll(const [
      ConversationFolder(
        folderId: 'a',
        name: '混装',
        sortOrder: 0,
        members: {
          'c2c_x': 1,
          'group_x': 1,
        },
      ),
    ]);

    await ConversationFolderStore.instance.setMemberInFolders(
      conversationId: 'c2c_x',
      folderIds: const <String>{},
    );

    final folder = ConversationFolderStore.instance.folderById('a')!;
    expect(folder.containsConversationId('c2c_x'), isFalse);
    expect(folder.containsConversationId('group_x'), isTrue);
  });

  test('collapse prefers member updatedAt over folder metadata rename', () {
    final collapsed = ConversationFolderStore.collapseExclusiveMembership(const [
      ConversationFolder(
        folderId: 'old_home',
        name: '旧组改名刷时间',
        sortOrder: 0,
        members: {'c2c_user1': 100},
        updatedAt: 9999,
      ),
      ConversationFolder(
        folderId: 'new_home',
        name: '真正新入组',
        sortOrder: 1,
        members: {'c2c_user1': 200},
        updatedAt: 1,
      ),
    ]);

    expect(
      collapsed.folders
          .firstWhere((f) => f.folderId == 'new_home')
          .containsConversationId('c2c_user1'),
      isTrue,
    );
    expect(
      collapsed.folders
          .firstWhere((f) => f.folderId == 'old_home')
          .containsConversationId('c2c_user1'),
      isFalse,
    );
    expect(collapsed.removedByFolderId['old_home'], contains('c2c_user1'));
  });

  test('collapse does not treat c2c_x and group_x as the same conversation', () {
    final collapsed = ConversationFolderStore.collapseExclusiveMembership(const [
      ConversationFolder(
        folderId: 'a',
        name: 'A',
        sortOrder: 0,
        members: {'c2c_x': 50},
      ),
      ConversationFolder(
        folderId: 'b',
        name: 'B',
        sortOrder: 1,
        members: {'group_x': 80},
      ),
    ]);

    expect(collapsed.removedByFolderId, isEmpty);
    expect(
      collapsed.folders
          .firstWhere((f) => f.folderId == 'a')
          .containsConversationId('c2c_x'),
      isTrue,
    );
    expect(
      collapsed.folders
          .firstWhere((f) => f.folderId == 'b')
          .containsConversationId('group_x'),
      isTrue,
    );
  });

  test('replaceAll collapses legacy multi-folder membership', () async {
    await ConversationFolderStore.instance.replaceAll(const [
      ConversationFolder(
        folderId: 'older',
        name: '旧组',
        sortOrder: 0,
        members: {'c2c_user1': 100},
        updatedAt: 100,
      ),
      ConversationFolder(
        folderId: 'newer',
        name: '新组',
        sortOrder: 1,
        members: {'c2c_user1': 200},
        updatedAt: 50,
      ),
    ]);

    expect(
      ConversationFolderStore.instance.folderIdsContaining('c2c_user1'),
      {'newer'},
    );
  });

  test('ensureLoaded collapses persisted multi-folder dirty data', () async {
    final dirty = [
      const ConversationFolder(
        folderId: 'a',
        name: 'A',
        sortOrder: 0,
        members: {'c2c_user1': 10},
      ),
      const ConversationFolder(
        folderId: 'b',
        name: 'B',
        sortOrder: 1,
        members: {'c2c_user1': 20},
      ),
    ];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'conversation_folders_v1__guest',
      jsonEncode(dirty.map((f) => f.toJson()).toList(growable: false)),
    );

    await ConversationFolderStore.instance.clearSession();
    await ConversationFolderStore.instance.ensureLoaded();

    expect(
      ConversationFolderStore.instance.folderIdsContaining('c2c_user1'),
      {'b'},
    );
    expect(
      ConversationFolderStore.instance
          .folderById('a')!
          .containsConversationId('c2c_user1'),
      isFalse,
    );
  });

  test('rename upsert does not steal member by folder updatedAt', () async {
    await ConversationFolderStore.instance.replaceAll(const [
      ConversationFolder(
        folderId: 'a',
        name: 'A',
        sortOrder: 0,
        members: {'c2c_user1': 100},
        updatedAt: 1,
      ),
      ConversationFolder(
        folderId: 'b',
        name: 'B',
        sortOrder: 1,
        members: <String, int?>{},
        updatedAt: 1,
      ),
    ]);

    await ConversationFolderStore.instance.upsertFolder(
      ConversationFolderStore.instance.folderById('a')!.copyWith(
            name: 'A-renamed',
            updatedAt: 99999,
          ),
    );

    expect(
      ConversationFolderStore.instance
          .folderById('a')!
          .containsConversationId('c2c_user1'),
      isTrue,
    );
  });

  test('isNameTaken is case-insensitive and excludes self on rename', () async {
    await ConversationFolderStore.instance.replaceAll(const [
      ConversationFolder(
        folderId: 'a',
        name: '业务',
        sortOrder: 0,
        members: <String, int?>{},
      ),
      ConversationFolder(
        folderId: 'b',
        name: 'Work',
        sortOrder: 1,
        members: <String, int?>{},
      ),
    ]);

    expect(ConversationFolderStore.instance.isNameTaken('业务'), isTrue);
    expect(ConversationFolderStore.instance.isNameTaken(' 业务 '), isTrue);
    expect(ConversationFolderStore.instance.isNameTaken('work'), isTrue);
    expect(ConversationFolderStore.instance.isNameTaken('WORK'), isTrue);
    expect(
      ConversationFolderStore.instance.isNameTaken(
        'Work',
        excludingFolderId: 'b',
      ),
      isFalse,
    );
    expect(ConversationFolderStore.instance.isNameTaken('家人'), isFalse);
  });
}
