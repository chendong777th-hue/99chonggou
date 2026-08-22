import 'dart:collection';

import 'package:flutter/foundation.dart';

/// LRU cache for link/mention **parse products** (flagged strings, URL lists).
///
/// [MessageHyperlinkTextCache] only caches the widget factory; [LinkText] still
/// rebuilt on scroll. Caching the parse output avoids repeating `RegExp.allMatches`.
class LinkTextParseCache {
  LinkTextParseCache._();

  static final LinkTextParseCache instance = LinkTextParseCache._();

  static const int maxEntries = 256;

  final LinkedHashMap<String, String> _flaggedContent =
      LinkedHashMap<String, String>();
  final LinkedHashMap<String, String> _wrappedMentions =
      LinkedHashMap<String, String>();
  final LinkedHashMap<String, List<String>> _urlMatches =
      LinkedHashMap<String, List<String>>();

  @visibleForTesting
  int flaggedHits = 0;

  @visibleForTesting
  int flaggedMisses = 0;

  @visibleForTesting
  int wrappedHits = 0;

  @visibleForTesting
  int wrappedMisses = 0;

  @visibleForTesting
  int urlHits = 0;

  @visibleForTesting
  int urlMisses = 0;

  @visibleForTesting
  void resetStats() {
    flaggedHits = 0;
    flaggedMisses = 0;
    wrappedHits = 0;
    wrappedMisses = 0;
    urlHits = 0;
    urlMisses = 0;
  }

  void clear() {
    _flaggedContent.clear();
    _wrappedMentions.clear();
    _urlMatches.clear();
    resetStats();
  }

  String getFlaggedContent({
    required String text,
    required bool scanMentions,
    required bool webZeroWidthPrefix,
    required String Function() compute,
  }) {
    final key =
        '${webZeroWidthPrefix ? '1' : '0'}|${scanMentions ? '1' : '0'}|$text';
    final hit = _flaggedContent.remove(key);
    if (hit != null) {
      flaggedHits++;
      _flaggedContent[key] = hit;
      return hit;
    }
    flaggedMisses++;
    final value = compute();
    _flaggedContent[key] = value;
    _evict(_flaggedContent);
    return value;
  }

  String getWrappedMentions({
    required String text,
    required String Function() compute,
  }) {
    final hit = _wrappedMentions.remove(text);
    if (hit != null) {
      wrappedHits++;
      _wrappedMentions[text] = hit;
      return hit;
    }
    wrappedMisses++;
    final value = compute();
    _wrappedMentions[text] = value;
    _evict(_wrappedMentions);
    return value;
  }

  List<String> getUrlMatches({
    required String text,
    required List<String> Function() compute,
  }) {
    final hit = _urlMatches.remove(text);
    if (hit != null) {
      urlHits++;
      _urlMatches[text] = hit;
      return hit;
    }
    urlMisses++;
    final value = List<String>.unmodifiable(compute());
    _urlMatches[text] = value;
    _evict(_urlMatches);
    return value;
  }

  void _evict<V>(LinkedHashMap<String, V> map) {
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
  }
}
