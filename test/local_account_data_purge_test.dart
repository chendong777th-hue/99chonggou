import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_account_data_purge.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_registration_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/push_token_local/push_token_upload_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/red_packet_local_store.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

MeFriendRecord _friend(String id) {
  return MeFriendRecord(
    friendUserId: id,
    remark: '',
    friendNickname: id,
    friendAvatarUrl: '',
    addedAt: 1,
    peerDeletedMe: false,
    canMessage: true,
  );
}

MeGroupRecord _group(String id) {
  return MeGroupRecord(
    groupId: id,
    groupType: 'Public',
    groupName: id,
    displayAlias: '',
    avatarUrl: '',
    notice: '',
    memberCount: 1,
    myRole: 200,
    myNameCard: '',
    joinedAt: 1,
    updatedAt: 1,
  );
}

V2TimConversation _c2c(String id) {
  return V2TimConversation(
    conversationID: id,
    type: 1,
    userID: id.replaceFirst('c2c_', ''),
    unreadCount: 0,
    isPinned: false,
    orderkey: 1,
    showName: id,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const ownerA = 'purge_owner_a';
  const ownerB = 'purge_owner_b';

  setUp(() async {
    ConversationLocalStore.bypassUpsertCoalesceForTest = true;
    PushRegistrationService.instance.debugResetPendingLogoutOwner();
    await ConversationLocalStore.instance.clearForOwner(ownerA);
    await ConversationLocalStore.instance.clearForOwner(ownerB);
    await FriendLocalStore.instance.clearForOwner(ownerA);
    await FriendLocalStore.instance.clearForOwner(ownerB);
    await GroupLocalStore.instance.clearForOwner(ownerA);
    await GroupLocalStore.instance.clearForOwner(ownerB);
    await RedPacketLocalStore.instance.clearForOwner(ownerA);
    await RedPacketLocalStore.instance.clearForOwner(ownerB);
    await PushTokenUploadLocalStore.instance.clearForOwner(ownerA);
    await PushTokenUploadLocalStore.instance.clearForOwner(ownerB);
  });

  tearDown(() async {
    ConversationLocalStore.instance.debugOwnerUserId = null;
    ConversationLocalStore.bypassUpsertCoalesceForTest = false;
    PushRegistrationService.instance.debugResetPendingLogoutOwner();
    await ConversationLocalStore.instance.clearForOwner(ownerA);
    await ConversationLocalStore.instance.clearForOwner(ownerB);
    await FriendLocalStore.instance.clearForOwner(ownerA);
    await FriendLocalStore.instance.clearForOwner(ownerB);
    await GroupLocalStore.instance.clearForOwner(ownerA);
    await GroupLocalStore.instance.clearForOwner(ownerB);
    await RedPacketLocalStore.instance.clearForOwner(ownerA);
    await RedPacketLocalStore.instance.clearForOwner(ownerB);
    await PushTokenUploadLocalStore.instance.clearForOwner(ownerA);
    await PushTokenUploadLocalStore.instance.clearForOwner(ownerB);
  });

  test('clearSession keeps both owners on disk', () async {
    await ConversationLocalStore.instance.upsertBatch(
      ownerUserId: ownerA,
      conversations: [_c2c('c2c_peer_a')],
    );
    await ConversationLocalStore.instance.upsertBatch(
      ownerUserId: ownerB,
      conversations: [_c2c('c2c_peer_b')],
    );

    await FriendLocalStore.instance.replaceAll(
      ownerUserId: ownerA,
      records: [_friend('friend_a')],
    );
    await FriendLocalStore.instance.replaceAll(
      ownerUserId: ownerB,
      records: [_friend('friend_b')],
    );
    await GroupLocalStore.instance.replaceAll(
      ownerUserId: ownerA,
      records: [_group('@TGS#purge_a')],
    );
    await GroupLocalStore.instance.replaceAll(
      ownerUserId: ownerB,
      records: [_group('@TGS#purge_b')],
    );

    await ConversationLocalStore.instance.clearSession();
    await FriendLocalStore.instance.clearSession();
    await GroupLocalStore.instance.clearSession();

    expect(await ConversationLocalStore.instance.countRows(ownerUserId: ownerA), 1);
    expect(await ConversationLocalStore.instance.countRows(ownerUserId: ownerB), 1);
    expect((await FriendLocalStore.instance.readAll(ownerUserId: ownerA)).length, 1);
    expect((await FriendLocalStore.instance.readAll(ownerUserId: ownerB)).length, 1);
    expect((await GroupLocalStore.instance.readAll(ownerUserId: ownerA)).length, 1);
    expect((await GroupLocalStore.instance.readAll(ownerUserId: ownerB)).length, 1);
  });

  test('clearForOwner / purgeOwnerDisk removes only that owner', () async {
    await ConversationLocalStore.instance.upsertBatch(
      ownerUserId: ownerA,
      conversations: [_c2c('c2c_peer_a2')],
    );
    await ConversationLocalStore.instance.upsertBatch(
      ownerUserId: ownerB,
      conversations: [_c2c('c2c_peer_b2')],
    );
    await FriendLocalStore.instance.replaceAll(
      ownerUserId: ownerA,
      records: [_friend('friend_a2')],
    );
    await FriendLocalStore.instance.replaceAll(
      ownerUserId: ownerB,
      records: [_friend('friend_b2')],
    );
    await GroupLocalStore.instance.replaceAll(
      ownerUserId: ownerA,
      records: [_group('@TGS#purge_a2')],
    );
    await GroupLocalStore.instance.replaceAll(
      ownerUserId: ownerB,
      records: [_group('@TGS#purge_b2')],
    );

    await LocalAccountDataPurge.instance.purgeOwnerDisk(ownerA);

    expect(await ConversationLocalStore.instance.countRows(ownerUserId: ownerA), 0);
    expect(await ConversationLocalStore.instance.countRows(ownerUserId: ownerB), 1);
    expect((await FriendLocalStore.instance.readAll(ownerUserId: ownerA)), isEmpty);
    expect((await FriendLocalStore.instance.readAll(ownerUserId: ownerB)).length, 1);
    expect((await GroupLocalStore.instance.readAll(ownerUserId: ownerA)), isEmpty);
    expect((await GroupLocalStore.instance.readAll(ownerUserId: ownerB)).length, 1);
  });

  test('purgeOwnerDisk removes red packet rows only for that owner', () async {
    await RedPacketLocalStore.instance.markOpened(
      orderId: 'rp_a',
      ownerUserId: ownerA,
    );
    await RedPacketLocalStore.instance.markOpened(
      orderId: 'rp_b',
      ownerUserId: ownerB,
    );

    await LocalAccountDataPurge.instance.purgeOwnerDisk(ownerA);

    expect(
      await RedPacketLocalStore.instance.getOpened(
        orderId: 'rp_a',
        ownerUserId: ownerA,
      ),
      isNull,
    );
    expect(
      await RedPacketLocalStore.instance.getOpened(
        orderId: 'rp_b',
        ownerUserId: ownerB,
      ),
      isNotNull,
    );
  });

  test('push logout with pending owner does not clearAll other accounts', () async {
    await PushTokenUploadLocalStore.instance.markSuccess(
      ownerUserId: ownerA,
      deviceId: 'dev',
      platform: 'IOS',
      tokenKeyHash: 'hash_a',
    );
    await PushTokenUploadLocalStore.instance.markSuccess(
      ownerUserId: ownerB,
      deviceId: 'dev',
      platform: 'IOS',
      tokenKeyHash: 'hash_b',
    );

    PushRegistrationService.instance.rememberLogoutOwner(ownerA);
    await PushRegistrationService.instance.clearLocalPushStateOnLogout();

    expect(
      await PushTokenUploadLocalStore.instance.hasSuccess(
        ownerUserId: ownerA,
        deviceId: 'dev',
        platform: 'IOS',
        tokenKeyHash: 'hash_a',
      ),
      isFalse,
    );
    expect(
      await PushTokenUploadLocalStore.instance.hasSuccess(
        ownerUserId: ownerB,
        deviceId: 'dev',
        platform: 'IOS',
        tokenKeyHash: 'hash_b',
      ),
      isTrue,
    );
  });

  test('push logout without owner skips sqlite and keeps both accounts', () async {
    await PushTokenUploadLocalStore.instance.markSuccess(
      ownerUserId: ownerA,
      deviceId: 'dev',
      platform: 'IOS',
      tokenKeyHash: 'hash_a2',
    );
    await PushTokenUploadLocalStore.instance.markSuccess(
      ownerUserId: ownerB,
      deviceId: 'dev',
      platform: 'IOS',
      tokenKeyHash: 'hash_b2',
    );

    PushRegistrationService.instance.debugResetPendingLogoutOwner();
    await PushRegistrationService.instance.clearLocalPushStateOnLogout();

    expect(
      await PushTokenUploadLocalStore.instance.hasSuccess(
        ownerUserId: ownerA,
        deviceId: 'dev',
        platform: 'IOS',
        tokenKeyHash: 'hash_a2',
      ),
      isTrue,
    );
    expect(
      await PushTokenUploadLocalStore.instance.hasSuccess(
        ownerUserId: ownerB,
        deviceId: 'dev',
        platform: 'IOS',
        tokenKeyHash: 'hash_b2',
      ),
      isTrue,
    );
  });
}
