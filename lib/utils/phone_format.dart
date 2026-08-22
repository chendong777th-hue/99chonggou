import 'package:dlibphonenumber/dlibphonenumber.dart';
import 'package:tencent_cloud_chat_demo/src/env.dart';

/// 业务短信接口使用的 E.164 手机号规范化。
///
/// 前端校验和后端保持同一思路：按用户选择的 ISO 国家/地区码解析，
/// 再用 libphonenumber 元数据判断号码是否属于该地区，最后输出 E.164。
class PhoneFormat {
  PhoneFormat._();

  static final PhoneNumberUtil _phoneUtil = PhoneNumberUtil.instance;
  static final RegExp _e164Pattern = RegExp(r'^\+[1-9]\d{7,14}$');

  static bool isValidE164(String? phone) {
    final value = phone?.trim() ?? '';
    return value.isNotEmpty && _e164Pattern.hasMatch(value);
  }

  static ParsedPhoneNumber? parseWithRegion({
    required String phone,
    required String countryIso,
  }) {
    final region = _normalizeRegion(countryIso);
    final raw = phone.trim();
    if (region.isEmpty || raw.isEmpty) {
      return null;
    }

    try {
      final parsed = _phoneUtil.parse(raw, region);
      if (!_phoneUtil.isValidNumber(parsed) ||
          !_phoneUtil.isValidNumberForRegion(parsed, region)) {
        return null;
      }
      final e164 = _phoneUtil.format(parsed, PhoneNumberFormat.e164);
      if (!isValidE164(e164)) {
        return null;
      }
      return ParsedPhoneNumber(
        e164: e164,
        countryIso: region,
      );
    } catch (_) {
      return null;
    }
  }

  static String? tryE164({
    required String countryCode,
    required String nationalNumber,
    String? countryIso,
  }) {
    final parsed = parseWithRegion(
      phone: nationalNumber,
      countryIso: countryIso ?? isoCountryFromDialCode(countryCode),
    );
    return parsed?.e164;
  }

  static String e164({
    required String countryCode,
    required String nationalNumber,
    String? countryIso,
  }) {
    final parsed = tryE164(
      countryCode: countryCode,
      nationalNumber: nationalNumber,
      countryIso: countryIso,
    );
    if (parsed != null) {
      return parsed;
    }

    // 理论上业务提交前已经通过 parseWithRegion 校验；这里仅保留兜底，
    // 防止历史调用点因为空值中断，最终仍由后端再次校验。
    final digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    final cc = countryCode.trim().startsWith('+')
        ? countryCode.trim()
        : '+${countryCode.trim()}';
    return '$cc$digits';
  }

  static bool isChinaDialCode(String countryCode) {
    return countryCode.trim() == '+86' || countryCode.trim() == '86';
  }

  static bool isValidNationalNumber({
    required String countryCode,
    required String nationalNumber,
    String? countryIso,
  }) {
    return tryE164(
          countryCode: countryCode,
          nationalNumber: nationalNumber,
          countryIso: countryIso,
        ) !=
        null;
  }

  static String? nationalNumberError({
    required String countryCode,
    required String nationalNumber,
    String? countryIso,
  }) {
    if (nationalNumber.trim().isEmpty) {
      return '请输入手机号';
    }
    return isValidNationalNumber(
      countryCode: countryCode,
      nationalNumber: nationalNumber,
      countryIso: countryIso,
    )
        ? null
        : '请输入正确的手机号';
  }

  /// 从账号输入（手机号 / +86 / 邮箱等）尝试解析 E.164。
  static String? tryResolveFromAccount({
    required String account,
    required String defaultCountryCode,
    String? defaultCountryIso,
  }) {
    final raw = account.trim();
    if (raw.isEmpty) {
      return null;
    }
    if (isValidE164(raw)) {
      final parsed = parseWithRegion(
        phone: raw,
        countryIso: defaultCountryIso ?? isoCountryFromDialCode(defaultCountryCode),
      );
      return parsed?.e164 ?? raw;
    }
    return tryE164(
      countryCode: defaultCountryCode,
      nationalNumber: raw,
      countryIso: defaultCountryIso,
    );
  }

