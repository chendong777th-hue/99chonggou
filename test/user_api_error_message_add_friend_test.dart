import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/user_api_error_message.dart';

void main() {
  test('maps ADD_FRIEND_VIA_GROUP_DISABLED away from raw backend code', () {
    final text = UserApiErrorMessage.fromAddFriendReasonCode(
      'ADD_FRIEND_VIA_GROUP_DISABLED',
      fallback: 'fallback',
    );
    expect(text, isNot(contains('ADD_FRIEND_VIA_GROUP_DISABLED')));
    expect(text.toLowerCase(), anyOf(contains('group'), contains('群聊')));
  });

  test('maps ADD_FRIEND_VIA_CARD_DISABLED away from raw backend code', () {
    final text = UserApiErrorMessage.fromAddFriendReasonCode(
      'ADD_FRIEND_VIA_CARD_DISABLED',
      fallback: 'fallback',
    );
    expect(text, isNot(contains('ADD_FRIEND_VIA_CARD_DISABLED')));
    expect(text.toLowerCase(), anyOf(contains('card'), contains('名片')));
  });

  test('unknown backend enum uses fallback instead of raw code', () {
    final text = UserApiErrorMessage.fromAddFriendReasonCode(
      'SOME_UNKNOWN_ENUM_CODE',
      fallback: '可读提示',
    );
    expect(text, '可读提示');
  });
}
