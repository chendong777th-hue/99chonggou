class NicknamePolicy {
  NicknamePolicy._();

  static const int minLength = 2;
  static const int maxLength = 22;
  static const int cooldownDays = 7;

  static bool isLengthValid(String text) {
    final trimmed = text.trim();
    return trimmed.length >= minLength && trimmed.length <= maxLength;
  }

  static bool canEditNow(DateTime? lastNicknameChangedAt) {
    if (lastNicknameChangedAt == null) {
      return true;
    }
    return DateTime.now().toUtc().isAfter(
          lastNicknameChangedAt.add(const Duration(days: cooldownDays)),
        );
  }

  static DateTime? activeCooldownEnd(DateTime? lastNicknameChangedAt) {
    if (lastNicknameChangedAt == null) {
      return null;
    }
    final end =
        lastNicknameChangedAt.add(const Duration(days: cooldownDays));
    if (DateTime.now().toUtc().isBefore(end)) {
      return end;
    }
    return null;
  }

  static DateTime? resolveCooldownEnd({
    DateTime? lastNicknameChangedAt,
    DateTime? checkNextChangeableAt,
    String? checkReason,
  }) {
    if (checkReason == 'NICKNAME_COOLDOWN' && checkNextChangeableAt != null) {
      return checkNextChangeableAt;
    }
    return activeCooldownEnd(lastNicknameChangedAt);
  }
}
