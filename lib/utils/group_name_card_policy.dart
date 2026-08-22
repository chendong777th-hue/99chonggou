import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 群内昵称（群名片）校验：仅限制 2–20 个字符。
class GroupNameCardPolicy {
  GroupNameCardPolicy._();

  static const int minLength = 2;
  static const int maxLength = 20;

  static bool isLengthValid(String text) {
    final length = text.trim().length;
    return length >= minLength && length <= maxLength;
  }

  static String? validationMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !isLengthValid(trimmed)) {
      return AppI18n.current.t(
        zhHans: '请输入2-20个字的昵称',
        zhHant: '請輸入2-20個字的暱稱',
        en: 'Enter a nickname of 2–20 characters',
        ja: '2〜20文字のニックネームを入力してください',
        ko: '2~20자 닉네임을 입력하세요',
      );
    }
    return null;
  }
}
