import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart'
    show GroupSystemNoticeItem;
import 'package:tencent_cloud_chat_demo/src/services/group_notice_unread_service.dart';

enum ConversationFeedRowKind {
  archived,
  groupNotice,
  conversation,
}

class ConversationFeedRow {
  final ConversationFeedRowKind kind;
  final V2TimConversation? conversation;
  final int timestampMs;

  const ConversationFeedRow.archived()
      : kind = ConversationFeedRowKind.archived,
        conversation = null,
        timestampMs = 0;

  const ConversationFeedRow.groupNotice(this.timestampMs)
      : kind = ConversationFeedRowKind.groupNotice,
        conversation = null;

  const ConversationFeedRow.conversation(this.conversation, this.timestampMs)
      : kind = ConversationFeedRowKind.conversation;
}

bool shouldShowGroupNoticeEntry(
  List<V2TimGroupApplication> applications,
  List<GroupSystemNoticeItem> notices, {
  int dismissWatermarkMs = 0,
}) {
  final hasData = applications.isNotEmpty || notices.isNotEmpty;
  if (!hasData) {
    return false;
  }
  return shouldShowGroupNoticeEntryData(
    latestNoticeMs: latestGroupNoticeTimestampMs(applications, notices),
    dismissWatermarkMs: dismissWatermarkMs,
  );
}

bool shouldShowGroupNoticeEntryData({
  required int latestNoticeMs,
  required int dismissWatermarkMs,
}) {
  return latestNoticeMs > dismissWatermarkMs;
}

/// 群通知入口显隐 / 排序时间 / 文案相关数据指纹。
///
/// 任一影响入口位置或预览的字段变化时指纹必须变，供 Feed 禁止结构 patch、
/// 并使虚拟列表插入点 cache 失效。
int groupNoticeFeedSignature({
  required List<V2TimGroupApplication> applications,
  required List<GroupSystemNoticeItem> notices,
  required bool includeGroupNoticeEntry,
  required bool groupNoticePinned,
  required int dismissWatermarkMs,
}) {
  var hash = Object.hash(
    includeGroupNoticeEntry,
    groupNoticePinned,
    dismissWatermarkMs,
    applications.length,
    notices.length,
    latestGroupNoticeTimestampMs(applications, notices),
  );
  for (final item in applications) {
    hash = Object.hash(
      hash,
      item.authentication,
      item.groupID,
      item.addTime,
      item.handleStatus,
      item.handleResult,
      item.fromUser,
      item.toUser,
      item.type,
    );
  }
  for (final item in notices) {
    hash = Object.hash(
      hash,
      item.id,
      item.groupID,
      item.timestamp,
      item.type.index,
    );
  }
  return hash;
}

/// 群通知在「库序会话」中的插入 typeIndex（不含归档 header）。
///
/// 库序：`is_pinned DESC, active_time DESC`。未置顶时：
/// `pinnedCount + count(非置顶且 active_time > noticeTs)`。
/// [groupNoticePinned] 为 true 时返回 0（调用方应放 header，而非 inline）。
int computeGroupNoticeInsertTypeIndex({
  required bool groupNoticePinned,
  required int total,
  required int pinnedCount,
  required int nonPinnedNewerThanNoticeCount,
}) {
  if (total <= 0) {
    return 0;
  }
  if (groupNoticePinned) {
    return 0;
  }
  final pinned = pinnedCount.clamp(0, total);
  final newer = nonPinnedNewerThanNoticeCount.clamp(0, total - pinned);
  return (pinned + newer).clamp(0, total);
}

/// 虚拟列表：会话 typeIndex → ListView index（含 header + 可选 inline 通知槽）。
/// [noticeInsertAt] `< 0` 表示无 inline 通知。
int virtualFeedListIndexForTypeIndex({
  required int typeIndex,
  required int headerCount,
  required int noticeInsertAt,
}) {
  if (noticeInsertAt < 0) {
    return headerCount + typeIndex;
  }
  if (typeIndex >= noticeInsertAt) {
    return headerCount + typeIndex + 1;
  }
  return headerCount + typeIndex;
}

