/// Shared call-related userId normalization and role helpers.
class CallUserId {
  CallUserId._();

  /// Strips `c2c_` prefix and TRTC composite suffix (`#...`).
  static String normalizeCallUserId(String raw) {
    var text = raw.trim();
    if (text.startsWith('c2c_')) {
      text = text.substring(4).trim();
    }
    final hashIndex = text.indexOf('#');
    if (hashIndex > 0) {
      text = text.substring(0, hashIndex).trim();
    }
    return text;
  }

  static bool isSameCallUserId(String a, String b) {
    final left = normalizeCallUserId(a);
    final right = normalizeCallUserId(b);
    if (left.isEmpty || right.isEmpty) {
      return false;
    }
    return left == right;
  }

  static String roleName(Object? role) {
    return role.toString().split('.').last.trim();
  }

  static bool isCallerRoleName(String roleName) {
    return roleName.trim() == 'caller';
  }

  static bool isCallerRole(Object? role) {
    return isCallerRoleName(roleName(role));
  }

  static bool isCalleeRoleName(String roleName) {
    final name = roleName.trim();
    return name == 'called' || name == 'callee';
  }

  static bool isCalleeRole(Object? role) {
    return isCalleeRoleName(roleName(role));
  }
}
