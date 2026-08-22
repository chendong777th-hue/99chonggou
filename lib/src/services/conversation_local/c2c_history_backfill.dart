import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';
import 'package:tencent_cloud_chat_demo/src/utils/archived_conversation_ref.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// C2C「有过会话记录 → 补壳」候选与结果（纯逻辑可单测）。
class C2cHistoryBackfill {
  C2cHistoryBackfill._();

  /// 是否在本轮补壳中扫描好友/置顶（纯门闩，可单测）。
  ///
  /// [floor] `<=0`：仅 [localC2c]==0 时扫（旧行为）。
  /// [floor] `>0`：`localC2c < floor` 且尚未 [friendScanDone] 时扫。
  static bool shouldRunFriendScan({
    required int localC2c,
    required int floor,
    required bool friendScanDone,
  }) {
    if (friendScanDone) {
      return false;
    }
    if (localC2c < 0) {
      return false;
    }
    if (floor <= 0) {
      return localC2c == 0;
    }
    return localC2c < floor;
  }

  /// 合并好友 / 置顶 / 额外 ID，去掉已在本地的，按 [maxPeers] 截断。
  static List<String> selectCandidateConversationIds({
    required Iterable<String> friendUserIds,
    required Iterable<String> pinnedConversationIds,
    Iterable<String> extraConversationIds = const [],
    required Set<String> existingLocalIds,
    int maxPeers = ConversationPerfFlags.c2cHistoryBackfillMaxPeers,
    bool includeFriends =
        ConversationPerfFlags.c2cHistoryBackfillIncludeFriends,
    bool includePinned =
        ConversationPerfFlags.c2cHistoryBackfillIncludePinned,
  }) {
    final out = <String>[];
    final seen = <String>{};

    void addConversationId(String raw) {
      final id = raw.trim();
      if (id.isEmpty || !id.startsWith('c2c_')) {
        return;
      }
      if (seen.contains(id)) {
        return;
      }
      if (_localContains(existingLocalIds, id)) {
        return;
      }
      seen.add(id);
      out.add(id);
    }

    void addPeerUserId(String rawPeer) {
      final peer = ChatIdFormat.rawUserUid(rawPeer);
      if (peer.isEmpty) {
        return;
      }
      addConversationId('c2c_$peer');
    }

    if (includePinned) {
      for (final pinned in pinnedConversationIds) {
        final ref = ArchivedConversationRef.fromConversationId(pinned);
        if (ref == null || ref.chatType != 'c2c') {
          continue;
        }
        addConversationId(ref.conversationId);
      }
    }
    if (includeFriends) {
      for (final peer in friendUserIds) {
        addPeerUserId(peer);
      }
    }
    for (final id in extraConversationIds) {
      addConversationId(id);
    }

    if (maxPeers <= 0 || out.length <= maxPeers) {
      return out;
    }
    return out.sublist(0, maxPeers);
  }

  static bool _localContains(Set<String> existing, String id) {
    if (existing.contains(id)) {
      return true;
    }
    for (final local in existing) {
      if (ArchivedConversationRef.fromConversationId(local)?.conversationId ==
              id ||
          local == id) {
        return true;
      }
      // 宽松：同 peer 的 c2c_ 前缀
      if (local.startsWith('c2c_') &&
          ChatIdFormat.rawUserUid(local.substring(4)) ==
              ChatIdFormat.rawUserUid(id.substring(4))) {
        return true;
      }
    }
    return false;
  }

  /// SDK 已有会话壳：直接采用。
  static bool shouldAdmitSdkConversation(V2TimConversation? conversation) {
    if (conversation == null) {
      return false;
    }
    final id = conversation.conversationID.trim();
    return id.startsWith('c2c_');
  }

  /// getConversation 常带回空壳：无 lastMessage / 无 msgID 时需 history 富化预览。
  static bool needsLastMessageEnrichment(V2TimConversation? conversation) {
    if (conversation == null) {
      return true;
    }
    final last = conversation.lastMessage;
    if (last == null) {
      return true;
    }
    final msgId = last.msgID?.trim() ?? '';
    return msgId.isEmpty;
  }

  /// SDK 壳是否允许持久化：RequireHistory 对 SDK 空壳同样生效；置顶例外。
  static bool shouldPersistBackfillRow({
    required V2TimConversation row,
    required bool requireHistory,
    required bool isPinned,
  }) {
    if (isPinned) {
      return true;
    }
    if (!requireHistory) {
      return true;
    }
    return !needsLastMessageEnrichment(row);
  }

  /// 写入前对齐置顶真相（PinSync 集合），避免 SDK isPinned=false 盖掉库列。
  static void applyPinnedFlag(
    V2TimConversation conversation, {
    required bool isPinned,
  }) {
    conversation.isPinned = isPinned;
  }

  /// 写入前对齐免打扰（getC2CReceiveMessageOpt）。
  static void applyRecvOpt(
    V2TimConversation conversation, {
    required int? recvOpt,
  }) {
    if (recvOpt == null) {
      return;
    }
    conversation.recvOpt = recvOpt;
  }

  /// SDK 无壳时：有历史消息才造壳（[requireHistory]）。
  static V2TimConversation? buildShellFromHistory({
    required String conversationId,
    V2TimMessage? lastMessage,
    required bool hasHistory,
    required bool requireHistory,
  }) {
    final id = conversationId.trim();
    if (!id.startsWith('c2c_')) {
      return null;
    }
    if (requireHistory && !hasHistory) {
      return null;
    }
    final peer = ChatIdFormat.rawUserUid(id.substring(4));
    if (peer.isEmpty) {
      return null;
    }
    return V2TimConversation(
      conversationID: id,
      type: 1,
      userID: peer,
      lastMessage: lastMessage,
      orderkey: lastMessage?.timestamp,
      unreadCount: 0,
    );
  }
}

/// 单次 backfill 统计，供日志与单测。
class C2cHistoryBackfillStats {
  const C2cHistoryBackfillStats({
    this.candidates = 0,
    this.sdkHit = 0,
    this.historyHit = 0,
    this.applied = 0,
    this.skipped = 0,
  });

  final int candidates;
  final int sdkHit;
  final int historyHit;
  final int applied;
  final int skipped;

  C2cHistoryBackfillStats copyWith({
    int? candidates,
    int? sdkHit,
    int? historyHit,
    int? applied,
    int? skipped,
  }) {
    return C2cHistoryBackfillStats(
      candidates: candidates ?? this.candidates,
      sdkHit: sdkHit ?? this.sdkHit,
      historyHit: historyHit ?? this.historyHit,
      applied: applied ?? this.applied,
      skipped: skipped ?? this.skipped,
    );
  }
}