  /// 设备验证短信：优先服务端返回，其次密码账号里的手机号，最后短信页已填手机号。
  static String? resolveForDeviceChallenge({
    required String account,
    required String defaultCountryCode,
    String? defaultCountryIso,
    String? phoneFromServer,
    String? phoneFromLoginField,
  }) {
    final server = phoneFromServer?.trim() ?? '';
    if (server.isNotEmpty) {
      final parsed = parseWithRegion(
        phone: server,
        countryIso: defaultCountryIso ?? isoCountryFromDialCode(defaultCountryCode),
      );
      if (parsed != null) {
        return parsed.e164;
      }
      if (isValidE164(server)) {
        return server;
      }
    }

    final fromAccount = tryResolveFromAccount(
      account: account,
      defaultCountryCode: defaultCountryCode,
      defaultCountryIso: defaultCountryIso,
    );
    if (fromAccount != null) {
      return fromAccount;
    }

    final loginField = phoneFromLoginField?.trim() ?? '';
    if (loginField.isEmpty) {
      return null;
    }
    final fromLoginField = parseWithRegion(
      phone: loginField,
      countryIso: defaultCountryIso ?? isoCountryFromDialCode(defaultCountryCode),
    );
    return fromLoginField?.e164 ?? (isValidE164(loginField) ? loginField : null);
  }

  /// 脱敏手机号（含 *）不能用于发短信接口。
  static bool isMaskedPhone(String? value) {
    final raw = value?.trim() ?? '';
    return raw.contains('*');
  }

  /// 通讯录常见备选地区：无国家码时，默认地区解析失败则依次尝试。
  static const List<String> _contactFallbackRegions = [
    'HK',
    'TW',
    'MO',
    'SG',
    'MY',
    'JP',
    'KR',
    'VN',
    'TH',
    'KH',
    'MM',
    'LA',
    'ID',
    'PH',
    'BN',
    'IN',
    'BD',
    'PK',
    'LK',
    'NP',
    'AE',
    'SA',
    'QA',
    'KW',
    'BH',
    'OM',
    'IL',
    'TR',
    'US',
    'CA',
    'GB',
    'AU',
    'DE',
    'FR',
    'NL',
    'RU',
    'BR',
    'MX',
  ];

  /// 将通讯录原始号码解析为 E.164；带/不带国家码、常见分隔符均可。
  ///
  /// 无法解析为合法手机号时返回 `null`（固话、短号等会被跳过，避免拖垮批量匹配）。
  static String? tryResolveContactPhone(
    String raw, {
    String? defaultCountryIso,
  }) {
    final defaultRegion =
        _normalizeRegion(defaultCountryIso ?? AppEnv.defaultPhoneCountry);
    if (defaultRegion.isEmpty) {
      return null;
    }

    final cleaned = _cleanContactPhoneRaw(raw);
    if (cleaned.isEmpty || isMaskedPhone(cleaned)) {
      return null;
    }

    if (isValidE164(cleaned)) {
      return _tryLenientParse(cleaned, defaultRegion) ?? cleaned;
    }

    var candidate = cleaned;
    if (candidate.startsWith('00')) {
      candidate = '+${candidate.substring(2)}';
      final parsed = _tryLenientParse(candidate, defaultRegion);
      if (parsed != null) {
        return parsed;
      }
    }

    final direct = _tryLenientParse(candidate, defaultRegion);
    if (direct != null) {
      return direct;
    }

    if (!candidate.startsWith('+')) {
      final digitsOnly = candidate.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length >= 7) {
        if (digitsOnly.startsWith('0') && digitsOnly.length >= 8) {
          final withoutLeadingZero = digitsOnly.substring(1);
          for (final region in _contactFallbackRegions) {
            if (region == defaultRegion) {
              continue;
            }
            final parsed = _tryLenientParse(withoutLeadingZero, region);
            if (parsed != null) {
              return parsed;
            }
          }
        }
        // 大陆 11 位手机号（如 158 2888 3888）优先按默认地区解析，
        // 避免被误判为 +1 北美号码。
        if (digitsOnly.length == 11 &&
            RegExp(r'^1[3-9]\d{9}$').hasMatch(digitsOnly)) {
          final cnMobile = _tryLenientParse(digitsOnly, defaultRegion);
          if (cnMobile != null) {
            return cnMobile;
          }
        }
        final withPlus = _tryLenientParse('+$digitsOnly', defaultRegion);
        if (withPlus != null) {
          return withPlus;
        }
      }

      for (final region in _contactFallbackRegions) {
        if (region == defaultRegion) {
          continue;
        }
        final parsed = _tryLenientParse(candidate, region);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  /// 批量规范化通讯录号码，去重并仅保留可解析的 E.164。
  static List<String> normalizeContactPhoneList(List<String> raw) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final item in raw) {
      final e164 = tryResolveContactPhone(item);
      if (e164 != null && seen.add(e164)) {
        normalized.add(e164);
      }
    }
    return normalized;
  }

