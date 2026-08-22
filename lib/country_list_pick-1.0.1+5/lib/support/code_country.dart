// ignore_for_file: provide_deprecation_message

mixin ToAlias {}

@deprecated
class CElement = CountryCode with ToAlias;

/// Country element. This is the element that contains all the information
class CountryCode {
  /// the display/default name of the country
  String? name;

  /// English name used for index and search
  String? nameEn;

  /// Chinese name used by auth pages
  String? nameZh;

  /// the flag of the country
  String? flagUri;

  /// the country code (IT,AF..)
  String? code;

  /// the dial code (+39,+93..)
  String? dialCode;

  CountryCode({this.name, this.nameEn, this.nameZh, this.flagUri, this.code, this.dialCode});

  @override
  String toString() => "$dialCode";

  String get normalizedCode => (code ?? '').toUpperCase();

  String get englishName => (nameEn?.trim().isNotEmpty == true)
      ? nameEn!.trim()
      : (name?.trim() ?? '');

  String get chineseName => (nameZh?.trim().isNotEmpty == true)
      ? nameZh!.trim()
      : englishName;

  String displayName({bool withDialCode = false}) {
    final zh = chineseName;
    final en = englishName;
    final names = zh == en || en.isEmpty ? zh : '$zh $en';
    final dial = dialCode?.trim() ?? '';
    return withDialCode && dial.isNotEmpty ? '$names $dial' : names;
  }

  String toLongString() => displayName(withDialCode: true);

  String toCountryStringOnly() => displayName();
}
