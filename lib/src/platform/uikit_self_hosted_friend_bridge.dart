import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/services/user_profile_local/user_profile_local_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/uikit_user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/friend_request_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart';

/// 将 UIKit 好友删/列表等操作收口到 99chat-server REST API。
class UikitSelfHostedFriendBridge {
  UikitSelfHostedFriendBridge._();

  static void install() {
    FriendSyncService.instance.install();
    UikitUserProfileLocalBridge.install();
    unawaited(UserProfileLocalService.instance.hydrateFromFriendLocalStore());
    SelfHostedFriendshipBridge.configure(
      loadFriendList: () =>
          MeFriendApi.instance.fetchV2TimFriends(allowLegacySdkFallback: false),
      loadFriendListFromNetwork: () async {
        final records = await MeFriendApi.instance.fetchFriendsFromNetwork();
        return records
            .map((record) => record.toV2TimFriendInfo())
            .toList(growable: false);
      },
      createFriendRequest: ({
        required String userID,
        String? addSource,
        String? addWording,
      }) async {
        final result = await FriendRequestApi.instance.create(
          targetUserId: userID,
          addWording: addWording ?? '',
          addSource: addSource ?? 'search',
        );
        return SelfHostedFriendshipAddResult(
          outcome: result.outcome,
          requestId: result.requestId,
        );
      },
      deleteFriend: MeFriendApi.instance.deleteFriend,
      updateRemark: ({
        required String userID,
        required String remark,
      }) =>
          MeFriendApi.instance.updateRemark(
            friendUserId: userID,
            remark: remark,
          ),
      isFriend: MeFriendApi.instance.isFriend,
      resolveFriendResultType: MeFriendApi.instance.imFriendCheckResultType,
      searchFriendsLocal: ({
        required String keyword,
        int limit = 80,
        String? cursor,
      }) async {
        final page = await FriendLocalStore.instance.searchFriendIds(
          keyword: keyword,
          limit: limit,
          cursor: cursor,
        );
        return SelfHostedIdSearchPage(
          ids: page.ids,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        );
      },
      hydrateFriends: (userIds) =>
          FriendLocalStore.instance.loadAsV2TimFriendsByIds(
        friendUserIds: userIds,
      ),
    );
  }
}
