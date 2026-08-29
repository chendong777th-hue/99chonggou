import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_local_store.dart';
import 'package:tencent_cloud_chat_demo/utils/conversation_face_url.dart';
import 'package:tencent_cloud_chat_demo/utils/group_display_resolver.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('findGroup matches short and full community ids', () {
    final group = V2TimGroupInfo(
      groupID: '@TGS#_@TGS#m2BXTRBN5CK',
      groupType: 'Community',
      groupName: '测试社群',
    );
    expect(
      GroupDisplayResolver.findGroup([group], 'm2BXTRBN5CK')?.groupName,
      '测试社群',
    );
    expect(
      GroupDisplayResolver.findGroup([group], '@m2BXTRBN5CK')?.groupName,
      '测试社群',
    );
  });

  test('resolveShowName prefers rest groupName over id-like showName', () {
    final conversation = V2TimConversation(
      conversationID: 'group_@TGS#_@TGS#m2BXTRBN5CK',
      type: 2,
      groupID: '@TGS#_@TGS#m2BXTRBN5CK',
      showName: '@TGS#_@TGS#m2BXTRBN5CK',
    );
    final group = V2TimGroupInfo(
      groupID: 'm2BXTRBN5CK',
      groupType: 'Community',
      groupName: '真实群名',
    );
    expect(
      GroupDisplayResolver.resolveShowName(
        conversation: conversation,
        groupList: [group],
      ),
      '真实群名',
    );
  });

  test('resolveShowName never returns full IM id as title', () {
    final conversation = V2TimConversation(
      conversationID: 'group_@TGS#_@TGS#m2C2BU2N5CE',
      type: 2,
      groupID: '@TGS#_@TGS#m2C2BU2N5CE',
      showName: '@TGS#_@TGS#m2C2BU2N5CE',
    );
    expect(
      GroupDisplayResolver.resolveShowName(conversation: conversation),
      '@m2C2BU2N5CE',
    );
    expect(
      GroupDisplayResolver.resolveShowName(
        conversation: conversation,
        localGroupName: '测群名',
      ),
      '测群名',
    );
  });

  test('looksLikeGroupIdLabel detects display alias', () {
    expect(
      GroupDisplayResolver.looksLikeGroupIdLabel(
        '@m2BXTRBN5CK',
        groupId: '@TGS#_@TGS#m2BXTRBN5CK',
      ),
      isTrue,
    );
    expect(
      GroupDisplayResolver.looksLikeGroupIdLabel(
        '@TGS#_@TGS#m2C2BU2N5CE',
      ),
      isTrue,
    );
    expect(
      GroupDisplayResolver.looksLikeGroupIdLabel('真实群名'),
      isFalse,
    );
  });

  test('resolve prefers GroupLocalStore over stale groupList and conversation',
      () {
    const owner = 'test_owner_group_display';
    const groupId = 'group_display_pref_name';
    final store = GroupLocalStore.instance;
    store.debugOwnerUserIdOverride = owner;
    store.debugPutCachedRecord(
      ownerUserId: owner,
      record: MeGroupRecord(
        groupId: groupId,
        groupType: 'Work',
        groupName: '群库新名',
        displayAlias: '',
        avatarUrl: 'https://example.com/new.png',
        notice: '',
        memberCount: 1,
        myRole: 200,
        myNameCard: '',
        joinedAt: 1,
        updatedAt: 1,
      ),
    );
    addTearDown(() {
      store.debugRemoveCachedRecord(ownerUserId: owner, groupId: groupId);
      store.debugClearOwnerOverride();
    });

    final conversation = V2TimConversation(
      conversationID: 'group_$groupId',
      type: 2,
      groupID: groupId,
      showName: '会话旧名',
      faceUrl: 'https://example.com/old.png',
    );
    final group = V2TimGroupInfo(
      groupID: groupId,
      groupType: 'Work',
      groupName: '列表旧名',
      faceUrl: 'https://example.com/list-old.png',
    );
    expect(
      GroupDisplayResolver.resolveShowName(
        conversation: conversation,
        groupList: [group],
      ),
      '群库新名',
    );
    expect(
      GroupDisplayResolver.resolveMemberCount(
        groupId: groupId,
        groupList: [
          V2TimGroupInfo(
            groupID: groupId,
            groupType: 'Work',
            groupName: '列表旧名',
            memberCount: 99,
          ),
        ],
      ),
      1,
    );
    expect(
      GroupDisplayResolver.resolveFaceUrl(
        conversation: conversation,
        groupList: [group],
      ),
      'https://example.com/new.png',
    );
    expect(
      ConversationFaceUrl.resolve(
        userId: null,
        conversationFaceUrl: conversation.faceUrl,
        isGroup: true,
        groupList: [group],
        groupId: groupId,
      ),
      'https://example.com/new.png',
    );
  });

  test('local group record blocks stale SDK name when local name is empty', () {
    const owner = 'test_owner_group_display_empty';
    const groupId = 'group_display_empty_name';
    final store = GroupLocalStore.instance;
    store.debugOwnerUserIdOverride = owner;
    store.debugPutCachedRecord(
      ownerUserId: owner,
      record: MeGroupRecord(
        groupId: groupId,
        groupType: 'Work',
        groupName: '',
        displayAlias: '',
        avatarUrl: '',
        notice: '',
        memberCount: 0,
        myRole: 200,
        myNameCard: '',
        joinedAt: 1,
        updatedAt: 1,
      ),
    );
    addTearDown(() {
      store.debugRemoveCachedRecord(ownerUserId: owner, groupId: groupId);
      store.debugClearOwnerOverride();
    });

    final conversation = V2TimConversation(
      conversationID: 'group_$groupId',
      type: 2,
      groupID: groupId,
      showName: 'SDK旧名',
    );
    final group = V2TimGroupInfo(
      groupID: groupId,
      groupType: 'Work',
      groupName: 'SDK列表旧名',
    );
    expect(
      GroupDisplayResolver.resolveShowName(
        conversation: conversation,
        groupList: [group],
      ),
      groupId,
    );
  });
}
