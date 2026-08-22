/// Face 消息约定：骰子（与 [StickerConstants.stickerDataScheme] 互斥）。
class DiceConstants {
  DiceConstants._();

  /// 与贴纸 group index 99 区分。
  static const int diceFaceGroupIndex = 98;

  static const String diceDataScheme = '99chat://dice/';

  /// 爱心 Tab 置顶骰子入口。
  static const bool showInStickerPanel = true;

  static bool isDiceFaceData(String data) {
    final trimmed = data.trim();
    return trimmed.startsWith(diceDataScheme);
  }

  static String? dataForValue(int value) {
    if (value < 1 || value > 6) {
      return null;
    }
    return '$diceDataScheme$value';
  }

  /// 本地动画 WebP：`assets/img/dice_{1-6}.webp`。
  static String assetPathForValue(int value) {
    final v = value < 1 || value > 6 ? 1 : value;
    return 'assets/img/dice_$v.webp';
  }

  static int? parseValue(String data) {
    final trimmed = data.trim();
    if (!trimmed.startsWith(diceDataScheme)) {
      return null;
    }
    var rest = trimmed.substring(diceDataScheme.length);
    final q = rest.indexOf('?');
    if (q >= 0) {
      rest = rest.substring(0, q);
    }
    final h = rest.indexOf('#');
    if (h >= 0) {
      rest = rest.substring(0, h);
    }
    rest = rest.trim();
    final value = int.tryParse(rest);
    if (value == null || value < 1 || value > 6) {
      return null;
    }
    return value;
  }
}
