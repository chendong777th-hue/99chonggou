import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/im_snapshot_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/message_archive_history_service.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 登录冷启优先补最近 C2C：后端 Snapshot + SDK by-ids 补未读等。
/// Snapshot 只负责先上屏，群会话和完整游标仍由 SDK paced sync 接管。
class ImSnapshotBootstrapService {
  ImSnapshotBootstrapService._();

  static final ImSnapshotBootstrapService instance =
      ImSnapshotBootstrapService._();

  ConversationService get _conversationService =>
      serviceLocator<ConversationService>();

  bool _inFlight = false;
  int _loginBootstrapGateDepth = 0;

  bool get isBootstrapInFlight => _inFlight;

  /// Stage1 / AuthBootstrap 整段会话预热期间抑制 UIKit 大批落库抢跑。
  bool get shouldSuppressViewModelPersist =>
      _inFlight || _loginBootstrapGateDepth > 0;

  void beginLoginBootstrapGate() {
    _loginBootstrapGateDepth++;
  }

  void endLoginBootstrapGate() {
    if (_loginBootstrapGateDepth > 0) {
      _loginBootstrapGateDepth--;
    }
  }

  /// 兼容旧名：登录暖窗（有库也走）。
  Future<bool> tryBootstrapEmptyStore({required String ownerUserId}) {
    return tryBootstrapOnLogin(ownerUserId: ownerUserId);
  }

  /// 成功上屏返回 `true`；失败/空列表返回 `false`（调用方走腾讯分页降级）。
  Future<bool> tryBootstrapOnLogin({required String ownerUserId}) async {
    final owner = ChatIdFormat.rawUserUid(ownerUserId);
    if (owner.isEmpty) {
      return false;
    }
    if (_inFlight) {
      _log('snapshot bootstrap skipped (already in flight)');
      return false;
    }
    _inFlight = true;
    try {
      final rowCountBefore =
          await ConversationLocalStore.instance.countRows(ownerUserId: owner);
      final syncMetaBefore = await ConversationLocalStore.instance
          .readSyncMeta(ownerUserId: owner);
      _log(
        'snapshot bootstrap start owner=$owner rowsBefore=$rowCountBefore',
      );
      final snap = await _fetchWithRateLimitRetry();
      if (snap == null || snap.conversations.isEmpty) {
        _log('snapshot empty or null → fallback');
        return false;
      }
      if (!_isCurrentOwner(owner)) {
        _log('snapshot discarded after account changed owner=$owner');
        return false;
      }

      final priorityRows = selectPriorityC2cConversations(
        snap.conversations,
        limit: ConversationPerfFlags.snapshotPriorityC2cLimit,
      );
      if (priorityRows.isEmpty) {
        _log('snapshot has no C2C rows → fallback');
        return false;
      }

      final ids = priorityRows
          .map((c) => c.conversationId.trim())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      final sdkList = ids.isEmpty
          ? const <V2TimConversation>[]
          : await _conversationService.getConversationListByConversationIds(
              conversationIDList: ids,
            );
      final sdkById = <String, V2TimConversation>{};
      for (final c in sdkList) {
        final id = c.conversationID.trim();
        if (id.isNotEmpty) {
          sdkById[id] = c;
        }
      }

      final localById = <String, V2TimConversation>{};
      final localList =
          await ConversationLocalStore.instance.conversationsByIds(
        ids,
        ownerUserId: owner,
      );
      for (final local in localList) {
        final id = local.conversationID.trim();
        if (id.isNotEmpty) {
          localById[id] = local;
        }
      }

      final merged = <V2TimConversation>[];
      for (final row in priorityRows) {
        final shell = buildShellConversation(row, loginUserId: owner);
        final id = row.conversationId.trim();
        final combined = mergeSnapshotWithSdk(
          shell: shell,
          sdk: sdkById[id],
          local: localById[id],
        );
        merged.add(combined);
      }
      if (merged.isEmpty) {
        return false;
      }
      if (!_isCurrentOwner(owner)) {
        _log('snapshot commit skipped after account changed owner=$owner');
        return false;
      }

      await ConversationLocalStore.instance.upsertBatch(
        conversations: merged,
        ownerUserId: owner,
      );
      await _writeSyncMetaAfterSnapshot(
        ownerUserId: owner,
        rowCountBefore: rowCountBefore,
        existing: syncMetaBefore,
      );
      await ConversationListNotifier.instance.reloadFromLocal();
      unawaited(
        ConversationSyncService.instance.syncFromSdk(
          reason: 'bootstrap_snapshot_followup',
          reset: !syncMetaBefore.hasSyncedOnce || rowCountBefore == 0,
          drainMode: ConversationSdkDrainMode.foregroundLimited,
          reloadUiEachPage: false,
        ),
      );
      _log(
        'snapshot bootstrap ok priorityC2c=${merged.length} '
        'sdkHit=${sdkById.length} localHit=${localById.length} '
        'rowsBefore=$rowCountBefore degraded=${snap.degraded} '
        'sdkFollowUp=scheduled',
      );
      return true;
    } catch (e, st) {
      _log('snapshot bootstrap failed: $e');
      if (kDebugMode) {
        debugPrint('ImSnapshotBootstrap: $st');
      }
      return false;
    } finally {
      _inFlight = false;
    }
  }

