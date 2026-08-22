import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/notification_display_mode.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/red_packet/red_packet_models.dart';
import 'package:tencent_cloud_chat_demo/src/utils/group_tip_custom_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_last_message.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/platform_wallet_notice_message.dart';
import 'package:tencent_cloud_chat_demo/utils/group_tips_message_helper.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_push/common/tim_push_message.dart';

class NotificationPushText {
  NotificationPushText._();

  static AppI18n get _i18n => AppI18n.current;

  static String get _appName => _i18n.t(
        zhHans: '99Chat',
        zhHant: '99Chat',
        en: '99Chat',
        ja: '99Chat',
        ko: '99Chat',
      );

  static String get _genericBody => _i18n.t(
        zhHans: '你收到了一条消息',
        zhHant: '你收到了一則訊息',
        en: 'You received a message',
        ja: 'メッセージを受信しました',
        ko: '메시지를 받았습니다',
      );

  static ({String title, String body}) format({
    required NotificationDisplayMode mode,
    String? senderName,
    String? conversationLabel,
    String? messageSummary,
    String? pushTitle,
    String? pushDesc,
  }) {
    if (mode == NotificationDisplayMode.anonymous) {
      return (
        title: _appName,
        body: _genericBody,
      );
    }
    if (mode == NotificationDisplayMode.hidden) {
      return (
        title: _appName,
        body: '',
      );
    }

    final title = _firstNonEmpty([
      conversationLabel,
      senderName,
      pushTitle,
      _appName,
    ]);
    final body = _firstNonEmpty([
      messageSummary,
      pushDesc,
      _genericBody,
    ]);
    return (title: title, body: body);
  }

  static ({String title, String body}) fromMessage(
    V2TimMessage message, {
    required NotificationDisplayMode mode,
    String? conversationLabel,
  }) {
    return format(
      mode: mode,
      senderName: message.nickName ?? message.sender,
      conversationLabel: conversationLabel,
      messageSummary: summarizeMessage(message),
    );
  }

  static ({String title, String body}) fromPush(
    TimPushMessage message, {
    required NotificationDisplayMode mode,
  }) {
    return format(
      mode: mode,
      pushTitle: message.title,
      pushDesc: message.desc,
      messageSummary: _pushMessageSummary(message),
    );
  }

  static String? _pushMessageSummary(TimPushMessage message) {
    final desc = message.desc?.trim();
    final ext = message.ext?.trim();
    for (final raw in <String?>[ext, desc]) {
      final summary = _customMessageSummary(raw ?? '');
      if (summary.isNotEmpty) {
        return summary;
      }
    }
    if (desc == null || desc.isEmpty) {
      return null;
    }
    final lower = desc.toLowerCase();
    if (lower == 'custom message' || desc == '自定义消息') {
      return _serviceMessageLabel();
    }
    return desc;
  }

