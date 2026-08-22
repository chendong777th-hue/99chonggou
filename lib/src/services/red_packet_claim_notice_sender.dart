import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// 领取成功后由领取端 App 发会话灰字（`businessID=red_packet_claim_notice`，全员可见）。
class RedPacketClaimNoticeSender {
  RedPacketClaimNoticeSender._();

  static final RedPacketClaimNoticeSender instance =
      RedPacketClaimNoticeSender._();

  final Set<String> _inflight = <String>{};

  Future<bool> sendAfterClaim({
    required String packetId,
    required String groupId,
    required String peerUserId,
    required bool showFinishedSuffix,
    String? claimerName,
    String? senderUserId,
    String? senderName,
  }) async {
    final packet = packetId.trim();
    final group = ChatIdFormat.canonicalGroupStorageId(groupId);
    final peer = ChatIdFormat.rawUserUid(peerUserId);
    if (packet.isEmpty || (group.isEmpty && peer.isEmpty)) {
      return false;
    }

    final claimerId =
        ChatIdFormat.rawUserUid(ContactSocialCacheStore.safeLoginUserId());
    if (claimerId.isEmpty) {
      return false;
    }

    final noticeId = buildRedPacketClaimNoticeId(
      packetId: packet,
      claimerUserId: claimerId,
    );
    if (!_inflight.add(noticeId)) {
      return false;
    }

    try {
      final name = (claimerName != null && claimerName.trim().isNotEmpty)
          ? claimerName.trim()
          : await _selfDisplayName(fallback: claimerId);
      final claimerDisplay = resolveRedPacketClaimPartyName(
        name: name,
        userId: claimerId,
      );
      final senderId = ChatIdFormat.rawUserUid(senderUserId);
      final senderDisplay = resolveRedPacketClaimPartyName(
        name: senderName,
        userId: senderId.isNotEmpty
            ? senderId
            : (group.isEmpty ? peer : ''),
      );
      final payload = buildRedPacketClaimNoticePayload(
        claimerUserId: claimerId,
        claimerName: claimerDisplay,
        packetId: packet,
        showFinishedSuffix: showFinishedSuffix,
        noticeId: noticeId,
        senderUserId: senderId.isNotEmpty ? senderId : null,
        senderName: senderDisplay,
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
          receiverUserId: group.isEmpty ? peer : '',
          groupId: group,
          reason: 'red_packet_claim_notice',
          isExcludedFromUnreadCount: true,
        );
        if (!sentOk && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
      if (!sentOk) {
        debugPrint(
          'RedPacketClaimNoticeSender send failed packetId=$packet '
          'group=$group peer=$peer',
        );
      }
      return sentOk;
    } catch (e) {
      debugPrint('RedPacketClaimNoticeSender error: $e');
      return false;
    } finally {
      _inflight.remove(noticeId);
    }
  }

  Future<String> _selfDisplayName({required String fallback}) async {
    try {
      final self = serviceLocator<CoreServicesImpl>().loginUserInfo;
      final nick = self?.nickName?.trim() ?? '';
      if (nick.isNotEmpty) {
        return nick;
      }
    } catch (_) {}
    return fallback;
  }
}
