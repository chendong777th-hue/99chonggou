import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const ownerUserId = 'owner_a';
  const peerUserId = 'b123456';

  setUp(() async {
    FriendSyncService.instance.debugOwnerUserId = ownerUserId;
    PeerProfileRefreshBus.instance.clear();
    await FriendLocalStore.instance.clearSession();
    await UserProfileLocalService.instance.clearSession();
    await FriendLocalStore.instance.replaceAll(
      ownerUserId: ownerUserId,
      records: [
        MeFriendRecord(
          friendUserId: peerUserId,
          remark: '旧备注',
          friendNickname: '小明',
          friendAvatarUrl: 'https://example.com/a.png',
          addedAt: 1718452800000,
          peerDeletedMe: false,
          canMessage: true,
        ),
      ],
    );
  });

  tearDown(() {
    FriendSyncService.instance.debugOwnerUserId = null;
  });

  test('FriendRealtimeEvent parses presence_changed payload', () {
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      'type': 'event',
      'event': 'presence_changed',
      'peerUserId': peerUserId,
      'lastActiveAt': 1718592000000,
      'lastActiveVisibility': 'hidden',
      'online': true,
      'ts': 1718592000123,
    });

    expect(event.event, 'presence_changed');
    expect(event.peerUserId, peerUserId);
    expect(event.lastActiveAt, 1718592000000);
    expect(event.lastActiveVisibility, 'hidden');
    expect(event.online, isTrue);
  });

  test('FriendRealtimeEvent parses remark_updated payload', () {
    final event = FriendRealtimeEvent.fromJson(<String, dynamic>{
      'type': 'event',
      'event': 'friend_list_changed',
      'action': 'remark_updated',
      'peerUserId': peerUserId,
      'peerNickname': '小明',
      'peerAvatarUrl': 'https://example.com/a.png',
      'remark': '备注名',
      'inMyFriendList': true,
      'isFriend': true,
      'peerDeletedMe': false,
      'canMessage': true,
      'ts': 1718452800000,
    });

    expect(event.event, 'friend_list_changed');
    expect(event.action, 'remark_updated');
    expect(event.peerUserId, peerUserId);
    expect(event.remark, '备注名');
  });

  test('applyListChanged remark_updated updates local friend remark', () async {
    final changed = await FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent.fromJson(<String, dynamic>{
        'type': 'event',
        'event': 'friend_list_changed',
        'action': 'remark_updated',
        'peerUserId': peerUserId,
        'remark': '备注名',
      }),
    );

    expect(changed, isTrue);
    final friends =
        await FriendLocalStore.instance.readAll(ownerUserId: ownerUserId);
    expect(friends.single.remark, '备注名');
    expect(friends.single.friendNickname, '小明');
    expect(PeerProfileRefreshBus.instance.matches(peerUserId), isTrue);

    final profile = await UserProfileLocalService.instance.read(peerUserId);
    expect(profile?.friendRemark, '备注名');
  });

  test('applyListChanged remark_updated clears remark when payload is empty',
      () async {
    final changed = await FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent.fromJson(<String, dynamic>{
        'type': 'event',
        'event': 'friend_list_changed',
        'action': 'remark_updated',
        'peerUserId': peerUserId,
        'remark': '',
      }),
    );

    expect(changed, isTrue);
    final friends =
        await FriendLocalStore.instance.readAll(ownerUserId: ownerUserId);
    expect(friends.single.remark, '');

    final profile = await UserProfileLocalService.instance.read(peerUserId);
    expect(profile?.friendRemark, '');
  });
}
