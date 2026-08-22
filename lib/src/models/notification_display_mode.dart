import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

enum NotificationDisplayMode {
  full,
  anonymous,
  hidden;

  String get storageKey {
    switch (this) {
      case NotificationDisplayMode.full:
        return 'full';
      case NotificationDisplayMode.anonymous:
        return 'anonymous';
      case NotificationDisplayMode.hidden:
        return 'hidden';
    }
  }

  /// 服务端 `notificationDisplayContent` 枚举值。
  String get apiValue {
    switch (this) {
      case NotificationDisplayMode.full:
        return 'show_all';
      case NotificationDisplayMode.anonymous:
        return 'generic';
      case NotificationDisplayMode.hidden:
        return 'hidden';
    }
  }

  static NotificationDisplayMode fromApiValue(String? raw) {
    switch (raw?.trim()) {
      case 'generic':
        return NotificationDisplayMode.anonymous;
      case 'hidden':
        return NotificationDisplayMode.hidden;
      case 'show_all':
      default:
        return NotificationDisplayMode.full;
    }
  }

  String localizedLabel(AppI18n i18n) {
    switch (this) {
      case NotificationDisplayMode.full:
        return i18n.t(
          zhHans: '显示朋友名称、群聊名及消息内容',
          zhHant: '顯示朋友名稱、群聊名及訊息內容',
          en: 'Show friend name, group name, and message content',
          ja: '友だち名、グループ名、メッセージ内容を表示',
          ko: '친구 이름, 그룹 이름 및 메시지 내용 표시',
        );
      case NotificationDisplayMode.anonymous:
        return i18n.t(
          zhHans: '仅显示「你收到了一条消息」',
          zhHant: '僅顯示「你收到了一則訊息」',
          en: 'Show only "You received a message"',
          ja: '「メッセージを受信しました」のみ表示',
          ko: '"메시지를 받았습니다"만 표시',
        );
      case NotificationDisplayMode.hidden:
        return i18n.t(
          zhHans: '隐藏朋友名称、群聊名及消息内容',
          zhHant: '隱藏朋友名稱、群聊名及訊息內容',
          en: 'Hide friend name, group name, and message content',
          ja: '友だち名、グループ名、メッセージ内容を非表示',
          ko: '친구 이름, 그룹 이름 및 메시지 내용 숨기기',
        );
    }
  }

  static NotificationDisplayMode fromStorage(String? raw) {
    switch (raw) {
      case 'anonymous':
        return NotificationDisplayMode.anonymous;
      case 'hidden':
        return NotificationDisplayMode.hidden;
      case 'full':
      default:
        return NotificationDisplayMode.full;
    }
  }
}
