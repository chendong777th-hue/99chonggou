// ignore_for_file: constant_identifier_names

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_search_param.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_param.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/self_hosted_friendship_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/self_hosted_group_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_local_store.dart';

enum KeywordListMatchType { V2TIM_KEYWORD_LIST_MATCH_TYPE_OR, V2TIM_KEYWORD_LIST_MATCH_TYPE_AND }

class TUISearchViewModel extends ChangeNotifier {
  final FriendshipServices _friendshipServices = serviceLocator<FriendshipServices>();
  final MessageService _messageService = serviceLocator<MessageService>();
  final ConversationService _conversationService = serviceLocator<ConversationService>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();

  List<V2TimFriendInfoResult>? friendList = [];

  List<V2TimMessageSearchResultItem>? msgList = [];
  int msgPage = 0;
  int totalMsgCount = 0;

  int totalMsgInConversationCount = 0;
  List<V2TimMessage> currentMsgListForConversation = [];

  /// 会话内图片/文件消息（用于文件名关键词搜索）。
  List<V2TimMessage> mediaFileMsgListForConversation = [];
  bool mediaFileHasMore = true;
  bool mediaFileLoading = false;
  String? _mediaFileLastMsgID;

  /// 媒体/文件专用浏览页数据。
  List<V2TimMessage> conversationMediaMessages = [];
  List<V2TimMessage> conversationFileMessages = [];
  bool conversationAssetLoading = false;
  bool conversationAssetHasMore = true;
  String? _conversationAssetLastMsgID;

  List<V2TimGroupInfo>? groupList = [];

  List<V2TimConversation?> conversationList = [];

  bool globalSearchLoading = false;
  String _completedGlobalSearchKey = '';
  Set<String>? _joinedGroupIdsForSearch;

  /// 绑定当前 IM 登录用户；切号后与此不一致则强制丢弃搜索上下文，避免串号。
  String _boundLoginUserId = '';

  /// 最近一次已完成的全局搜索关键词；与输入框一致时才可展示「无结果」空状态。
  String get completedGlobalSearchKey => _completedGlobalSearchKey;

  Timer? _globalSearchDebounce;
  int _globalSearchGeneration = 0;
  static const Duration _globalSearchDebounceDuration =
      Duration(milliseconds: 100);
  static const Duration _globalMessageSearchDeferDuration =
      Duration(milliseconds: 80);

  Timer? _conversationTextSearchDebounce;
  int _conversationTextSearchGeneration = 0;
  static const Duration _conversationTextSearchDebounceDuration =
      Duration(milliseconds: 300);

  Timer? _conversationMediaSearchDebounce;
  int _conversationMediaSearchGeneration = 0;
  static const Duration _conversationMediaSearchDebounceDuration =
      Duration(milliseconds: 500);

  Future<List<V2TimConversation?>?> initConversationMsg() async {
    _syncSearchAccountScope(forceReloadContext: false);
    try {
      final fromLocal = await ConversationLocalStore.instance.loadUiWindow();
      if (fromLocal.isNotEmpty) {
        conversationList = fromLocal
            .where((item) => !shouldHideConversationFromPickers(item))
            .map((item) => item as V2TimConversation?)
            .toList(growable: false);
        return conversationList;
      }
    } catch (_) {}

    final cached = serviceLocator<TUIConversationViewModel>().conversationList;
    if (cached.isNotEmpty) {
      conversationList = cached
          .where((item) => !shouldHideConversationFromPickers(item))
          .toList(growable: false);
      return conversationList;
    }

    final conversationResult =
        await _conversationService.getConversationList(nextSeq: "0", count: 500);
    final conversationListData = conversationResult?.conversationList;
    conversationList = (conversationListData ?? [])
        .where((item) => !shouldHideConversationFromPickers(item))
        .toList(growable: false);
    return conversationListData;
  }

  void _mergeConversationsIntoSearchContext(
    Iterable<V2TimConversation> incoming,
  ) {
    final byId = <String, V2TimConversation>{};
    for (final item in conversationList) {
      if (item == null) {
        continue;
      }
      final id = item.conversationID.trim();
      if (id.isNotEmpty) {
        byId[id] = item;
      }
    }
    for (final item in incoming) {
      if (shouldHideConversationFromPickers(item)) {
        continue;
      }
      final id = item.conversationID.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = item;
    }
    conversationList = byId.values
        .map((item) => item as V2TimConversation?)
        .toList(growable: false);
  }

  Future<List<V2TimConversation>> _localConversationsMatchingKeyword(
    String keyword, {
    int? generation,
    void Function(List<V2TimConversation> batch)? onBatch,
  }) async {
    final q = keyword.trim();
    if (q.isEmpty) {
      return const [];
    }
    try {
      final hits =
          await ConversationLocalStore.instance.searchConversationsAllPages(
        keyword: q,
        shouldCancel: generation == null
            ? null
            : () => generation != _globalSearchGeneration,
        onBatch: (batch, _) {
          _mergeConversationsIntoSearchContext(batch);
          onBatch?.call(batch);
        },
      );
      _mergeConversationsIntoSearchContext(hits);
      return hits;
    } catch (_) {
      return const [];
    }
  }

  void _applyLocalC2cMatchesToFriendMap(
    Map<String, V2TimFriendInfoResult> byUserId,
    Iterable<V2TimConversation> localMatches, {
    Set<String>? friendIds,
  }) {
    for (final conversation in localMatches) {
      if (isGroupConversation(conversation)) {
        continue;
      }
      final friendInfo = friendInfoFromC2cConversation(conversation);
      final userId = friendInfo.userID.trim();
      if (userId.isEmpty || byUserId.containsKey(userId)) {
        continue;
      }
      if (friendIds != null && !friendIds.contains(userId)) {
        continue;
      }
      byUserId[userId] = V2TimFriendInfoResult(
        resultCode: 0,
        resultInfo: '',
        relation: 0,
        friendInfo: friendInfo,
      );
    }
  }

