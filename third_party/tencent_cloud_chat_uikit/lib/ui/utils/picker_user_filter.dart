import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

bool shouldHideUserFromPickers(String? userId) {
  final filter =
      serviceLocator<TUISelfInfoViewModel>().globalConfig?.shouldHideUserFromPickers;
  if (filter == null) {
    return false;
  }
  return filter(userId);
}

bool shouldHideConversationFromPickers(V2TimConversation? conversation) {
  if (conversation == null) {
    return false;
  }
  if (conversation.type == 1) {
    return shouldHideUserFromPickers(conversation.userID);
  }
  final conversationId = conversation.conversationID?.trim() ?? '';
  if (conversationId.startsWith('c2c_')) {
    return shouldHideUserFromPickers(conversationId.substring(4));
  }
  return false;
}

List<V2TimFriendInfo> filterFriendListForPickers(List<V2TimFriendInfo> list) {
  return list
      .where((item) => !shouldHideUserFromPickers(item.userID))
      .toList();
}

List<V2TimFriendInfoResult>? filterFriendSearchResultsForPickers(
  List<V2TimFriendInfoResult>? list,
) {
  if (list == null) {
    return list;
  }
  return list
      .where((item) => !shouldHideUserFromPickers(item.friendInfo?.userID))
      .toList();
}
