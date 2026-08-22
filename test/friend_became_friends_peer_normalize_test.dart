import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';

void main() {
  test('normalizeFriendBecameFriendsPeerId 去掉 c2c_ 与 @', () {
    expect(normalizeFriendBecameFriendsPeerId('user_a'), 'user_a');
    expect(normalizeFriendBecameFriendsPeerId('c2c_user_a'), 'user_a');
    expect(normalizeFriendBecameFriendsPeerId('C2C_user_a'), 'user_a');
    expect(normalizeFriendBecameFriendsPeerId('@user_a'), 'user_a');
    expect(normalizeFriendBecameFriendsPeerId('  c2c_user_a  '), 'user_a');
    expect(normalizeFriendBecameFriendsPeerId(''), '');
  });
}
