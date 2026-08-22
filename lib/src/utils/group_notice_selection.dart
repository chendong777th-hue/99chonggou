/// 群聊 Tab 多选时，群通知入口行使用的哨兵 ID（非真实会话）。
const String kGroupNoticeSelectionId = '__group_notice_entry__';

bool isGroupNoticeSelectionId(String id) {
  return id.trim() == kGroupNoticeSelectionId;
}

Set<String> selectionIdsWithoutGroupNotice(Set<String> selected) {
  return selected
      .where((id) => !isGroupNoticeSelectionId(id))
      .toSet();
}

bool isAllSelectedWithGroupNotice({
  required Iterable<String> visibleConvIds,
  required Set<String> selected,
  required bool noticeVisible,
}) {
  final ids = visibleConvIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (ids.isEmpty && !noticeVisible) {
    return false;
  }
  final allConvsSelected =
      ids.every((id) => selected.contains(id));
  if (!allConvsSelected) {
    return false;
  }
  if (noticeVisible) {
    return selected.contains(kGroupNoticeSelectionId);
  }
  return !selected.contains(kGroupNoticeSelectionId);
}

Set<String> selectAllIds({
  required Iterable<String> visibleConvIds,
  required bool noticeVisible,
}) {
  final next = visibleConvIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet();
  if (noticeVisible) {
    next.add(kGroupNoticeSelectionId);
  }
  return next;
}
