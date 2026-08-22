import 'dart:async';

import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/outgoing_visible_probe.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/roaming_contiguous_window.dart';

/// 本地 + 90 天云端漫游：旧本地留在集合里，中间空洞用云端往前翻补上再合并。
/// 首屏只交付最新连续一段，避免月份级两截焊成假连续。
class MessageHistoryPeekLoader {
  MessageHistoryPeekLoader._();

  static const int _maxPaginationRounds = 12;
  static final Map<String, Future<V2TimMessageListResult>> _inFlightByKey =
      <String, Future<V2TimMessageListResult>>{};

  static String _inFlightKey({
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    bool localOnly = false,
    String? mode,
  }) {
    final conv = (userID ?? groupID ?? '').trim();
    final anchor = lastMsgID?.trim() ?? '';
    final resolved = mode ?? (localOnly ? 'local' : 'localCloud');
    return '$resolved|$conv|$anchor|$lastMsgSeq';
  }

  static Future<List<V2TimMessage>> loadOlderLocalThenCloud({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
  }) async {
    final result = await loadOlderLocalThenCloudResult(
      messageService: messageService,
      count: count,
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq,
      lastMsg: lastMsg,
    );
    return result.messageList;
  }

  /// 仅读 IM SDK 本地库，不足也不打云。供列表视口预热防读写风暴。
  static Future<List<V2TimMessage>> loadOlderLocalOnly({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
  }) async {
    final result = await loadOlderLocalOnlyResult(
      messageService: messageService,
      count: count,
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq,
      lastMsg: lastMsg,
    );
    return result.messageList;
  }

  /// C2C / 群聊只拉 IM 云端上一页，不和本地库/脊柱合并。
  /// 本地+云 union 会把另一截本地历史焊进最新 20 条下面。
  static Future<V2TimMessageListResult> loadOlderCloudOnlyResult({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
  }) async {
    final effectiveSeq = _effectiveLastMsgSeq(
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
    );
    return _loadWithInFlight(
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: effectiveSeq,
      localOnly: false,
      mode: 'cloudOnly',
      count: count,
      run: () async {
        final response = await messageService.getHistoryMessageListWithComplete(
          count: count,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          lastMsgSeq: effectiveSeq,
          lastMsg: lastMsg,
        );
        ChatHistoryTrace.log(
          'peek_cloud_only',
          conversationID: userID ?? groupID,
          extras: <String, Object?>{
            'lastMsgID': lastMsgID ?? '',
            'lastMsgSeq': effectiveSeq,
            'count': count,
            'cloudCount': response?.messageList.length ?? 0,
            'isFinished': response?.isFinished ?? true,
          },
        );
        OutgoingVisibleProbe.dumpSdkRawPage(
          source: 'cloud_older',
          userID: userID,
          groupID: groupID,
          lastMsgID: lastMsgID,
          askCount: count,
          messages: response?.messageList ?? const <V2TimMessage>[],
          isFinished: response?.isFinished,
        );
        return V2TimMessageListResult(
          isFinished: response?.isFinished ?? true,
          messageList: response?.messageList ?? const <V2TimMessage>[],
        );
      },
    );
  }

  static Future<V2TimMessageListResult> loadOlderLocalThenCloudResult({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
  }) async {
    final effectiveSeq = _effectiveLastMsgSeq(
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
    );
    return _loadWithInFlight(
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: effectiveSeq,
      localOnly: false,
      count: count,
      run: () => _loadOlderPagedImpl(
        messageService: messageService,
        count: count,
        userID: userID,
        groupID: groupID,
        lastMsgID: lastMsgID,
        lastMsgSeq: effectiveSeq,
        lastMsg: lastMsg,
        localOnly: false,
      ),
    );
  }

  static Future<V2TimMessageListResult> loadOlderLocalOnlyResult({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
  }) async {
    final effectiveSeq = _effectiveLastMsgSeq(
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
    );
    return _loadWithInFlight(
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: effectiveSeq,
      localOnly: true,
      count: count,
      run: () => _loadOlderPagedImpl(
        messageService: messageService,
        count: count,
        userID: userID,
        groupID: groupID,
        lastMsgID: lastMsgID,
        lastMsgSeq: effectiveSeq,
        lastMsg: lastMsg,
        localOnly: true,
      ),
    );
  }

