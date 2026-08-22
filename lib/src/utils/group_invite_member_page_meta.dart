import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_group_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_join_application_approval.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_application.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_application.dart';

/// 「添加群成员」页：邀请审批提示 / 进群审核中 userId / 已在群成员禁选。
class GroupInviteMemberPageMeta {
  GroupInviteMemberPageMeta._();

  static Future<bool> inviteNeedsApproval(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return false;
    }
    try {
      final options = await GroupJoinApi.instance.fetchJoinOptions(id);
      return options.inviteJoinOption == GroupJoinOption.needPermission;
    } catch (_) {
      return false;
    }
  }

  /// 已在群成员 userId（本地库 + 分页拉齐），供邀请选人禁选。
  ///
  /// 解决：资料页 `groupMemberList` 仅首屏分页时，未加载页的成员仍可勾选。
  static Future<Set<String>> existingMemberUserIds(String groupId) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return const <String>{};
    }
    final out = <String>{};

    try {
      final local = await GroupMemberLocalStore.instance.readAll(groupId: id);
      for (final record in local) {
        final uid = ChatIdFormat.rawUserUid(record.userId);
        if (uid.isNotEmpty) {
          out.add(uid);
        }
      }
    } catch (_) {}

    try {
      var offset = 0;
      const limit = 100;
      const maxPages = 100;
      for (var pageIndex = 0; pageIndex < maxPages; pageIndex++) {
        final page = await MeGroupApi.instance.fetchGroupMembersPage(
          groupId: id,
          limit: limit,
          offset: offset,
          refresh: offset <= 0,
        );
        for (final item in page.items) {
          final uid = ChatIdFormat.rawUserUid(item.userId);
          if (uid.isNotEmpty) {
            out.add(uid);
          }
        }
        if (page.items.length < limit) {
          break;
        }
        offset += page.items.length;
        if (page.total > 0 && offset >= page.total) {
          break;
        }
      }
    } catch (_) {}

    return out;
  }

  /// 优先使用 `GET /group/{id}/pending-invitees`（任意成员可读）。
  static Future<Set<String>> pendingReviewUserIds(
    String groupId, {
    Set<String> memberUserIds = const <String>{},
  }) async {
    final id = groupId.trim();
    if (id.isEmpty) {
      return const <String>{};
    }

    final pending = <String>{};
    try {
      final userIds = await GroupJoinApi.instance.fetchPendingInvitees(id);
      pending.addAll(userIds);
    } catch (_) {}

    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet();
    pending.removeWhere(members.contains);
    return pending;
  }

  static Set<String> collectPendingInviteeUserIds({
    required List<V2TimGroupApplication> applications,
    required String groupId,
  }) {
    return _collectInviteeUserIds(
      applications: applications,
      groupId: groupId,
      pendingOnly: true,
    );
  }

  static Set<String> collectHandledInviteeUserIds({
    required List<V2TimGroupApplication> applications,
    required String groupId,
  }) {
    return _collectInviteeUserIds(
      applications: applications,
      groupId: groupId,
      pendingOnly: false,
    );
  }

  static Set<String> _collectInviteeUserIds({
    required List<V2TimGroupApplication> applications,
    required String groupId,
    required bool pendingOnly,
  }) {
    final targetGroup = ChatIdFormat.normalizeGroupId(groupId);
    final result = <String>{};
    for (final application in applications) {
      final isPending = groupJoinApplicationIsPending(application);
      if (pendingOnly ? !isPending : isPending) {
        continue;
      }
      final appGroup = ChatIdFormat.normalizeGroupId(application.groupID);
      if (appGroup.isEmpty ||
          (appGroup != targetGroup && application.groupID.trim() != groupId)) {
        continue;
      }
      final invitee = groupJoinApplicationIsInviteType(application)
          ? (application.toUser?.trim().isNotEmpty == true
              ? application.toUser!
              : (application.fromUser ?? ''))
          : (application.fromUser ?? '');
      final uid = ChatIdFormat.rawUserUid(invitee);
      if (uid.isNotEmpty) {
        result.add(uid);
      }
    }
    return result;
  }
}
