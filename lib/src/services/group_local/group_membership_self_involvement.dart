import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';

/// 判断当前用户是否是被移出/退群的当事人（而非操作者）。
bool isSelfRemovedFromGroupMembershipEvent({
  required String action,
  required String ownerUserId,
  required List<String> memberUserIds,
  String? fromUserId,
  String? detailUserId,
}) {
  final owner = ChatIdFormat.rawUserUid(ownerUserId);
  if (owner.isEmpty) {
    return false;
  }
  final members = memberUserIds
      .map(ChatIdFormat.rawUserUid)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (members.contains(owner)) {
    return true;
  }
  final normalizedAction = action.trim().toLowerCase();
  if (normalizedAction == 'member_removed') {
    final detailUser = ChatIdFormat.rawUserUid(detailUserId ?? '');
    return detailUser.isNotEmpty && detailUser == owner;
  }
  if (normalizedAction != 'member_left') {
    return false;
  }
  final fromUser = ChatIdFormat.rawUserUid(fromUserId ?? '');
  if (fromUser.isNotEmpty && fromUser == owner) {
    return true;
  }
  final detailUser = ChatIdFormat.rawUserUid(detailUserId ?? '');
  return detailUser.isNotEmpty && detailUser == owner;
}

/// 判断当前用户是否是被拉入群的当事人（`member_added`）。
///
/// 与 [isSelfRemovedFromGroupMembershipEvent] 分离：入群事件常把操作者放在
/// `fromUserId`，被邀请人只在 `memberUserIds` / `detail.userId` 里；不能复用退群判定。
bool isSelfAddedToGroupMembershipEvent({
  required String action,
  required String ownerUserId,
  required List<String> memberUserIds,
  String? detailUserId,
}) {
  final normalizedAction = action.trim().toLowerCase();
  if (normalizedAction != 'member_added') {
    return false;
  }
  final owner = ChatIdFormat.rawUserUid(ownerUserId);
  if (owner.isEmpty) {
    return false;
  }
  final members = memberUserIds
      .map(ChatIdFormat.rawUserUid)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);
  if (members.contains(owner)) {
    return true;
  }
  final detailUser = ChatIdFormat.rawUserUid(detailUserId ?? '');
  return detailUser.isNotEmpty && detailUser == owner;
}
