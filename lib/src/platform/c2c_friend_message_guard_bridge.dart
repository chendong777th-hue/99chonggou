import 'package:tencent_cloud_chat_demo/src/services/c2c_friend_message_guard.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/c2c_friend_message_guard_bridge.dart';

class UikitC2cFriendMessageGuardBridge {
  UikitC2cFriendMessageGuardBridge._();

  static void install() {
    C2cFriendMessageGuardBridge.configure(
      checker: C2cFriendMessageGuard.checkSend,
    );
  }
}
