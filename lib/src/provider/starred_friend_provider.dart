import 'package:flutter/foundation.dart';

import 'package:tencent_cloud_chat_demo/src/api/starred_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';

class StarredFriendProvider extends ChangeNotifier {
  StarredFriendProvider._() {
    hydrateFromLocalCache();
  }

  static final StarredFriendProvider shared = StarredFriendProvider._();

  final Map<String, DateTime> _starredAt = {};

  bool _loaded = false;
  bool _hydratedFromLocalCache = false;
  bool _refreshInFlight = false;
  String? _activeScope;

  bool get loaded => _loaded;

  Set<String> get starredIds => Set<String>.from(_starredAt.keys);

  bool isStarred(String userId) {
    final id = userId.trim();
    return id.isNotEmpty && _starredAt.containsKey(id);
  }

  DateTime? starredAtOf(String userId) => _starredAt[userId.trim()];

  Future<void> hydrateFromLocalCache() async {
    final scope = ContactSocialCacheStore.accountScope();
    if (ContactSocialCacheStore.consumeScopeInvalidation(scope) ||
        (_activeScope != null && _activeScope != scope)) {
      _starredAt.clear();
      _loaded = false;
      _hydratedFromLocalCache = false;
    }
    _activeScope = scope;
    if (_hydratedFromLocalCache) {
      return;
    }
    _hydratedFromLocalCache = true;
    final cached = await ContactSocialCacheStore.readStarredFriends();
    if (cached.isEmpty) {
      return;
    }
    _starredAt
      ..clear()
      ..addAll(cached);
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh({bool force = false}) async {
    await hydrateFromLocalCache();
    if (_refreshInFlight) {
      return;
    }
    _refreshInFlight = true;
    try {
      final items = await StarredFriendApi.instance.list();
      _starredAt
        ..clear()
        ..addEntries(
          items.map(
            (e) => MapEntry(
              e.friendUserId,
              e.starredAt ?? DateTime.now().toUtc(),
            ),
          ),
        );
      _loaded = true;
      await ContactSocialCacheStore.writeStarredFriends(_starredAt);
      notifyListeners();
    } catch (_) {
      if (!_loaded) {
        _loaded = true;
      }
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> star(String friendUserId) async {
    final id = friendUserId.trim();
    if (id.isEmpty) {
      return;
    }
    final optimisticAt = DateTime.now().toUtc();
    _starredAt[id] = optimisticAt;
    _loaded = true;
    notifyListeners();
    try {
      final result = await StarredFriendApi.instance.star(id);
      _starredAt[id] = result.starredAt ?? optimisticAt;
      await ContactSocialCacheStore.writeStarredFriends(_starredAt);
      notifyListeners();
    } catch (e) {
      _starredAt.remove(id);
      await ContactSocialCacheStore.writeStarredFriends(_starredAt);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unstar(String friendUserId) async {
    final id = friendUserId.trim();
    if (id.isEmpty) {
      return;
    }
    final previous = _starredAt.remove(id);
    notifyListeners();
    try {
      await StarredFriendApi.instance.unstar(id);
      await ContactSocialCacheStore.writeStarredFriends(_starredAt);
      notifyListeners();
    } catch (e) {
      if (previous != null) {
        _starredAt[id] = previous;
      }
      await ContactSocialCacheStore.writeStarredFriends(_starredAt);
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _starredAt.clear();
    _loaded = false;
    _hydratedFromLocalCache = false;
    _activeScope = null;
    notifyListeners();
  }
}
