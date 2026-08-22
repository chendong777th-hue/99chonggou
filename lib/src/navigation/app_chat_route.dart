import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/chat.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';

Route<T> appChatRoute<T>(
  V2TimConversation conversation, {
  int? entryUnreadCount,
  V2TimMessage? initFindingMsg,
  MessageAnchor? searchJumpAnchor,
  bool? initialC2cCanMessage,
  String? c2cPermissionHintSource,
}) {
  final resolvedAnchor =
      searchJumpAnchor ??
      (initFindingMsg == null
          ? null
          : MessageAnchor.fromConversationMessage(
              conversation,
              initFindingMsg,
            ));
  return AppMaterialPageRoute<T>(
    settings: const RouteSettings(name: AppRoutes.chat),
    // 聊天页禁止转场 snapshot：转场结束切回 live 树时会卸掉消息列表 State，
    // 表现为 t+300ms partition_cache_miss 全字段 -1→N 的整表重建抖动。
    allowSnapshotting: false,
    routeVisibilityDeferredFrames: 1,
    // 消息列表与上推动画抢边缘命中时，略加宽左缘返回条更稳。
    edgeStartWidthPx: 40,
    builder: (_) => RepaintBoundary(
      // 侧滑只合成图层，避免 20 条气泡跟着手势每帧 relayout。
      child: Chat(
        selectedConversation: conversation,
        entryUnreadCount: entryUnreadCount,
        initFindingMsg: initFindingMsg,
        searchJumpAnchor: resolvedAnchor,
        initialC2cCanMessage: initialC2cCanMessage,
        c2cPermissionHintSource: c2cPermissionHintSource,
      ),
    ),
  );
}

Future<T?> openChatWithAnchor<T>(
  BuildContext context,
  V2TimConversation conversation, {
  MessageAnchor? anchor,
}) {
  if (!context.mounted) {
    return Future<T?>.value();
  }
  return Navigator.of(
    context,
  ).push<T>(appChatRoute<T>(conversation, searchJumpAnchor: anchor));
}
