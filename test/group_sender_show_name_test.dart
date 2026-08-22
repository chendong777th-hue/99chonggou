import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

void main() {
  tearDown(() {
    UserProfileLocalBridge.clear();
  });

  test('resolveGroupSenderShowName prefers remark then card then store then nick',
      () {
    expect(
      resolveGroupSenderShowName(
        friendRemark: '备注甲',
        storeName: 'Store名',
        nameCard: '群名片',
        nickName: '昵称',
        userID: 'u1',
      ),
      '备注甲',
    );
    expect(
      resolveGroupSenderShowName(
        friendRemark: '',
        storeName: 'Store名',
        nameCard: '群名片',
        nickName: '昵称',
        userID: 'u1',
      ),
      '群名片',
    );
    expect(
      resolveGroupSenderShowName(
        nameCard: '群名片',
        nickName: '昵称',
        userID: 'u1',
      ),
      '群名片',
    );
    expect(
      resolveGroupSenderShowName(
        nickName: '昵称',
        userID: 'u1',
      ),
      '昵称',
    );
    expect(
      resolveGroupSenderShowName(userID: 'u1'),
      'u1',
    );
    expect(
      resolveGroupSenderShowName(
        storeName: 'u1',
        nickName: '张三',
        userID: 'u1',
      ),
      '张三',
    );
    expect(
      resolveGroupSenderShowName(
        storeName: '@u1',
        nameCard: '群名片',
        nickName: '昵称',
        userID: 'u1',
      ),
      '群名片',
    );
  });

  test('GroupSenderDisplayNameCache hits same fingerprint and misses on remark',
      () {
    final cache = GroupSenderDisplayNameCache();
    final fp1 = GroupSenderDisplayNameCache.fingerprint(
      friendRemark: '旧备注',
      nameCard: '名片',
      nickName: '昵称',
      storeName: '',
    );
    cache.put('u1', fp1, '旧备注');
    expect(cache.lookup('u1', fp1), '旧备注');
    expect(cache.debugEntryCount, 1);

    final fp2 = GroupSenderDisplayNameCache.fingerprint(
      friendRemark: '新备注',
      nameCard: '名片',
      nickName: '昵称',
      storeName: '',
    );
    expect(cache.lookup('u1', fp2), isNull);

    cache.invalidate('u1');
    expect(cache.lookup('u1', fp1), isNull);
    expect(cache.debugEntryCount, 0);
  });

  test('local profile remark and nickname beat IM fallbacks', () {
    UserProfileLocalBridge.configure(
      readCached: (id) {
        if (id != 'u1') return null;
        return const UserProfileCachedSnapshot(
          remark: '本地备注',
          nickname: '本地昵称',
          avatarUrl: 'https://cdn.example/a.png',
        );
      },
    );
    expect(
      resolveGroupSenderShowName(
        friendRemark: 'IM备注',
        nameCard: '群名片',
        nickName: 'IM昵称',
        userID: 'u1',
      ),
      '本地备注',
    );
    UserProfileLocalBridge.configure(
      readCached: (id) {
        if (id != 'u1') return null;
        return const UserProfileCachedSnapshot(
          nickname: '本地昵称',
          avatarUrl: 'https://cdn.example/a.png',
        );
      },
    );
    expect(
      resolveGroupSenderShowName(
        nameCard: '',
        nickName: 'IM昵称',
        storeName: 'Store名',
        userID: 'u1',
      ),
      '本地昵称',
    );
    expect(
      UserProfileLocalBridge.cachedAvatarUrl('u1', fallback: 'old.png'),
      'https://cdn.example/a.png',
    );
  });
}
