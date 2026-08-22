import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_web_ready_guard.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

class WebMessageLoader {
  WebMessageLoader._();

  static final WebMessageLoader instance = WebMessageLoader._();

  final Set<String> _loadingKeys = <String>{};

  Future<void> loadInitialHistory({
    required V2TimConversation conversation,
    ChatLifeCycle? lifeCycle,
    int count = 30,
  }) async {
    if (!kIsWeb) {
      return;
    }
    final convKey = _conversationKey(conversation);
    if (convKey.isEmpty) {
      return;
    }
    final loadingKey = 'initial:$convKey';
    if (!_loadingKeys.add(loadingKey)) {
      return;
    }
    try {
      final ready = await ImWebReadyGuard.instance.wait();
      if (!ready) {
        return;
      }
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final existing = globalModel.messageListMap[convKey];
      if (existing != null && existing.isNotEmpty) {
        unawaited(syncLatest(conversation: conversation, lifeCycle: lifeCycle));
        return;
      }
      final messages = await _fetchHistory(
        conversation: conversation,
        count: count,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
      );
      final finalList = await _applyLifeCycle(messages, lifeCycle);
      if (finalList.isEmpty) {
        return;
      }
      globalModel.loadingMessage.remove(convKey);
      globalModel.setMessageList(
        convKey,
        TUIChatGlobalModel.dedupeMessages(finalList),
        needResetNewMessageCount: false,
        replace: true,
      );
      globalModel.markInitialHistoryLoaded(convKey);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WebMessageLoader: load initial history ignored: $e');
      }
    } finally {
      _loadingKeys.remove(loadingKey);
    }
  }

  Future<void> syncLatest({
    required V2TimConversation conversation,
    ChatLifeCycle? lifeCycle,
    int count = 30,
  }) async {
    if (!kIsWeb) {
      return;
    }
    final convKey = _conversationKey(conversation);
    if (convKey.isEmpty) {
      return;
    }
    final loadingKey = 'latest:$convKey';
    if (!_loadingKeys.add(loadingKey)) {
      return;
    }
    try {
      final ready = await ImWebReadyGuard.instance.wait();
      if (!ready) {
        return;
      }
      final globalModel = serviceLocator<TUIChatGlobalModel>();
      final current = globalModel.messageListMap[convKey] ?? const <V2TimMessage>[];
      final lastSeq = _maxSeq(current);
      final messages = await _fetchHistory(
        conversation: conversation,
        count: count,
        getType: conversation.type == 2 && lastSeq > 0
            ? HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG
            : HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        lastMsgSeq: conversation.type == 2 && lastSeq > 0 ? lastSeq : -1,
      );
      if (messages.isEmpty) {
        return;
      }
      final finalList = await _applyLifeCycle(messages, lifeCycle);
      final combined = TUIChatGlobalModel.mergeHistoricalWithInMemory(
        existing: current,
        fetched: finalList,
      );
      globalModel.setMessageList(
        convKey,
        combined,
        needResetNewMessageCount: false,
        replace: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('WebMessageLoader: sync latest ignored: $e');
      }
    } finally {
      _loadingKeys.remove(loadingKey);
    }
  }

  Future<List<V2TimMessage>> _fetchHistory({
    required V2TimConversation conversation,
    required int count,
    required HistoryMsgGetTypeEnum getType,
    int lastMsgSeq = -1,
  }) async {
    final isGroup = conversation.type == 2;
    final userID = isGroup ? null : conversation.userID?.trim();
    final groupID = isGroup ? conversation.groupID?.trim() : null;
    if ((userID == null || userID.isEmpty) &&
        (groupID == null || groupID.isEmpty)) {
      return const <V2TimMessage>[];
    }

    final manager = TencentImSDKPlugin.v2TIMManager.getMessageManager();
    Future<List<V2TimMessage>> fetch(HistoryMsgGetTypeEnum type) async {
      final res = await manager.getHistoryMessageList(
        count: count,
        getType: type,
        userID: userID,
        groupID: groupID,
        lastMsgSeq: lastMsgSeq,
      );
      if (res.code != 0) {
        if (kDebugMode) {
          debugPrint(
            'WebMessageLoader: getHistoryMessageList failed '
            'code=${res.code} desc=${res.desc}',
          );
        }
        return const <V2TimMessage>[];
      }
      return res.data ?? const <V2TimMessage>[];
    }

    var messages = await fetch(getType);
    if (messages.isEmpty && getType != HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG) {
      messages = await fetch(HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG);
    }
    return messages;
  }

  Future<List<V2TimMessage>> _applyLifeCycle(
    List<V2TimMessage> messages,
    ChatLifeCycle? lifeCycle,
  ) async {
    if (messages.isEmpty) {
      return messages;
    }
    return await lifeCycle?.didGetHistoricalMessageList(messages) ?? messages;
  }

  int _maxSeq(List<V2TimMessage> messages) {
    var maxSeq = 0;
    for (final message in messages) {
      final Object? rawSeq = message.seq;
      final int seq = rawSeq is num
          ? rawSeq.toInt()
          : int.tryParse(rawSeq?.toString() ?? '') ?? 0;
      if (seq > maxSeq) {
        maxSeq = seq;
      }
    }
    return maxSeq;
  }

  String _conversationKey(V2TimConversation conversation) {
    if (conversation.type == 2) {
      return conversation.groupID?.trim() ?? '';
    }
    return conversation.userID?.trim() ?? '';
  }
}
