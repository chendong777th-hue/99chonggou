import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/models/group_join_option.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_public_display_name.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:uuid/uuid.dart';

/// REST 成功后由操作端 App 发群 Custom 灰字（`businessID=group_tip`）。
class GroupTipCustomSender {
  GroupTipCustomSender._();

  static final GroupTipCustomSender instance = GroupTipCustomSender._();

  static const _uuid = Uuid();
  final Set<String> _inflight = <String>{};

  /// join-options 保存成功后，按字段 diff 发 tip（通常 1 条）。
  Future<void> sendJoinOptionsDiff({
    required String groupId,
    required GroupJoinOptions before,
    required GroupJoinOptions after,
  }) async {
    final specs = groupJoinOptionsTipDiffs(before, after);
    for (final spec in specs) {
      await send(
        groupId: groupId,
        action: spec.action,
        detail: spec.detail,
      );
    }
  }

  Future<bool> sendPrivacyChanged({
    required String groupId,
    required bool enabled,
  }) {
    return send(
      groupId: groupId,
      action: enabled ? 'group_privacy_enabled' : 'group_privacy_disabled',
      detail: <String, dynamic>{
        'privacyProtectionEnabled': enabled,
      },
    );
  }

  Future<bool> send({
    required String groupId,
    required String action,
    List<String> memberUserIds = const <String>[],
    Map<String, dynamic>? detail,
    String? clientMsgId,
    /// 邀请审核通过等场景：灰字操作人应是原邀请人，而不是当前审核人。
    String? opUserId,
    String? opUserName,
  }) async {
    if (!SelfHostedGroupBridge.enabled) {
      // ignore: avoid_print
      print('[GroupInviteDiag] tip skip: SelfHostedGroupBridge disabled');
      return false;
    }
    final id = ChatIdFormat.canonicalGroupStorageId(groupId);
    final normalizedAction = action.trim().toLowerCase();
    if (id.isEmpty || !kGroupTipActions.contains(normalizedAction)) {
      // ignore: avoid_print
      print(
        '[GroupInviteDiag] tip skip: invalid groupId/action '
        'groupId="$groupId" action="$action"',
      );
      return false;
    }
    final resolvedOpUserId = ChatIdFormat.rawUserUid(
      (opUserId != null && opUserId.trim().isNotEmpty)
          ? opUserId
          : ContactSocialCacheStore.safeLoginUserId(),
    );
    if (resolvedOpUserId.isEmpty) {
      // ignore: avoid_print
      print('[GroupInviteDiag] tip skip: empty opUserId');
      return false;
    }

    final members = memberUserIds
        .map(ChatIdFormat.rawUserUid)
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final msgId = (clientMsgId != null && clientMsgId.trim().isNotEmpty)
        ? clientMsgId.trim()
        : _uuid.v4();
    final dedupeKey = '$id|$normalizedAction|$msgId';
    if (!_inflight.add(dedupeKey)) {
      return false;
    }

    try {
      final hintName = opUserName?.trim() ?? '';
      final opName = hintName.isNotEmpty
          ? hintName
          : await _displayName(groupId: id, userId: resolvedOpUserId);
      final memberNames = await _resolveMemberNamesParallel(
        groupId: id,
        memberUserIds: members,
      );
      final payload = buildGroupTipPayload(
        action: normalizedAction,
        opUserId: resolvedOpUserId,
        opUserName: opName,
        clientMsgId: msgId,
        memberUserIds: members,
        memberNames: memberNames,
        detail: detail,
      );
      final data = jsonEncode(payload);
      final sdk = TIMUIKitCore.getSDKInstance();
      var sentOk = false;
      for (var attempt = 0; attempt < 2 && !sentOk; attempt++) {
        final created =
            await sdk.getMessageManager().createCustomMessage(data: data);
        if (created.code != 0 || created.data?.messageInfo == null) {
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          }
          continue;
        }
        sentOk = await ChatExternalMessageSender.sendCreatedMessage(
          messageInfo: created.data!.messageInfo,
          receiverUserId: '',
          groupId: id,
          reason: 'group_tip_$normalizedAction',
          isExcludedFromUnreadCount: true,
        );
        if (!sentOk && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      if (!sentOk) {
        // ignore: avoid_print
        print(
          '[GroupInviteDiag] GroupTipCustomSender FAILED '
          'groupId=$id action=$normalizedAction members=$members',
        );
        debugPrint(
          'GroupTipCustomSender send failed groupId=$id action=$normalizedAction',
        );
      } else {
        // ignore: avoid_print
        print(
          '[GroupInviteDiag] GroupTipCustomSender OK '
          'groupId=$id action=$normalizedAction members=$members',
        );
      }
      return sentOk;
    } catch (e) {
      // ignore: avoid_print
      print('[GroupInviteDiag] GroupTipCustomSender error: $e');
      debugPrint('GroupTipCustomSender error: $e');
      return false;
    } finally {
      _inflight.remove(dedupeKey);
    }
  }

  Future<String> _displayName({
    required String groupId,
    required String userId,
  }) {
    return GroupTipPublicDisplayName.resolve(
      groupId: groupId,
      userId: userId,
    );
  }

  /// 有限并行解析成员公开名，避免邀请多人时串行拖长 tip。
  Future<List<String>> _resolveMemberNamesParallel({
    required String groupId,
    required List<String> memberUserIds,
    int concurrency = 8,
  }) async {
    if (memberUserIds.isEmpty) {
      return const <String>[];
    }
    final names = List<String>.filled(memberUserIds.length, '');
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next;
        next++;
        if (index >= memberUserIds.length) {
          return;
        }
        names[index] = await _displayName(
          groupId: groupId,
          userId: memberUserIds[index],
        );
      }
    }

    final workers = List<Future<void>>.generate(
      memberUserIds.length < concurrency ? memberUserIds.length : concurrency,
      (_) => worker(),
    );
    await Future.wait(workers);
    return names;
  }
}
