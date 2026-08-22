import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_models.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_record.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_result_repository.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_preview_text_cache.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/calling_message/calling_message_data_provider.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/contact_card_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/friend_became_friends_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/group_live_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/link_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/platform_wallet_notice_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/web_link_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 未识别 CUSTOM 的列表预览兜底（与 [TIM_t] 源文案对齐，供禁降级判定）。
const String kBusinessMessageFallbackPreview = '[业务消息]';

bool isBusinessMessageFallbackPreview(String? text) {
  final trimmed = text?.trim() ?? '';
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed == kBusinessMessageFallbackPreview) {
    return true;
  }
  // TIM_t 可能返回翻译后文案；源 key 仍参与判定。
  try {
    if (trimmed == TIM_t(kBusinessMessageFallbackPreview)) {
      return true;
    }
  } catch (_) {}
  return false;
}

String? _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

Map<String, dynamic>? _decodeMap(String raw) {
  if (raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}

bool _isSameUser(String a, String b) {
  return a.trim().isNotEmpty && a.trim() == b.trim();
}

String _currentUserId() {
  try {
    return TIMUIKitCore.getInstance().loginInfo.userID.trim();
  } catch (_) {
    return '';
  }
}

bool _isTransferOutgoing(V2TimMessage message, Map<String, dynamic> data) {
  final currentUserId = _currentUserId();
  final senderId = _readString(data, [
        'senderId',
        'fromUserId',
        'payerId',
        'operatorId',
      ]) ??
      message.sender?.trim() ??
      '';
  final receiverId = _readString(data, [
        'receiverId',
        'toUserId',
        'receiveUserId',
        'payeeId',
      ]) ??
      '';

  if (currentUserId.isNotEmpty) {
    if (_isSameUser(receiverId, currentUserId)) return false;
    if (_isSameUser(senderId, currentUserId)) return true;
  }
  return message.isSelf ?? false;
}

String _walletTransferPreview(V2TimMessage message, Map<String, dynamic> data) {
  final memo = _readString(data, ['memo', 'greeting', 'msg']);
  if (memo != null && memo.trim().isNotEmpty) {
    return TIM_t_para('[转账] {{option1}}', '[转账] $memo')(option1: memo);
  }
  final outgoing = _isTransferOutgoing(message, data);
  if (!outgoing) {
    return TIM_t('[转账] 转账给你');
  }
  final receiverName = _readString(data, [
    'receiverName',
    'toUserName',
    'receiveUserName',
    'receiverNickname',
    'toNickname',
    'toNickName',
  ]);
  final receiverId = _readString(data, [
    'receiverId',
    'toUserId',
    'receiveUserId',
  ]);
  final name = receiverName ?? receiverId;
  if (name != null && name.trim().isNotEmpty) {
    return TIM_t_para('[转账] 转账给 {{option1}}', '[转账] 转账给 $name')(
      option1: name,
    );
  }
  return TIM_t('[转账] 转账给对方');
}

String _walletGroupTransferPreview(Map<String, dynamic> data) {
  final memo = _readString(data, ['memo', 'greeting', 'msg']);
  if (memo != null && memo.trim().isNotEmpty) {
    return TIM_t_para('[群转账] {{option1}}', '[群转账] $memo')(option1: memo);
  }
  final receiverName = _readString(data, [
    'receiverName',
    'toUserName',
    'receiveUserName',
  ]);
  final receiverId = _readString(data, [
    'receiverId',
    'toUserId',
    'receiveUserId',
  ]);
  final name = receiverName ?? receiverId;
  if (name != null && name.trim().isNotEmpty) {
    return TIM_t_para('[群转账] 转账给 {{option1}}', '[群转账] 转账给 $name')(
      option1: name,
    );
  }
  return TIM_t('[群转账]');
}

String _walletRedPacketPreview(
  V2TimMessage message,
  Map<String, dynamic> data,
) {
  final greeting = _readString(data, ['greeting', 'msg']) ?? '恭喜发财，大吉大利';
  final packetType = data['packetType']?.toString().trim() ?? '';
  final typeLabel = packetType.isNotEmpty
      ? redPacketTypeLabel(packetType)
      : ((message.groupID?.trim().isNotEmpty ?? false)
          ? redPacketTypeLabel(null)
          : redPacketTypeLabel('NORMAL_C2C'));
  return '[$typeLabel] $greeting';
}

String? _callConversationPreviewLabel(V2TimMessage message) {
  if (!CallingMessageDataProvider.looksLikeCallMessage(message)) {
    return null;
  }
  try {
    final provider = CallingMessageDataProvider(message);
    // Prefer terminal result cached for this callId — conversation lastMessage
    // is often still the lk_call invite mid-state after the call ended.
    final callId = provider.inviteID.trim();
    if (callId.isNotEmpty) {
      final record = CallResultRepository.instance.get(callId);
      if (record != null &&
          record.protocolType != CallProtocolType.unknown) {
        final fromRecord = _previewFromCallResult(record, provider);
        if (fromRecord.isNotEmpty) {
          return fromRecord;
        }
      }
    }
    final content = provider.content.trim();
    if (content.isNotEmpty &&
        content != '未知通话' &&
        !content.contains('未知通话')) {
      // Mid-state invite/accept as lastMessage: show media tag, not "发起通话".
      if (!provider.shouldDisplayInHistory &&
          (provider.protocolType == CallProtocolType.send ||
              provider.protocolType == CallProtocolType.accept)) {
        return provider.streamMediaType == CallStreamMediaType.video
            ? '[视频通话]'
            : '[语音通话]';
      }
      return content;
    }
  } catch (_) {}
  return CallingMessageDataProvider.fallbackText();
}

String _previewFromCallResult(
  CallResultRecord record,
  CallingMessageDataProvider provider,
) {
  final i18n = AppI18n.current;
  switch (record.protocolType) {
    case CallProtocolType.hangup:
      final sec = record.durationSec < 0 ? 0 : record.durationSec;
      final mm = (sec ~/ 60).toString().padLeft(2, '0');
      final ss = (sec % 60).toString().padLeft(2, '0');
      return '${i18n.t(zhHans: '通话时长', zhHant: '通話時長', en: 'Call duration', ja: '通話時間', ko: '통화 시간')}：$mm:$ss';
    case CallProtocolType.cancel:
      final cancelledByMe = record.isOutgoing == true;
      return cancelledByMe
          ? i18n.t(zhHans: '已取消', zhHant: '已取消', en: 'Cancelled', ja: 'キャンセルしました', ko: '취소함')
          : i18n.t(zhHans: '对方已取消', zhHant: '對方已取消', en: 'Cancelled by other party', ja: '相手がキャンセルしました', ko: '상대방이 취소했습니다');
    case CallProtocolType.reject:
      final rejectedByMe = record.isOutgoing == false;
      return rejectedByMe
          ? i18n.t(zhHans: '已拒绝', zhHant: '已拒絕', en: 'Declined', ja: '拒否しました', ko: '거절함')
          : i18n.t(zhHans: '对方已拒绝', zhHant: '對方已拒絕', en: 'Declined by other party', ja: '相手が拒否しました', ko: '상대방이 거절했습니다');
    case CallProtocolType.timeout:
    case CallProtocolType.lineBusy:
      final isCaller = record.isOutgoing == true;
      if (record.protocolType == CallProtocolType.lineBusy) {
        return isCaller
            ? i18n.t(zhHans: '对方忙线中', zhHant: '對方忙線中', en: 'Line busy', ja: '話し中', ko: '통화 중')
            : i18n.t(zhHans: '忙线未接', zhHant: '忙線未接', en: 'Line busy, missed', ja: '話し中で不在', ko: '통화 중 부재');
      }
      return isCaller
          ? i18n.t(zhHans: '对方无应答', zhHant: '對方無應答', en: 'No answer', ja: '応答なし', ko: '응답 없음')
          : i18n.t(zhHans: '未接听', zhHant: '未接聽', en: 'Missed call', ja: '不在着信', ko: '부재중 전화');
    default:
      return record.mediaType == 'video' ? '[视频通话]' : '[语音通话]';
  }
}

String? _customConversationPreviewLabel(V2TimMessage message) {
  final raw = message.customElem?.data;
  if (raw == null || raw.trim().isEmpty) return null;
  final data = _decodeMap(raw);
  if (data == null) {
    if (raw == 'group_create') return TIM_t('群聊创建成功！');
    final lower = raw.toLowerCase();
    if (lower.contains('av_call') ||
        lower.contains('rtc_call') ||
        lower.contains('lk_call')) {
      return _callConversationPreviewLabel(message) ?? TIM_t('[通话]');
    }
    return null;
  }

  final customType = data['customType']?.toString() ?? '';
  final legacyType = data['type']?.toString() ?? '';
  final businessID = data['businessID']?.toString() ?? '';
  final type = customType.isNotEmpty ? customType : legacyType;
  final normalized = '$businessID|$type'.toLowerCase();

  if (businessID == kFriendBecameFriendsBusinessID) {
    return _readString(data, ['text', 'content', 'desc']) ??
        TIM_t('你们已成为好友，现在可以开始聊天了');
  }

  if (businessID == kRedPacketClaimNoticeBusinessID) {
    return redPacketClaimNoticeDisplayText(data);
  }

  if (type == 'wallet_red_packet' ||
      (businessID == 'wallet_order' && legacyType == 'wallet_red_packet')) {
    return _walletRedPacketPreview(message, data);
  }
  if (type == 'wallet_group_transfer' ||
      (businessID == 'wallet_order' && legacyType == 'wallet_group_transfer')) {
    return _walletGroupTransferPreview(data);
  }
  if (type == 'wallet_transfer' ||
      (businessID == 'wallet_order' && legacyType == 'wallet_transfer')) {
    return _walletTransferPreview(message, data);
  }

  if (GroupLiveMessageIds.allCardIds.contains(businessID)) {
    final roomName = _readString(data, ['roomName']);
    if (businessID == GroupLiveMessageIds.started) {
      return roomName == null
          ? TIM_t('[群直播] 直播中')
          : TIM_t_para('[群直播] {{option1}}', '[群直播] $roomName')(option1: roomName);
    }
    if (businessID == GroupLiveMessageIds.ended) {
      return roomName == null
          ? TIM_t('[群直播] 已结束')
          : TIM_t_para('[群直播] {{option1}}', '[群直播] $roomName')(option1: roomName);
    }
    return roomName == null
        ? TIM_t('[群直播]')
        : TIM_t_para('[群直播] {{option1}}', '[群直播] $roomName')(option1: roomName);
  }

  if (businessID == kContactCardBusinessID || type == kContactCardBusinessID) {
    final name =
        _readString(data, ['nickName', 'nickname', 'name', 'userID', 'userId']);
    return name == null
        ? TIM_t('[个人名片]')
        : TIM_t_para('[个人名片] {{option1}}', '[个人名片] $name')(option1: name);
  }

  if (businessID == 'group_create' || type == 'group_create') {
    final detailed = MessageUtils.getCustomGroupCreatedOrDismissedString(message);
    if (detailed.isNotEmpty) {
      return detailed;
    }
    return TIM_t('群聊创建成功！');
  }

  if (businessID == kGroupTipBusinessID || type == kGroupTipBusinessID) {
    final tip = parseGroupTipPayload(message.customElem);
    if (tip != null) {
      return groupTipDisplayText(tip);
    }
  }

  if (businessID == kPlatformWalletNoticeCustomType ||
      type == kPlatformWalletNoticeCustomType ||
      businessID == 'platform_notice' ||
      normalized.contains('notice')) {
    return platformWalletNoticeConversationPreview(message) ??
        _readString(
            data, ['title', 'summary', 'content', 'text', 'body', 'desc']) ??
        TIM_t('[系统通知]');
  }

  if (normalized.contains('official') || normalized.contains('article')) {
    return _readString(data, ['title', 'summary', 'description']) ??
        TIM_t('[图文]');
  }

  if (normalized.contains('revoke') || normalized.contains('recall')) {
    return TIM_t('对方撤回了一条消息');
  }

  if (normalized.contains('av_call') ||
      normalized.contains('rtc_call') ||
      normalized.contains('lk_call') ||
      normalized.contains('call')) {
    return _callConversationPreviewLabel(message) ?? TIM_t('[通话]');
  }

  return _readString(
      data, ['title', 'summary', 'content', 'text', 'body', 'desc']);
}

String buildConversationLastCustomMessagePreview(V2TimMessage message) {
  final noticePreview = platformWalletNoticeConversationPreview(message);
  if (noticePreview != null) {
    return noticePreview;
  }

  final customLabel = _customConversationPreviewLabel(message);
  if (customLabel != null && customLabel.trim().isNotEmpty) {
    return customLabel;
  }

  final linkMessage = getLinkMessage(message.customElem);
  if (linkMessage != null) {
    final text = linkMessage.text?.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    final link = linkMessage.link?.trim() ?? '';
    if (link.isNotEmpty) {
      return TIM_t('[链接]');
    }
  }

  final webLinkMessage = getWebLinkMessage(message.customElem);
  if (webLinkMessage != null) {
    final title = webLinkMessage.title?.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    final description = webLinkMessage.description?.trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }
    return TIM_t('[链接]');
  }

  final contactCardMessage = getContactCardMessage(message.customElem);
  if (contactCardMessage != null) {
    final displayName = contactCardMessage.nickName.isNotEmpty
        ? contactCardMessage.nickName
        : contactCardMessage.userID;
    return TIM_t_para("[联系人] {{option1}}", "[联系人] $displayName")(
      option1: displayName,
    );
  }

  try {
    final callingMessageDataProvider = CallingMessageDataProvider(message);
    if (callingMessageDataProvider.isCallingSignal) {
      final content = callingMessageDataProvider.content.trim();
      return content.isNotEmpty
          ? content
          : CallingMessageDataProvider.fallbackText();
    }
    if (CallingMessageDataProvider.looksLikeCallMessage(message)) {
      return CallingMessageDataProvider.fallbackText();
    }
  } catch (_) {
    if (CallingMessageDataProvider.looksLikeCallMessage(message)) {
      return CallingMessageDataProvider.fallbackText();
    }
  }

  final articleMessage = parseOfficialAccountArticleFromMessage(message);
  if (articleMessage != null && articleMessage.title.isNotEmpty) {
    return articleMessage.title;
  }
  if (articleMessage != null && articleMessage.description.isNotEmpty) {
    return articleMessage.description;
  }
  if (articleMessage != null &&
      (articleMessage.imageUrl?.isNotEmpty ?? false)) {
    return TIM_t("[图文]");
  }

  final customElem = message.customElem;
  final friendTip = getFriendBecameFriendsDisplayText(customElem);
  if (friendTip.isNotEmpty) {
    return friendTip;
  }

  if (customElem?.data == "group_create") {
    return TIM_t("群聊创建成功！");
  }

  final groupTips =
      MessageUtils.getCustomGroupCreatedOrDismissedString(message);
  if (groupTips.isNotEmpty) {
    return groupTips;
  }

  return TIM_t(kBusinessMessageFallbackPreview);
}

