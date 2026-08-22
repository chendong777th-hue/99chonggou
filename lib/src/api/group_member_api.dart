import 'dart:async';

import 'package:tencent_cloud_chat_demo/src/api/group_join_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_join_application_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_change_event_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_tip_custom_sender.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/group_create_limit_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_operation_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_operation_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';

void _groupInviteDiag(String message) {
  // ignore: avoid_print
  print('[GroupInviteDiag] $message');
}

class GroupMemberApi {
  GroupMemberApi._();

  static final GroupMemberApi instance = GroupMemberApi._();

  Future<V2TimValueCallback<List<V2TimGroupMemberOperationResult>>> inviteMembers({
    required String groupId,
    required List<String> userIds,
    String? message,
  }) async {
    final id = groupId.trim();
    final normalized = userIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    _groupInviteDiag(
      'GroupMemberApi.inviteMembers groupId="$id" '
      'rawUserIds=$userIds normalized=$normalized',
    );
    if (id.isEmpty || normalized.isEmpty) {
      return V2TimValueCallback(
        code: -1,
        desc: 'INVALID_INPUT',
        data: const <V2TimGroupMemberOperationResult>[],
      );
    }

    final response = await GroupJoinApi.instance.inviteMembers(
      groupId: id,
      userIds: normalized,
      message: message,
    );
    final results = response.results
        .map(_toOperationResult)
        .toList(growable: false);
    final failed = results.where((item) => (item.result ?? 0) == 0).length;

    _notifyMembersAddedIfNeeded(id, response);
    _healAlreadyMembersLocallyIfNeeded(id, response);

    if (failed > 0 && failed < results.length) {
      _groupInviteDiag(
        'callback PARTIAL_SUCCESS failed=$failed/'
        '${results.length} imResults=${results.map((e) => '${e.memberID}:${e.result}').join(',')}',
      );
      if (response.results.any(
        (item) => item.status == GroupInviteMemberStatus.pending,
      )) {
        unawaited(
          GroupJoinApplicationService.instance.refresh(
            force: true,
            syncMembership: false,
          ),
        );
      }
      return V2TimValueCallback(
        code: 0,
        desc: 'PARTIAL_SUCCESS',
        data: results,
      );
    }
    if (failed == results.length && results.isNotEmpty) {
      final firstCode = response.results
          .firstWhere(
            (item) => item.status == GroupInviteMemberStatus.failed,
            orElse: () => response.results.first,
          )
          .code;
      final quota = response.quotaError;
      final quotaMessage = quota == null
          ? null
          : GroupCreateLimitMessage.fromQuotaError(quota);
      final desc = quotaMessage ??
          firstCode ??
          response.topLevelCode ??
          'INVITE_FAILED';
      _groupInviteDiag('callback FAIL code=-1 desc=$desc');
      return V2TimValueCallback(
        code: -1,
        desc: desc,
        data: results,
      );
    }

    final hasPending = response.results.any(
      (item) => item.status == GroupInviteMemberStatus.pending,
    );
    final alreadyOnly = response.results.isNotEmpty &&
        response.results.every(
          (item) => item.status == GroupInviteMemberStatus.alreadyMember,
        );
    final hasAlready = response.results.any(
      (item) => item.status == GroupInviteMemberStatus.alreadyMember,
    );
    final hasAdded = response.results.any(
      (item) => item.status == GroupInviteMemberStatus.added,
    );
    final String desc;
    if (hasPending) {
      desc = 'PENDING_APPROVAL';
      unawaited(
        GroupJoinApplicationService.instance.refresh(
          force: true,
          syncMembership: false,
        ),
      );
    } else if (alreadyOnly) {
      desc = 'ALREADY_MEMBER';
    } else if (hasAlready && hasAdded) {
      desc = 'ALREADY_MEMBER_PARTIAL';
    } else {
      desc = 'ok';
    }
    _groupInviteDiag(
      'callback OK code=0 desc=$desc '
      'imResults=${results.map((e) => '${e.memberID}:${e.result}').join(',')}',
    );
    return V2TimValueCallback(
      code: 0,
      desc: desc,
      data: results,
    );
  }

  void _notifyMembersAddedIfNeeded(
    String groupId,
    GroupInviteResponse response,
  ) {
    final addedUserIds = response.results
        .where((item) => item.status == GroupInviteMemberStatus.added)
        .map((item) => item.userId)
        .where((userId) => userId.trim().isNotEmpty)
        .toList(growable: false);
    if (addedUserIds.isEmpty) {
      _groupInviteDiag(
        'notifyAdded SKIP (no status=added) '
        'statuses=${response.results.map((e) => '${e.userId}:${e.status.name}').join(',')}',
      );
      return;
    }
    _groupInviteDiag(
      'notifyAdded APPLY+TIP groupId=$groupId addedUserIds=$addedUserIds',
    );
    unawaited(
      GroupMembershipSyncService.instance.applyMembersAddedLocally(
        groupId: groupId,
        addedUserIds: addedUserIds,
      ),
    );
    unawaited(() async {
      final ok = await GroupTipCustomSender.instance.send(
        groupId: groupId,
        action: 'member_added',
        memberUserIds: addedUserIds,
      );
      _groupInviteDiag(
        'tip member_added result=$ok groupId=$groupId members=$addedUserIds',
      );
    }());
    // 热路径不 await 重快照 / syncForGroup；短延迟合并 TCP 与本地，靠 cooldown 去重。
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        await GroupChangeEventSyncService.instance.syncForGroup(
          groupId,
          reason: 'invite_members',
        );
      }),
    );
  }

  /// 服务端判定已在群：补本地成员壳，避免「提示成功但列表没有」。不发 tip。
  void _healAlreadyMembersLocallyIfNeeded(
    String groupId,
    GroupInviteResponse response,
  ) {
    final alreadyUserIds = response.results
        .where((item) => item.status == GroupInviteMemberStatus.alreadyMember)
        .map((item) => item.userId)
        .where((userId) => userId.trim().isNotEmpty)
        .toList(growable: false);
    if (alreadyUserIds.isEmpty) {
      return;
    }
    _groupInviteDiag(
      'healAlready APPLY groupId=$groupId userIds=$alreadyUserIds',
    );
    unawaited(
      GroupMembershipSyncService.instance.applyMembersAddedLocally(
        groupId: groupId,
        addedUserIds: alreadyUserIds,
      ),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 500), () async {
        await GroupChangeEventSyncService.instance.syncForGroup(
          groupId,
          reason: 'heal_already_member',
        );
      }),
    );
  }

  V2TimGroupMemberOperationResult _toOperationResult(
    GroupInviteMemberResult item,
  ) {
    final result = switch (item.status) {
      GroupInviteMemberStatus.added => 1,
      GroupInviteMemberStatus.alreadyMember => 2,
      GroupInviteMemberStatus.pending => 3,
      GroupInviteMemberStatus.failed => 0,
    };
    return V2TimGroupMemberOperationResult(
      memberID: item.userId,
      result: item.imResult ?? result,
    );
  }
}
