import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 会话 lastMessage 合并：禁止弱 CUSTOM（「[业务消息]」兜底）盖掉更强预览。
class ConversationLastMessagePrefer {
  ConversationLastMessagePrefer._();

  /// 是否为未识别 CUSTOM，列表只会显示「[业务消息]」兜底。
  static bool isWeakCustomLastMessage(V2TimMessage? message) {
    if (message == null) {
      return false;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
      return false;
    }
    // 成友 tip 仅适合新会话；老会话有真实聊天时不应作为 lastMessage / 列表预览。
    if (isFriendRelationshipCustomMessage(message)) {
      return true;
    }
    final raw = message.customElem?.data?.trim() ?? '';
    if (raw.isEmpty) {
      return true;
    }
    final light = lightCustomConversationPreview(message)?.trim() ?? '';
    if (light.isNotEmpty) {
      return false;
    }
    // 轻量路径无法识别 → 与完整预览的「[业务消息]」兜底同级，视为弱。
    return true;
  }

  static bool isStrongLastMessage(V2TimMessage? message) {
    if (message == null) {
      return false;
    }
    if (isWeakCustomLastMessage(message)) {
      return false;
    }
    return true;
  }

  /// tip/时间戳选择之后再套禁降级；同 msgID 终态/撤回升级仍允许。
  static V2TimMessage? preferLastMessage({
    V2TimMessage? existing,
    V2TimMessage? incoming,
  }) {
    final tipped = GroupTipsMessageHelper.pickPreferredLastMessage(
      existing: existing,
      incoming: incoming,
    );
    if (tipped == null) {
      return null;
    }
    if (existing == null) {
      return tipped;
    }

    preserveRevokedLastMessageState(
      existing: existing,
      incoming: incoming,
      preferred: tipped,
    );

    final existingId = existing.msgID?.trim() ?? '';
    final tippedId = tipped.msgID?.trim() ?? '';
    if (existingId.isNotEmpty &&
        tippedId.isNotEmpty &&
        existingId == tippedId &&
        GroupTipsMessageHelper.shouldUpgradeSameIdLastMessage(
          existing: existing,
          incoming: tipped,
        )) {
      return tipped;
    }

    if (identical(tipped, existing)) {
      return existing;
    }

    if (isWeakCustomLastMessage(tipped) && isStrongLastMessage(existing)) {
      return existing;
    }
    return tipped;
  }
}
