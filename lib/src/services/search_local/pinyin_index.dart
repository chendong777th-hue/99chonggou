import 'package:lpinyin/lpinyin.dart';

/// 联系人/群聊搜索用的拼音与首字母索引。
class PinyinIndex {
  PinyinIndex._();

  /// 全拼（小写、无音调、空格去掉），失败返回空串。
  static String pinyinOf(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return '';
    }
    try {
      return PinyinHelper.getPinyinE(text)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
    } catch (_) {
      return '';
    }
  }

  /// 首字母串（小写），如「张三」→「zs」。
  static String initialsOf(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return '';
    }
    try {
      return PinyinHelper.getShortPinyin(text).toLowerCase();
    } catch (_) {
      return '';
    }
  }

  /// 拼接进 haystack 的拼音片段（全拼 + 首字母）。
  static String searchTokensFor(String raw) {
    final pinyin = pinyinOf(raw);
    final initials = initialsOf(raw);
    if (pinyin.isEmpty && initials.isEmpty) {
      return '';
    }
    if (pinyin.isEmpty) {
      return initials;
    }
    if (initials.isEmpty || initials == pinyin) {
      return pinyin;
    }
    return '$pinyin $initials';
  }

  /// 联系人 haystack：userId / 昵称 / 备注 + 拼音。
  static String friendHaystack({
    required String userId,
    required String nickname,
    required String remark,
  }) {
    final parts = <String>[
      userId.trim().toLowerCase(),
      nickname.trim().toLowerCase(),
      remark.trim().toLowerCase(),
      searchTokensFor(nickname),
      searchTokensFor(remark),
      searchTokensFor(userId),
    ];
    return parts.where((e) => e.isNotEmpty).join(' ');
  }

  /// 群聊 haystack：groupId / 群名 / 别名 + 拼音。
  static String groupHaystack({
    required String groupId,
    required String groupName,
    required String displayAlias,
  }) {
    final parts = <String>[
      groupId.trim().toLowerCase(),
      groupName.trim().toLowerCase(),
      displayAlias.trim().toLowerCase(),
      searchTokensFor(groupName),
      searchTokensFor(displayAlias),
      searchTokensFor(groupId),
    ];
    return parts.where((e) => e.isNotEmpty).join(' ');
  }
}
