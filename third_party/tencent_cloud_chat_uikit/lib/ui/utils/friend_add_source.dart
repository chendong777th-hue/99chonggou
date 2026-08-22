import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';

/// 腾讯云 IM 好友添加来源（addSource）常量。
/// 格式：AddSource_Type_ + 英文关键字（关键字不超过 8 字节）。
class FriendAddSource {
  FriendAddSource._();

  static const String search = 'AddSource_Type_Search';
  static const String qrCode = 'AddSource_Type_QRCode';
  static const String phone = 'AddSource_Type_Phone';
  static const String group = 'AddSource_Type_Group';
  static const String chat = 'AddSource_Type_Chat';
  static const String card = 'AddSource_Type_Card';

  static final RegExp _wordingSourceTag =
      RegExp(r'\[99chat_src:(AddSource_Type_[^\]]+)\]');

  /// 附言里用于展示渠道的可见后缀（如「，通过名片添加」），列表展示时应去掉。
  static final RegExp _wordingChannelSuffix =
      RegExp(r'[，,]\s*通过.+添加\s*$');

  /// 与后端 POST /users/search 入参识别规则对齐。
  static String resolveSearchKeywordSource(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.startsWith('+') || RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return phone;
    }
    if (RegExp(r'^[A-Za-z]').hasMatch(trimmed)) {
      return search;
    }
    if (RegExp(r'^\+?\d{5,15}$').hasMatch(trimmed)) {
      return phone;
    }
    return search;
  }

  /// 在附言中嵌入来源，防止部分端上 addSource 被置为 Unknow 时丢失场景信息。
  static String embedInWording(String? addSource, String wording) {
    final source = addSource?.trim() ?? '';
    if (source.isEmpty) {
      return wording;
    }
    final cleaned = stripFromWording(wording);
    final tag = '[99chat_src:$source]';
    if (cleaned.isEmpty) {
      return tag;
    }
    return '$tag $cleaned';
  }

  static String repairLegacyMojibake(String? text) {
    var value = text ?? '';
    if (value.isEmpty) {
      return value;
    }

    // Older app builds accidentally stored several UTF-8 Chinese strings as
    // mojibake in SDK friend-application wording. Keep this compatibility here
    // so "新的朋友" and audit pages can render old records without changing SDK
    // history data.
    const replacements = <String, String>{
      '鎴戞槸': '我是',
      '锛歿name}': '：{name}',
      '锛歿option1}': '：{option1}',
      '锛�{name}': '：{name}',
      '锛�{option1}': '：{option1}',
      '锛�': '：',
      '璇︾粏璧勬枡': '详细资料',
      '鎬у埆': '性别',
      '99鍙稩D': '99号ID',
      '99铏烮D': '99號ID',
    };

    for (final entry in replacements.entries) {
      value = value.replaceAll(entry.key, entry.value);
    }
    return value;
  }

  static String stripFromWording(String? wording) {
    var text = repairLegacyMojibake(wording)
        .replaceAll(_wordingSourceTag, '')
        .trim();
    text = text.replaceAll(_wordingChannelSuffix, '').trim();
    return text;
  }

  static String? parseFromWording(String? wording) {
    final match = _wordingSourceTag.firstMatch(wording ?? '');
    return match?.group(1)?.trim();
  }

  static bool isUnknownSource(String? addSource) {
    final raw = addSource?.trim() ?? '';
    if (raw.isEmpty) {
      return true;
    }
    final normalized = raw.toLowerCase().replaceAll('_', '');
    return normalized.contains('unknow');
  }

  /// 优先用 addSource 字段，无效时从附言标签回退。
  static String? resolveRawSource(String? addSource, String? addWording) {
    if (!isUnknownSource(addSource)) {
      return addSource?.trim();
    }
    return parseFromWording(addWording) ?? addSource?.trim();
  }

  /// 添加来源展示文案（如「对方通过手机号码添加」）。
  static String displayLabel(String? addSource, {String? addWording}) {
    final raw = resolveRawSource(addSource, addWording) ?? '';
    if (raw.isEmpty) {
      return TIM_t("对方通过其他方式添加");
    }

    var keyword = raw;
    if (keyword.toLowerCase().startsWith('addsource_type_')) {
      keyword = keyword.substring('addsource_type_'.length);
    }
    final normalized = keyword.toLowerCase().replaceAll('_', '');

    switch (normalized) {
      case 'unknow':
      case 'unknown':
        return TIM_t("对方通过其他方式添加");
      case 'search':
        return TIM_t("对方通过搜索添加");
      case 'qrcode':
      case 'qr':
        return TIM_t("对方通过扫描二维码添加");
      case 'phone':
      case 'mobile':
        return TIM_t("对方通过手机号码添加");
      case 'contact':
        return TIM_t("对方通过手机通讯录添加");
      case 'chat':
        return TIM_t("对方通过好友对话添加");
      case 'android':
        return TIM_t("对方通过 Android 客户端添加");
      case 'ios':
      case 'iphone':
        return TIM_t("对方通过 iOS 客户端添加");
      case 'web':
      case 'h5':
        return TIM_t("对方通过网页添加");
      case 'card':
      case 'contactcard':
        return TIM_t("对方通过名片添加");
    }

    if (normalized.startsWith('group') || keyword.contains('群')) {
      var groupName = keyword;
      groupName = groupName.replaceFirst(
        RegExp(r'^group_?', caseSensitive: false),
        '',
      );
      groupName = groupName.replaceAll('_', ' ').trim();
      if (groupName.isEmpty) {
        return TIM_t("对方通过群聊添加");
      }
      return TIM_t_para("对方通过群聊{{option1}}添加", "对方通过群聊$groupName添加")(
        option1: groupName,
      );
    }

    final readable = keyword.replaceAll('_', ' ').trim();
    if (readable.isEmpty) {
      return TIM_t("对方通过其他方式添加");
    }
    return TIM_t_para("对方通过{{option1}}添加", "对方通过$readable添加")(
      option1: readable,
    );
  }
}
