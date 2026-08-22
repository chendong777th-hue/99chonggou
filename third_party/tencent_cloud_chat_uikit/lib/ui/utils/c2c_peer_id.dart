class C2cPeerId {
  C2cPeerId._();

  /// Single C2C peer-id normalizer for UIKit and app.
  ///
  /// Trim → strip leading `@` → strip case-insensitive `c2c_` → drop `@suffix`
  /// → trim + lowercase.
  static String normalize(String? raw) {
    var id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    if (id.startsWith('@')) {
      id = id.substring(1);
    }
    if (id.toLowerCase().startsWith('c2c_')) {
      id = id.substring(4);
    }
    final at = id.indexOf('@');
    if (at > 0) {
      id = id.substring(0, at);
    }
    return id.trim().toLowerCase();
  }
}