/// 轻量 CUSTOM 预览（不含通话 Provider / TIM 核），供 lastMessage 禁降级判定。
///
/// 返回非空表示已识别为强业务摘要；返回 null 表示将落入「[业务消息]」或需重依赖解析。
String? lightCustomConversationPreview(V2TimMessage message) {
  final noticePreview = platformWalletNoticeConversationPreview(message);
  if (noticePreview != null && noticePreview.trim().isNotEmpty) {
    return noticePreview;
  }
  final customLabel = _customConversationPreviewLabel(message);
  if (customLabel != null && customLabel.trim().isNotEmpty) {
    return customLabel;
  }
  final linkMessage = getLinkMessage(message.customElem);
  if (linkMessage != null) {
    final text = linkMessage.text?.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }
    final link = linkMessage.link?.trim() ?? '';
    if (link.isNotEmpty) {
      return TIM_t('[链接]');
    }
  }
  final webLinkMessage = getWebLinkMessage(message.customElem);
  if (webLinkMessage != null) {
    final title = webLinkMessage.title?.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }
    final description = webLinkMessage.description?.trim() ?? '';
    if (description.isNotEmpty) {
      return description;
    }
    return TIM_t('[链接]');
  }
  final contactCardMessage = getContactCardMessage(message.customElem);
  if (contactCardMessage != null) {
    final displayName = contactCardMessage.nickName.isNotEmpty
        ? contactCardMessage.nickName
        : contactCardMessage.userID;
    return TIM_t_para("[联系人] {{option1}}", "[联系人] $displayName")(
      option1: displayName,
    );
  }
  if (CallingMessageDataProvider.looksLikeCallMessage(message)) {
    return CallingMessageDataProvider.fallbackText();
  }
  final articleMessage = parseOfficialAccountArticleFromMessage(message);
  if (articleMessage != null) {
    if (articleMessage.title.isNotEmpty) {
      return articleMessage.title;
    }
    if (articleMessage.description.isNotEmpty) {
      return articleMessage.description;
    }
    if (articleMessage.imageUrl?.isNotEmpty ?? false) {
      return TIM_t("[图文]");
    }
  }
  final friendTip = getFriendBecameFriendsDisplayText(message.customElem);
  if (friendTip.isNotEmpty) {
    return friendTip;
  }
  if (message.customElem?.data == "group_create") {
    return TIM_t("群聊创建成功！");
  }
  final groupTips =
      MessageUtils.getCustomGroupCreatedOrDismissedString(message);
  if (groupTips.isNotEmpty) {
    return groupTips;
  }
  return null;
}