  void _applyLocalGroupMatchesToGroupMap(
    Map<String, V2TimGroupInfo> byGroupId,
    Iterable<V2TimConversation> localMatches,
  ) {
    for (final conversation in localMatches) {
      if (shouldHideConversationFromPickers(conversation)) {
        continue;
      }
      if (!isGroupConversation(conversation)) {
        continue;
      }
      final groupInfo = groupInfoFromGroupConversation(conversation);
      final groupId = groupInfo.groupID.trim();
      if (groupId.isEmpty || byGroupId.containsKey(groupId)) {
        continue;
      }
      byGroupId[groupId] = groupInfo;
    }
  }

  /// 群名变更后轻量修补搜索会话缓存，避免全局搜索仍显示旧 showName。
  void patchGroupShowNameLocally({
    required String groupId,
    required String showName,
  }) {
    final id = groupId.trim();
    final name = showName.trim();
    if (id.isEmpty || name.isEmpty || conversationList.isEmpty) {
      return;
    }
    var changed = false;
    for (final item in conversationList) {
      if (item == null) {
        continue;
      }
      final gid = item.groupID?.trim() ?? '';
      final fromCid = groupIdFromConversationId(item.conversationID) ?? '';
      final hit = searchGroupIdsEquivalent(gid, id) ||
          searchGroupIdsEquivalent(fromCid, id);
      if (!hit) {
        continue;
      }
      if ((item.showName?.trim() ?? '') == name) {
        continue;
      }
      item.showName = name;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  String _currentLoginUserId() {
    try {
      final fromSelf =
          serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
      if (fromSelf.isNotEmpty) {
        return fromSelf;
      }
    } catch (_) {}
    return '';
  }

  /// 登录用户变化时丢弃全局搜索上下文，防止复用上一账号会话/群缓存。
  bool _syncSearchAccountScope({required bool forceReloadContext}) {
    final current = _currentLoginUserId();
    final changed = _boundLoginUserId.isNotEmpty &&
        current.isNotEmpty &&
        _boundLoginUserId != current;
    final missingBinding = _boundLoginUserId.isEmpty && current.isNotEmpty;
    if (forceReloadContext || changed || missingBinding) {
      if (changed || forceReloadContext) {
        conversationList = [];
        _joinedGroupIdsForSearch = null;
        friendList = [];
        msgList = [];
        groupList = [];
        totalMsgCount = 0;
        _completedGlobalSearchKey = '';
      }
      if (current.isNotEmpty) {
        _boundLoginUserId = current;
      } else if (forceReloadContext) {
        _boundLoginUserId = '';
      }
      return true;
    }
    if (current.isNotEmpty) {
      _boundLoginUserId = current;
    }
    return false;
  }

  /// 本地消息搜索前：当前 IM 用户必须已绑定且可用。
  bool _canSearchLocalMessagesForCurrentUser() {
    final current = _currentLoginUserId();
    if (current.isEmpty) {
      return false;
    }
    if (_boundLoginUserId.isNotEmpty && _boundLoginUserId != current) {
      _syncSearchAccountScope(forceReloadContext: true);
    }
    _boundLoginUserId = current;
    return true;
  }

  void initSearch({bool notify = true}) {
    _globalSearchDebounce?.cancel();
    _conversationTextSearchDebounce?.cancel();
    _conversationMediaSearchDebounce?.cancel();
    _globalSearchGeneration++;
    _conversationTextSearchGeneration++;
    _conversationMediaSearchGeneration++;
    friendList = [];
    msgList = [];
    groupList = [];
    totalMsgCount = 0;
    mediaFileMsgListForConversation = [];
    mediaFileHasMore = true;
    _mediaFileLastMsgID = null;
    conversationMediaMessages = [];
    conversationFileMessages = [];
    conversationAssetHasMore = true;
    _conversationAssetLastMsgID = null;
    globalSearchLoading = false;
    _completedGlobalSearchKey = '';
    _joinedGroupIdsForSearch = null;
    // 必须清会话缓存：否则切号后仍复用上一账号 conversationList。
    conversationList = [];
    _syncSearchAccountScope(forceReloadContext: false);
    if (notify) {
      notifyListeners();
    }
  }

  /// 登出 / 切号时清空全部全局搜索态（含会话上下文）。
  void clearSession({bool notify = false}) {
    _globalSearchDebounce?.cancel();
    _conversationTextSearchDebounce?.cancel();
    _conversationMediaSearchDebounce?.cancel();
    _globalSearchGeneration++;
    _conversationTextSearchGeneration++;
    _conversationMediaSearchGeneration++;
    friendList = [];
    msgList = [];
    groupList = [];
    conversationList = [];
    totalMsgCount = 0;
    totalMsgInConversationCount = 0;
    currentMsgListForConversation = [];
    mediaFileMsgListForConversation = [];
    mediaFileHasMore = true;
    _mediaFileLastMsgID = null;
    conversationMediaMessages = [];
    conversationFileMessages = [];
    conversationAssetHasMore = true;
    _conversationAssetLastMsgID = null;
    globalSearchLoading = false;
    _completedGlobalSearchKey = '';
    _joinedGroupIdsForSearch = null;
    _boundLoginUserId = '';
    if (notify) {
      notifyListeners();
    }
  }

  /// 进入全局搜索页时预热会话/群/通讯录缓存，缩短首次输入后的首屏等待。
  Future<void> warmGlobalSearchContext() async {
    _syncSearchAccountScope(forceReloadContext: false);
    final friendshipModel = serviceLocator<TUIFriendShipViewModel>();
    final contactWarm = (friendshipModel.friendList == null ||
            friendshipModel.friendList!.isEmpty)
        ? friendshipModel.loadContactListData()
        : Future<void>.value();
    await Future.wait<void>([
      initConversationMsg().then((_) => null),
      _ensureJoinedGroupIdsForSearch(),
      contactWarm,
    ]);
  }

  Future<void> _ensureJoinedGroupIdsForSearch() async {
    if (_joinedGroupIdsForSearch != null) {
      return;
    }
    _joinedGroupIdsForSearch = await _loadJoinedGroupIdsForSearch();
  }

  Future<void> _ensureGlobalSearchContext(int generation) async {
    final scopeChanged = _syncSearchAccountScope(forceReloadContext: false);
    final futures = <Future<void>>[];
    if (scopeChanged || conversationList.isEmpty) {
      futures.add(initConversationMsg().then((_) => null));
    }
    if (scopeChanged || _joinedGroupIdsForSearch == null) {
      futures.add(_ensureJoinedGroupIdsForSearch());
    }
    if (futures.isEmpty) {
      return;
    }
    await Future.wait<void>(futures);
    if (generation != _globalSearchGeneration) {
      return;
    }
  }

  /// 自托管模式下刷新并返回当前已加入群 ID 集合；非自托管返回 null（跳过过滤）。
  Future<Set<String>?> _loadJoinedGroupIdsForSearch() async {
    if (!SelfHostedGroupBridge.enabled) {
      return null;
    }
    final friendshipModel = serviceLocator<TUIFriendShipViewModel>();
    if (friendshipModel.groupList.isEmpty) {
      await friendshipModel.loadGroupListData();
    }
    return friendshipModel.groupList
        .map((group) => group.groupID.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  List<V2TimMessageSearchResultItem>? _filterMsgListForJoinedGroups(
    List<V2TimMessageSearchResultItem>? items,
  ) {
    final joinedIds = _joinedGroupIdsForSearch;
    if (joinedIds == null || items == null) {
      return items;
    }
    return filterMessageSearchResultsByJoinedGroups(items, joinedIds)
        .cast<V2TimMessageSearchResultItem>();
  }

  ({String? userID, String? groupID})? _conversationTargets(String conversationId) {
    if (conversationId.startsWith('c2c_')) {
      final userID = conversationId.substring(4).trim();
      return userID.isEmpty ? null : (userID: userID, groupID: null);
    }
    if (conversationId.startsWith('group_')) {
      final groupID = conversationId.substring(6).trim();
      return groupID.isEmpty ? null : (userID: null, groupID: groupID);
    }
    return null;
  }

  ({String? userID, String? groupID})? _resolveConversationTargets({
    required String conversationId,
    String? groupID,
    String? userID,
  }) {
    final parsed = _conversationTargets(conversationId);
    if (parsed != null) {
      return parsed;
    }
    final resolvedGroupId = groupID?.trim() ?? '';
    if (resolvedGroupId.isNotEmpty) {
      return (userID: null, groupID: resolvedGroupId);
    }
    final resolvedUserId = userID?.trim() ?? '';
    if (resolvedUserId.isNotEmpty) {
      return (userID: resolvedUserId, groupID: null);
    }
    return null;
  }

  bool _messageMatchesSenderFilter(V2TimMessage message, Set<String> senderSet) {
    final sender = (message.sender ?? message.userID ?? '').trim();
    final senderAlt = (message.userID ?? message.sender ?? '').trim();
    if (senderSet.contains(sender) || senderSet.contains(senderAlt)) {
      return true;
    }
    if (message.isSelf == true) {
      final loginUserId =
          serviceLocator<TUISelfInfoViewModel>().loginInfo?.userID?.trim() ?? '';
      if (loginUserId.isNotEmpty && senderSet.contains(loginUserId)) {
        return true;
      }
    }
    return false;
  }

  bool _isImageOrFileMessage(V2TimMessage message) {
    final type = message.elemType;
    return type == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        type == MessageElemType.V2TIM_ELEM_TYPE_FILE;
  }

  Future<List<V2TimMessage>> _loadConversationHistoryBatch({
    required String? userID,
    required String? groupID,
    required int count,
    String? lastMsgID,
  }) async {
    final localBatch = await _messageService.getHistoryMessageList(
      userID: userID,
      groupID: groupID,
      count: count,
      lastMsgID: lastMsgID,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    );
    if (localBatch.isNotEmpty) {
      return localBatch;
    }
    return _messageService.getHistoryMessageList(
      userID: userID,
      groupID: groupID,
      count: count,
      lastMsgID: lastMsgID,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
    );
  }

  bool _mediaFileMatchesKeyword(V2TimMessage message, String keyword) {
    if (keyword.isEmpty) {
      return true;
    }
    final lower = keyword.toLowerCase();
    if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE) {
      final name = message.fileElem?.fileName?.toLowerCase() ?? '';
      return name.contains(lower);
    }
    return false;
  }

  Future<void> loadMediaAndFileForConversation(
    String conversationId, {
    required bool reset,
    String keyword = '',
  }) async {
    if (mediaFileLoading) {
      return;
    }
    if (reset) {
      mediaFileMsgListForConversation = [];
      mediaFileHasMore = true;
      _mediaFileLastMsgID = null;
    }
    if (!mediaFileHasMore) {
      return;
    }
    final targets = _conversationTargets(conversationId);
    if (targets == null) {
      mediaFileHasMore = false;
      notifyListeners();
      return;
    }

    mediaFileLoading = true;
    notifyListeners();
    try {
      final seen = mediaFileMsgListForConversation
          .map((m) => m.msgID ?? m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      var appendedCount = 0;
      var keepLoading = true;
      while (keepLoading && mediaFileHasMore) {
        final batch = await _loadConversationHistoryBatch(
          userID: targets.userID,
          groupID: targets.groupID,
          count: 50,
          lastMsgID: _mediaFileLastMsgID,
        );
        if (batch.isEmpty) {
          mediaFileHasMore = false;
          break;
        }
        final nextLastMsgId = batch.last.msgID;
        if (nextLastMsgId == null ||
            nextLastMsgId.isEmpty ||
            nextLastMsgId == _mediaFileLastMsgID) {
          mediaFileHasMore = false;
          break;
        }
        _mediaFileLastMsgID = nextLastMsgId;
        if (batch.length < 50) {
          mediaFileHasMore = false;
        }

        for (final message in batch) {
          if (!_isImageOrFileMessage(message)) {
            continue;
          }
          if (!_mediaFileMatchesKeyword(message, keyword)) {
            continue;
          }
          final id = message.msgID ?? message.id ?? '';
          if (id.isNotEmpty && seen.contains(id)) {
            continue;
          }
          if (id.isNotEmpty) {
            seen.add(id);
          }
          mediaFileMsgListForConversation.add(message);
          appendedCount++;
        }
        keepLoading = appendedCount == 0;
      }
    } finally {
      mediaFileLoading = false;
      notifyListeners();
    }
  }

  List<V2TimMessage> mergedConversationSearchResults({required String keyword}) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return const [];
    }
    final seen = <String>{};
    final merged = <V2TimMessage>[];
    void addMessage(V2TimMessage message) {
      final id = message.msgID ?? message.id ?? '';
      if (id.isNotEmpty && seen.contains(id)) {
        return;
      }
      if (id.isNotEmpty) {
        seen.add(id);
      }
      merged.add(message);
    }

    for (final message in currentMsgListForConversation) {
      addMessage(message);
    }
    for (final message in mediaFileMsgListForConversation) {
      if (_mediaFileMatchesKeyword(message, trimmed)) {
        addMessage(message);
      }
    }
    merged.sort(
      (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
    );
    return merged;
  }

  bool _isMediaMessage(V2TimMessage message) {
    final type = message.elemType;
    return type == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
        type == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
  }

  bool _isFileMessage(V2TimMessage message) {
    return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE;
  }

  Future<void> loadConversationAssets(
    String conversationId, {
    required bool reset,
    String? userID,
    String? groupID,
  }) async {
    if (conversationAssetLoading) {
      return;
    }
    if (reset) {
      conversationMediaMessages = [];
      conversationFileMessages = [];
      conversationAssetHasMore = true;
      _conversationAssetLastMsgID = null;
    }
    if (!conversationAssetHasMore) {
      return;
    }
    final targets = _resolveConversationTargets(
      conversationId: conversationId,
      userID: userID,
      groupID: groupID,
    );
    if (targets == null) {
      conversationAssetHasMore = false;
      notifyListeners();
      return;
    }

    conversationAssetLoading = true;
    notifyListeners();
    try {
      final seenMedia = conversationMediaMessages
          .map((m) => m.msgID ?? m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      final seenFile = conversationFileMessages
          .map((m) => m.msgID ?? m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      var appendedCount = 0;
      var keepLoading = true;
      while (keepLoading && conversationAssetHasMore) {
        final batch = await _loadConversationHistoryBatch(
          userID: targets.userID,
          groupID: targets.groupID,
          count: 50,
          lastMsgID: _conversationAssetLastMsgID,
        );
        if (batch.isEmpty) {
          conversationAssetHasMore = false;
          break;
        }
        final nextLastMsgId = batch.last.msgID;
        if (nextLastMsgId == null ||
            nextLastMsgId.isEmpty ||
            nextLastMsgId == _conversationAssetLastMsgID) {
          conversationAssetHasMore = false;
          break;
        }
        _conversationAssetLastMsgID = nextLastMsgId;
        if (batch.length < 50) {
          conversationAssetHasMore = false;
        }

        for (final message in batch) {
          final id = message.msgID ?? message.id ?? '';
          if (_isMediaMessage(message)) {
            if (id.isEmpty || !seenMedia.contains(id)) {
              if (id.isNotEmpty) {
                seenMedia.add(id);
              }
              conversationMediaMessages.add(message);
              appendedCount++;
            }
          }
          if (_isFileMessage(message)) {
            if (id.isEmpty || !seenFile.contains(id)) {
              if (id.isNotEmpty) {
                seenFile.add(id);
              }
              conversationFileMessages.add(message);
              appendedCount++;
            }
          }
        }
        keepLoading = appendedCount == 0;
      }
    } finally {
      conversationAssetLoading = false;
      notifyListeners();
    }
  }

  void searchFriendByKey(String searchKey) async {
    final keyword = searchKey.trim();
    if (keyword.isEmpty) {
      friendList = [];
      notifyListeners();
      return;
    }
    final searchResult = await _friendshipServices.searchFriends(
      searchParam: _buildFriendSearchParam(keyword),
    );
    friendList = await _mergeFriendSearchResults(
      keyword,
      filterFriendSearchResultsForPickers(searchResult),
    );
    notifyListeners();
  }

  V2TimFriendSearchParam _buildFriendSearchParam(String keyword) {
    return V2TimFriendSearchParam(
      keywordList: [keyword],
      isSearchUserID: true,
      isSearchNickName: true,
      isSearchRemark: true,
    );
  }

  V2TimGroupSearchParam _buildGroupSearchParam(String keyword) {
    return V2TimGroupSearchParam(
      keywordList: [keyword],
      isSearchGroupID: true,
      isSearchGroupName: true,
    );
  }

  Future<List<V2TimFriendInfo>> _localFriendsForSearch() async {
    if (SelfHostedFriendshipBridge.enabled) {
      return filterFriendListForPickers(
        await SelfHostedFriendshipBridge.loadFriendList(),
      );
    }
    final friendshipModel = serviceLocator<TUIFriendShipViewModel>();
    if (friendshipModel.friendList == null ||
        friendshipModel.friendList!.isEmpty) {
      await friendshipModel.loadContactListData();
    }
    return filterFriendListForPickers(friendshipModel.friendList ?? const []);
  }

  /// 好友删除后会话列表可能仍缓存 C2C，需清空以便下次搜索重新拉取。
  void invalidateGlobalSearchContext() {
    conversationList = [];
    _joinedGroupIdsForSearch = null;
    _syncSearchAccountScope(forceReloadContext: false);
  }

  Future<List<V2TimGroupInfo>> _localGroupsForSearch() async {
    final friendshipModel = serviceLocator<TUIFriendShipViewModel>();
    if (friendshipModel.groupList.isEmpty) {
      await friendshipModel.loadGroupListData();
    }
    return friendshipModel.groupList;
  }

  Future<List<V2TimFriendInfoResult>> _mergeFriendSearchResults(
    String keyword,
    List<V2TimFriendInfoResult>? apiResults, {
    int? generation,
    void Function()? notifyIfCurrent,
  }) async {
    final restrictToFriends = SelfHostedFriendshipBridge.enabled;
    Set<String>? friendIds;
    if (restrictToFriends && !SelfHostedFriendshipBridge.localSearchEnabled) {
      final localFriends = await _localFriendsForSearch();
      friendIds = localFriends
          .map((friend) => friend.userID.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    final byUserId = <String, V2TimFriendInfoResult>{};
    for (final item in apiResults ?? const <V2TimFriendInfoResult>[]) {
      final userId = item.friendInfo?.userID.trim() ?? '';
      if (userId.isEmpty) {
        continue;
      }
      if (friendIds != null && !friendIds.contains(userId)) {
        continue;
      }
      byUserId[userId] = item;
    }

    if (SelfHostedFriendshipBridge.localSearchEnabled) {
      final page = await SelfHostedFriendshipBridge.searchFriendsLocal(
        keyword: keyword,
        limit: 80,
      );
      final hydrated =
          await SelfHostedFriendshipBridge.hydrateFriends(page.ids);
      for (final friend in hydrated) {
        final userId = friend.userID.trim();
        if (userId.isEmpty || byUserId.containsKey(userId)) {
          continue;
        }
        byUserId[userId] = V2TimFriendInfoResult(
          resultCode: 0,
          resultInfo: '',
          relation: 0,
          friendInfo: friend,
        );
      }
    } else {
      final localFriends = await _localFriendsForSearch();
      for (final friend in localFriends) {
        if (!friendInfoMatchesSearchKeyword(friend, keyword)) {
          continue;
        }
        final userId = friend.userID.trim();
        if (userId.isEmpty || byUserId.containsKey(userId)) {
          continue;
        }
        byUserId[userId] = V2TimFriendInfoResult(
          resultCode: 0,
          resultInfo: '',
          relation: 0,
          friendInfo: friend,
        );
      }
    }

    if (conversationList.isEmpty) {
      await initConversationMsg();
    }
    await _localConversationsMatchingKeyword(
      keyword,
      generation: generation,
      onBatch: (batch) {
        if (generation != null && generation != _globalSearchGeneration) {
          return;
        }
        _applyLocalC2cMatchesToFriendMap(
          byUserId,
          batch,
          friendIds: friendIds,
        );
        if (notifyIfCurrent != null) {
          friendList = byUserId.values.toList(growable: false);
          notifyIfCurrent();
        }
      },
    );

    return byUserId.values.toList(growable: false);
  }

  Future<List<V2TimGroupInfo>> _mergeGroupSearchResults(
    String keyword,
    List<V2TimGroupInfo> apiResults, {
    int? generation,
    void Function()? notifyIfCurrent,
  }) async {
    final byGroupId = <String, V2TimGroupInfo>{};
    for (final group in apiResults) {
      final groupId = group.groupID.trim();
      if (groupId.isNotEmpty) {
        byGroupId[groupId] = group;
      }
    }

    if (SelfHostedGroupBridge.localSearchEnabled) {
      final page = await SelfHostedGroupBridge.searchGroupsLocal(
        keyword: keyword,
        limit: 80,
      );
      final hydrated = await SelfHostedGroupBridge.hydrateGroups(page.ids);
      for (final group in hydrated) {
        final groupId = group.groupID.trim();
        if (groupId.isEmpty || byGroupId.containsKey(groupId)) {
          continue;
        }
        byGroupId[groupId] = group;
      }
    } else {
      for (final group in await _localGroupsForSearch()) {
        if (!groupInfoMatchesSearchKeyword(group, keyword)) {
          continue;
        }
        final groupId = group.groupID.trim();
        if (groupId.isEmpty || byGroupId.containsKey(groupId)) {
          continue;
        }
        byGroupId[groupId] = group;
      }
    }

    if (conversationList.isEmpty) {
      await initConversationMsg();
    }
    await _localConversationsMatchingKeyword(
      keyword,
      generation: generation,
      onBatch: (batch) {
        if (generation != null && generation != _globalSearchGeneration) {
          return;
        }
        _applyLocalGroupMatchesToGroupMap(byGroupId, batch);
        if (notifyIfCurrent != null) {
          var partial = byGroupId.values.toList(growable: false);
          final joinedIds = _joinedGroupIdsForSearch;
          if (joinedIds != null) {
            partial = filterGroupInfosByJoinedIds(partial, joinedIds);
          }
          groupList = partial;
          notifyIfCurrent();
        }
      },
    );

    var results = byGroupId.values.toList(growable: false);
    final joinedIds = _joinedGroupIdsForSearch;
    if (joinedIds != null) {
      results = filterGroupInfosByJoinedIds(results, joinedIds);
    }
    return results;
  }

  Future<void> _searchFriendByKeyQuiet(
    String searchKey, {
    required int generation,
    required void Function() notifyIfCurrent,
    void Function(List<V2TimFriendInfoResult> apiResults)? onApiResults,
  }) async {
    final keyword = searchKey.trim();
    if (keyword.isEmpty) {
      friendList = [];
      return;
    }
    final searchResult = await _friendshipServices.searchFriends(
      searchParam: _buildFriendSearchParam(keyword),
    );
    if (generation != _globalSearchGeneration) {
      return;
    }
    final apiResults =
        filterFriendSearchResultsForPickers(searchResult) ?? const [];
    onApiResults?.call(apiResults);
    friendList = apiResults;
    notifyIfCurrent();

    friendList = await _mergeFriendSearchResults(
      keyword,
      apiResults,
      generation: generation,
      notifyIfCurrent: notifyIfCurrent,
    );
    if (generation != _globalSearchGeneration) {
      return;
    }
    notifyIfCurrent();
  }

  void searchGroupByKey(String searchKey) async {
    final keyword = searchKey.trim();
    if (keyword.isEmpty) {
      groupList = [];
      notifyListeners();
      return;
    }
    final searchResult = await _groupServices.searchGroups(
      searchParam: _buildGroupSearchParam(keyword),
    );
    groupList = await _mergeGroupSearchResults(
      keyword,
      searchResult.data ?? const [],
    );
    notifyListeners();
  }

  Future<void> _searchGroupByKeyQuiet(
    String searchKey, {
    required int generation,
    required void Function() notifyIfCurrent,
    void Function(List<V2TimGroupInfo> apiResults)? onApiResults,
  }) async {
    final keyword = searchKey.trim();
    if (keyword.isEmpty) {
      groupList = [];
      return;
    }
    final searchResult = await _groupServices.searchGroups(
      searchParam: _buildGroupSearchParam(keyword),
    );
    if (generation != _globalSearchGeneration) {
      return;
    }
    final apiResults = searchResult.data ?? const <V2TimGroupInfo>[];
    onApiResults?.call(apiResults);
    groupList = apiResults;
    notifyIfCurrent();

    groupList = await _mergeGroupSearchResults(
      keyword,
      apiResults,
      generation: generation,
      notifyIfCurrent: notifyIfCurrent,
    );
    if (generation != _globalSearchGeneration) {
      return;
    }
    notifyIfCurrent();
  }

  void clearConversationTextResults() {
    currentMsgListForConversation = [];
    totalMsgInConversationCount = 0;
    notifyListeners();
  }

  List<V2TimMessage> conversationFilterMessages = [];
  bool conversationFilterLoading = false;
  bool conversationFilterHasMore = true;
  String? _conversationFilterLastMsgID;
  int _conversationFilterSearchPageIndex = 0;
  /// Once local search fails (e.g. non-premium), stick to history scan for
  /// this filter session so "load more" stays consistent.
  bool _conversationFilterPreferHistoryScan = false;

  void clearConversationFilterResults() {
    conversationFilterMessages = [];
    conversationFilterLoading = false;
    conversationFilterHasMore = true;
    _conversationFilterLastMsgID = null;
    _conversationFilterSearchPageIndex = 0;
    _conversationFilterPreferHistoryScan = false;
    notifyListeners();
  }

  /// Searchable elem types so date-only queries may omit keywords
  /// (IM requires keyword when both sender and type lists are empty).
  static const List<int> _conversationFilterSearchMessageTypes = [
    MessageElemType.V2TIM_ELEM_TYPE_TEXT,
    MessageElemType.V2TIM_ELEM_TYPE_CUSTOM,
    MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
    MessageElemType.V2TIM_ELEM_TYPE_SOUND,
    MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
    MessageElemType.V2TIM_ELEM_TYPE_FILE,
    MessageElemType.V2TIM_ELEM_TYPE_LOCATION,
    MessageElemType.V2TIM_ELEM_TYPE_MERGER,
  ];

  Future<void> searchConversationWithFilter({
    required String conversationId,
    required bool reset,
    int searchTimePosition = 0,
    int searchTimePeriod = 0,
    List<String>? userIDList,
    String? groupID,
    String? userID,
  }) async {
    if (reset) {
      conversationFilterMessages = [];
      conversationFilterHasMore = true;
      _conversationFilterLastMsgID = null;
      _conversationFilterSearchPageIndex = 0;
      _conversationFilterPreferHistoryScan = false;
    }
    if (!conversationFilterHasMore || conversationFilterLoading) {
      return;
    }

    final targets = _resolveConversationTargets(
      conversationId: conversationId,
      groupID: groupID,
      userID: userID,
    );
    if (targets == null) {
      conversationFilterHasMore = false;
      notifyListeners();
      return;
    }

    final senderList = (userIDList ?? const [])
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    final hasDateFilter = searchTimePosition > 0 && searchTimePeriod > 0;
    final hasSenderFilter = senderList.isNotEmpty;
    if (!hasDateFilter && !hasSenderFilter) {
      conversationFilterHasMore = false;
      notifyListeners();
      return;
    }

    conversationFilterLoading = true;
    notifyListeners();
    try {
      final useLocalSearch = !_conversationFilterPreferHistoryScan &&
          _canSearchLocalMessagesForCurrentUser();
      if (useLocalSearch) {
        final ok = await _searchConversationFilterViaLocalMessages(
          conversationId: conversationId,
          searchTimePosition: hasDateFilter ? searchTimePosition : 0,
          searchTimePeriod: hasDateFilter ? searchTimePeriod : 0,
          senderList: senderList,
        );
        if (ok) {
          return;
        }
        // Premium/API failure → history scan for the rest of this session.
        _conversationFilterPreferHistoryScan = true;
        if (reset) {
          conversationFilterMessages = [];
          _conversationFilterLastMsgID = null;
          conversationFilterHasMore = true;
        }
      }

      await _searchConversationFilterViaHistoryScan(
        targets: targets,
        searchTimePosition: searchTimePosition,
        searchTimePeriod: searchTimePeriod,
        senderList: senderList,
        reset: reset,
      );
    } finally {
      conversationFilterLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when SDK local search handled the page (including empty).
  Future<bool> _searchConversationFilterViaLocalMessages({
    required String conversationId,
    required int searchTimePosition,
    required int searchTimePeriod,
    required List<String> senderList,
  }) async {
    const pageSize = 30;
    final pageIndex = _conversationFilterSearchPageIndex;
    try {
      final searchResult = await _messageService.searchLocalMessages(
        searchParam: V2TimMessageSearchParam(
          conversationID: conversationId,
          // Empty keywords allowed when sender and/or messageTypeList is set.
          keywordList: const <String>[],
          userIDList: senderList,
          messageTypeList: senderList.isEmpty
              ? _conversationFilterSearchMessageTypes
              : const <int>[],
          searchTimePosition: searchTimePosition,
          searchTimePeriod: searchTimePeriod,
          pageIndex: pageIndex,
          pageSize: pageSize,
          type: KeywordListMatchType.V2TIM_KEYWORD_LIST_MATCH_TYPE_OR.index,
        ),
      );
      if (!_canSearchLocalMessagesForCurrentUser()) {
        return false;
      }
      if (searchResult.code != 0 || searchResult.data == null) {
        return false;
      }

      final items = searchResult.data!.messageSearchResultItems;
      final matched = items?.firstWhereOrNull(
            (element) => element.conversationID == conversationId,
          ) ??
          (items != null && items.length == 1 ? items.first : null);
      final pageMessages = matched?.messageList ?? const <V2TimMessage>[];
      final totalCount = matched?.messageCount ?? 0;

      final seen = conversationFilterMessages
          .map((m) => m.msgID ?? m.id ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
      for (final message in pageMessages) {
        final id = message.msgID ?? message.id ?? '';
        if (id.isNotEmpty && seen.contains(id)) {
          continue;
        }
        if (id.isNotEmpty) {
          seen.add(id);
        }
        conversationFilterMessages.add(message);
      }

      _conversationFilterSearchPageIndex = pageIndex + 1;
      if (pageMessages.isEmpty) {
        conversationFilterHasMore = false;
      } else if (totalCount > 0) {
        conversationFilterHasMore =
            conversationFilterMessages.length < totalCount;
      } else {
        conversationFilterHasMore = pageMessages.length >= pageSize;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _searchConversationFilterViaHistoryScan({
    required ({String? userID, String? groupID}) targets,
    required int searchTimePosition,
    required int searchTimePeriod,
    required List<String> senderList,
    required bool reset,
  }) async {
    final dateRange = timestampRangeFromSearchParams(
      searchTimePosition: searchTimePosition,
      searchTimePeriod: searchTimePeriod,
    );
    final hasDateFilter = dateRange.startTs > 0 && dateRange.endTs > 0;
    final senderSet = senderList.toSet();
    final hasSenderFilter = senderSet.isNotEmpty;

    const targetBatchSize = 30;
    const fetchCount = 50;
    final seen = conversationFilterMessages
        .map((m) => m.msgID ?? m.id ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final initialCount = conversationFilterMessages.length;
    var reachedBeforeRange = false;
    var lastMsgID = reset ? null : _conversationFilterLastMsgID;

    while (conversationFilterMessages.length - initialCount < targetBatchSize &&
        !reachedBeforeRange &&
        conversationFilterHasMore) {
      final batch = await _messageService.getHistoryMessageList(
        userID: targets.userID,
        groupID: targets.groupID,
        count: fetchCount,
        lastMsgID: lastMsgID,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
      );
      if (batch.isEmpty) {
        conversationFilterHasMore = false;
        break;
      }

      lastMsgID = batch.last.msgID;
      if (batch.length < fetchCount) {
        conversationFilterHasMore = false;
      }

      for (final message in batch) {
        final ts = message.timestamp ?? 0;
        if (hasDateFilter) {
          if (ts > dateRange.endTs) {
            continue;
          }
          if (ts < dateRange.startTs) {
            reachedBeforeRange = true;
            conversationFilterHasMore = false;
            break;
          }
        }
        if (hasSenderFilter &&
            !_messageMatchesSenderFilter(message, senderSet)) {
          continue;
        }

        final id = message.msgID ?? message.id ?? '';
        if (id.isNotEmpty && seen.contains(id)) {
          continue;
        }
        if (id.isNotEmpty) {
          seen.add(id);
        }
        conversationFilterMessages.add(message);
      }
    }

    _conversationFilterLastMsgID = lastMsgID;
  }

  void getMsgForConversation(String keyword, String conversationId, int page) async {
    void clearData() {
      clearConversationTextResults();
    }

    if (page == 0) {
      clearData();
    }
    if (keyword.isEmpty) {
      clearData();
      notifyListeners();
      return;
    }
    if (!_canSearchLocalMessagesForCurrentUser()) {
      clearData();
      notifyListeners();
      return;
    }
    final generation = ++_conversationTextSearchGeneration;
    final searchResult = await _messageService.searchLocalMessages(
        searchParam: V2TimMessageSearchParam(
      keywordList: [keyword],
      pageIndex: page,
      pageSize: 30,
      searchTimePeriod: 0,
      searchTimePosition: 0,
      conversationID: conversationId,
      type: KeywordListMatchType.V2TIM_KEYWORD_LIST_MATCH_TYPE_OR.index,
    ));
    if (generation != _conversationTextSearchGeneration) {
      return;
    }
    if (!_canSearchLocalMessagesForCurrentUser()) {
      clearData();
      notifyListeners();
      return;
    }
    if (searchResult.code == 0 && searchResult.data != null) {
      final messageSearchResultItems = searchResult.data!.messageSearchResultItems!
          .firstWhereOrNull((element) => element.conversationID == conversationId);
      totalMsgInConversationCount = messageSearchResultItems?.messageCount ?? 0;
      currentMsgListForConversation = [
        ...currentMsgListForConversation,
        ...(messageSearchResultItems?.messageList ?? [])
      ];
    }
    notifyListeners();
  }

  void scheduleConversationTextSearch({
    required String keyword,
    required String conversationId,
    required int page,
    bool reset = true,
  }) {
    _conversationTextSearchDebounce?.cancel();
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      _conversationTextSearchGeneration++;
      clearConversationTextResults();
      return;
    }
    if (reset) {
      clearConversationTextResults();
    }
    _conversationTextSearchDebounce = Timer(
      _conversationTextSearchDebounceDuration,
      () {
        getMsgForConversation(trimmed, conversationId, page);
      },
    );
  }

  void scheduleConversationMediaFileSearch({
    required String conversationId,
    required bool reset,
    String keyword = '',
  }) {
    _conversationMediaSearchDebounce?.cancel();
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      _conversationMediaSearchGeneration++;
      mediaFileMsgListForConversation = [];
      mediaFileHasMore = true;
      _mediaFileLastMsgID = null;
      notifyListeners();
      return;
    }
    final generation = ++_conversationMediaSearchGeneration;
    _conversationMediaSearchDebounce = Timer(
      _conversationMediaSearchDebounceDuration,
      () {
        if (generation != _conversationMediaSearchGeneration) {
          return;
        }
        unawaited(
          loadMediaAndFileForConversation(
            conversationId,
            reset: reset,
            keyword: trimmed,
          ),
        );
      },
    );
  }

  void searchMsgByKey(String searchKey, bool isFirst) async {
    if (!_canSearchLocalMessagesForCurrentUser()) {
      msgList = [];
      totalMsgCount = 0;
      notifyListeners();
      return;
    }
    if (_joinedGroupIdsForSearch == null && SelfHostedGroupBridge.enabled) {
      _joinedGroupIdsForSearch = await _loadJoinedGroupIdsForSearch();
    }
    if (isFirst == true) {
      msgPage = 0;
      msgList = [];
      totalMsgCount = 0;
    }
    final searchResult = await _messageService.searchLocalMessages(
        searchParam: V2TimMessageSearchParam(
      keywordList: [searchKey],
      pageIndex: msgPage,
      pageSize: 5,
      searchTimePeriod: 0,
      searchTimePosition: 0,
      type: KeywordListMatchType.V2TIM_KEYWORD_LIST_MATCH_TYPE_OR.index,
    ));
    if (!_canSearchLocalMessagesForCurrentUser()) {
      msgList = [];
      totalMsgCount = 0;
      notifyListeners();
      return;
    }
    if (searchResult.code == 0 && searchResult.data != null) {
      msgPage++;
      msgList = [...?msgList, ...?searchResult.data!.messageSearchResultItems];
      msgList = _filterMsgListForJoinedGroups(msgList);
      totalMsgCount = searchResult.data!.totalCount ?? 0;
    }
    notifyListeners();
  }

  Future<void> _searchMsgByKeyQuiet(
    String searchKey, {
    required int generation,
    required void Function() notifyIfCurrent,
    void Function(
      List<V2TimMessageSearchResultItem>? items,
      int totalCount,
    )? onApiResults,
  }) async {
    if (!_canSearchLocalMessagesForCurrentUser()) {
      if (generation != _globalSearchGeneration) {
        return;
      }
      onApiResults?.call(null, 0);
      msgList = [];
      totalMsgCount = 0;
      notifyIfCurrent();
      return;
    }
    final searchResult = await _messageService.searchLocalMessages(
      searchParam: V2TimMessageSearchParam(
        keywordList: [searchKey],
        pageIndex: 0,
        pageSize: 5,
        searchTimePeriod: 0,
        searchTimePosition: 0,
        type: KeywordListMatchType.V2TIM_KEYWORD_LIST_MATCH_TYPE_OR.index,
      ),
    );
    if (generation != _globalSearchGeneration) {
      return;
    }
    if (!_canSearchLocalMessagesForCurrentUser()) {
      onApiResults?.call(null, 0);
      msgList = [];
      totalMsgCount = 0;
      notifyIfCurrent();
      return;
    }
    msgPage = 1;
    if (searchResult.code == 0 && searchResult.data != null) {
      final apiResults = searchResult.data!.messageSearchResultItems;
      final totalCount = searchResult.data!.totalCount ?? 0;
      onApiResults?.call(apiResults, totalCount);
      msgList = apiResults;
      totalMsgCount = totalCount;
    } else {
      onApiResults?.call(null, 0);
      msgList = [];
      totalMsgCount = 0;
    }
    notifyIfCurrent();

    msgList = _filterMsgListForJoinedGroups(msgList);
    if (generation != _globalSearchGeneration) {
      return;
    }
    notifyIfCurrent();
  }

  Future<void> _refreshGlobalSearchWithContext(
    String searchKey, {
    required int generation,
    required List<V2TimFriendInfoResult> friendApiResults,
    required List<V2TimGroupInfo> groupApiResults,
    required List<V2TimMessageSearchResultItem>? msgApiResults,
    required int msgTotalCount,
    required void Function() notifyIfCurrent,
  }) async {
    if (generation != _globalSearchGeneration) {
      return;
    }
    var changed = false;
    if (friendApiResults.isNotEmpty || searchKey.trim().isNotEmpty) {
      friendList = await _mergeFriendSearchResults(
        searchKey,
        friendApiResults,
        generation: generation,
        notifyIfCurrent: notifyIfCurrent,
      );
      changed = true;
    }
    if (generation != _globalSearchGeneration) {
      return;
    }
    if (groupApiResults.isNotEmpty || searchKey.trim().isNotEmpty) {
      groupList = await _mergeGroupSearchResults(
        searchKey,
        groupApiResults,
        generation: generation,
        notifyIfCurrent: notifyIfCurrent,
      );
      changed = true;
    }
    if (generation != _globalSearchGeneration) {
      return;
    }
    if (msgApiResults != null) {
      msgList = _filterMsgListForJoinedGroups(msgApiResults);
      totalMsgCount = msgTotalCount;
      changed = true;
    }
    if (changed) {
      notifyIfCurrent();
    }
  }

  Future<void> _runGlobalSearch(String searchKey) async {
    final generation = ++_globalSearchGeneration;
    friendList = [];
    groupList = [];
    msgList = [];
    totalMsgCount = 0;
    msgPage = 0;
    globalSearchLoading = true;
    _completedGlobalSearchKey = '';
    notifyListeners();

    void notifyIfCurrent() {
      if (generation == _globalSearchGeneration) {
        notifyListeners();
      }
    }

    try {
      var friendApiResults = const <V2TimFriendInfoResult>[];
      var groupApiResults = const <V2TimGroupInfo>[];
      List<V2TimMessageSearchResultItem>? msgApiResults;
      var msgTotalCount = 0;

      final prepareFuture = _ensureGlobalSearchContext(generation).then((_) async {
        await _refreshGlobalSearchWithContext(
          searchKey,
          generation: generation,
          friendApiResults: friendApiResults,
          groupApiResults: groupApiResults,
          msgApiResults: msgApiResults,
          msgTotalCount: msgTotalCount,
          notifyIfCurrent: notifyIfCurrent,
        );
      });

      Future<void> deferredMsgSearch() async {
        await Future<void>.delayed(_globalMessageSearchDeferDuration);
        if (generation != _globalSearchGeneration) {
          return;
        }
        await _searchMsgByKeyQuiet(
          searchKey,
          generation: generation,
          notifyIfCurrent: notifyIfCurrent,
          onApiResults: (items, totalCount) {
            msgApiResults = items;
            msgTotalCount = totalCount;
          },
        );
      }

      await Future.wait<void>([
        prepareFuture,
        _searchFriendByKeyQuiet(
          searchKey,
          generation: generation,
          notifyIfCurrent: notifyIfCurrent,
          onApiResults: (results) => friendApiResults = results,
        ),
        _searchGroupByKeyQuiet(
          searchKey,
          generation: generation,
          notifyIfCurrent: notifyIfCurrent,
          onApiResults: (results) => groupApiResults = results,
        ),
        deferredMsgSearch(),
      ]);
    } catch (_) {
      if (generation != _globalSearchGeneration) {
        return;
      }
      friendList = [];
      groupList = [];
      msgList = [];
      totalMsgCount = 0;
      msgPage = 0;
      globalSearchLoading = false;
      _completedGlobalSearchKey = searchKey;
      notifyListeners();
      return;
    }
    if (generation != _globalSearchGeneration) {
      return;
    }
    globalSearchLoading = false;
    _completedGlobalSearchKey = searchKey;
    notifyListeners();
  }

  void searchByKey(String? searchKey) {
    _globalSearchDebounce?.cancel();
    final trimmed = searchKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      _globalSearchGeneration++;
      friendList = [];
      groupList = [];
      msgList = [];
      totalMsgCount = 0;
      msgPage = 0;
      globalSearchLoading = false;
      _completedGlobalSearchKey = '';
      notifyListeners();
      return;
    }
    _globalSearchDebounce = Timer(_globalSearchDebounceDuration, () {
      unawaited(_runGlobalSearch(trimmed));
    });
  }
}
