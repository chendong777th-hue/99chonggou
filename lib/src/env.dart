class AppEnv {
  static const String defaultCountryCode =
      String.fromEnvironment('DEFAULT_COUNTRY_CODE', defaultValue: '+86');

  /// ISO 3166-1 alpha-2，用于密码登录 account 为纯数字时的解析（与后端 phoneCountry 对齐）。
  static const String defaultPhoneCountry =
      String.fromEnvironment('DEFAULT_PHONE_COUNTRY', defaultValue: 'CN');
}
