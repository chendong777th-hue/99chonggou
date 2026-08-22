import 'package:tencent_cloud_chat_demo/src/services/peer_profile_refresh_bus.dart';
import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/utils/user_display_profile.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';

class UikitUserProfileLocalBridge {
  UikitUserProfileLocalBridge._();

  static void install() {
    UserProfileLocalBridge.configure(
      loadFriendInfo: UserProfileLocalService.instance.loadFriendInfo,
      saveFriendInfo: UserProfileLocalService.instance.saveFriendInfo,
      mergePreferLocal: UserProfileLocalService.instance.mergePreferLocal,
      saveUserInfo: UserProfileLocalService.instance.saveUserFullInfo,
      mergeHostedFriendRemark:
          UserProfileLocalService.instance.mergeHostedFriendRemark,
      readCached: UserDisplayProfile.cachedSnapshot,
      changeListenable: PeerProfileRefreshBus.instance.revision,
    );
  }
}
