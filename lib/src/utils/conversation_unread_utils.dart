import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archive_conversation_lookup.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_conversation_visibility.dart'
    as group_visibility;
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';

/// 会话未读数工具：与列表页免打扰展示规则保持一致。
class ConversationUnreadUtils {
  ConversationUnreadUtils._();

  /// 会议群在 UI 上不展示免打扰，未读仍计入 Tab 角标。
  static bool isConversationDisturbed(V2TimConversation conversation) {
    if (conversation.groupType == 'Meeting') {
      return false;
    }
    return (conversation.recvOpt ?? 0) != 0;
  }

  /// Tab 角标 / 汇总未读：免打扰会话不计入。
  static int notifiableUnreadCount(V2TimConversation conversation) {
    if (isConversationDisturbed(conversation)) {
      return 0;
    }
    final unread = conversation.unreadCount ?? 0;
    return unread > 0 ? unread : 0;
  }

  static bool isGroupConversation(V2TimConversation conversation) {
    // 与 membership / HistoryPeer 对齐：c2c_ 前缀硬覆盖 type / 误填 groupID。
    return group_visibility.isGroupConversation(conversation);
  }

  /// Tab / App 角标聚合用：在 [notifiableUnreadCount] 之上叠加归档与官方号隐藏。
  ///
  /// 归档判定走 token 展开（兼容裸 ID / `c2c_` / `group_`），
  /// 与主列表 purge / 归档页一致，避免归档会话未读仍进底部导航。
  static int notifiableUnreadForAggregate(
    V2TimConversation conversation, {
    required Set<String> archivedC2c,
    required Set<String> archivedGroup,
    Set<String>? archivedC2cLookup,
    Set<String>? archivedGroupLookup,
  }) {
    if (conversation.userID == '10000') {
      return 0;
    }
    final isGroup = isGroupConversation(conversation);
    final id = conversation.conversationID.trim();
    if (id.isNotEmpty) {
      final archived = isGroup ? archivedGroup : archivedC2c;
      if (archived.isNotEmpty) {
        final lookup = isGroup
            ? (archivedGroupLookup ??
                cachedArchiveLookupTokenSet(archivedGroup))
            : (archivedC2cLookup ?? cachedArchiveLookupTokenSet(archivedC2c));
        if (conversationIdInArchivedLookup(lookup, id)) {
          return 0;
        }
      }
    }
    if (!isGroup &&
        PlatformOfficialAccountService.shouldHideConversation(conversation)) {
      return 0;
    }
    return notifiableUnreadCount(conversation);
  }

  /// 与 SQL `sumNotifiableUnreadByScope` 列条件对齐的轻量判定（无归档/官方号）。
  static int notifiableUnreadFromColumns({
    required int unreadCount,
    required int recvOpt,
    required String groupType,
  }) {
    if (unreadCount <= 0) {
      return 0;
    }
    final meeting = groupType == 'Meeting';
    if (!meeting && recvOpt != 0) {
      return 0;
    }
    return unreadCount;
  }
}

/// 单次角标增量样本。
class ConversationUnreadDelta {
  const ConversationUnreadDelta({
    required this.isGroup,
    required this.oldNotifiable,
    required this.newNotifiable,
  });

  final bool isGroup;
  final int oldNotifiable;
  final int newNotifiable;

  int get delta => newNotifiable - oldNotifiable;
}

/// 分 scope 未读合计。
class NotifiableUnreadSums {
  const NotifiableUnreadSums({required this.c2c, required this.group});

  final int c2c;
  final int group;
}
