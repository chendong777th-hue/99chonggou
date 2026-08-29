import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/message_conversation_id.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/archived_conversation_store.dart';

/// 主列表「归档」入口可见性。
///
/// - 不能只用主列表窗内残留行（归档后会 purge，会误藏入口）。
/// - 也不能只认归档 ID 集合非空（脏/孤儿 ID 会让空归档页仍显示入口）。
/// - 以「当前 scope 能解析出至少一条真实会话」为准；ID 新增时先乐观显示，再异步调和。
class ArchivedConversationEntryVisibility {
  ArchivedConversationEntryVisibility._();

  static final ArchivedConversationEntryVisibility instance =
      ArchivedConversationEntryVisibility._();

  static const int _sdkHydrateCap = 8;

  final ValueNotifier<bool> c2cVisible = ValueNotifier<bool>(false);
  final ValueNotifier<bool> groupVisible = ValueNotifier<bool>(false);

  bool _started = false;
  final Map<ConversationArchiveScope, Set<String>> _lastIds =
      <ConversationArchiveScope, Set<String>>{
    ConversationArchiveScope.c2c: <String>{},
    ConversationArchiveScope.group: <String>{},
  };
  final Map<ConversationArchiveScope, int> _reconcileSerial =
      <ConversationArchiveScope, int>{
    ConversationArchiveScope.c2c: 0,
    ConversationArchiveScope.group: 0,
  };
  final Map<ConversationArchiveScope, Timer?> _debounce =
      <ConversationArchiveScope, Timer?>{
    ConversationArchiveScope.c2c: null,
    ConversationArchiveScope.group: null,
  };

  /// 供单测注入：返回某 ID 的会话；`null` 表示 SDK 确认不存在。
  Future<V2TimConversation?> Function(String conversationId)?
      sdkGetConversationForTest;

  /// 供单测注入：跳过真实 LocalStore。
  Future<List<V2TimConversation>> Function(List<String> ids)? localByIdsForTest;

  /// 供单测注入：跳过真实 save。
  Future<void> Function(ConversationArchiveScope scope, Set<String> ids)?
      saveIdsForTest;

  ValueNotifier<bool> notifierFor(ConversationArchiveScope scope) {
    switch (scope) {
      case ConversationArchiveScope.c2c:
        return c2cVisible;
      case ConversationArchiveScope.group:
        return groupVisible;
    }
  }

  bool shouldShow(ConversationArchiveScope scope) => notifierFor(scope).value;

  void ensureStarted() {
    if (_started) {
      return;
    }
    _started = true;
    archivedConversationC2cIDsNotifier.addListener(_onC2cIdsChanged);
    archivedConversationGroupIDsNotifier.addListener(_onGroupIdsChanged);
    _onIdsChanged(ConversationArchiveScope.c2c);
    _onIdsChanged(ConversationArchiveScope.group);
  }

  @visibleForTesting
  void resetForTest() {
    for (final timer in _debounce.values) {
      timer?.cancel();
    }
    if (_started) {
      archivedConversationC2cIDsNotifier.removeListener(_onC2cIdsChanged);
      archivedConversationGroupIDsNotifier.removeListener(_onGroupIdsChanged);
    }
    _started = false;
    c2cVisible.value = false;
    groupVisible.value = false;
    _lastIds[ConversationArchiveScope.c2c] = <String>{};
    _lastIds[ConversationArchiveScope.group] = <String>{};
    _reconcileSerial[ConversationArchiveScope.c2c] = 0;
    _reconcileSerial[ConversationArchiveScope.group] = 0;
    sdkGetConversationForTest = null;
    localByIdsForTest = null;
    saveIdsForTest = null;
  }

  void _onC2cIdsChanged() => _onIdsChanged(ConversationArchiveScope.c2c);

  void _onGroupIdsChanged() => _onIdsChanged(ConversationArchiveScope.group);

  void _onIdsChanged(ConversationArchiveScope scope) {
    final ids = Set<String>.from(
      archivedConversationIDsNotifierFor(scope).value,
    );
    final previous = _lastIds[scope] ?? <String>{};
    final added = ids.difference(previous);
    _lastIds[scope] = ids;

    if (ids.isEmpty) {
      _debounce[scope]?.cancel();
      _debounce[scope] = null;
      notifierFor(scope).value = false;
      return;
    }

    // ID 新增（用户归档 / 远端同步）：先露出入口，避免再等一轮 IO。
    if (added.isNotEmpty) {
      notifierFor(scope).value = true;
    }

    _debounce[scope]?.cancel();
    _debounce[scope] = Timer(const Duration(milliseconds: 120), () {
      _debounce[scope] = null;
      unawaited(reconcile(scope));
    });
  }

