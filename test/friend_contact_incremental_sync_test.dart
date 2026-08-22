import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/friend_contact_change.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_realtime/friend_realtime_event.dart';
import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const ownerUserId = 'owner_seq';
  const peerUserId = 'peer_seq_1';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FriendSyncService.instance.debugOwnerUserId = ownerUserId;
    FriendSyncService.instance.debugSkipBecameFriendsSideEffects = true;
    FriendContactIncrementalSyncService.instance.debugOwnerUserId = ownerUserId;
    PeerProfileRefreshBus.instance.clear();
    await FriendContactIncrementalSyncService.instance.clearCursor(
      ownerUserId: ownerUserId,
    );
    await FriendLocalStore.instance.clearForOwner(ownerUserId);
    await UserProfileLocalStore.instance.clearForOwner(ownerUserId);
  });

  tearDown(() {
    FriendSyncService.instance.debugOwnerUserId = null;
    FriendSyncService.instance.debugSkipBecameFriendsSideEffects = false;
    FriendContactIncrementalSyncService.instance.debugOwnerUserId = null;
  });

  test('FriendContactChangeEvent maps type to tcpAction', () {
    final created = FriendContactChangeEvent.fromJson({
      'seq': 10041,
      'type': 'CONTACT_CREATED',
      'peerUserId': peerUserId,
      'peerNickname': '阿伦',
      'inMyFriendList': true,
      'isFriend': true,
      'canMessage': true,
    });
    expect(created.resolvedTcpAction, 'added');

    final remark = FriendContactChangeEvent.fromJson({
      'seq': 10042,
      'type': 'CONTACT_REMARK_UPDATED',
      'peer_user_id': peerUserId,
      'remark': '新备注',
      'tcpAction': 'remark_updated',
    });
    expect(remark.resolvedTcpAction, 'remark_updated');
    expect(remark.remark, '新备注');
  });

  test('FriendRealtimeEvent parses friend_list_changed seq', () {
    final event = FriendRealtimeEvent.fromJson({
      'event': 'friend_list_changed',
      'action': 'added',
      'peerUserId': peerUserId,
      'seq': 88,
    });
    expect(event.seq, 88);
  });

  test('noteRealtimeSeq only advances contiguous cursor', () async {
    final sync = FriendContactIncrementalSyncService.instance;
    await sync.writeCursor(10, ownerUserId: ownerUserId);
    await sync.noteRealtimeSeq(12);
    expect(await sync.readCursor(ownerUserId: ownerUserId), 10);
    await sync.noteRealtimeSeq(11);
    expect(await sync.readCursor(ownerUserId: ownerUserId), 11);
  });

  test('sync restart invalidates in-flight pull generation', () {
    final sync = FriendContactIncrementalSyncService.instance;
    final before = sync.debugPullGeneration;
    sync.invalidateInFlightPull();
    expect(sync.debugPullGeneration, before + 1);
  });

  test('TCP seq <= cursor is treated as already applied', () async {
    final sync = FriendContactIncrementalSyncService.instance;
    await sync.writeCursor(50, ownerUserId: ownerUserId);
    expect(await sync.shouldApplyRealtimeSeq(50), isFalse);
    expect(await sync.shouldApplyRealtimeSeq(51), isTrue);
    expect(await sync.shouldApplyRealtimeSeq(null), isTrue);
  });

  test('applyListChanged with older seq still upserts added peer', () async {
    await FriendContactIncrementalSyncService.instance.writeCursor(
      20,
      ownerUserId: ownerUserId,
    );
    final handled = await FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent(
        event: 'friend_list_changed',
        fromUserId: '',
        toUserId: '',
        action: 'added',
        peerUserId: peerUserId,
        peerNickname: '晚到',
        seq: 19,
      ),
    );
    expect(handled, isTrue);
    final all = await FriendLocalStore.instance.readAll(ownerUserId: ownerUserId);
    expect(all.single.friendUserId, peerUserId);
    expect(all.single.friendNickname, '晚到');
  });

  test('applyListChanged with contiguous seq advances cursor', () async {
    await FriendContactIncrementalSyncService.instance.writeCursor(
      5,
      ownerUserId: ownerUserId,
    );
    final changed = await FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent(
        event: 'friend_list_changed',
        fromUserId: '',
        toUserId: '',
        action: 'added',
        peerUserId: peerUserId,
        peerNickname: '新友',
        peerAvatarUrl: 'https://example.com/a.png',
        remark: '',
        seq: 6,
      ),
    );
    expect(changed, isTrue);
    expect(
      await FriendContactIncrementalSyncService.instance.readCursor(
        ownerUserId: ownerUserId,
      ),
      6,
    );
    final all = await FriendLocalStore.instance.readAll(ownerUserId: ownerUserId);
    expect(all.single.friendUserId, peerUserId);
  });

  test('fromDifference applies remark without advancing cursor', () async {
    await FriendContactIncrementalSyncService.instance.writeCursor(
      100,
      ownerUserId: ownerUserId,
    );
    await FriendLocalStore.instance.upsert(
      ownerUserId: ownerUserId,
      record: MeFriendRecord(
        friendUserId: peerUserId,
        remark: '旧',
        friendNickname: '名',
        friendAvatarUrl: '',
        addedAt: 1,
        peerDeletedMe: false,
        canMessage: true,
      ),
    );
    final changed = await FriendSyncService.instance.applyListChanged(
      FriendRealtimeEvent(
        event: 'friend_list_changed',
        fromUserId: '',
        toUserId: '',
        action: 'remark_updated',
        peerUserId: peerUserId,
        remark: '差量备注',
        seq: 100,
      ),
      fromDifference: true,
    );
    expect(changed, isTrue);
    final all = await FriendLocalStore.instance.readAll(ownerUserId: ownerUserId);
    expect(all.single.remark, '差量备注');
    // fromDifference 不推进游标（由 page.nextSeq 推进）
    expect(
      await FriendContactIncrementalSyncService.instance.readCursor(
        ownerUserId: ownerUserId,
      ),
      100,
    );
  });
}
