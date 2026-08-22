import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/platform/group_invite_router.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';

void main() {
  group('shouldInviteViaRest', () {
    test('returns true for Work group', () {
      expect(shouldInviteViaRest(GroupType.Work), isTrue);
    });

    test('returns true for Public group', () {
      expect(shouldInviteViaRest(GroupType.Public), isTrue);
    });

    test('returns false for AVChatRoom', () {
      expect(shouldInviteViaRest(GroupType.AVChatRoom), isFalse);
    });
  });
}
