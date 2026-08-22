import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/me_friend_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/c2c_friend_message_guard_bridge.dart';

enum C2cSendPermissionDecision {
  allowed,
  blocked,
  unknown,
}

class C2cUiPermissionSnapshot {
  const C2cUiPermissionSnapshot({
    required this.decision,
    required this.relationConfirmed,
  });

  final C2cSendPermissionDecision decision;
  final bool relationConfirmed;
}

class C2cFriendMessageGuard {
  C2cFriendMessageGuard._();

  static const String becameFriendsTrustSource = 'became_friends';

  static final Map<String, _PermissionCacheEntry> _permissionCache = {};
  static final Map<String, Future<C2cSendPermissionDecision>> _inflightFetches =
      {};
  static final Map<String, _TrustedAllowHint> _trustedAllowHints = {};

  static const Duration _positiveTtl = Duration(seconds: 8);
  static const Duration _negativeTtl = Duration(seconds: 2);
  static const Duration _trustedAllowHintTtl = Duration(seconds: 30);

  /// Authoritative C2C send permission check.
  ///
  /// Unknown (timeout / no cache / no trust) returns true so IM SDK can send;
  /// only an explicit blocked decision fails closed.
  static Future<bool> canSendTo(String peerUserId) async {
    final decision = await _resolveDecision(peerUserId, forceNetwork: false);
    return sdkAllowsSend(decision);
  }

  /// Three-state check for the UIKit send bridge.
  static Future<C2cSendCheckResult> checkSend(String peerUserId) async {
    final decision = await _resolveDecision(peerUserId, forceNetwork: false);
    return _toUikit(decision);
  }

  /// Refresh from server with in-flight de-duplication.
  static Future<bool> refreshAndCanSendTo(
    String peerUserId, {
    bool forceNetwork = false,
  }) async {
    final decision =
        await _resolveDecision(peerUserId, forceNetwork: forceNetwork);
    return sdkAllowsSend(decision);
  }

