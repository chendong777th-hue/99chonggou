/// 锁屏回前台恢复分相策略：同页流畅优先，允许短窗预览/未读滞后。
enum ResumeIntensity {
  light,
  full,
}

class ResumeForegroundPolicy {
  ResumeForegroundPolicy._();

  static const Duration shortBackgroundThreshold = Duration(seconds: 15);
  /// 亮屏后会话重活静默窗（可被 ConversationPerfFlags.resumeQuietDuration 覆盖）。
  static const Duration conversationHoldDuration = Duration(seconds: 3);
  static const Duration phase1Delay = Duration(milliseconds: 800);
  static const Duration phase2Delay = Duration(milliseconds: 2000);

  static ResumeIntensity intensityFor(Duration? background) {
    if (background == null) {
      return ResumeIntensity.full;
    }
    if (background < shortBackgroundThreshold) {
      return ResumeIntensity.light;
    }
    return ResumeIntensity.full;
  }

  static bool shouldRunChatRefreshInPhase0(ResumeIntensity intensity) {
    return false;
  }

  static bool shouldRunHeavySideEffects(ResumeIntensity intensity) {
    return intensity == ResumeIntensity.full;
  }

  static List<Duration> chatRecoveryRetryDelays({
    required bool hasVisibleMessages,
    required bool previewAhead,
    bool cloudCatchUpRequired = false,
  }) {
    if (hasVisibleMessages && !previewAhead && !cloudCatchUpRequired) {
      return const <Duration>[Duration.zero];
    }
    return const <Duration>[
      Duration.zero,
      Duration(milliseconds: 800),
      Duration(milliseconds: 2000),
    ];
  }
}
