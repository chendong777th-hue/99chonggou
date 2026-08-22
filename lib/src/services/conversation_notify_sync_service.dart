import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/api/conversation_notify_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_list_notifier.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_receive_message_opt_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_receive_message_opt_info.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

/// IM 会话免打扰与服务端离线 Push 策略同步。
class ConversationNotifySyncService {
  ConversationNotifySyncService._();

  static final ConversationNotifySyncService instance =
      ConversationNotifySyncService._();

  static const int _c2cImBatchSize = 30;
  static const int _restBatchSize = 100;
  static const Duration _loginSyncCooldown = Duration(minutes: 5);

  DateTime? _lastLoginSyncAt;
  Future<void>? _loginSyncInFlight;

  static bool recvOptToMuted(int? recvOpt) {
    if (recvOpt == null) {
      return false;
    }
    return recvOpt != ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index;
  }

  static bool receiveMessageOptToMuted(int? receiveMessageOpt) {
    if (receiveMessageOpt == null) {
      return false;
    }
    return receiveMessageOpt != ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index;
  }

  Future<void> reportAfterImSuccess({
    required String chatType,
    required String peerId,
    required bool muted,
  }) async {
    final type = chatType.trim().toLowerCase();
    final id = _restPeerId(chatType: type, peerId: peerId);
    if (type != 'c2c' && type != 'group') {
      return;
    }
    if (id.isEmpty) {
      return;
    }
    try {
      await ConversationNotifyApi.instance.updateMute(
        chatType: type,
        peerId: id,
        muted: muted,
      );
    } catch (e, st) {
      debugPrint('ConversationNotifySync: single sync failed $type/$id: $e\n$st');
    }
  }

  /// REST `/me/conversation-notify` 的群 peerId 用后端群 ID，禁止拼完整 IM ID。
  static String _restPeerId({
    required String chatType,
    required String peerId,
  }) {
    final type = chatType.trim().toLowerCase();
    final raw = peerId.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (type != 'group') {
      return ChatIdFormat.rawUserUid(raw).isNotEmpty
          ? ChatIdFormat.rawUserUid(raw)
          : raw;
    }
    final api = ChatIdFormat.apiGroupId(raw);
    return api.isNotEmpty ? api : raw;
  }

  Future<void> syncAllOnLogin({bool force = false}) {
    if (!force &&
        _lastLoginSyncAt != null &&
        DateTime.now().difference(_lastLoginSyncAt!) < _loginSyncCooldown) {
      return Future<void>.value();
    }
    return _loginSyncInFlight ??= _syncAllOnLogin(force: force).whenComplete(() {
      _loginSyncInFlight = null;
    });
  }

  Future<void> _syncAllOnLogin({required bool force}) async {
    try {
      await ConversationListNotifier.instance.reloadFromLocal();
      final items = await _collectMuteItemsFromImAndLocal();
      if (items.isEmpty) {
        return;
      }
      for (final chunk in _chunkItems(items, _restBatchSize)) {
        await ConversationNotifyApi.instance.batchUpdate(chunk);
      }
      _lastLoginSyncAt = DateTime.now();
      debugPrint(
        'ConversationNotifySync: login batch synced ${items.length} item(s)',
      );
    } catch (e, st) {
      debugPrint('ConversationNotifySync: login batch failed: $e\n$st');
      if (force) {
        rethrow;
      }
    }
  }

  Future<List<ConversationNotifyItem>> _collectMuteItemsFromImAndLocal() async {
    final conversations = ConversationListNotifier.instance.conversations;
    final c2cUserIds = <String>{};
    final groupItems = <ConversationNotifyItem>[];

    for (final conversation in conversations) {
      final groupId = conversation.groupID?.trim() ?? '';
      if (groupId.isNotEmpty) {
        final peerId = _restPeerId(chatType: 'group', peerId: groupId);
        if (peerId.isEmpty) {
          continue;
        }
        groupItems.add(
          ConversationNotifyItem(
            chatType: 'group',
            peerId: peerId,
            muted: recvOptToMuted(conversation.recvOpt),
          ),
        );
        continue;
      }
      final userId = conversation.userID?.trim() ?? '';
      if (userId.isEmpty || userId == '10000') {
        continue;
      }
      c2cUserIds.add(userId);
    }

    final merged = <String, ConversationNotifyItem>{};
    for (final item in groupItems) {
      merged[_itemKey(item)] = item;
    }

    final c2cBatches = _chunkList(c2cUserIds.toList(growable: false), _c2cImBatchSize);
    for (final batch in c2cBatches) {
      final optByUserId = await _fetchC2cReceiveOpts(batch);
      for (final userId in batch) {
        final muted = receiveMessageOptToMuted(optByUserId[userId]);
        merged[_itemKey(
          ConversationNotifyItem(
            chatType: 'c2c',
            peerId: userId,
            muted: muted,
          ),
        )] = ConversationNotifyItem(
          chatType: 'c2c',
          peerId: userId,
          muted: muted,
        );
      }
    }

    return merged.values.toList(growable: false);
  }

  Future<Map<String, int?>> _fetchC2cReceiveOpts(List<String> userIds) async {
    final out = <String, int?>{};
    if (userIds.isEmpty) {
      return out;
    }
    try {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .getC2CReceiveMessageOpt(userIDList: userIds);
      if (res.code != 0) {
        debugPrint(
          'ConversationNotifySync: getC2CReceiveMessageOpt failed code=${res.code}',
        );
        return _fallbackC2cOptsFromLocal(userIds);
      }
      for (final info in res.data ?? const <V2TimReceiveMessageOptInfo>[]) {
        final userId = info.userID?.trim() ?? '';
        if (userId.isEmpty) {
          continue;
        }
        out[userId] = info.c2CReceiveMessageOpt;
      }
      for (final userId in userIds) {
        out.putIfAbsent(userId, () => null);
      }
      return out;
    } catch (e) {
      debugPrint('ConversationNotifySync: getC2CReceiveMessageOpt error: $e');
      return _fallbackC2cOptsFromLocal(userIds);
    }
  }

  Map<String, int?> _fallbackC2cOptsFromLocal(List<String> userIds) {
    final out = <String, int?>{};
    final byUserId = <String, V2TimConversation>{
      for (final conversation in ConversationListNotifier.instance.conversations)
        if ((conversation.userID?.trim().isNotEmpty ?? false))
          conversation.userID!.trim(): conversation,
    };
    for (final userId in userIds) {
      out[userId] = byUserId[userId]?.recvOpt;
    }
    return out;
  }

  String _itemKey(ConversationNotifyItem item) {
    return '${item.chatType}:${item.peerId}';
  }

  List<List<T>> _chunkList<T>(List<T> values, int size) {
    if (values.isEmpty) {
      return const [];
    }
    final chunks = <List<T>>[];
    for (var i = 0; i < values.length; i += size) {
      final end = i + size > values.length ? values.length : i + size;
      chunks.add(values.sublist(i, end));
    }
    return chunks;
  }

  List<List<ConversationNotifyItem>> _chunkItems(
    List<ConversationNotifyItem> items,
    int size,
  ) {
    return _chunkList(items, size);
  }
}