  static Future<C2cUiPermissionSnapshot> refreshUiSnapshot(
    String peerUserId, {
    bool forceNetwork = false,
  }) async {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: false,
      );
    }

    if (!forceNetwork) {
      final cached = _uiSnapshotFromCache(id);
      if (cached != null) {
        return cached;
      }
    }

    final relation = await MeFriendApi.instance.tryFetchRelation(id);
    if (relation != null) {
      final canSend = await _applyRelationResult(id, relation);
      return C2cUiPermissionSnapshot(
        decision: canSend
            ? C2cSendPermissionDecision.allowed
            : C2cSendPermissionDecision.blocked,
        relationConfirmed: true,
      );
    }

    final local = await MeFriendApi.instance.cachedByUserId(id);
    if (local != null) {
      final canSend = _preferTrustOverNegative(id, local.canMessage);
      _permissionCache[id] = _PermissionCacheEntry(
        canSend,
        fromRelation: false,
      );
      if (canSend) {
        return const C2cUiPermissionSnapshot(
          decision: C2cSendPermissionDecision.allowed,
          relationConfirmed: false,
        );
      }
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.unknown,
        relationConfirmed: false,
      );
    }

    if (hasFreshTrustedCanSendHint(id)) {
      _permissionCache[id] = _PermissionCacheEntry(true, fromRelation: false);
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: false,
      );
    }

    return const C2cUiPermissionSnapshot(
      decision: C2cSendPermissionDecision.unknown,
      relationConfirmed: false,
    );
  }

  /// UI-only silent permission refresh.
  static Future<bool?> refreshCanSendToForUi(
    String peerUserId, {
    bool forceNetwork = false,
  }) async {
    final snapshot = await refreshUiSnapshot(
      peerUserId,
      forceNetwork: forceNetwork,
    );
    return uiCanSend(snapshot.decision);
  }

  static void invalidate(
    String peerUserId, {
    bool clearTrusted = false,
  }) {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return;
    }
    _permissionCache.remove(id);
    _inflightFetches.remove(id);
    if (clearTrusted) {
      _trustedAllowHints.remove(id);
    }
  }

  static void clearTrustedHint(String peerUserId) {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return;
    }
    _trustedAllowHints.remove(id);
  }

  static void trustCanSendHint(
    String peerUserId, {
    String source = '',
    Duration ttl = _trustedAllowHintTtl,
  }) {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return;
    }
    _trustedAllowHints[id] = _TrustedAllowHint(
      source: source,
      ttl: ttl,
    );
    _permissionCache[id] = _PermissionCacheEntry(true, fromRelation: false);
  }

  static bool hasFreshTrustedCanSendHint(String peerUserId) {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return true;
    }
    final hint = _trustedAllowHints[id];
    if (hint == null) {
      return false;
    }
    if (hint.isFresh) {
      return true;
    }
    _trustedAllowHints.remove(id);
    return false;
  }

  static Future<void> refreshRelation(String peerUserId) async {
    await refreshAndCanSendTo(peerUserId, forceNetwork: true);
  }

  static bool? cachedCanSendToSync(String peerUserId) {
    final snapshot = cachedUiSnapshot(peerUserId);
    if (snapshot == null) {
      return null;
    }
    return uiCanSend(snapshot.decision);
  }

  static C2cUiPermissionSnapshot? cachedUiSnapshot(String peerUserId) {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: false,
      );
    }
    return _uiSnapshotFromCache(id);
  }

  static void clearSession() {
    debugReset();
  }

  @visibleForTesting
  static void debugReset() {
    _permissionCache.clear();
    _inflightFetches.clear();
    _trustedAllowHints.clear();
  }

  @visibleForTesting
  static int debugTrustedHintCount() => _trustedAllowHints.length;

  @visibleForTesting
  static bool resolveCanSendWithTrust({
    required bool relationCanMessage,
    required bool hasFreshTrust,
  }) {
    if (relationCanMessage) {
      return true;
    }
    return hasFreshTrust;
  }

  @visibleForTesting
  static C2cSendPermissionDecision resolveDecision({
    bool? relationCanMessage,
    bool? localCanMessage,
    required bool hasFreshTrust,
    required bool lookupFailed,
  }) {
    if (relationCanMessage != null) {
      if (relationCanMessage || hasFreshTrust) {
        return C2cSendPermissionDecision.allowed;
      }
      return C2cSendPermissionDecision.blocked;
    }
    if (localCanMessage != null) {
      if (localCanMessage || hasFreshTrust) {
        return C2cSendPermissionDecision.allowed;
      }
      return C2cSendPermissionDecision.unknown;
    }
    if (hasFreshTrust) {
      return C2cSendPermissionDecision.allowed;
    }
    if (lookupFailed) {
      return C2cSendPermissionDecision.unknown;
    }
    return C2cSendPermissionDecision.unknown;
  }

  @visibleForTesting
  static C2cUiPermissionSnapshot resolveUiSnapshot({
    bool? relationCanMessage,
    bool? localCanMessage,
    required bool hasFreshTrust,
    required bool lookupFailed,
  }) {
    if (relationCanMessage != null) {
      if (relationCanMessage || hasFreshTrust) {
        return const C2cUiPermissionSnapshot(
          decision: C2cSendPermissionDecision.allowed,
          relationConfirmed: true,
        );
      }
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.blocked,
        relationConfirmed: true,
      );
    }
    if (hasFreshTrust) {
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: false,
      );
    }
    if (localCanMessage == true) {
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: false,
      );
    }
    return const C2cUiPermissionSnapshot(
      decision: C2cSendPermissionDecision.unknown,
      relationConfirmed: false,
    );
  }

  @visibleForTesting
  static bool sdkAllowsSend(C2cSendPermissionDecision decision) {
    return decision != C2cSendPermissionDecision.blocked;
  }

  @visibleForTesting
  static bool? uiCanSend(C2cSendPermissionDecision decision) {
    switch (decision) {
      case C2cSendPermissionDecision.allowed:
        return true;
      case C2cSendPermissionDecision.blocked:
        return false;
      case C2cSendPermissionDecision.unknown:
        return null;
    }
  }

  static C2cSendCheckResult _toUikit(C2cSendPermissionDecision decision) {
    switch (decision) {
      case C2cSendPermissionDecision.allowed:
        return C2cSendCheckResult.allowed;
      case C2cSendPermissionDecision.blocked:
        return C2cSendCheckResult.blocked;
      case C2cSendPermissionDecision.unknown:
        return C2cSendCheckResult.unknown;
    }
  }

  static C2cUiPermissionSnapshot? _uiSnapshotFromCache(String id) {
    final cached = _permissionCache[id];
    if (cached == null || !cached.isFresh) {
      return null;
    }
    final canSend = _preferTrustOverNegative(id, cached.canSend);
    if (canSend) {
      return C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.allowed,
        relationConfirmed: cached.fromRelation,
      );
    }
    if (cached.fromRelation) {
      return const C2cUiPermissionSnapshot(
        decision: C2cSendPermissionDecision.blocked,
        relationConfirmed: true,
      );
    }
    return null;
  }

  static Future<C2cSendPermissionDecision> _resolveDecision(
    String peerUserId, {
    required bool forceNetwork,
  }) async {
    final id = _normalizePeerId(peerUserId);
    if (id == null) {
      return C2cSendPermissionDecision.allowed;
    }

    final cached = _permissionCache[id];
    if (!forceNetwork && cached != null && cached.isFresh) {
      if (_preferTrustOverNegative(id, cached.canSend)) {
        return C2cSendPermissionDecision.allowed;
      }
      if (cached.fromRelation) {
        return C2cSendPermissionDecision.blocked;
      }
      return C2cSendPermissionDecision.unknown;
    }

    final inflight = _inflightFetches[id];
    if (inflight != null) {
      return inflight;
    }

    final future = _fetchDecision(id);
    _inflightFetches[id] = future;
    try {
      return await future;
    } finally {
      if (identical(_inflightFetches[id], future)) {
        _inflightFetches.remove(id);
      }
    }
  }

  static Future<C2cSendPermissionDecision> _fetchDecision(String id) async {
    final relation = await MeFriendApi.instance.tryFetchRelation(id);
    if (relation != null) {
      final canSend = await _applyRelationResult(id, relation);
      return canSend
          ? C2cSendPermissionDecision.allowed
          : C2cSendPermissionDecision.blocked;
    }

    final cached = await MeFriendApi.instance.cachedByUserId(id);
    if (cached != null) {
      final canSend = _preferTrustOverNegative(id, cached.canMessage);
      _permissionCache[id] = _PermissionCacheEntry(
        canSend,
        fromRelation: false,
      );
      return canSend
          ? C2cSendPermissionDecision.allowed
          : C2cSendPermissionDecision.unknown;
    }

    if (hasFreshTrustedCanSendHint(id)) {
      _permissionCache[id] = _PermissionCacheEntry(true, fromRelation: false);
      return C2cSendPermissionDecision.allowed;
    }

    return C2cSendPermissionDecision.unknown;
  }

  static Future<bool> _applyRelationResult(
    String id,
    FriendRelation relation,
  ) async {
    final trusted = hasFreshTrustedCanSendHint(id);
    final canSend = resolveCanSendWithTrust(
      relationCanMessage: relation.canMessage,
      hasFreshTrust: trusted,
    );
    await _patchLocalRelation(
      relation,
      preserveOptimisticCanMessage: trusted && !relation.canMessage,
    );
    _permissionCache[id] = _PermissionCacheEntry(
      canSend,
      fromRelation: true,
    );
    return canSend;
  }

  static bool _preferTrustOverNegative(String id, bool canSend) {
    if (canSend) {
      return true;
    }
    return hasFreshTrustedCanSendHint(id);
  }

  static String? _normalizePeerId(String peerUserId) {
    var trimmed = peerUserId.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.toLowerCase().startsWith('c2c_')) {
      trimmed = trimmed.substring(4).trim();
    }
    // 群/社群 ID 不进 C2C 权限槽。不能用 rawUserUid.isEmpty：
    // 含大写的 99 号 UID 会被当成社群短码而误伤。
    if (trimmed.toLowerCase().startsWith('group_') ||
        trimmed.toUpperCase().contains('TGS#')) {
      return null;
    }
    final id = ChatIdFormat.canonicalC2cUserId(peerUserId);
    if (id.isEmpty) {
      return null;
    }
    if (PlatformOfficialAccountService.isPlatformOfficialAccount(id)) {
      return null;
    }
    return id;
  }

  static Future<void> _patchLocalRelation(
    FriendRelation relation, {
    bool preserveOptimisticCanMessage = false,
  }) async {
    final id = ChatIdFormat.canonicalC2cUserId(relation.peerUserId);
    if (id.isEmpty) {
      return;
    }

    final owner = FriendLocalStore.instance.currentOwnerUserId();
    if (owner.isEmpty) {
      return;
    }

    final existing = await MeFriendApi.instance.cachedByUserId(id);
    if (existing != null) {
      await FriendLocalStore.instance.patch(
        ownerUserId: owner,
        friendUserId: id,
        transform: (current) => current.copyWith(
          canMessage: preserveOptimisticCanMessage
              ? current.canMessage
              : relation.canMessage,
          peerDeletedMe: relation.peerDeletedMe,
          inMyFriendList: relation.inMyFriendList,
          isFriend: relation.isFriend,
        ),
      );
      return;
    }

    if (relation.canMessage || relation.inMyFriendList || relation.isFriend) {
      await FriendLocalStore.instance.upsert(
        ownerUserId: owner,
        record: MeFriendRecord(
          friendUserId: id,
          remark: '',
          friendNickname: '',
          friendAvatarUrl: '',
          addedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          peerDeletedMe: relation.peerDeletedMe,
          canMessage: preserveOptimisticCanMessage ? true : relation.canMessage,
          inMyFriendList: relation.inMyFriendList,
          isFriend: relation.isFriend,
        ),
      );
    }
  }
}

class _TrustedAllowHint {
  _TrustedAllowHint({
    required this.source,
    required this.ttl,
  }) : createdAt = DateTime.now();

  final String source;
  final Duration ttl;
  final DateTime createdAt;

  bool get isFresh => DateTime.now().difference(createdAt) < ttl;
}

class _PermissionCacheEntry {
  _PermissionCacheEntry(
    this.canSend, {
    required this.fromRelation,
  }) : createdAt = DateTime.now();

  final bool canSend;
  final bool fromRelation;
  final DateTime createdAt;

  bool get isFresh {
    final ttl = canSend
        ? C2cFriendMessageGuard._positiveTtl
        : C2cFriendMessageGuard._negativeTtl;
    return DateTime.now().difference(createdAt) < ttl;
  }
}
