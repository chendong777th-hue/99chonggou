import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 从聊天消息列表批量预取表情元数据（`POST /stickers/batch`）。
class StickerMessagePrefetch {
  StickerMessagePrefetch._();

  static Set<String> _missingStickerIds(Iterable<V2TimMessage?> messages) {
    final repo = StickerRepository.instance;
    final missing = <String>{};
    for (final message in messages) {
      if (message == null) {
        continue;
      }
      if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_FACE &&
          message.faceElem == null) {
        continue;
      }
      final data = message.faceElem?.data?.trim() ?? '';
      if (data.isEmpty) {
        continue;
      }
      if (repo.resolveStickerItemSync(data) != null) {
        continue;
      }
      final stickerId = repo.parseStickerId(data);
      if (stickerId != null && stickerId.isNotEmpty) {
        missing.add(stickerId);
      }
    }
    return missing;
  }

  static void fromMessages(Iterable<V2TimMessage?> messages) {
    final missing = _missingStickerIds(messages);
    if (missing.isNotEmpty) {
      // ignore: discarded_futures
      StickerRepository.instance.prefetchStickerIds(missing);
    }
  }

  /// 会话预览：等表情元数据回来再渲染，减少灰块/占位。
  static Future<void> resolveForMessages(
    Iterable<V2TimMessage?> messages, {
    Duration budget = const Duration(milliseconds: 800),
  }) async {
    final missing = _missingStickerIds(messages);
    if (missing.isEmpty) {
      return;
    }
    try {
      await StickerRepository.instance
          .prefetchStickerIds(missing)
          .timeout(budget);
    } catch (_) {}
  }
}