  /// 部分 C2C 快照不能冒充 SDK 已同步；空库保留冷启动游标，有库保留原游标。
  Future<void> _writeSyncMetaAfterSnapshot({
    required String ownerUserId,
    required int rowCountBefore,
    required ConversationSyncMeta existing,
  }) async {
    if (rowCountBefore <= 0 || !existing.hasSyncedOnce) {
      await ConversationLocalStore.instance.writeSyncMeta(
        meta: const ConversationSyncMeta(),
        ownerUserId: ownerUserId,
      );
      return;
    }
    await ConversationLocalStore.instance.writeSyncMeta(
      meta: ConversationSyncMeta(
        nextSeq: existing.nextSeq,
        haveMore: existing.haveMore,
        hasSyncedOnce: existing.hasSyncedOnce,
      ),
      ownerUserId: ownerUserId,
    );
  }

  Future<ImSnapshotResponse?> _fetchWithRateLimitRetry() async {
    try {
      return await ImSnapshotApi.instance.fetch(
        limitC2c: ConversationPerfFlags.snapshotPriorityC2cLimit,
        limitGroup: ConversationPerfFlags.snapshotRequestGroupFloor,
        limitMsg: ConversationPerfFlags.snapshotRequestMessageFloor,
      );
    } on ImSnapshotApiException catch (e) {
      if (!e.isRateLimited) {
        _log('snapshot api error: $e');
        return null;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        return await ImSnapshotApi.instance.fetch(
          limitC2c: ConversationPerfFlags.snapshotPriorityC2cLimit,
          limitGroup: ConversationPerfFlags.snapshotRequestGroupFloor,
          limitMsg: ConversationPerfFlags.snapshotRequestMessageFloor,
        );
      } on ImSnapshotApiException catch (e2) {
        _log('snapshot retry failed: $e2');
        return null;
      }
    } catch (e) {
      _log('snapshot fetch failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static List<ImSnapshotConversation> selectPriorityC2cConversations(
    List<ImSnapshotConversation> conversations, {
    required int limit,
  }) {
    if (limit <= 0 || conversations.isEmpty) {
      return const <ImSnapshotConversation>[];
    }
    final out = <ImSnapshotConversation>[];
    for (final row in conversations) {
      final id = row.conversationId.trim();
      final isC2c = row.chatType.trim().toLowerCase() == 'c2c' ||
          id.toLowerCase().startsWith('c2c_');
      if (id.isEmpty || !isC2c) {
        continue;
      }
      out.add(row);
      if (out.length >= limit) {
        break;
      }
    }
    return out;
  }

  bool _isCurrentOwner(String owner) {
    final current = ChatIdFormat.rawUserUid(
      ContactSocialCacheStore.safeLoginUserId(),
    );
    return current.isNotEmpty && current == owner;
  }

  @visibleForTesting
  static V2TimConversation buildShellConversation(
    ImSnapshotConversation row, {
    required String loginUserId,
  }) {
    final id = row.conversationId.trim();
    final isGroup =
        row.chatType == 'group' || id.toLowerCase().startsWith('group_');
    final peer = row.peerId.trim().isNotEmpty
        ? row.peerId.trim()
        : (isGroup
            ? (id.toLowerCase().startsWith('group_') ? id.substring(6) : id)
            : (id.toLowerCase().startsWith('c2c_') ? id.substring(4) : id));
    final shell = isGroup
        ? V2TimConversation(
            conversationID: id.startsWith('group_') ? id : 'group_$peer',
            type: 2,
            groupID: peer,
            showName: peer,
          )
        : V2TimConversation(
            conversationID: id.startsWith('c2c_') ? id : 'c2c_$peer',
            type: 1,
            userID: peer,
            showName: peer,
          );
    final last = row.lastMessage;
    if (last != null) {
      final req = ArchiveHistoryRequest(
        isGroup: isGroup,
        conversationID: peer,
        loginUserID: loginUserId,
        count: 1,
      );
      shell.lastMessage = MessageArchiveHistoryService.convertItem(
        snapshotMessageToHistoryItem(last),
        req,
      );
    }
    // 无 SDK 时默认 0；有本地时由 merge 保留本地未读。禁止 Snapshot 无字段覆盖。
    shell.unreadCount = 0;
    return shell;
  }

  @visibleForTesting
  static V2TimConversation mergeSnapshotWithSdk({
    required V2TimConversation shell,
    V2TimConversation? sdk,
    V2TimConversation? local,
  }) {
    if (sdk != null) {
      shell.showName = (sdk.showName?.trim().isNotEmpty == true)
          ? sdk.showName
          : shell.showName;
      shell.faceUrl = sdk.faceUrl ?? shell.faceUrl;
      shell.draftText = sdk.draftText;
      shell.draftTimestamp = sdk.draftTimestamp;
      shell.isPinned = sdk.isPinned;
      shell.recvOpt = sdk.recvOpt;
      // 未读只信 SDK（含 0）。
      shell.unreadCount = sdk.unreadCount ?? 0;
      shell.orderkey = sdk.orderkey ?? shell.orderkey;
      shell.groupType = sdk.groupType ?? shell.groupType;
      shell.groupAtInfoList = sdk.groupAtInfoList ?? shell.groupAtInfoList;
      shell.lastMessage = pickFresherLastMessage(
        snapshot: shell.lastMessage,
        sdk: sdk.lastMessage,
      );
      return shell;
    }
    if (local != null) {
      // 无 SDK：保留本地未读/展示名等；预览取 Snapshot 与本地较新者。
      shell.unreadCount = local.unreadCount ?? 0;
      shell.showName = (local.showName?.trim().isNotEmpty == true)
          ? local.showName
          : shell.showName;
      shell.faceUrl = local.faceUrl ?? shell.faceUrl;
      shell.recvOpt = local.recvOpt ?? shell.recvOpt;
      shell.orderkey = local.orderkey ?? shell.orderkey;
      shell.lastMessage = pickFresherLastMessage(
        snapshot: shell.lastMessage,
        sdk: local.lastMessage,
      );
      return shell;
    }
    return shell;
  }

  @visibleForTesting
  static V2TimMessage? pickFresherLastMessage({
    V2TimMessage? snapshot,
    V2TimMessage? sdk,
  }) {
    if (snapshot == null) {
      return sdk;
    }
    if (sdk == null) {
      return snapshot;
    }
    final snapTs = snapshot.timestamp ?? 0;
    final sdkTs = sdk.timestamp ?? 0;
    if (sdkTs > snapTs) {
      return sdk;
    }
    if (snapTs > sdkTs) {
      return snapshot;
    }
    // 平局偏 SDK。
    return sdk;
  }

  @visibleForTesting
  static Map<String, dynamic> snapshotMessageToHistoryItem(
    ImSnapshotMessage message,
  ) {
    final keyRaw = message.msgKey?.trim() ?? '';
    final msgKey = keyRaw.isNotEmpty ? keyRaw : (message.msgId?.trim() ?? '');
    final timeSec = message.time ?? 0;
    var body = List<dynamic>.from(message.msgBody);
    if (body.isEmpty && (message.type?.trim().isNotEmpty == true)) {
      final type = message.type!.trim();
      if (type == 'TIMTextElem') {
        body = <dynamic>[
          <String, dynamic>{
            'MsgType': type,
            'MsgContent': <String, dynamic>{
              'Text': message.text ?? '',
            },
          },
        ];
      } else {
        body = <dynamic>[
          <String, dynamic>{
            'MsgType': type,
            'MsgContent': <String, dynamic>{},
          },
        ];
      }
    }
    return <String, dynamic>{
      'msgKey': msgKey,
      'msgId': message.msgId,
      'fromAccount': message.sender,
      'msgTimeMs': timeSec > 0 ? timeSec * 1000 : 0,
      'msgSeq': message.seq,
      'status': message.status ?? 1,
      'previewText': message.text ?? '',
      'msgBody': body,
    };
  }

  void _log(String message) {
    debugPrint('ImSnapshotBootstrap: $message');
  }
}