/// 虚拟列表 bodyIndex → 会话 typeIndex；若落在通知槽返回 null。
/// [noticeInsertAt] `< 0` 表示无 inline 通知。
int? virtualFeedTypeIndexForBodyIndex({
  required int bodyIndex,
  required int noticeInsertAt,
  required int total,
}) {
  if (bodyIndex < 0) {
    return null;
  }
  if (noticeInsertAt < 0) {
    return bodyIndex < total ? bodyIndex : null;
  }
  final bodyLen = total + 1;
  if (bodyIndex >= bodyLen) {
    return null;
  }
  if (bodyIndex == noticeInsertAt) {
    return null;
  }
  if (bodyIndex > noticeInsertAt) {
    final typeIndex = bodyIndex - 1;
    return typeIndex < total ? typeIndex : null;
  }
  return bodyIndex < total ? bodyIndex : null;
}

bool virtualFeedBodyIndexIsGroupNotice({
  required int bodyIndex,
  required int noticeInsertAt,
}) {
  return noticeInsertAt >= 0 && bodyIndex == noticeInsertAt;
}

List<ConversationFeedRow> buildConversationFeedRows({
  required List<V2TimConversation> conversations,
  required bool includeArchivedEntry,
  required bool includeGroupNoticeEntry,
  required List<V2TimGroupApplication> applications,
  required List<GroupSystemNoticeItem> notices,
  required int Function(V2TimConversation conversation) conversationTimestampMs,
  bool groupNoticePinned = false,
  int groupNoticeDismissWatermarkMs = 0,
}) {
  final rows = conversations
      .map(
        (conversation) => ConversationFeedRow.conversation(
          conversation,
          conversationTimestampMs(conversation),
        ),
      )
      .toList();

  if (!includeGroupNoticeEntry ||
      !shouldShowGroupNoticeEntry(
        applications,
        notices,
        dismissWatermarkMs: groupNoticeDismissWatermarkMs,
      )) {
    if (includeArchivedEntry) {
      rows.insert(0, const ConversationFeedRow.archived());
    }
    return rows;
  }

  final noticeTs = latestGroupNoticeTimestampMs(applications, notices);
  final groupNoticeRow = ConversationFeedRow.groupNotice(noticeTs);

  if (groupNoticePinned) {
    rows.insert(0, groupNoticeRow);
    if (includeArchivedEntry) {
      rows.insert(0, const ConversationFeedRow.archived());
    }
    return rows;
  }

  if (rows.isEmpty) {
    if (includeArchivedEntry) {
      return [
        const ConversationFeedRow.archived(),
        groupNoticeRow,
      ];
    }
    return [groupNoticeRow];
  }

  var pinnedCount = 0;
  var newerNonPinned = 0;
  for (final row in rows) {
    if (row.conversation?.isPinned ?? false) {
      pinnedCount++;
      continue;
    }
    if (row.timestampMs > noticeTs) {
      newerNonPinned++;
    }
  }
  final insertIndex = computeGroupNoticeInsertTypeIndex(
    groupNoticePinned: false,
    total: rows.length,
    pinnedCount: pinnedCount,
    nonPinnedNewerThanNoticeCount: newerNonPinned,
  );
  rows.insert(insertIndex, groupNoticeRow);
  if (includeArchivedEntry) {
    rows.insert(0, const ConversationFeedRow.archived());
  }
  return rows;
}

/// 结构未变时：按 ID 替换会话行引用，保留 archived / groupNotice 行。
List<ConversationFeedRow> patchConversationFeedRowsById({
  required List<ConversationFeedRow> cached,
  required List<V2TimConversation> visible,
  required int Function(V2TimConversation conversation) conversationTimestampMs,
}) {
  if (cached.isEmpty) {
    return cached;
  }
  final byId = <String, V2TimConversation>{};
  for (final conversation in visible) {
    final id = conversation.conversationID.trim();
    if (id.isNotEmpty) {
      byId[id] = conversation;
    }
  }
  return cached.map((row) {
    if (row.kind != ConversationFeedRowKind.conversation) {
      return row;
    }
    final id = row.conversation?.conversationID.trim() ?? '';
    if (id.isEmpty) {
      return row;
    }
    final next = byId[id];
    if (next == null) {
      return row;
    }
    return ConversationFeedRow.conversation(
      next,
      conversationTimestampMs(next),
    );
  }).toList(growable: false);
}