/// 引用回复、转发摘要等场景下的自定义消息文案。
String? buildReplyAbstractMessage(V2TimMessage message) {
  if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
    return null;
  }
  return buildConversationLastCustomMessagePreview(message);
}

String? _conversationIdForPreviewCache(V2TimMessage lastMsg) {
  return MessageConversationId.fromMessage(lastMsg);
}

String conversationPreviewCacheMessageKey(V2TimMessage lastMsg) {
  const sep = '\u001f';
  return <Object?>[
    lastMsg.msgID,
    lastMsg.id,
    lastMsg.seq,
    lastMsg.timestamp,
    lastMsg.elemType,
    lastMsg.groupID,
    lastMsg.userID,
    lastMsg.sender,
    lastMsg.textElem?.text,
    lastMsg.customElem?.data,
    lastMsg.cloudCustomData,
    lastMsg.localCustomData,
    lastMsg.status,
    revokedLastMessageFingerprint(lastMsg),
    groupTipsPreviewFingerprint(lastMsg),
  ].map((item) => item?.toString() ?? '').join(sep);
}

/// SDK GroupTips 内容指纹：操作者补丁 / 改名后必须让预览缓存失效。
String groupTipsPreviewFingerprint(V2TimMessage lastMsg) {
  final tip = lastMsg.groupTipsElem;
  if (tip == null) {
    return '';
  }
  final members = (tip.memberList ?? const [])
      .map((m) => m?.userID?.trim() ?? '')
      .where((id) => id.isNotEmpty)
      .join(',');
  final changes = (tip.groupChangeInfoList ?? const [])
      .map((c) {
        if (c == null) {
          return '';
        }
        return '${c.type}:${c.value ?? ''}';
      })
      .join(',');
  return '${tip.type}|${tip.groupID}|${tip.opMember.userID}|$members|$changes|${tip.memberCount ?? ''}';
}

