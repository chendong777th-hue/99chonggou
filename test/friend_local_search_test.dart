import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const owner = 'owner_search_a';

  setUp(() async {
    await FriendLocalStore.instance.clearForOwner(owner);
    await FriendLocalStore.instance.replaceAll(
      ownerUserId: owner,
      records: [
        MeFriendRecord(
          friendUserId: 'u_zhang',
          remark: '李四',
          friendNickname: '张三',
          friendAvatarUrl: '',
          addedAt: 1,
          peerDeletedMe: false,
          canMessage: true,
        ),
        MeFriendRecord(
          friendUserId: 'u_wang',
          remark: '',
          friendNickname: '王五',
          friendAvatarUrl: '',
          addedAt: 1,
          peerDeletedMe: false,
          canMessage: true,
        ),
        MeFriendRecord(
          friendUserId: 'u_other',
          remark: '无关',
          friendNickname: '赵六',
          friendAvatarUrl: '',
          addedAt: 1,
          peerDeletedMe: false,
          canMessage: true,
        ),
      ],
    );
  });

  test('searchFriendIds hits nickname and pinyin', () async {
    final byName = await FriendLocalStore.instance.searchFriendIds(
      ownerUserId: owner,
      keyword: '张',
      limit: 80,
    );
    expect(byName.ids, contains('u_zhang'));
    expect(byName.ids, isNot(contains('u_other')));

    final byPinyin = await FriendLocalStore.instance.searchFriendIds(
      ownerUserId: owner,
      keyword: 'zs',
      limit: 80,
    );
    expect(byPinyin.ids, contains('u_zhang'));
  });

  test('searchFriendIds cursor pages without overlap', () async {
    final first = await FriendLocalStore.instance.searchFriendIds(
      ownerUserId: owner,
      keyword: 'u_',
      limit: 2,
    );
    expect(first.ids.length, 2);
    expect(first.hasMore, isTrue);
    final second = await FriendLocalStore.instance.searchFriendIds(
      ownerUserId: owner,
      keyword: 'u_',
      limit: 2,
      cursor: first.nextCursor,
    );
    expect(second.ids.length, 1);
    expect(
      first.ids.toSet().intersection(second.ids.toSet()),
      isEmpty,
    );
  });

  test('readByIds preserves order of requested ids', () async {
    final rows = await FriendLocalStore.instance.readByIds(
      ownerUserId: owner,
      friendUserIds: const ['u_wang', 'u_zhang'],
    );
    expect(rows.map((e) => e.friendUserId).toList(), ['u_wang', 'u_zhang']);
  });
}
