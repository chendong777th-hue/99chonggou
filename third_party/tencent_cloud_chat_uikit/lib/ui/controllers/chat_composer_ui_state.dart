import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// Page-local composer UI: reply quote + @ member panel.
class ChatComposerUiState {
  V2TimMessage? repliedMessage;
  int activeAtIndex = -1;
  List<V2TimGroupMemberFullInfo?> showAtMemberList =
      <V2TimGroupMemberFullInfo?>[];
  double atPositionX = 0.0;
  double atPositionY = 0.0;

  bool clearAtPanel() {
    var changed = false;
    if (showAtMemberList.isNotEmpty) {
      showAtMemberList = <V2TimGroupMemberFullInfo?>[];
      changed = true;
    }
    if (activeAtIndex != -1) {
      activeAtIndex = -1;
      changed = true;
    }
    return changed;
  }

  static bool sameAtMemberList(
    List<V2TimGroupMemberFullInfo?> left,
    List<V2TimGroupMemberFullInfo?> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i++) {
      if (left[i]?.userID != right[i]?.userID) {
        return false;
      }
    }
    return true;
  }
}
