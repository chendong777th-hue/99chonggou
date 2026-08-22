/// Non-web: TIM scripts are not injected from Flutter.
class TimWebScriptLoader {
  TimWebScriptLoader._();

  static Future<void> ensureLoaded() async {}

  static void rebindRealtimeListeners() {}
}
