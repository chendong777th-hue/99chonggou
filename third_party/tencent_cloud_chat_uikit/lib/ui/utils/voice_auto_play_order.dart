import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';

bool messageMatchesPlaybackId(V2TimMessage message, String id) {
  if (id.isEmpty) {
    return false;
  }
  return message.msgID == id || message.id == id;
}

bool isPlayableSoundMessage(V2TimMessage message) {
  if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
    return false;
  }
  if (message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING ||
      message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
    return false;
  }
  return TencentUtils.checkString(message.msgID) != null ||
      TencentUtils.checkString(message.id) != null;
}

String? soundPlaybackId(V2TimMessage message) {
  return TencentUtils.checkString(message.msgID) ??
      TencentUtils.checkString(message.id);
}

/// 连播下一条时，气泡可能尚未对上播放器 messageId，但仍是当前正在播的那条。
/// 进度条 / 剩余时长 / 暂停图标只要「当前条 + 播放器在工作」就要跟着走。
bool shouldDriveVoicePlaybackUi({
  required bool isCurrent,
  required bool engineMatches,
  required bool isAnimating,
  required bool isPaused,
  required bool playerActive,
}) {
  if (engineMatches || isAnimating || isPaused) {
    return true;
  }
  return isCurrent && playerActive;
}

/// 会话内存表为 newest-first（index 0 = 最新 = 屏幕下方）。
/// 连播「往下」= 时间上更晚 = 列表里更靠前的下一条可播语音。
V2TimMessage? findNextPlayableSound({
  required List<V2TimMessage> messagesNewestFirst,
  required String completedMessageId,
}) {
  final completedId = completedMessageId.trim();
  if (completedId.isEmpty || messagesNewestFirst.isEmpty) {
    return null;
  }

  var anchorIndex = -1;
  for (var i = 0; i < messagesNewestFirst.length; i++) {
    if (messageMatchesPlaybackId(messagesNewestFirst[i], completedId)) {
      anchorIndex = i;
      break;
    }
  }
  if (anchorIndex <= 0) {
    return null;
  }

  for (var i = anchorIndex - 1; i >= 0; i--) {
    final candidate = messagesNewestFirst[i];
    if (isPlayableSoundMessage(candidate)) {
      return candidate;
    }
  }
  return null;
}