/// 写入 [ConversationPreviewTextCache] 的强摘要；撤回态优先于 textElem 原文。
String? strongConversationPreviewTextForCache(V2TimMessage message) {
  if (isRevokedMessage(message)) {
    return buildRevokedMessagePreviewLabel(message);
  }
  final text = message.textElem?.text?.trim() ?? '';
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_TEXT &&
      text.isNotEmpty) {
    return text;
  }
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
    final preview = buildConversationLastCustomMessagePreview(message).trim();
    if (preview.isNotEmpty && !isBusinessMessageFallbackPreview(preview)) {
      return preview;
    }
  }
  return null;
}

/// 会话列表 lastMessage 字符串摘要：CUSTOM 走业务预览，其它类型返回 null 回落默认。
String? conversationListLastMessageAbstract(
  V2TimMessage lastMsg,
  List<V2TimGroupAtInfo?> groupAtInfoList,
) {
  if (lastMsg.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM) {
    final convId = _conversationIdForPreviewCache(lastMsg);
    final messageKey = conversationPreviewCacheMessageKey(lastMsg);
    final preview = strongConversationPreviewTextForCache(lastMsg);
    if (convId != null && preview != null && preview.isNotEmpty) {
      ConversationPreviewTextCache.instance.putStrong(
        convId,
        preview,
        messageKey: messageKey,
      );
    }
    if (isRevokedMessage(lastMsg) && preview != null && preview.isNotEmpty) {
      return preview;
    }
    return null;
  }
  if (isFriendRelationshipCustomMessage(lastMsg)) {
    final preview = buildConversationLastCustomMessagePreview(lastMsg);
    final convId = _conversationIdForPreviewCache(lastMsg);
    final messageKey = conversationPreviewCacheMessageKey(lastMsg);
    if (convId != null) {
      final cachedForMessage = ConversationPreviewTextCache.instance
          .getForMessage(convId, messageKey);
      if (cachedForMessage != null && cachedForMessage.trim().isNotEmpty) {
        return cachedForMessage;
      }
      final previousPreview = ConversationPreviewTextCache.instance.get(convId);
      if (previousPreview != null &&
          previousPreview.trim().isNotEmpty &&
          previousPreview.trim() != preview.trim()) {
        return previousPreview;
      }
      if (preview.trim().isNotEmpty) {
        ConversationPreviewTextCache.instance.putStrong(
          convId,
          preview,
          messageKey: messageKey,
        );
      }
    }
    return preview;
  }
  final preview = buildConversationLastCustomMessagePreview(lastMsg);
  if (isBusinessMessageFallbackPreview(preview)) {
    final convId = _conversationIdForPreviewCache(lastMsg);
    final messageKey = conversationPreviewCacheMessageKey(lastMsg);
    final cached = convId == null
        ? null
        : ConversationPreviewTextCache.instance.getForMessage(
            convId,
            messageKey,
          ) ??
            ConversationPreviewTextCache.instance.get(convId);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    return preview;
  }
  final convId = _conversationIdForPreviewCache(lastMsg);
  final messageKey = conversationPreviewCacheMessageKey(lastMsg);
  if (convId != null && preview.trim().isNotEmpty) {
    ConversationPreviewTextCache.instance.putStrong(
      convId,
      preview,
      messageKey: messageKey,
    );
  }
  return preview;
}

class RenderCustomMessage extends StatelessWidget {
  final V2TimMessage message;
  final BuildContext context;

  const RenderCustomMessage({
    super.key,
    required this.message,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final theme =
        Provider.of<DefaultThemeData>(this.context, listen: false).theme;
    final isWideScreen =
        TUIKitScreenUtils.getFormFactor(this.context) == DeviceType.Desktop;
    final fontSize = isWideScreen ? 12.0 : 14.0;
    final senderName = (message.groupID?.trim().isNotEmpty ?? false)
        ? MessageUtils.getDisplayName(message).trim()
        : '';
    final preview = buildConversationLastCustomMessagePreview(message);
    final text = senderName.isEmpty ? preview : '$senderName: $preview';
    return Text(
      text,
      softWrap: false,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        height: 1.2,
        color: theme.weakTextColor,
        fontSize: fontSize,
      ),
    );
  }
}