  static Future<V2TimMessageListResult> _loadWithInFlight({
    required String? userID,
    required String? groupID,
    required String? lastMsgID,
    required int lastMsgSeq,
    required bool localOnly,
    required int count,
    String? mode,
    required Future<V2TimMessageListResult> Function() run,
  }) async {
    if (count <= 0) {
      return V2TimMessageListResult(isFinished: true, messageList: const []);
    }

    final key = _inFlightKey(
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq,
      localOnly: localOnly,
      mode: mode,
    );
    final inFlight = _inFlightByKey[key];
    if (inFlight != null) {
      return inFlight;
    }

    // 必须先占坑再 run：否则同一拍两个 hydrate 会各打一遍 LOCAL+CLOUD。
    final completer = Completer<V2TimMessageListResult>();
    _inFlightByKey[key] = completer.future;
    try {
      final result = await run();
      if (!completer.isCompleted) {
        completer.complete(result);
      }
      return result;
    } catch (error, stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
      rethrow;
    } finally {
      if (identical(_inFlightByKey[key], completer.future)) {
        _inFlightByKey.remove(key);
      }
    }
  }

  static Future<V2TimMessageListResult> _loadOlderPagedImpl({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
    required bool localOnly,
  }) async {
    var accumulated = <V2TimMessage>[];
    var trustedIds = <String>{};
    var isFinished = false;
    var cursorId = lastMsgID;
    var cursorSeq = lastMsgSeq;
    var cursorMsg = lastMsg;
    var spine = <V2TimMessage>[];

    for (var safety = 0; safety < _maxPaginationRounds; safety++) {
      final batch = await _fetchBatchWithComplete(
        messageService: messageService,
        count: count,
        userID: userID,
        groupID: groupID,
        lastMsgID: cursorId,
        lastMsgSeq: cursorSeq,
        lastMsg: cursorMsg,
        localOnly: localOnly,
      );
      final beforeSpine = spine.length;
      accumulated = RoamingContiguousWindow.unionSorted(
        accumulated,
        batch.messageList,
        idOf: _messageId,
        seqOf: _messageSeq,
        timestampSecOf: _timestampSec,
      );
      trustedIds = {...trustedIds, ...batch.cloudIds};
      // C2C 的 seq 按发送方各自编号；本地或云端都不能按群 seq 裁脊柱，
      // 否则上一页会被切成不连续的一小截。
      if (_isC2c(userID: userID, groupID: groupID)) {
        for (final message in accumulated) {
          final id = _messageId(message);
          if (id.isNotEmpty) {
            trustedIds.add(id);
          }
        }
      }
      spine = RoamingContiguousWindow.keepNewestContiguousSpine(
        ascending: accumulated,
        trustedIds: trustedIds,
        idOf: _messageId,
        seqOf: _messageSeq,
        timestampSecOf: _timestampSec,
      );
      isFinished = batch.isFinished;
      final spineGrew = spine.length > beforeSpine;
      final hasHole = accumulated.length > spine.length;

      if (spine.length >= count && !hasHole) {
        break;
      }
      if (!_shouldContinuePagingToFill(
        localOnly: localOnly,
        spineGrew: spineGrew,
        cloudBacked: batch.cloudBacked,
        isFinished: isFinished,
        needCount: spine.length < count,
        hasHole: hasHole,
      )) {
        if (!localOnly && !batch.cloudBacked && !spineGrew) {
          isFinished = true;
        }
        break;
      }

      final oldest = _oldestMessage(spine);
      if (oldest == null) {
        break;
      }
      final nextId = oldest.msgID;
      final nextSeq = _messageSeq(oldest);
      if (safety > 0 &&
          !spineGrew &&
          nextId == cursorId &&
          nextSeq == cursorSeq) {
        break;
      }
      cursorId = nextId;
      cursorSeq = _effectiveLastMsgSeq(
        userID: userID,
        groupID: groupID,
        lastMsgSeq: nextSeq,
      );
      cursorMsg = oldest;
    }

    final window = RoamingContiguousWindow.takeNewest(spine, count);
    final leftover = accumulated.length > spine.length;
    final truncated = spine.length > window.length;
    return V2TimMessageListResult(
      isFinished: !truncated && !leftover && isFinished,
      messageList: window,
    );
  }

  /// 窗口不足 [count]、或集合里还有未接上的旧本地时：继续向云端往前翻补洞。
  /// 不能单凭本页 `isFinished` 停。云端已空才停止补洞；旧本地仍留在集合语义里
  /// （`isFinished=false`），上拉再决定是否并入。
  static bool _shouldContinuePagingToFill({
    required bool localOnly,
    required bool spineGrew,
    required bool cloudBacked,
    required bool isFinished,
    required bool needCount,
    required bool hasHole,
  }) {
    if (localOnly) {
      return spineGrew && !isFinished && needCount;
    }
    if (needCount) {
      if (!cloudBacked && !spineGrew) {
        return false;
      }
      if (!spineGrew && isFinished) {
        return false;
      }
      return true;
    }
    if (hasHole && cloudBacked) {
      return true;
    }
    return false;
  }