  /// 立即调和（可测 / 归档页冷加载后也可调用）。
  Future<void> reconcile(ConversationArchiveScope scope) async {
    final serial = (_reconcileSerial[scope] ?? 0) + 1;
    _reconcileSerial[scope] = serial;
    final ids = Set<String>.from(
      archivedConversationIDsNotifierFor(scope).value,
    );
    if (ids.isEmpty) {
      if (serial == _reconcileSerial[scope]) {
        notifierFor(scope).value = false;
      }
      return;
    }

    List<V2TimConversation> localRows;
    try {
      localRows = await _loadLocal(ids.toList(growable: false));
    } catch (e, st) {
      debugPrint('ArchivedEntryVisibility local probe failed: $e\n$st');
      // 本地探测失败时保持现状，避免误藏。
      return;
    }
    if (serial != _reconcileSerial[scope]) {
      return;
    }

    final foundIds = <String>{};
    for (final row in localRows) {
      final id = row.conversationID.trim();
      if (id.isNotEmpty) {
        foundIds.add(id);
      }
    }

    final missing = ids
        .where(
          (id) => !foundIds.any(
            (f) => MessageConversationId.sameConversation(f, id),
          ),
        )
        .toList(growable: false);

    if (missing.isEmpty) {
      notifierFor(scope).value = true;
      return;
    }

    final hydrate = await _hydrateMissing(missing);
    if (serial != _reconcileSerial[scope]) {
      return;
    }
    for (final row in hydrate.found) {
      final id = row.conversationID.trim();
      if (id.isNotEmpty) {
        foundIds.add(id);
      }
    }

    if (foundIds.isNotEmpty) {
      notifierFor(scope).value = true;
      if (hydrate.confirmedMissing.isNotEmpty) {
        await _pruneOrphans(
          scope,
          keep: foundIds,
          orphans: hydrate.confirmedMissing,
        );
      }
      return;
    }

    // 全部无法解析：隐藏入口；仅清理 SDK 明确不存在的孤儿。
    notifierFor(scope).value = false;
    if (hydrate.confirmedMissing.isNotEmpty) {
      await _pruneOrphans(
        scope,
        keep: foundIds,
        orphans: hydrate.confirmedMissing,
      );
    }
  }

  Future<List<V2TimConversation>> _loadLocal(List<String> ids) {
    final override = localByIdsForTest;
    if (override != null) {
      return override(ids);
    }
    return ConversationLocalStore.instance.conversationsByIds(
      ids,
      caller: 'archive_entry_visibility',
    );
  }

  Future<({List<V2TimConversation> found, List<String> confirmedMissing})>
      _hydrateMissing(List<String> missing) async {
    if (missing.isEmpty) {
      return (
        found: const <V2TimConversation>[],
        confirmedMissing: const <String>[],
      );
    }
    final take = missing.length > _sdkHydrateCap
        ? missing.sublist(0, _sdkHydrateCap)
        : missing;
    final found = <V2TimConversation>[];
    final confirmedMissing = <String>[];
    for (final id in take) {
      try {
        final conversation = await _getConversation(id);
        if (conversation == null) {
          confirmedMissing.add(id);
          continue;
        }
        if (localByIdsForTest == null) {
          await ConversationSyncService.instance
              .commitSdkHydratedConversations(<V2TimConversation>[
            conversation,
          ]);
        }
        found.add(conversation);
      } catch (e) {
        debugPrint('ArchivedEntryVisibility hydrate failed: $id $e');
        // 网络/SDK 异常：中止后续，已确认的 missing 仍可清。
        break;
      }
    }
    return (found: found, confirmedMissing: confirmedMissing);
  }

  Future<V2TimConversation?> _getConversation(String conversationId) async {
    final override = sdkGetConversationForTest;
    if (override != null) {
      return override(conversationId);
    }
    setupServiceLocator();
    return serviceLocator<ConversationService>().getConversation(
      conversationID: conversationId,
    );
  }

  Future<void> _pruneOrphans(
    ConversationArchiveScope scope, {
    required Set<String> keep,
    required List<String> orphans,
  }) async {
    if (orphans.isEmpty) {
      return;
    }
    final current = archivedConversationIDsNotifierFor(scope).value;
    final next = <String>{
      for (final id in current)
        if (!orphans.any(
          (o) => MessageConversationId.sameConversation(o, id),
        ))
          id,
      ...keep,
    };
    // 若 keep 用的是另一套 ID 形态，合并去重。
    final normalized = <String>{};
    for (final id in next) {
      final trimmed = id.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      if (normalized.any(
        (n) => MessageConversationId.sameConversation(n, trimmed),
      )) {
        continue;
      }
      normalized.add(trimmed);
    }
    if (normalized.length == current.length &&
        normalized.every(
          (id) => current.any(
            (c) => MessageConversationId.sameConversation(c, id),
          ),
        )) {
      return;
    }
    final save = saveIdsForTest;
    if (save != null) {
      await save(scope, normalized);
    } else {
      await saveArchivedConversationIDs(scope, normalized);
    }
    debugPrint(
      'ArchivedEntryVisibility pruned orphans scope=$scope '
      'removed=${orphans.length} remain=${normalized.length}',
    );
  }
}
