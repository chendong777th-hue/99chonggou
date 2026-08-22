import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';

typedef OpenAddFriendPage = Future<void> Function(
  BuildContext context, {
  required String userID,
  required V2TimUserFullInfo friendInfo,
  String? addSource,
  String? groupId,
});

/// 宿主可注入自研 [AddFriendPage] 等加好友页，替代 UIKit 默认 [SendApplication]。
class AddFriendNavigator {
  AddFriendNavigator._();

  static OpenAddFriendPage? openAddFriendPage;
}
