
/// Configures Tencent Cloud live playback licence once per process.
class GroupLiveTencentLicence {
  GroupLiveTencentLicence._();

  /// Whether dart-define licence credentials were provided at build time.
  static bool get hasCredentials {
    return false;
  }

  static Future<void> ensureConfigured() async {
    return;
  }
}
