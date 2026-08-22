import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 从长按消息构建快速定庄请求体（方式二：文本 + 发送者）。
class SangongQuickSetupBankerInput {
  const SangongQuickSetupBankerInput({
    required this.text,
    required this.imUserId,
    this.nickname,
  });

  final String text;
  final String imUserId;
  final String? nickname;

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'imUserId': imUserId,
      if (nickname != null && nickname!.trim().isNotEmpty)
        'nickname': nickname!.trim(),
    };
  }

  static bool canUseMessage(V2TimMessage message) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_TEXT) {
      return false;
    }
    final text = message.textElem?.text?.trim() ?? '';
    final imUserId = message.sender?.trim() ?? '';
    return text.isNotEmpty && imUserId.isNotEmpty;
  }

  static SangongQuickSetupBankerInput? fromMessage(V2TimMessage message) {
    if (!canUseMessage(message)) {
      return null;
    }
    final text = message.textElem!.text!.trim();
    final imUserId = message.sender!.trim();
    final nickname = _firstNonEmpty([
      message.nameCard,
      message.nickName,
      message.friendRemark,
    ]);
    return SangongQuickSetupBankerInput(
      text: text,
      imUserId: imUserId,
      nickname: nickname,
    );
  }

  static String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }
}

/// 解析定庄输入，与服务端 quick-setup 文本规则一致（如 `2`、`2.5000`）。
class SangongBankerSetupParseResult {
  const SangongBankerSetupParseResult({
    this.door,
    this.limit,
    this.hasExplicitLimit = false,
  });

  final int? door;
  final int? limit;
  final bool hasExplicitLimit;
}

SangongBankerSetupParseResult parseSangongBankerSetupText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return const SangongBankerSetupParseResult();
  }
  for (final sep in ['.', '/', '、', '-', '+']) {
    final idx = trimmed.indexOf(sep);
    if (idx <= 0 || idx >= trimmed.length - 1) {
      continue;
    }
    final door = int.tryParse(trimmed.substring(0, idx).trim());
    final limit = int.tryParse(trimmed.substring(idx + 1).trim());
    if (door != null && limit != null) {
      return SangongBankerSetupParseResult(
        door: door,
        limit: limit,
        hasExplicitLimit: true,
      );
    }
  }
  final single = int.tryParse(trimmed);
  if (single != null) {
    return SangongBankerSetupParseResult(door: single);
  }
  return const SangongBankerSetupParseResult();
}
