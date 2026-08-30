import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// 将自建归档还原的消息，在对齐 **腾讯云端 msgID** 后写入 IM SDK 本地库（补空）。
///
/// 解析顺序：消息已有真 msgID → 本端 CLOUD 匹配。
/// 禁止用归档 `msgKey` 冒充云端 msgID。Web 跳过。
///
/// 另：自动清理历史误 insert 产生的 `LOCAL_IMPORTED`（`userId-ts-random`）假消息。
class ArchiveImLocalPersistService {
  ArchiveImLocalPersistService._();

  static final ArchiveImLocalPersistService instance =
      ArchiveImLocalPersistService._();

  static const int _maxConcurrency = 3;
  static const int _purgeLocalPageSize = 100;
  static const int _purgeLocalMaxPages = 30;

  /// debug 下打印落库摘要（不依赖 ChatHistoryTrace）。
  static const bool logEnabled = kDebugMode;

  static final RegExp _sdkMsgIdPattern = RegExp(r'^\d+-\d+-');

  /// 归档误 insert 后原生生成的本地 id：`q14gkm5swv-1785813840-14214776`。
  static final RegExp _userLocalImportedMsgIdPattern =
      RegExp(r'^[A-Za-z][A-Za-z0-9_-]*-\d+-\d+$');

  final Map<String, Future<int>> _purgeInFlight = <String, Future<int>>{};

  /// 归档 msgKey 常见形态，不得当作云端 msgID。
  @visibleForTesting
  static bool looksLikeArchiveMsgKey(String? id) {
    final v = id?.trim() ?? '';
    if (v.isEmpty) {
      return true;
    }
    // seq_random_ts
    final parts = v.split('_');
    if (parts.length == 3 &&
        int.tryParse(parts[0]) != null &&
        int.tryParse(parts[1]) != null &&
        int.tryParse(parts[2]) != null) {
      return true;
    }
    return false;
  }

  /// 可写入 SDK / 用作 UI 身份的腾讯云端 msgID。
  static bool isTrustedCloudMsgId(String? id) {
    final v = id?.trim() ?? '';
    if (v.isEmpty || looksLikeArchiveMsgKey(v)) {
      return false;
    }
    if (v.contains(':') && v.toUpperCase().contains('TGS#')) {
      return false;
    }
    return _sdkMsgIdPattern.hasMatch(v);
  }

  /// 归档拼装体是否允许直接作为 `insert*ToLocalStorageV2` 入参。
  ///
  /// 恒为 false：真 msgId 只用于 UI 身份与 `findMessages` 探测；
  /// 原生 `DartSaveMessage` 不会保留云端 msgID/历史 timestamp，硬插会造
  /// `LOCAL_IMPORTED`（`sender-now-random`）并与归档气泡双开。
  @visibleForTesting
  static bool isArchiveSynthesizedInsertAllowed({
    required bool hasTrustedCloudMsgId,
  }) {
    return false;
  }

  /// 是否为归档误 insert 产生的假本地消息（可安全只删本地）。
  ///
  /// 判定：`status == LOCAL_IMPORTED(5)` 且 msgID 为字母开头的 `user-ts-random`，
  /// 不是腾讯数字云端 id。本仓库仅 [ArchiveImLocalPersistService] 调用 insert。
  @visibleForTesting
  static bool isSpuriousArchiveLocalImported(V2TimMessage message) {
    return isSpuriousArchiveLocalImportedFields(
      status: message.status,
      msgID: message.msgID,
    );
  }

  @visibleForTesting
  static bool isSpuriousArchiveLocalImportedFields({
    required int? status,
    required String? msgID,
  }) {
    if (status != MessageStatus.V2TIM_MSG_STATUS_LOCAL_IMPORTED) {
      return false;
    }
    final id = msgID?.trim() ?? '';
    if (id.isEmpty || isTrustedCloudMsgId(id)) {
      return false;
    }
    return _userLocalImportedMsgIdPattern.hasMatch(id);
  }

