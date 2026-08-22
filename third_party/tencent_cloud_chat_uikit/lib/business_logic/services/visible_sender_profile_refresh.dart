import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/profile/user_profile_local_bridge.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

/// Lazy-refresh public nick/avatar for senders built by the chat message list.
///
/// Cost scales with unique near-visible senders (builder + cacheExtent), never
/// with total group member count. Do not use for full-group fan-out.
class VisibleSenderProfileRefresh {
  VisibleSenderProfileRefresh._();

  static const bool enabled = true;
  static const Duration ttl = Duration(minutes: 10);
  static const Duration debounce = Duration(milliseconds: 400);
  static const Duration continueDelay = Duration(milliseconds: 200);
  static const int maxPerFlush = 25;

  static final Set<String> _pending = <String>{};
  static final Map<String, int> _lastLiveRefreshMs = <String, int>{};
  static Timer? _debounceTimer;
  static Timer? _continueTimer;
  static bool _flushInFlight = false;

  /// Enqueue a sender seen while building a message row (group chats).
  static void noteSender(String? userId, {String? selfUserId}) {
    if (!enabled) {
      return;
    }
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return;
    }
    final self = selfUserId?.trim() ?? '';
    if (self.isNotEmpty && id == self) {
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = _lastLiveRefreshMs[id] ?? 0;
    if (now - last < ttl.inMilliseconds) {
      return;
    }
    _pending.add(id);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () {
      unawaited(_flush());
    });
  }

  static void cancelPending() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _continueTimer?.cancel();
    _continueTimer = null;
    _pending.clear();
  }

  @visibleForTesting
  static void resetForTest() {
    cancelPending();
    _lastLiveRefreshMs.clear();
    _flushInFlight = false;
  }

  @visibleForTesting
  static List<String> selectIdsForFlush({
    required Iterable<String> pending,
    required Map<String, int> lastRefreshMs,
    required int nowMs,
    required int ttlMs,
    required int maxPerFlush,
    required String? selfUserId,
  }) {
    final self = selfUserId?.trim() ?? '';
    final out = <String>[];
    for (final raw in pending) {
      final id = raw.trim();
      if (id.isEmpty) {
        continue;
      }
      if (self.isNotEmpty && id == self) {
        continue;
      }
      final last = lastRefreshMs[id] ?? 0;
      if (nowMs - last < ttlMs) {
        continue;
      }
      out.add(id);
      if (out.length >= maxPerFlush) {
        break;
      }
    }
    return out;
  }

  static Future<void> _flush() async {
    if (_flushInFlight) {
      return;
    }
    if (_pending.isEmpty) {
      return;
    }
    _flushInFlight = true;
    try {
      final self =
          TIMUIKitCore.getInstance().loginUserInfo?.userID?.trim() ?? '';
      final now = DateTime.now().millisecondsSinceEpoch;
      final chunk = selectIdsForFlush(
        pending: _pending,
        lastRefreshMs: _lastLiveRefreshMs,
        nowMs: now,
        ttlMs: ttl.inMilliseconds,
        maxPerFlush: maxPerFlush,
        selfUserId: self,
      );
      for (final id in chunk) {
        _pending.remove(id);
      }
      // Drop TTL-fresh leftovers so they do not loop forever.
      _pending.removeWhere((id) {
        final last = _lastLiveRefreshMs[id] ?? 0;
        return now - last < ttl.inMilliseconds;
      });
      if (chunk.isEmpty) {
        return;
      }
      if (!UserProfileLocalBridge.enabled) {
        // Still mark TTL so we do not retry every scroll while bridge is down.
        for (final id in chunk) {
          _lastLiveRefreshMs[id] = now;
        }
        return;
      }
      try {
        final res = await TIMUIKitCore.getSDKInstance().getUsersInfo(
          userIDList: chunk,
        );
        final users = res.code == 0 ? res.data : null;
        if (users != null) {
          for (final info in users) {
            final uid = info.userID?.trim() ?? '';
            if (uid.isEmpty) {
              continue;
            }
            await UserProfileLocalBridge.saveUserInfo(
              V2TimUserFullInfo(
                userID: uid,
                nickName: info.nickName,
                faceUrl: info.faceUrl,
              ),
            );
            _lastLiveRefreshMs[uid] = DateTime.now().millisecondsSinceEpoch;
          }
        }
        // Mark requested IDs even if SDK omitted some, to avoid hammering.
        final refreshedAt = DateTime.now().millisecondsSinceEpoch;
        for (final id in chunk) {
          _lastLiveRefreshMs.putIfAbsent(id, () => refreshedAt);
        }
      } catch (_) {
        final failedAt = DateTime.now().millisecondsSinceEpoch;
        for (final id in chunk) {
          _lastLiveRefreshMs.putIfAbsent(id, () => failedAt);
        }
      }
    } finally {
      _flushInFlight = false;
      if (_pending.isNotEmpty) {
        _continueTimer?.cancel();
        _continueTimer = Timer(continueDelay, () {
          unawaited(_flush());
        });
      }
    }
  }
}
