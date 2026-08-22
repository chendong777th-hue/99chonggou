import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

void main() {
  test('preferSearchGroupShowName prefers groupName over stale conversation', () {
    expect(
      preferSearchGroupShowName(
        groupName: '王者',
        conversationShowName: '群聊',
        groupId: 'g1',
      ),
      '王者',
    );
  });

  test('preferSearchGroupShowName prefers store over conversation', () {
    expect(
      preferSearchGroupShowName(
        groupName: '',
        conversationShowName: '群聊',
        storeName: '王者',
        groupId: 'g1',
      ),
      '王者',
    );
  });

  test('preferSearchGroupShowName skips groupId-like labels', () {
    expect(
      preferSearchGroupShowName(
        groupName: '@TGS#_abc',
        conversationShowName: '群聊',
        groupId: '@TGS#_abc',
      ),
      '群聊',
    );
  });

  test('searchGroupIdsEquivalent strips group_ prefix', () {
    expect(searchGroupIdsEquivalent('group_g1', 'g1'), isTrue);
    expect(searchGroupIdsEquivalent('g1', 'g2'), isFalse);
  });

  test('searchGroupIdsEquivalent matches community short token and full id', () {
    const short = 'm227LP3N5C5';
    const full = '@TGS#_@TGS#m227LP3N5C5';
    expect(searchGroupIdsEquivalent(short, full), isTrue);
    expect(searchGroupIdsEquivalent('group_$short', 'group_$full'), isTrue);
    expect(searchGroupIdsEquivalent('group_$short', full), isTrue);
    expect(searchGroupIdsEquivalent('@$short', full), isTrue);
    expect(isGroupConversationId(short), isTrue);
    expect(isGroupConversationId(full), isTrue);
    expect(isGroupConversationId('group_$full'), isTrue);
    expect(isGroupConversationId('c2c_kv8vxgtlha'), isFalse);
    expect(isGroupConversationId('kv8vxgtlha'), isFalse);
  });

  test('preferSearchGroupShowName skips short-token labels equivalent to groupId',
      () {
    expect(
      preferSearchGroupShowName(
        groupName: 'm227LP3N5C5',
        conversationShowName: '@TGS#_@TGS#m227LP3N5C5',
        storeName: '周末局',
        groupId: '@TGS#_@TGS#m227LP3N5C5',
      ),
      '周末局',
    );
    expect(
      preferSearchGroupShowName(
        groupName: '',
        conversationShowName: 'm227LP3N5C5',
        storeName: '周末局',
        groupId: 'm227LP3N5C5',
      ),
      '周末局',
    );
  });

  test('resolveSearchConversationById maps short group token to cached group',
      () {
    const short = 'm227LP3N5C5';
    const full = '@TGS#_@TGS#m227LP3N5C5';
    final cached = V2TimConversation(
      conversationID: 'group_$full',
      groupID: full,
      type: 2,
      showName: '周末局',
    );
    final resolved = resolveSearchConversationById(
      conversationId: short,
      conversationById: <String, V2TimConversation>{
        cached.conversationID: cached,
      },
    );
    expect(resolved.conversationID, 'group_$full');
    expect(resolved.groupID, full);
    expect(resolved.showName, '周末局');
    expect(resolved.type, 2);
  });

  test('resolveSearchConversationById classifies short token as group not c2c',
      () {
    const short = 'm227LP3N5C5';
    final resolved = resolveSearchConversationById(conversationId: short);
    expect(isGroupConversation(resolved), isTrue);
    expect(resolved.groupID, short);
    expect(resolved.userID, isNull);
    expect(resolved.type, 2);
  });

  test('lookupSearchGroupStoreName matches equivalent group ids', () {
    const short = 'm227LP3N5C5';
    const full = '@TGS#_@TGS#m227LP3N5C5';
    DisplayNameStore.instance.setGroup(full, '周末局', notify: false);
    addTearDown(() {
      DisplayNameStore.instance.setGroup(full, '', notify: false);
    });
    expect(lookupSearchGroupStoreName(short), '周末局');
    expect(lookupSearchGroupStoreName('group_$short'), '周末局');
  });

  test('preferSearchC2cShowName prefers remark then store then nick', () {
    expect(
      preferSearchC2cShowName(
        friendRemark: '备注甲',
        storeName: 'Store名',
        nickName: '昵称',
        conversationShowName: 'kv8vxgtlha',
        userID: 'kv8vxgtlha',
      ),
      '备注甲',
    );
    expect(
      preferSearchC2cShowName(
        friendRemark: '',
        storeName: 'Store名',
        nickName: '昵称',
        conversationShowName: 'kv8vxgtlha',
        userID: 'kv8vxgtlha',
      ),
      'Store名',
    );
    expect(
      preferSearchC2cShowName(
        friendRemark: null,
        storeName: null,
        nickName: '昵称乙',
        conversationShowName: 'kv8vxgtlha',
        userID: 'kv8vxgtlha',
      ),
      '昵称乙',
    );
  });

  test('preferSearchC2cShowName skips uid-like conversation showName', () {
    expect(
      preferSearchC2cShowName(
        conversationShowName: 'm227LP3N5C5',
        userID: 'm227LP3N5C5',
      ),
      'm227LP3N5C5',
    );
    expect(
      preferSearchC2cShowName(
        nickName: '沐林',
        conversationShowName: 'm227LP3N5C5',
        userID: 'm227LP3N5C5',
      ),
      '沐林',
    );
  });
}
