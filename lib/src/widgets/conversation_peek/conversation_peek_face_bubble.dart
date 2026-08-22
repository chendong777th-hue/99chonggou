import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/dice/dice_face_bubble.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_face_bubble.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 会话长按预览用表情气泡。
///
/// - 骰子 Face：永远静帧（[DiceFaceBubble] 不传 playKey）
/// - 动态/自定义表情走 [StickerFaceBubble]（会解析 sticker 协议与内置 asset）
/// - 关闭全屏点击预览，避免在 Overlay 里再弹一层
/// - 预览卡片宽度更小，用略小的 maxWidthFactor，减少「大方灰块」感
class ConversationPeekFaceBubble extends StatelessWidget {
  const ConversationPeekFaceBubble({
    super.key,
    required this.message,
  });

  final V2TimMessage message;

  @override
  Widget build(BuildContext context) {
    final data = message.faceElem?.data?.trim() ?? '';
    if (data.isEmpty) {
      return _emptyFace(context);
    }
    final diceValue = DiceConstants.parseValue(data);
    if (diceValue != null) {
      return DiceFaceBubble(value: diceValue, maxWidthFactor: 0.26);
    }
    return StickerFaceBubble(
      data: data,
      maxWidthFactor: 0.26,
      enableFullScreenPreview: false,
    );
  }

  Widget _emptyFace(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.emoji_emotions_outlined,
        size: 28,
        color: Color(0xFF8E8E93),
      ),
    );
  }
}
