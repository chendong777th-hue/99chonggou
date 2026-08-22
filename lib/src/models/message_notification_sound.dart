import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 应用内消息提示音选项（assets/yin）。
class MessageNotificationSound {
  const MessageNotificationSound({
    required this.id,
    required this.assetPath,
  });

  final String id;
  final String assetPath;

  static const String defaultId = 'preview000';

  static const List<MessageNotificationSound> options = <MessageNotificationSound>[
    MessageNotificationSound(
      id: 'preview000',
      assetPath: 'assets/yin/preview000.wav',
    ),
    MessageNotificationSound(
      id: 'crisp',
      assetPath: 'assets/yin/crisp.wav',
    ),
    MessageNotificationSound(
      id: 'soft',
      assetPath: 'assets/yin/soft.wav',
    ),
    MessageNotificationSound(
      id: 'chime',
      assetPath: 'assets/yin/chime.wav',
    ),
    MessageNotificationSound(
      id: 'preview',
      assetPath: 'assets/yin/preview.wav',
    ),
    MessageNotificationSound(
      id: 'preview1',
      assetPath: 'assets/yin/preview1.wav',
    ),
    MessageNotificationSound(
      id: 'preview04',
      assetPath: 'assets/yin/preview04.wav',
    ),
  ];

  static MessageNotificationSound fromId(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        normalized == 'default' ||
        normalized == 'system') {
      return options.first;
    }
    for (final option in options) {
      if (option.id == normalized) {
        return option;
      }
    }
    return options.first;
  }

  String localizedLabel(AppI18n i18n) {
    switch (id) {
      case 'preview000':
        return i18n.t(
          zhHans: '默认',
          zhHant: '預設',
          en: 'Default',
          ja: 'デフォルト',
          ko: '기본',
        );
      case 'crisp':
        return i18n.t(
          zhHans: '清脆',
          zhHant: '清脆',
          en: 'Crisp',
          ja: 'さわやか',
          ko: '맑음',
        );
      case 'soft':
        return i18n.t(
          zhHans: '柔和',
          zhHant: '柔和',
          en: 'Soft',
          ja: 'やわらか',
          ko: '부드러움',
        );
      case 'chime':
        return i18n.t(
          zhHans: '叮咚',
          zhHant: '叮咚',
          en: 'Chime',
          ja: 'チム',
          ko: '딩동',
        );
      case 'preview':
        return i18n.t(
          zhHans: '简约',
          zhHant: '簡約',
          en: 'Minimal',
          ja: 'シンプル',
          ko: '심플',
        );
      case 'preview1':
        return i18n.t(
          zhHans: '明快',
          zhHant: '明快',
          en: 'Bright',
          ja: '明るい',
          ko: '명쾌',
        );
      case 'preview04':
        return i18n.t(
          zhHans: '悦耳',
          zhHant: '悅耳',
          en: 'Pleasant',
          ja: '心地よい',
          ko: '듣기 좋음',
        );
      default:
        return id;
    }
  }
}