  /// 通讯录匹配接口用：仅保留 libphonenumber 认可的 E.164，避免拖垮整批请求。
  static bool isValidForContactMatch(String? phone) {
    final value = phone?.trim() ?? '';
    if (!isValidE164(value)) {
      return false;
    }
    try {
      final parsed = _phoneUtil.parse(value, null);
      return _phoneUtil.isValidNumber(parsed);
    } catch (_) {
      return false;
    }
  }

  /// 解析并过滤出可提交给 `/users/contacts/match` 的号码。
  static List<String> filterForContactMatch(Iterable<String> phones) {
    final seen = <String>{};
    final result = <String>[];
    for (final phone in phones) {
      final resolved = isValidE164(phone)
          ? phone.trim()
          : tryResolveContactPhone(phone);
      if (resolved != null &&
          isValidForContactMatch(resolved) &&
          seen.add(resolved)) {
        result.add(resolved);
      }
    }
    return result;
  }

  /// 将通讯录原始号码清洗为可展示的文本（不保证可解析为 E.164）。
  static String cleanContactPhoneRaw(String raw) {
    return _cleanContactPhoneRaw(raw);
  }

  static String _cleanContactPhoneRaw(String raw) {
    var value = raw.trim();
    if (value.toLowerCase().startsWith('tel:')) {
      value = value.substring(4).trim();
    }
    value = value
        .split(RegExp(r'(?:ext\.?|x|#)', caseSensitive: false))
        .first
        .trim();
    value = value.replaceAll(RegExp(r'[（）()]'), '');
    value = value.replaceAll(RegExp(r'[.\-/\\]'), ' ');
    value = value.replaceAll('＋', '+');
    value = value.replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '');
    value = value.replaceAll(
      RegExp(
        r'\s*(mobile|cell|work|home|other|fax|iphone|android)\s*$',
        caseSensitive: false,
      ),
      '',
    );
    // iOS/部分机型通讯录分组空格（含窄不换行空格 U+202F）统一为普通空格。
    value = value.replaceAll(
      RegExp(r'[\s\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff]+'),
      ' ',
    );
    return value.trim();
  }

  static String? _tryLenientParse(String phone, String defaultRegion) {
    final raw = phone.trim();
    if (raw.isEmpty) {
      return null;
    }
    try {
      final parsed = _phoneUtil.parse(raw, defaultRegion);
      if (!_phoneUtil.isValidNumber(parsed)) {
        return null;
      }
      final e164 = _phoneUtil.format(parsed, PhoneNumberFormat.e164);
      return isValidE164(e164) ? e164 : null;
    } catch (_) {
      return null;
    }
  }

  /// 拨号区号 → ISO 国家码（供 `POST /auth/login/password` 的 phoneCountry）。
  static String isoCountryFromDialCode(String dialCode) {
    switch (dialCode.trim()) {
      case '+86':
        return 'CN';
      case '+852':
        return 'HK';
      case '+886':
        return 'TW';
      case '+1':
        return 'US';
      case '+81':
        return 'JP';
      case '+82':
        return 'KR';
      default:
        return AppEnv.defaultPhoneCountry;
    }
  }

  static String _normalizeRegion(String countryIso) {
    final region = countryIso.trim().toUpperCase();
    return RegExp(r'^[A-Z]{2}$').hasMatch(region) ? region : '';
  }
}

class ParsedPhoneNumber {
  const ParsedPhoneNumber({
    required this.e164,
    required this.countryIso,
  });

  final String e164;
  final String countryIso;
}
