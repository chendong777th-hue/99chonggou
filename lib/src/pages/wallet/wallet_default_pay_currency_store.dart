import 'package:shared_preferences/shared_preferences.dart';

/// 发红包 / 转账默认付款币种本地持久化。
///
/// 以付款方式 `id`（如 `99`、`USDT`）为键，选中后下次进入默认使用。
class WalletDefaultPayCurrencyStore {
  WalletDefaultPayCurrencyStore._();

  static const _key = 'wallet_default_pay_currency_id';
  static String? _cachedId;

  static Future<String?> readId() async {
    final cached = _cachedId;
    if (cached != null) return cached.isEmpty ? null : cached;
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key)?.trim() ?? '';
    _cachedId = id;
    return id.isEmpty ? null : id;
  }

  static Future<void> writeId(String payId) async {
    final id = payId.trim();
    if (id.isEmpty) return;
    if (_cachedId == id) return;
    _cachedId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, id);
  }

  /// 在可用付款方式中选中默认项：优先匹配已保存 id，否则第一项可用项。
  static T pick<T>({
    required List<T> items,
    required String Function(T) idOf,
    required bool Function(T) enabledOf,
    String? preferredId,
  }) {
    assert(items.isNotEmpty);
    final preferred = preferredId?.trim() ?? '';
    if (preferred.isNotEmpty) {
      for (final item in items) {
        if (idOf(item) == preferred && enabledOf(item)) return item;
      }
      for (final item in items) {
        if (idOf(item) == preferred) return item;
      }
    }
    for (final item in items) {
      if (enabledOf(item)) return item;
    }
    return items.first;
  }
}
