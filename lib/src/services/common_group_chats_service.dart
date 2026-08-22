import 'package:tencent_cloud_chat_demo/src/api/user_api.dart';

/// 共同群聊：走后端 `GET /users/{peerUserId}/common-groups`。
class CommonGroupChatsService {
  CommonGroupChatsService._();

  static final CommonGroupChatsService instance = CommonGroupChatsService._();

  /// 测分页时可先用较小值；上线前可改回 50。
  static const int defaultPageSize = 20;

  Future<CommonGroupsPage> loadCommonGroupsPage(
    String peerUserId, {
    int limit = defaultPageSize,
    int offset = 0,
  }) {
    return UserApi.instance.fetchCommonGroups(
      peerUserId,
      limit: limit,
      offset: offset,
    );
  }
}
