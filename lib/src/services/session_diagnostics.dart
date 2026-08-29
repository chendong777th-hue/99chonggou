import 'dart:developer' as developer;

/// Credential-free diagnostics for auth and account-boundary transitions.
///
/// The app silences `print` and `debugPrint`, so important session events use
/// the VM log stream and retain a small in-memory trail for support tooling.
class SessionDiagnostics {
  SessionDiagnostics._();

  static const int _maxEvents = 200;
  static int _nextId = 0;
  static final List<String> _events = <String>[];

  static void log(String message) {
    final event = '${++_nextId} ${_scrub(message)}';
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
    developer.log(event, name: 'ninechat.session');
  }

  static List<String> get recentEvents => List<String>.unmodifiable(_events);

  static void clearForTest() {
    _events.clear();
    _nextId = 0;
  }

  static String _scrub(String value) {
    var result = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    result = result.replaceAll(
      RegExp(
        r'(userSig|user_sig|token|authorization|password|smsCode|sms_code|loginKey)=([^ ]+)',
        caseSensitive: false,
      ),
      r'\1=<redacted>',
    );
    return result.length <= 900 ? result : '${result.substring(0, 897)}...';
  }
}