  static String? archiveMsgKeyOf(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final key = decoded['archiveMsgKey']?.toString().trim() ?? '';
          if (key.isNotEmpty) {
            return key;
          }
        }
      } catch (_) {}
    }
    final id = message.msgID?.trim() ?? '';
    if (looksLikeArchiveMsgKey(id)) {
      return id;
    }
    return null;
  }

  void _log(
    String event, {
    String? conversationID,
    Map<String, Object?> extras = const <String, Object?>{},
  }) {
    ChatHistoryTrace.log(event, conversationID: conversationID, extras: extras);
    if (!logEnabled) {
      return;
    }
    final buffer = StringBuffer('[ArchiveImLocal] event=$event');
    final conv = conversationID?.trim() ?? '';
    if (conv.isNotEmpty) {
      buffer.write(' conv=$conv');
    }
    extras.forEach((key, value) {
      if (value != null) {
        buffer.write(' $key=$value');
      }
    });
    // ignore: avoid_print
    print(buffer.toString());
  }

  /// 清除会话内由归档误 insert 产生的 `LOCAL_IMPORTED` 假消息（只删本地）。
  ///
  /// 返回成功删除条数。同会话并发调用会复用 in-flight Future。
  Future<int> purgeSpuriousLocalImported({
    required bool isGroup,
    required String conversationID,
  }) async {
    if (PlatformUtils().isWeb || kIsWeb) {
      return 0;
    }
    final conv = conversationID.trim();
    if (conv.isEmpty) {
      return 0;
    }
    final existing = _purgeInFlight[conv];
    if (existing != null) {
      return existing;
    }
    final future = _purgeSpuriousLocalImportedImpl(
      isGroup: isGroup,
      conversationID: conv,
    );
    _purgeInFlight[conv] = future;
    try {
      return await future;
    } finally {
      if (identical(_purgeInFlight[conv], future)) {
        _purgeInFlight.remove(conv);
      }
    }
  }

  Future<int> _purgeSpuriousLocalImportedImpl({
    required bool isGroup,
    required String conversationID,
  }) async {
    _log(
      'archive_im_local_purge_start',
      conversationID: conversationID,
      extras: <String, Object?>{'isGroup': isGroup},
    );

    final byId = <String, V2TimMessage>{};

    void absorb(Iterable<V2TimMessage> list) {
      for (final m in list) {
        if (!isSpuriousArchiveLocalImported(m)) {
          continue;
        }
        final id = m.msgID?.trim() ?? '';
        if (id.isNotEmpty) {
          byId[id] = m;
        }
      }
    }

    // 1) 内存窗先摘掉，避免 tip 继续展示假消息。
    absorb(_memoryMessagesForConversation(conversationID));
    if (byId.isNotEmpty) {
      _stripMemoryIds(
        conversationID: conversationID,
        msgIds: byId.keys.toSet(),
      );
    }

    // 2) 扫本地库（污染可能远多于当前内存窗）。
    absorb(await _scanLocalHistoryForSpurious(
      isGroup: isGroup,
      conversationID: conversationID,
    ));

    if (byId.isEmpty) {
      _log(
        'archive_im_local_purge_done',
        conversationID: conversationID,
        extras: const <String, Object?>{'deleted': 0, 'failed': 0},
      );
      return 0;
    }

    _stripMemoryIds(
      conversationID: conversationID,
      msgIds: byId.keys.toSet(),
    );

    final mgr = TencentImSDKPlugin.v2TIMManager.getMessageManager();
    var deleted = 0;
    var failed = 0;
    final ids = byId.keys.toList(growable: false);
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final message = byId[id];
      try {
        final res = await mgr.deleteMessageFromLocalStorage(
          message: message,
          msgID: id,
        );
        if (res.code == 0) {
          deleted++;
        } else {
          failed++;
          _log(
            'archive_im_local_purge_fail',
            conversationID: conversationID,
            extras: <String, Object?>{
              'msgID': id,
              'code': res.code,
              'desc': res.desc,
            },
          );
        }
      } catch (e) {
        failed++;
        _log(
          'archive_im_local_purge_fail',
          conversationID: conversationID,
          extras: <String, Object?>{'msgID': id, 'error': e.toString()},
        );
      }
      // 避免一口气打满原生删除。
      if (i > 0 && i % 10 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
    }

    _log(
      'archive_im_local_purge_done',
      conversationID: conversationID,
      extras: <String, Object?>{
        'candidates': ids.length,
        'deleted': deleted,
        'failed': failed,
      },
    );
    return deleted;
  }

  List<V2TimMessage> _memoryMessagesForConversation(String conversationID) {
    try {
      final global = serviceLocator<TUIChatGlobalModel>();
      final bare = ChatIdFormat.rawUserUid(conversationID);
      final keys = <String>{
        conversationID,
        if (bare.isNotEmpty) bare,
        if (bare.isNotEmpty) 'c2c_$bare',
        if (conversationID.startsWith('@') || conversationID.contains('TGS'))
          ChatIdFormat.canonicalGroupStorageId(conversationID),
      };
      final out = <V2TimMessage>[];
      for (final key in keys) {
        final list = global.messageListMap[key];
        if (list != null && list.isNotEmpty) {
          out.addAll(list);
        }
      }
      return out;
    } catch (_) {
      return const <V2TimMessage>[];
    }
  }

  void _stripMemoryIds({
    required String conversationID,
    required Set<String> msgIds,
  }) {
    if (msgIds.isEmpty) {
      return;
    }
    try {
      final global = serviceLocator<TUIChatGlobalModel>();
      final bare = ChatIdFormat.rawUserUid(conversationID);
      final keys = <String>{
        conversationID,
        if (bare.isNotEmpty) bare,
        if (bare.isNotEmpty) 'c2c_$bare',
        if (conversationID.startsWith('@') || conversationID.contains('TGS'))
          ChatIdFormat.canonicalGroupStorageId(conversationID),
      };
      for (final key in keys) {
        final list = global.messageListMap[key];
        if (list == null || list.isEmpty) {
          continue;
        }
        final next = list
            .where((m) => !msgIds.contains(m.msgID?.trim() ?? ''))
            .toList(growable: false);
        if (next.length == list.length) {
          continue;
        }
        global.setMessageList(key, next, replace: true);
      }
    } catch (_) {
      // serviceLocator 未就绪时忽略；本地删除仍继续。
    }
  }

  Future<List<V2TimMessage>> _scanLocalHistoryForSpurious({
    required bool isGroup,
    required String conversationID,
  }) async {
    final mgr = TencentImSDKPlugin.v2TIMManager.getMessageManager();
    final found = <V2TimMessage>[];
    V2TimMessage? lastMsg;
    final peer = ChatIdFormat.rawUserUid(conversationID);
    final userID = peer.isNotEmpty ? peer : conversationID;
    final groupID = ChatIdFormat.canonicalGroupStorageId(conversationID);
    for (var page = 0; page < _purgeLocalMaxPages; page++) {
      final res = isGroup
          ? await mgr.getHistoryMessageListV2(
              count: _purgeLocalPageSize,
              getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
              groupID: groupID,
              lastMsg: lastMsg,
            )
          : await mgr.getHistoryMessageListV2(
              count: _purgeLocalPageSize,
              getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
              userID: userID,
              lastMsg: lastMsg,
            );
      final list = res.data?.messageList ?? const <V2TimMessage>[];
      if (list.isEmpty) {
        break;
      }
      for (final m in list) {
        if (isSpuriousArchiveLocalImported(m)) {
          found.add(m);
        }
      }
      lastMsg = list.last;
      if (list.length < _purgeLocalPageSize) {
        break;
      }
    }
    return found;
  }

  Future<void> persist({
    required bool isGroup,
    required String conversationID,
    required List<V2TimMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return;
    }
    if (PlatformUtils().isWeb || kIsWeb) {
      _log(
        'archive_im_local_persist_skip',
        conversationID: conversationID,
        extras: const <String, Object?>{'reason': 'web', 'count': 0},
      );
      return;
    }

    final conv = conversationID.trim();
    if (conv.isEmpty) {
      return;
    }

    // 先清历史误插，再尝试（仅 SDK 原件）补空。
    await purgeSpuriousLocalImported(
      isGroup: isGroup,
      conversationID: conv,
    );

    _log(
      'archive_im_local_persist_start',
      conversationID: conv,
      extras: <String, Object?>{'count': messages.length, 'isGroup': isGroup},
    );

    var inserted = 0;
    var skipped = 0;
    var failed = 0;

    final queue = List<V2TimMessage>.from(messages);
    while (queue.isNotEmpty) {
      final batch = <V2TimMessage>[];
      while (batch.length < _maxConcurrency && queue.isNotEmpty) {
        batch.add(queue.removeAt(0));
      }
      final results = await Future.wait(
        batch.map(
          (m) => _persistOne(
            isGroup: isGroup,
            conversationID: conv,
            archiveMessage: m,
          ),
        ),
      );
      for (final r in results) {
        switch (r) {
          case _PersistOutcome.inserted:
            inserted++;
          case _PersistOutcome.skipped:
            skipped++;
          case _PersistOutcome.failed:
            failed++;
        }
      }
    }

    _log(
      'archive_im_local_persist_done',
      conversationID: conv,
      extras: <String, Object?>{
        'inserted': inserted,
        'skipped': skipped,
        'failed': failed,
      },
    );
  }

  Future<_PersistOutcome> _persistOne({
    required bool isGroup,
    required String conversationID,
    required V2TimMessage archiveMessage,
  }) async {
    try {
      final archiveId = archiveMessage.msgID?.trim() ?? '';
      final hasTrustedArchiveId = isTrustedCloudMsgId(archiveId);

      // 真 id：只做本地已存在探测，绝不把归档拼装体当 insert 入参。
      if (hasTrustedArchiveId) {
        final found = await TencentImSDKPlugin.v2TIMManager
            .getMessageManager()
            .findMessages(messageIDList: <String>[archiveId]);
        if (found.code == 0 && found.data != null && found.data!.isNotEmpty) {
          _log(
            'archive_im_local_persist_skip',
            conversationID: conversationID,
            extras: <String, Object?>{
              'reason': 'exists_msg_id',
              'msgID': archiveId,
            },
          );
          return _PersistOutcome.skipped;
        }
      }

      final V2TimMessage? cloud;
      if (isArchiveSynthesizedInsertAllowed(
        hasTrustedCloudMsgId: hasTrustedArchiveId,
      )) {
        // 策略恒 false；保留分支仅防回归误开短路。
        cloud = archiveMessage;
      } else {
        cloud = await _resolveFromUserCloud(
          isGroup: isGroup,
          conversationID: conversationID,
          archiveMessage: archiveMessage,
        );
      }
      if (cloud == null) {
        _log(
          'archive_im_local_persist_skip',
          conversationID: conversationID,
          extras: <String, Object?>{
            'reason':
                hasTrustedArchiveId ? 'no_sdk_cloud_object' : 'no_cloud_msgid',
            'archiveId': archiveId,
            'seq': archiveMessage.seq ?? '',
          },
        );
        return _PersistOutcome.skipped;
      }
      final cloudId = cloud.msgID?.trim() ?? '';
      if (!isTrustedCloudMsgId(cloudId)) {
        _log(
          'archive_im_local_persist_skip',
          conversationID: conversationID,
          extras: const <String, Object?>{'reason': 'invalid_cloud_msgid'},
        );
        return _PersistOutcome.skipped;
      }

      if (cloudId != archiveId) {
        final found = await TencentImSDKPlugin.v2TIMManager
            .getMessageManager()
            .findMessages(messageIDList: <String>[cloudId]);
        if (found.code == 0 && found.data != null && found.data!.isNotEmpty) {
          _log(
            'archive_im_local_persist_skip',
            conversationID: conversationID,
            extras: <String, Object?>{
              'reason': 'exists_msg_id',
              'msgID': cloudId,
            },
          );
          return _PersistOutcome.skipped;
        }
      }

      final sender = (cloud.sender ?? cloud.userID ?? '').trim();
      if (sender.isEmpty) {
        return _PersistOutcome.skipped;
      }

      final String returnedId;
      if (isGroup) {
        final groupID = ChatIdFormat.canonicalGroupStorageId(conversationID);
        final res = await TencentImSDKPlugin.v2TIMManager
            .getMessageManager()
            .insertGroupMessageToLocalStorageV2(
              groupID: groupID,
              senderID: sender,
              message: cloud,
            );
        if (res.code != 0) {
          _log(
            'archive_im_local_persist_fail',
            conversationID: conversationID,
            extras: <String, Object?>{
              'code': res.code,
              'desc': res.desc,
              'msgID': cloudId,
            },
          );
          return _PersistOutcome.failed;
        }
        returnedId = res.data?.msgID?.trim() ?? '';
      } else {
        final peer = ChatIdFormat.rawUserUid(conversationID);
        final res = await TencentImSDKPlugin.v2TIMManager
            .getMessageManager()
            .insertC2CMessageToLocalStorageV2(
              userID: peer.isNotEmpty ? peer : conversationID,
              senderID: sender,
              message: cloud,
            );
        if (res.code != 0) {
          _log(
            'archive_im_local_persist_fail',
            conversationID: conversationID,
            extras: <String, Object?>{
              'code': res.code,
              'desc': res.desc,
              'msgID': cloudId,
            },
          );
          return _PersistOutcome.failed;
        }
        returnedId = res.data?.msgID?.trim() ?? '';
      }

      _log(
        'archive_im_local_persist_ok',
        conversationID: conversationID,
        extras: <String, Object?>{
          'inputMsgID': cloudId,
          'returnedMsgID': returnedId,
          'msgIdPreserved': returnedId.isNotEmpty && returnedId == cloudId,
        },
      );
      return _PersistOutcome.inserted;
    } catch (e) {
      _log(
        'archive_im_local_persist_fail',
        conversationID: conversationID,
        extras: <String, Object?>{'error': e.toString()},
      );
      return _PersistOutcome.failed;
    }
  }

  Future<V2TimMessage?> _resolveFromUserCloud({
    required bool isGroup,
    required String conversationID,
    required V2TimMessage archiveMessage,
  }) async {
    final mgr = TencentImSDKPlugin.v2TIMManager.getMessageManager();
    if (isGroup) {
      final seq = int.tryParse(archiveMessage.seq?.toString() ?? '') ?? 0;
      if (seq <= 0) {
        return null;
      }
      final groupID = ChatIdFormat.canonicalGroupStorageId(conversationID);
      final res = await mgr.getHistoryMessageListV2(
        count: 1,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        groupID: groupID,
        messageSeqList: <int>[seq],
      );
      final list = res.data?.messageList ?? const <V2TimMessage>[];
      for (final m in list) {
        final s = int.tryParse(m.seq?.toString() ?? '') ?? 0;
        if (s == seq) {
          final id = m.msgID?.trim() ?? '';
          if (isTrustedCloudMsgId(id)) {
            _promoteArchiveIdentity(
              conversationID: conversationID,
              archiveMessage: archiveMessage,
              cloudId: id,
            );
            return m;
          }
        }
      }
      return null;
    }

    final tsSec = _timestampSec(archiveMessage);
    if (tsSec <= 0) {
      return null;
    }
    final peer = ChatIdFormat.rawUserUid(conversationID);
    final res = await mgr.getHistoryMessageListV2(
      count: 20,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
      userID: peer.isNotEmpty ? peer : conversationID,
      timeBegin: tsSec + 1,
      timePeriod: 3,
    );
    final list = res.data?.messageList ?? const <V2TimMessage>[];
    final archiveKey = _c2cMatchKey(archiveMessage);
    for (final m in list) {
      if (_c2cMatchKey(m) == archiveKey) {
        final id = m.msgID?.trim() ?? '';
        if (isTrustedCloudMsgId(id)) {
          _promoteArchiveIdentity(
            conversationID: conversationID,
            archiveMessage: archiveMessage,
            cloudId: id,
          );
          return m;
        }
      }
    }
    final sender = (archiveMessage.sender ?? '').trim();
    for (final m in list) {
      if (_timestampSec(m) != tsSec) {
        continue;
      }
      final s = (m.sender ?? m.userID ?? '').trim();
      if (sender.isNotEmpty && s == sender) {
        final id = m.msgID?.trim() ?? '';
        if (isTrustedCloudMsgId(id)) {
          _promoteArchiveIdentity(
            conversationID: conversationID,
            archiveMessage: archiveMessage,
            cloudId: id,
          );
          return m;
        }
      }
    }
    return null;
  }

  void _promoteArchiveIdentity({
    required String conversationID,
    required V2TimMessage archiveMessage,
    required String cloudId,
  }) {
    final fromId = archiveMessage.msgID?.trim() ?? '';
    final key = archiveMsgKeyOf(archiveMessage) ?? fromId;
    if (fromId.isNotEmpty && fromId != cloudId) {
      _rewriteMemoryIdentity(
        conversationID: conversationID,
        fromId: fromId,
        toId: cloudId,
        archiveMsgKey: key,
      );
    }
  }

  void _rewriteMemoryIdentity({
    required String conversationID,
    required String fromId,
    required String toId,
    String? archiveMsgKey,
  }) {
    if (fromId.isEmpty || toId.isEmpty || fromId == toId) {
      return;
    }
    try {
      final global = serviceLocator<TUIChatGlobalModel>();
      final bare = ChatIdFormat.rawUserUid(conversationID);
      final keys = <String>{
        conversationID,
        if (bare.isNotEmpty) bare,
        if (bare.isNotEmpty) 'c2c_$bare',
        if (conversationID.startsWith('@') || conversationID.contains('TGS'))
          ChatIdFormat.canonicalGroupStorageId(conversationID),
      };
      for (final key in keys) {
        final list = global.messageListMap[key];
        if (list == null || list.isEmpty) {
          continue;
        }
        var changed = false;
        final next = list.map((message) {
          final m = V2TimMessage.fromJson(
            Map<String, dynamic>.from(message.toJson()),
          );
          final id = m.msgID?.trim() ?? '';
          if (id == fromId) {
            m.msgID = toId;
            changed = true;
            return m;
          }
          final ak = archiveMsgKeyOf(m);
          if (archiveMsgKey != null &&
              ak == archiveMsgKey &&
              !isTrustedCloudMsgId(id)) {
            m.msgID = toId;
            changed = true;
          }
          return m;
        }).toList(growable: false);
        if (changed) {
          global.setMessageList(
            key,
            next,
          );
        }
      }
    } catch (_) {
      // serviceLocator 未就绪时忽略 UI 改写；落库仍继续。
    }
  }

  static String _c2cMatchKey(V2TimMessage m) {
    final sender = (m.sender ?? m.userID ?? '').trim();
    final ts = _timestampSec(m);
    final random = m.random ?? 0;
    if (random > 0) {
      return '$sender|$ts|$random';
    }
    return TUIChatGlobalModel.messageDedupKey(m);
  }

  static int _timestampSec(V2TimMessage m) {
    final ts = m.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    return ts < 1000000000000 ? ts : ts ~/ 1000;
  }
}

enum _PersistOutcome { inserted, skipped, failed }
