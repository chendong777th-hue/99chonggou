import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 持久化账号/手机号；密码可选记住（存于 SecureStorage，用户可关闭）。
class LoginCredentialStore {
  LoginCredentialStore._();

  static final LoginCredentialStore instance = LoginCredentialStore._();

  static const _accountKey = 'saved_login_account';
  static const _phoneKey = 'saved_login_phone';
  static const _countryCodeKey = 'saved_login_country_code';
  static const _countryIsoKey = 'saved_login_country_iso';
  static const _passwordKey = 'saved_login_password';
  static const _rememberPasswordKey = 'saved_login_remember_password';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<StoredLoginCredentials> load() async {
    await _migrateLegacyPrefsIfNeeded();
    final rememberRaw = await _secure.read(key: _rememberPasswordKey);
    final rememberPassword = rememberRaw != '0';
    return StoredLoginCredentials(
      account: await _secure.read(key: _accountKey),
      phone: await _secure.read(key: _phoneKey),
      countryCode: await _secure.read(key: _countryCodeKey),
      countryIso: await _secure.read(key: _countryIsoKey),
      password: rememberPassword
          ? await _secure.read(key: _passwordKey)
          : null,
      rememberPassword: rememberPassword,
    );
  }

  Future<void> _migrateLegacyPrefsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateSingleKey(prefs, _accountKey);
    await _migrateSingleKey(prefs, _phoneKey);
    await _migrateSingleKey(prefs, _countryCodeKey);
    await _migrateSingleKey(prefs, _countryIsoKey);
  }

  Future<void> _migrateSingleKey(SharedPreferences prefs, String key) async {
    final legacyValue = prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) {
      return;
    }
    final secureValue = await _secure.read(key: key);
    if (secureValue == null || secureValue.isEmpty) {
      await _secure.write(key: key, value: legacyValue);
    }
    await prefs.remove(key);
  }

  Future<void> savePasswordLogin({
    required String account,
    required String password,
    required bool rememberPassword,
    String? phoneCountryIso,
    String? countryCode,
    String? phone,
  }) async {
    await _secure.write(key: _accountKey, value: account.trim());
    if (phoneCountryIso != null && phoneCountryIso.isNotEmpty) {
      await _secure.write(key: _countryIsoKey, value: phoneCountryIso);
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      await _secure.write(key: _countryCodeKey, value: countryCode);
    }
    if (phone != null && phone.isNotEmpty) {
      await _secure.write(key: _phoneKey, value: phone);
    }
    await _secure.write(
      key: _rememberPasswordKey,
      value: rememberPassword ? '1' : '0',
    );
    if (rememberPassword && password.isNotEmpty) {
      await _secure.write(key: _passwordKey, value: password);
    } else {
      await _secure.delete(key: _passwordKey);
    }
  }

  Future<void> saveSmsLogin({
    required String phone,
    String? countryCode,
    String? countryIso,
  }) async {
    await _secure.write(key: _phoneKey, value: phone);
    if (countryCode != null && countryCode.isNotEmpty) {
      await _secure.write(key: _countryCodeKey, value: countryCode);
    }
    if (countryIso != null && countryIso.isNotEmpty) {
      await _secure.write(key: _countryIsoKey, value: countryIso);
    }
  }

  /// 用户开启「记住密码」时，同步更新本地保存的登录密码。
  Future<void> updateSavedPasswordIfRemembered(String newPassword) async {
    final trimmed = newPassword.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final rememberRaw = await _secure.read(key: _rememberPasswordKey);
    if (rememberRaw == '0') {
      return;
    }
    await _secure.write(key: _passwordKey, value: trimmed);
  }
}

class StoredLoginCredentials {
  final String? account;
  final String? phone;
  final String? countryCode;
  final String? countryIso;
  final String? password;
  final bool rememberPassword;

  const StoredLoginCredentials({
    this.account,
    this.phone,
    this.countryCode,
    this.countryIso,
    this.password,
    this.rememberPassword = true,
  });
}
