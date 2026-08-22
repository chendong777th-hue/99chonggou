import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_web_ready_guard.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_conversation_controller.dart';

class WebConversationSyncService {
  WebConversationSyncService._();

  static final WebConversationSyncService instance = WebConversationSyncService._();

  bool _running = false;

  Future<void> syncJoinedGroupConversations(
    TIMUIKitConversationController controller,
  ) async {
    if (!kIsWeb || _running) {
      return;
    }
    _running = true;
    try {
      final ready = await ImWebReadyGuard.instance.wait();
      if (!ready) {
        return;
      }
      final groupServices = serviceLocator<GroupServices>();
      final groups = await groupServices.getJoinedGroupList() ?? const [];
      if (groups.isEmpty) {
        return;
      }

      final current = List<V2TimConversation?>.from(controller.conversationList);
      final existingIDs = current
          .whereType<V2TimConversation>()
          .map((item) => item.conversationID)
          .where((id) => id.isNotEmpty)
          .toSet();
      final additions = <V2TimConversation>[];

      for (final group in groups) {
        final groupID = group.groupID.trim();
        if (groupID.isEmpty) {
          continue;
        }
        final conversationID = 'group_$groupID';
        if (existingIDs.contains(conversationID)) {
          continue;
        }
        final conv = await _loadGroupConversation(conversationID);
        additions.add(
          conv ??
              V2TimConversation(
                conversationID: conversationID,
                type: 2,
                groupID: groupID,
                showName: (group.groupName ?? '').trim().isNotEmpty
                    ? group.groupName
                    : groupID,
                groupType: group.groupType,
                faceUrl: group.faceUrl,
              ),
        );
      }

      if (additions.isEmpty) {
        return;
      }
      controller.conversationList = [...current, ...additions];
    } finally {
      _running = false;
    }
  }

  Future<V2TimConversation?> _loadGroupConversation(String conversationID) async {
    final res = await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .getConversation(conversationID: conversationID);
    if (res.code == 0) {
      return res.data;
    }
    return null;
  }
}
