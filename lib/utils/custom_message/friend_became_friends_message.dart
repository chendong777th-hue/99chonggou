import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_external_message_sender.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

const String kFriendBecameFriendsBusinessID = 'friend_became_friends';

final Set<String> _inboundApplyingPeers = <String>{};

String _friendBecameFriendsText() => AppI18n.current.t(
      zhHans: '你们已成为好友，现在可以开始聊天了',
      zhHant: '你們已成為好友，現在可以開始聊天了',
      en: 'You are now friends. Start chatting!',
      ja: '友達になりました。チャットを始めましょう！',
      ko: '친구가 되었습니다. 채팅을 시작해 보세요!',
    );

String getFriendBecameFriendsDisplayText(V2TimCustomElem? customElem) {
  if (customElem == null) {
    return '';
  }
  try {
    final raw = customElem.data;
    if (raw == null || raw.isEmpty) {
      return '';
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['businessID'] != kFriendBecameFriendsBusinessID) {
      return '';
    }
    final text = map['text'] as String?;
    if (text != null && text.trim().isNotEmpty) {
      return text.trim();
    }
    return _friendBecameFriendsText();
  } catch (_) {
    return '';
  }
}

bool isFriendRelationshipCustomMessage(V2TimMessage message) {
  return getFriendBecameFriendsDisplayText(message.customElem).isNotEmpty;
}

/// 对端发来的「已成为好友」tip → 乐观写入通讯录（与 HTTP/TCP 收口同一路径）。
Future<void> applyInboundFriendBecameFriendsIfNeeded(
  V2TimMessage message,
) async {
  if (!isFriendRelationshipCustomMessage(message)) {
    return;
  }
  if (message.isSelf == true) {
    return;
  }
  if ((message.groupID ?? '').trim().isNotEmpty) {
    return;
  }
  final peer = ChatIdFormat.rawUserUid(
    (message.sender ?? message.userID ?? '').trim(),
  );
  if (peer.isEmpty || !_inboundApplyingPeers.add(peer)) {
    return;
  }
  try {
    await FriendSyncService.instance.onBecameFriends(
      peerUserId: peer,
      nickname: message.nickName,
      avatarUrl: message.faceUrl,
      reason: 'friend_became_friends',
    );
  } finally {
    _inboundApplyingPeers.remove(peer);
  }
}

/// 发送「已成为好友」tip 前的 peer 规范化：裸 UID，去掉误带的 `c2c_`。
@visibleForTesting
String normalizeFriendBecameFriendsPeerId(String peerUserId) {
  var peer = peerUserId.trim();
  if (peer.startsWith('@')) {
    peer = peer.substring(1).trim();
  }
  final lower = peer.toLowerCase();
  if (lower.startsWith('c2c_')) {
    peer = peer.substring(4).trim();
  }
  return ChatIdFormat.rawUserUid(peer);
}

class FriendBecameFriendsNotifier {
  static final Set<String> _sendingPeers = <String>{};

  static Future<void> notifyIfBecameFriends({required String peerUserId}) async {
    final peer = normalizeFriendBecameFriendsPeerId(peerUserId);
    if (peer.isEmpty || !_sendingPeers.add(peer)) return;

    try {
      final payload = jsonEncode({
        'businessID': kFriendBecameFriendsBusinessID,
        'version': 1,
        'text': _friendBecameFriendsText(),
      });
      final sdk = TIMUIKitCore.getSDKInstance();
      var sentOk = false;
      for (var i = 0; i < 2 && !sentOk; i++) {
        final created = await sdk.getMessageManager().createCustomMessage(
              data: payload,
            );
        final messageID = created.data?.id;
        if (created.code != 0 || messageID == null || messageID.isEmpty) {
          if (i == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          }
          continue;
        }
        sentOk = await ChatExternalMessageSender.sendCreatedMessage(
          messageInfo: created.data?.messageInfo,
          receiverUserId: peer,
          groupId: '',
          reason: 'friend_became_friends_sent',
        );
        if (!sentOk && i == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    } finally {
      _sendingPeers.remove(peer);
    }
  }
}
