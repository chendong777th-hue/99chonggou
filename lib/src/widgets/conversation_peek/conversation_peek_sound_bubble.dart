import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_sound_elem.dart';

/// 会话长按预览语音气泡：复用聊天页 [TIMUIKitSoundElem]，外观与交互布局一致。
/// 外层通常包 [IgnorePointer]，预览内不播语音。
class ConversationPeekSoundBubble extends StatelessWidget {
  const ConversationPeekSoundBubble({
    super.key,
    required this.message,
    required this.chatModel,
  });

  final V2TimMessage message;
  final TUIChatSeparateViewModel chatModel;

  bool get _isSelf => message.isSelf ?? false;

  @override
  Widget build(BuildContext context) {
    final soundElem = message.soundElem;
    if (soundElem == null) {
      return const SizedBox.shrink();
    }
    return TIMUIKitSoundElem(
      chatModel: chatModel,
      message: message,
      soundElem: soundElem,
      msgID: message.msgID ?? '',
      isFromSelf: _isSelf,
      localCustomInt: message.localCustomInt,
      isShowJump: false,
      clearJump: () {},
      isShowMessageReaction: false,
    );
  }
}