  static String summarizeMessage(V2TimMessage message) {
    final groupRelated = GroupTipsMessageHelper.messagePreviewAbstract(message);
    if (groupRelated != null && groupRelated.trim().isNotEmpty) {
      return groupRelated.trim();
    }
    if (GroupTipsMessageHelper.isPendingAdministratorMemberTip(message) ||
        GroupTipsMessageHelper.isSuppressedAdministratorTip(message)) {
      return '';
    }

    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        return message.textElem?.text?.trim().isNotEmpty == true
            ? message.textElem!.text!.trim()
            : _textMessageLabel();
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return _bracketLabel(
          zhHans: '图片',
          zhHant: '圖片',
          en: 'Image',
          ja: '画像',
          ko: '이미지',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        return _bracketLabel(
          zhHans: '语音',
          zhHant: '語音',
          en: 'Voice',
          ja: '音声',
          ko: '음성',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return _bracketLabel(
          zhHans: '视频',
          zhHant: '影片',
          en: 'Video',
          ja: '動画',
          ko: '동영상',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        return _fileMessageSummary(message);
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return _bracketLabel(
          zhHans: '表情',
          zhHant: '表情',
          en: 'Sticker',
          ja: 'スタンプ',
          ko: '스티커',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        return _bracketLabel(
          zhHans: '位置',
          zhHant: '位置',
          en: 'Location',
          ja: '位置',
          ko: '위치',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_MERGER:
        return _bracketLabel(
          zhHans: '聊天记录',
          zhHant: '聊天記錄',
          en: 'Chat history',
          ja: 'チャット履歴',
          ko: '채팅 기록',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        return buildConversationLastCustomMessagePreview(message);
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS:
        if (GroupTipsMessageHelper.isImAdministratorMemberTip(message)) {
          return '';
        }
        return _bracketLabel(
          zhHans: '群提示',
          zhHant: '群提示',
          en: 'Group notice',
          ja: 'グループ通知',
          ko: '그룹 알림',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT:
        return _bracketLabel(
          zhHans: '群系统通知',
          zhHant: '群系統通知',
          en: 'Group system notice',
          ja: 'グループシステム通知',
          ko: '그룹 시스템 알림',
        );
      case MessageElemType.V2TIM_ELEM_TYPE_STREAM:
        return _streamMessageSummary(message);
      case MessageElemType.V2TIM_ELEM_TYPE_NONE:
      default:
        return _newMessageLabel();
    }
  }

  static String _fileMessageSummary(V2TimMessage message) {
    final fileName = message.fileElem?.fileName?.trim() ?? '';
    if (fileName.isNotEmpty) {
      final tag = _bracketLabel(
        zhHans: '文件',
        zhHant: '檔案',
        en: 'File',
        ja: 'ファイル',
        ko: '파일',
      );
      return '$tag $fileName';
    }
    return _i18n.t(
      zhHans: '文件消息',
      zhHant: '檔案訊息',
      en: 'File message',
      ja: 'ファイルメッセージ',
      ko: '파일 메시지',
    );
  }

  static String _streamMessageSummary(V2TimMessage message) {
    final markdown = message.streamElem?.markdown?.trim() ?? '';
    if (markdown.isNotEmpty) {
      return markdown;
    }
    final data = message.streamElem?.data?.trim() ?? '';
    if (data.isNotEmpty) {
      return data;
    }
    return _bracketLabel(
      zhHans: '流式消息',
      zhHant: '流式訊息',
      en: 'Streaming message',
      ja: 'ストリーミングメッセージ',
      ko: '스트리밍 메시지',
    );
  }

  static String _bracketLabel({
    required String zhHans,
    required String zhHant,
    required String en,
    required String ja,
    required String ko,
  }) {
    final label = _i18n.t(
      zhHans: zhHans,
      zhHant: zhHant,
      en: en,
      ja: ja,
      ko: ko,
    );
    return '[$label]';
  }

  static String _textMessageLabel() => _i18n.t(
        zhHans: '文本消息',
        zhHant: '文字訊息',
        en: 'Text message',
        ja: 'テキストメッセージ',
        ko: '텍스트 메시지',
      );

  static String _newMessageLabel() => _i18n.t(
        zhHans: '新消息',
        zhHant: '新訊息',
        en: 'New message',
        ja: '新しいメッセージ',
        ko: '새 메시지',
      );

  static String _serviceMessageLabel() => _i18n.t(
        zhHans: '业务消息',
        zhHant: '業務訊息',
        en: 'Service message',
        ja: 'サービスメッセージ',
        ko: '서비스 메시지',
      );

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }

  static String _customMessageSummary(String raw) {
    if (raw.trim().isEmpty) {
      return '';
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        final lower = raw.toLowerCase();
        if (lower.contains('av_call') || lower.contains('rtc_call')) {
          return _bracketLabel(
            zhHans: '通话',
            zhHant: '通話',
            en: 'Call',
            ja: '通話',
            ko: '통화',
          );
        }
        return '';
      }
      final data = Map<String, dynamic>.from(decoded);
      final businessID = data['businessID']?.toString() ?? '';
      if (businessID == 'user_typing_status') {
        return '';
      }
      final customType = data['customType']?.toString() ?? '';
      final type = data['type']?.toString() ?? '';
      final mergedType = customType.isNotEmpty ? customType : type;
      final normalized = '$businessID|$mergedType'.toLowerCase();
      if (businessID == 'friend_became_friends') {
        final text = _readString(data, ['text', 'content', 'desc']);
        return text ??
            _i18n.t(
              zhHans: '你们已成为好友，现在可以开始聊天了',
              zhHant: '你們已成為好友，現在可以開始聊天了',
              en: 'You are now friends. Start chatting!',
              ja: '友達になりました。チャットを始めましょう！',
              ko: '친구가 되었습니다. 채팅을 시작해 보세요!',
            );
      }
      if (businessID == 'red_packet_claim_notice') {
        return '';
      }
      if (mergedType == 'wallet_red_packet' ||
          (businessID == 'wallet_order' && mergedType == 'wallet_red_packet')) {
        final greeting =
            _readString(data, ['greeting', 'msg']) ??
                _i18n.t(
                  zhHans: '恭喜发财，大吉大利',
                  zhHant: '恭喜發財，大吉大利',
                  en: 'Best wishes and good fortune',
                  ja: 'ご健勝とご多幸をお祈りします',
                  ko: '복 많이 받으세요',
                );
        final packetType = data['packetType']?.toString().trim() ?? '';
        final convId = data['conversationId']?.toString().trim() ?? '';
        final typeLabel = packetType.isNotEmpty
            ? redPacketTypeLabel(packetType, i18n: _i18n)
            : (convId.toLowerCase().startsWith('group_')
                ? redPacketTypeLabel(null, i18n: _i18n)
                : redPacketTypeLabel('NORMAL_C2C', i18n: _i18n));
        return '[$typeLabel] $greeting';
      }
      if (mergedType == 'wallet_group_transfer' ||
          (businessID == 'wallet_order' &&
              mergedType == 'wallet_group_transfer')) {
        final memo = _readString(data, ['memo', 'greeting', 'msg']);
        final tag = _i18n.t(
          zhHans: '群转账',
          zhHant: '群轉帳',
          en: 'Group Transfer',
          ja: 'グループ送金',
          ko: '그룹 이체',
        );
        if (memo != null && memo.isNotEmpty) {
          return '[$tag] $memo';
        }
        return _i18n.t(
          zhHans: '[群转账]',
          zhHant: '[群轉帳]',
          en: '[Group Transfer]',
          ja: '[グループ送金]',
          ko: '[그룹 이체]',
        );
      }
      if (mergedType == 'wallet_transfer' ||
          (businessID == 'wallet_order' && mergedType != 'wallet_red_packet')) {
        final memo = _readString(data, ['memo', 'greeting', 'msg']);
        if (memo != null && memo.isNotEmpty) {
          final tag = _i18n.t(
            zhHans: '转账',
            zhHant: '轉帳',
            en: 'Transfer',
            ja: '送金',
            ko: '이체',
          );
          return '[$tag] $memo';
        }
        return _i18n.t(
          zhHans: '[转账] 转账给你',
          zhHant: '[轉帳] 轉帳給你',
          en: '[Transfer] Sent you a transfer',
          ja: '[送金] 送金しました',
          ko: '[이체] 송금했습니다',
        );
      }
      if (isPlatformWalletNoticePayload(data) ||
          businessID == 'platform_notice' ||
          normalized.contains('notice')) {
        final notice = parsePlatformWalletNoticeData(data);
        if (notice != null) {
          final service = notice.serviceName?.trim() ?? '';
          if (notice.title.isNotEmpty) {
            if (service.isNotEmpty) {
              return '[$service] ${notice.title}';
            }
            return notice.title;
          }
          if (service.isNotEmpty) {
            return '[$service]';
          }
        }
        final text = _readString(
          data,
          ['title', 'summary', 'content', 'text', 'body', 'desc'],
        );
        return text ??
            _bracketLabel(
              zhHans: '系统通知',
              zhHant: '系統通知',
              en: 'System notice',
              ja: 'システム通知',
              ko: '시스템 알림',
            );
      }
      if (businessID == 'contact_card' || mergedType == 'contact_card') {
        final name = _readString(
          data,
          ['nickName', 'nickname', 'name', 'userID', 'userId'],
        );
        final tag = _bracketLabel(
          zhHans: '个人名片',
          zhHant: '個人名片',
          en: 'Contact card',
          ja: '連絡先カード',
          ko: '연락처 카드',
        );
        if (name != null && name.isNotEmpty) {
          return '$tag $name';
        }
        return tag;
      }
      if (businessID == 'group_create' || mergedType == 'group_create') {
        final opUser = data['opUser']?.toString().trim() ?? '';
        final content = data['content']?.toString().trim() ?? '';
        final combined = '$opUser$content'.trim();
        if (combined.isNotEmpty) {
          return combined;
        }
        return _i18n.t(
          zhHans: '群聊创建成功！',
          zhHant: '群聊建立成功！',
          en: 'Group chat created',
          ja: 'グループチャットを作成しました',
          ko: '그룹 채팅이 생성되었습니다',
        );
      }
      if (businessID == 'group_tip' || mergedType == 'group_tip') {
        final preview = data['previewAbstract']?.toString().trim() ?? '';
        if (preview.isNotEmpty) {
          return preview;
        }
        return groupTipDisplayText(Map<String, dynamic>.from(data));
      }
      if (normalized.contains('official') || normalized.contains('article')) {
        final text = _readString(data, ['title', 'summary', 'description']);
        return text ??
            _bracketLabel(
              zhHans: '图文',
              zhHant: '圖文',
              en: 'Article',
              ja: '記事',
              ko: '아티클',
            );
      }
      if (normalized.contains('revoke') || normalized.contains('recall')) {
        return _i18n.t(
          zhHans: '对方撤回了一条消息',
          zhHant: '對方撤回了一則訊息',
          en: 'A message was recalled',
          ja: 'メッセージが取り消されました',
          ko: '메시지가 회수되었습니다',
        );
      }
      if (normalized.contains('av_call') ||
          normalized.contains('rtc_call') ||
          normalized.contains('call')) {
        return _bracketLabel(
          zhHans: '通话',
          zhHant: '通話',
          en: 'Call',
          ja: '通話',
          ko: '통화',
        );
      }
      return _readString(
            data,
            ['title', 'summary', 'content', 'text', 'body', 'desc', 'link'],
          ) ??
          '';
    } catch (_) {}
    return '';
  }

  static bool isCallPush({String? title, String? desc, String? ext}) {
    final blob = '${title ?? ''}${desc ?? ''}${ext ?? ''}';
    if (blob.contains('av_call') ||
        blob.contains('rtc_call') ||
        blob.contains('videoCall') ||
        blob.contains('audioCall') ||
        blob.contains('inviteID')) {
      return true;
    }
    return blob.contains('通话') ||
        blob.contains('通話') ||
        blob.contains('视频') ||
        blob.contains('視訊') ||
        blob.contains('语音') ||
        blob.contains('語音') ||
        blob.toLowerCase().contains('call');
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
