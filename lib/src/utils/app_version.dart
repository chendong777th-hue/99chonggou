import 'package:package_info_plus/package_info_plus.dart';

class AppVersion {
  AppVersion._();

  static String? _displayVersion;
  static String? _clientVersion;

  static Future<String> getDisplayVersion() async {
    final cached = _displayVersion;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final build = info.buildNumber.trim();
      _clientVersion = build.isEmpty ? version : '$version+$build';
      _displayVersion = build.isEmpty ? version : '$version($build)';
    } catch (_) {
      _clientVersion = '1.0.0';
      _displayVersion = '1.0.0';
    }
    return _displayVersion!;
  }

  static Future<String> getClientVersion() async {
    final cached = _clientVersion;
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }
    await getDisplayVersion();
    return _clientVersion ?? '1.0.0';
  }
}
