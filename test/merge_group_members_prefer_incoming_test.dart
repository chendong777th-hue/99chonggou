import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';

V2TimGroupMemberFullInfo _member(String userId, {String? nick}) {
  return V2TimGroupMemberFullInfo(
    userID: userId,
    nickName: nick ?? userId,
  );
}

void main() {
  test('merge keeps existing order and appends new members', () {
    final existing = [_member('a'), _member('b')];
    final incoming = [_member('b', nick: 'B2'), _member('c')];
    final merged = mergeGroupMembersPreferIncoming(existing, incoming);
    expect(merged.map((m) => m.userID).toList(), ['a', 'b', 'c']);
    expect(merged[1].nickName, 'B2');
  });

  test('merge does not shrink when incoming is a prefix page', () {
    final existing = [
      for (var i = 0; i < 150; i++) _member('u$i'),
    ];
    final incoming = [
      for (var i = 0; i < 100; i++) _member('u$i'),
    ];
    final merged = mergeGroupMembersPreferIncoming(existing, incoming);
    expect(merged.length, 150);
  });
}
