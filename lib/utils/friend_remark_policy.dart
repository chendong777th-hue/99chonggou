import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 好友备注名校验：仅限制 2–30 个字符，不允许换行。
class FriendRemarkPolicy {
  FriendRemarkPolicy._();

  static const int minLength = 2;
  static const int maxLength = 30;

  static String stripLineBreaks(String text) {
    return text.replaceAll(RegExp(r'[\r\n]+'), '');
  }

  static bool isLengthValid(String text) {
    final length = stripLineBreaks(text).trim().length;
    return length >= minLength && length <= maxLength;
  }

  static String? validationMessage(String text) {
    final trimmed = stripLineBreaks(text).trim();
    if (trimmed.isEmpty || !isLengthValid(trimmed)) {
      return AppI18n.current.t(
        zhHans: '请输入2-30个字的备注',
        zhHant: '請輸入2-30個字的備註',
        en: 'Enter a remark of 2–30 characters',
        ja: '2〜30文字の備考を入力してください',
        ko: '2~30자 비고를 입력하세요',
      );
    }
    return null;
  }
}