  static Future<_PeekFetchBatch> _fetchBatchWithComplete({
    required MessageService messageService,
    required int count,
    String? userID,
    String? groupID,
    String? lastMsgID,
    int lastMsgSeq = -1,
    V2TimMessage? lastMsg,
    bool localOnly = false,
  }) async {
    final requestSeq = _effectiveLastMsgSeq(
      userID: userID,
      groupID: groupID,
      lastMsgSeq: lastMsgSeq,
    );
    final localResponse = await messageService.getHistoryMessageListWithComplete(
      count: count,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: requestSeq,
      lastMsg: lastMsg,
    );
    final localMessages = localResponse?.messageList ?? const <V2TimMessage>[];
    var isFinished = localResponse?.isFinished ?? localMessages.isEmpty;

    var cloudMessages = const <V2TimMessage>[];
    // 90 天漫游：本地满窗也可能全是上次登录的旧消息，必须打云端。
    if (!localOnly) {
      final cloudResponse =
          await messageService.getHistoryMessageListWithComplete(
        count: count,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        userID: userID,
        groupID: groupID,
        lastMsgID: lastMsgID,
        lastMsgSeq: requestSeq,
        lastMsg: lastMsg,
      );
      cloudMessages = cloudResponse?.messageList ?? const <V2TimMessage>[];
      isFinished = cloudResponse?.isFinished ?? cloudMessages.isEmpty;
    }

    final cloudIds = <String>{};
    for (final message in cloudMessages) {
      final id = _messageId(message);
      if (id.isNotEmpty) {
        cloudIds.add(id);
      }
    }
    final union = RoamingContiguousWindow.unionSorted(
      localMessages,
      localOnly ? const <V2TimMessage>[] : cloudMessages,
      idOf: _messageId,
      seqOf: _messageSeq,
      timestampSecOf: _timestampSec,
    );
    final spine = RoamingContiguousWindow.keepNewestContiguousSpine(
      ascending: union,
      trustedIds: cloudIds,
      idOf: _messageId,
      seqOf: _messageSeq,
      timestampSecOf: _timestampSec,
    );

    ChatHistoryTrace.log(
      'peek_fetch_batch',
      conversationID: userID ?? groupID,
      extras: <String, Object?>{
        'lastMsgID': lastMsgID,
        'lastMsgSeq': requestSeq,
        'count': count,
        'localCount': localMessages.length,
        'cloudCount': cloudMessages.length,
        'unionCount': union.length,
        'spineCount': spine.length,
        'holeKeptLocal': union.length > spine.length,
        'localOnly': localOnly,
        'cloudBacked': cloudMessages.isNotEmpty,
        'isFinished': isFinished,
        'shortWindowContinue':
            !localOnly && spine.length < count && cloudMessages.isNotEmpty,
        'isInitialWindow': lastMsgID == null && requestSeq <= 0,
        'roamingDays': RoamingContiguousWindow.roamingCoverageDays,
      },
    );

    return _PeekFetchBatch(
      isFinished: isFinished,
      cloudBacked: cloudMessages.isNotEmpty,
      cloudIds: cloudIds,
      messageList: union,
    );
  }

  static bool _isC2c({String? userID, String? groupID}) {
    final user = userID?.trim() ?? '';
    final group = groupID?.trim() ?? '';
    return user.isNotEmpty && group.isEmpty;
  }

  /// C2C 只能用 lastMsg 翻页；lastMsgSeq 是群起点，传发送方 seq 会拉错页。
  static int _effectiveLastMsgSeq({
    String? userID,
    String? groupID,
    required int lastMsgSeq,
  }) {
    if (_isC2c(userID: userID, groupID: groupID)) {
      return -1;
    }
    return lastMsgSeq;
  }

  static V2TimMessage? _oldestMessage(List<V2TimMessage> messages) {
    if (messages.isEmpty) {
      return null;
    }
    return messages.first;
  }

  static int _messageSeq(V2TimMessage message) {
    return int.tryParse(message.seq?.toString() ?? '') ?? -1;
  }

  static String _messageId(V2TimMessage message) {
    final msgID = message.msgID?.trim() ?? '';
    if (msgID.isNotEmpty) {
      return msgID;
    }
    return message.id?.trim() ?? '';
  }

  static int _timestampSec(V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    return ts < 1000000000000 ? ts : ts ~/ 1000;
  }
}

class _PeekFetchBatch {
  const _PeekFetchBatch({
    required this.isFinished,
    required this.cloudBacked,
    required this.cloudIds,
    required this.messageList,
  });

  final bool isFinished;
  final bool cloudBacked;
  final Set<String> cloudIds;
  final List<V2TimMessage> messageList;
}
