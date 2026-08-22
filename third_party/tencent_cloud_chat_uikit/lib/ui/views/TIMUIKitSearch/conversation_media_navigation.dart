import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_asset_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_conversation_media_file_page.dart';

/// 将聊天页 [conversationID] 规范为 IM 会话 ID（`c2c_*` / `group_*`）。
String canonicalChatConversationId({
  required String conversationId,
  required ConvType? conversationType,
}) {
  final raw = conversationId.trim();
  if (raw.isEmpty) {
    return raw;
  }
  if (raw.startsWith('c2c_') || raw.startsWith('group_')) {
    return raw;
  }
  if (conversationType == ConvType.group) {
    return 'group_$raw';
  }
  return 'c2c_$raw';
}

Set<String> _conversationIdCandidates({
  required String conversationId,
  required ConvType? conversationType,
}) {
  final raw = conversationId.trim();
  final canonical = canonicalChatConversationId(
    conversationId: raw,
    conversationType: conversationType,
  );
  return {
    raw,
    canonical,
    if (conversationType == ConvType.group && !raw.startsWith('group_'))
      'group_$raw'
    else if (conversationType != ConvType.group && !raw.startsWith('c2c_'))
      'c2c_$raw',
  };
}

V2TimConversation conversationForChatMediaPage(
  TUIChatSeparateViewModel chatModel,
) {
  final rawId = chatModel.conversationID.trim();
  final candidates = _conversationIdCandidates(
    conversationId: rawId,
    conversationType: chatModel.conversationType,
  );

  final selected = chatModel.conversationViewModel.selectedConversation;
  final selectedId = selected?.conversationID.trim() ?? '';
  if (selected != null && candidates.contains(selectedId)) {
    return selected;
  }

  for (final id in candidates) {
    if (!id.startsWith('c2c_') && !id.startsWith('group_')) {
      continue;
    }
    final cached = chatModel.conversationViewModel.getConversation(id);
    if (cached != null) {
      return cached;
    }
  }

  final canonicalId = canonicalChatConversationId(
    conversationId: rawId,
    conversationType: chatModel.conversationType,
  );
  String? showName;
  for (final id in candidates) {
    showName = TencentUtils.checkString(
      chatModel.conversationViewModel.getConversation(id)?.showName,
    );
    if (showName != null) {
      break;
    }
  }

  return resolveSearchConversationById(
    conversationId: canonicalId,
    showName: showName,
  );
}

Future<void> pushConversationMediaFilePage(
  BuildContext context, {
  required V2TimConversation conversation,
  ConversationAssetTab initialTab = ConversationAssetTab.media,
  void Function(V2TimConversation conversation, V2TimMessage message)?
      onTapMessage,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TIMUIKitConversationMediaFilePage(
        conversation: conversation,
        initialTab: initialTab,
        onTapMessage: onTapMessage ?? (_, __) {},
      ),
    ),
  );
}

Future<void> openChatConversationMediaPage({
  required BuildContext context,
  required TUIChatSeparateViewModel chatModel,
  void Function(V2TimConversation conversation, V2TimMessage message)?
      onTapMessage,
}) async {
  final conversation = conversationForChatMediaPage(chatModel);
  final conversationId = conversation.conversationID.trim();
  if (conversationId.isEmpty) {
    return;
  }

  // 立即进入页面，由页面内 reset + loading 状态负责首批加载。不要在路由
  // 外等待多页历史，否则用户点击后会停留在聊天页且没有任何加载反馈。
  await pushConversationMediaFilePage(
    context,
    conversation: conversation,
    onTapMessage: onTapMessage ??
        (_, __) {
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        },
  );
}
