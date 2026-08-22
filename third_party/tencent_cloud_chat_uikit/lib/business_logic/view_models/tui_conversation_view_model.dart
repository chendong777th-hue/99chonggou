// ignore_for_file: unnecessary_getters_setters

import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/V2TimConversationListener.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_search_param.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_search_param.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/conversation_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class TUIConversationViewModelHooks {
  static void Function({
    required List<V2TimConversation?> conversations,
    required bool isRefresh,
    required String nextSeq,
    required bool haveMoreData,
    required bool hasLoadedOnce,
  })? onPageLoaded;

  static void Function(List<V2TimConversation> conversations)?
      onConversationsChanged;

  static void Function(List<String> conversationIds)? onConversationsDeleted;

  static void Function(String conversationID)? onConversationReadLocally;
}

List<T> removeDuplicates<T>(
    List<T> list, bool Function(T first, T second) isEqual) {
  List<T> output = [];
  for (var i = 0; i < list.length; i++) {
    bool found = false;
    for (var j = 0; j < output.length; j++) {
      if (isEqual(list[i], output[j])) {
        found = true;
      }
    }
    if (!found) {
      output.add(list[i]);
    }
  }

  return output;
}

class TUIConversationViewModel extends ChangeNotifier {
  static const String conversationC2CPrefix = "c2c_";
  static const String conversationGroupPrefix = "group_";

  final TUISelfInfoViewModel selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  final ConversationService _conversationService =
      serviceLocator<ConversationService>();
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final TUIChatGlobalModel _chatGlobalModel =
      serviceLocator<TUIChatGlobalModel>();
  final MessageService _messageService = serviceLocator<MessageService>();
  late V2TimConversationListener _conversationListener;
  List<V2TimConversation?> _conversationList = [];
  List<V2TimConversation?>? _sortedConversationCache;
  bool _conversationListDirty = true;
  bool _isLoadingConversationData = false;
  bool _hasLoadedOnce = false;
  int? _pendingLoadCount;
  DateTime? _lastUnreadQueryAt;
  static const Duration _unreadQueryMinInterval = Duration(seconds: 8);
  static V2TimConversation? _selectedConversation;
  Map<String, String> webDraftMap = {};

  bool _haveMoreData = true;
  int _totalUnReadCount = 0;
  String? _scrollToConversation;
  final TUIChatGlobalModel globalChatModel =
      serviceLocator<TUIChatGlobalModel>();

  String _nextSeq = "0";
  ConversationLifeCycle? _lifeCycle;

  int _conversationSortTimestamp(V2TimConversation? conversation) {
    if (conversation == null) {
      return 0;
    }
    final draftTimestamp = conversation.draftTimestamp ?? 0;
    final lastMessageTimestamp = conversation.lastMessage?.timestamp ?? 0;
    final orderKey = conversation.orderkey ?? 0;
    return [draftTimestamp, lastMessageTimestamp, orderKey]
        .reduce((value, element) => value > element ? value : element);
  }

  List<V2TimConversation?> get conversationList {
    if (_conversationListDirty || _sortedConversationCache == null) {
      final sorted = List<V2TimConversation?>.from(_conversationList);
      sorted.sort((a, b) {
        final aPinned = a?.isPinned == true ? 1 : 0;
        final bPinned = b?.isPinned == true ? 1 : 0;
        if (aPinned != bPinned) {
          return bPinned.compareTo(aPinned);
        }
        return _conversationSortTimestamp(b)
            .compareTo(_conversationSortTimestamp(a));
      });
      _sortedConversationCache = sorted;
      _conversationListDirty = false;
    }
    return _sortedConversationCache!;
  }

  void _markConversationListDirty() {
    _conversationListDirty = true;
    _sortedConversationCache = null;
  }

  V2TimConversation? getConversation(String conversationID) {
    return _conversationList.firstWhereOrNull(
        (element) => element?.conversationID == conversationID);
  }

  void markConversationReadLocally(String? conversationID) {
    if (conversationID == null || conversationID.isEmpty) {
      return;
    }
    var changed = false;
    for (final conversation in _conversationList) {
      if (conversation?.conversationID == conversationID &&
          (conversation?.unreadCount ?? 0) != 0) {
        conversation!.unreadCount = 0;
        changed = true;
      }
    }
    if (_selectedConversation?.conversationID == conversationID &&
        (_selectedConversation?.unreadCount ?? 0) != 0) {
      _selectedConversation!.unreadCount = 0;
      changed = true;
    }
    TUIConversationViewModelHooks.onConversationReadLocally?.call(
      conversationID,
    );
    if (changed) {
      _markConversationListDirty();
      notifyListeners();
    }
  }

  Future<void> refreshConversationItem(String? conversationID) async {
    if (conversationID == null || conversationID.isEmpty) {
      return;
    }
    final conversation = await _conversationService.getConversation(
      conversationID: conversationID,
    );
    if (conversation == null) {
      return;
    }
    DisplayNameStore.instance.applyToConversation(conversation);
    _onConversationListChanged([conversation]);
  }

  String? get scrollToConversation => _scrollToConversation;

  set scrollToConversation(String? value) {
    _scrollToConversation = value;
    notifyListeners();
  }

  void clearScrollToConversation() {
    _scrollToConversation = null;
  }

  bool get haveMoreData {
    return _haveMoreData;
  }

  bool get isLoadingConversationData => _isLoadingConversationData;

  bool get hasLoadedOnce => _hasLoadedOnce;

  int get totalUnReadCount => _totalUnReadCount;

  set totalUnReadCount(int value) {
    _totalUnReadCount = value;
  }

  set lifeCycle(ConversationLifeCycle? value) {
    _lifeCycle = value;
  }

  set conversationList(List<V2TimConversation?> conversationList) {
    _conversationList = conversationList;
    _applyNameOverrides(_conversationList);
    _markConversationListDirty();
    notifyListeners();
  }

  set selectedConversation(V2TimConversation? value) {
    assignSelectedConversation(value);
  }

  void assignSelectedConversation(
    V2TimConversation? value, {
    bool notify = true,
  }) {
    DisplayNameStore.instance.applyToConversation(value);
    _selectedConversation = value;
    if (notify) {
      notifyListeners();
    }
  }

  V2TimConversation? get selectedConversation {
    return _selectedConversation;
  }

  static V2TimConversation? of() {
    return _selectedConversation;
  }

  void _onDisplayNameChanged() {
    final change = DisplayNameStore.instance.lastChange;
    if (change == null) {
      return;
    }
    final conversationID = change.type == 'group'
        ? '$conversationGroupPrefix${change.id}'
        : '$conversationC2CPrefix${change.id}';
    final updated = _applyNameOverrideByID(conversationID);
    if (updated) {
      _markConversationListDirty();
      notifyListeners();
    }
  }

  bool _applyNameOverrideByID(String conversationID) {
    var updated = false;
    for (final conversation in _conversationList) {
      if (conversation?.conversationID == conversationID) {
        updated = DisplayNameStore.instance.applyToConversation(conversation) ||
            updated;
      }
    }
    if (_selectedConversation?.conversationID == conversationID) {
      updated = DisplayNameStore.instance
              .applyToConversation(_selectedConversation) ||
          updated;
    }
    return updated;
  }

  void _applyNameOverrides(Iterable<V2TimConversation?> list) {
    for (final conversation in list) {
      DisplayNameStore.instance.applyToConversation(conversation);
    }
  }

  void reapplyDisplayNameOverrides() {
    var updated = false;
    for (final conversation in _conversationList) {
      updated = DisplayNameStore.instance.applyToConversation(conversation) ||
          updated;
    }
    updated =
        DisplayNameStore.instance.applyToConversation(_selectedConversation) ||
            updated;
    if (updated) {
      _markConversationListDirty();
      notifyListeners();
    }
  }

  TUIConversationViewModel() {
    DisplayNameStore.instance.addListener(_onDisplayNameChanged);
    _conversationListener =
        V2TimConversationListener(onConversationChanged: (conversationList) {
      _onConversationListChanged(conversationList);
    }, onNewConversation: (conversationList) {
      _addNewConversation(conversationList);
    }, onTotalUnreadMessageCountChanged: (totalUnread) {
      _totalUnReadCount = totalUnread;
      _chatGlobalModel.totalUnReadCount = totalUnread;
      notifyListeners();
    }, onSyncServerFinish: () {
      // Remove the process to load such a many of conversations after launching
      if (!PlatformUtils().isWeb) {
        // SDK can emit sync-finished more than once during startup/reconnect.
        // Conversation changes are already delivered by the incremental
        // callbacks above, so only seed the paged list once here.
        unawaited(loadInitConversation());
      }
      _chatGlobalModel.notifyRoamingSyncFinished();
    }, onConversationDeleted: (List<String> conversationIDList) {
      _onConversationDeleted(conversationIDList);
      for (var conversationID in conversationIDList) {
        String resultID = "";
        if (conversationID.startsWith(conversationC2CPrefix)) {
          resultID = conversationID.replaceFirst(conversationC2CPrefix, "");
        } else if (conversationID.startsWith(conversationGroupPrefix)) {
          resultID = conversationID.replaceFirst(conversationGroupPrefix, "");
        }

        if (resultID != "") {
          _chatGlobalModel.removeMessageList(resultID);
        }
      }
    });
  }

  loadInitConversation() async {
    if (_hasLoadedOnce || _isLoadingConversationData) {
      return;
    }
    await loadData(count: 40);
    // Remove the process to load such a many of conversations after launching
    // if (selfInfoViewModel.globalConfig?.isPreloadMessagesAfterInit ?? true) {
    //   _chatGlobalModel.initMessageMapFromLocalDatabase(_conversationList);
    // }
  }

  initConversation() async {
    clearData();
    loadInitConversation();
  }

  Future<void> loadData({required int count}) async {
    final isRefresh = _nextSeq == "0";
    if (!_haveMoreData) {
      return;
    }
    if (_isLoadingConversationData) {
      _pendingLoadCount = _pendingLoadCount == null
          ? count
          : (_pendingLoadCount! > count ? _pendingLoadCount : count);
      return;
    }

    _isLoadingConversationData = true;
    try {
      if (isRefresh) {
        _haveMoreData = true;
      }
      bool shouldNotify = false;
      final conversationResult = await _conversationService.getConversationList(
          nextSeq: _nextSeq, count: count);
      _nextSeq = conversationResult?.nextSeq ?? "";
      final conversationList = conversationResult?.conversationList;
      if (conversationList != null) {
        _hasLoadedOnce = true;
        if (conversationResult?.isFinished == true ||
            conversationList.isEmpty ||
            conversationList.length < count) {
          _haveMoreData = false;
        }
        if (conversationList.isNotEmpty || isRefresh) {
          List<V2TimConversation?> combinedConversationList = [];
          if (isRefresh) {
            combinedConversationList = conversationList;
          } else {
            combinedConversationList = [
              ..._conversationList,
              ...conversationList
            ];
          }
          final List<V2TimConversation?> finalConversationList =
              await _lifeCycle
                      ?.conversationListWillMount(combinedConversationList) ??
                  combinedConversationList;
          _conversationList = removeDuplicates<V2TimConversation?>(
              finalConversationList,
              (item1, item2) => item1?.conversationID == item2?.conversationID);
          _applyNameOverrides(_conversationList);
          _markConversationListDirty();
          shouldNotify = true;
        }
      }

      final now = DateTime.now();
      final lastUnread = _lastUnreadQueryAt;
      if (lastUnread == null ||
          now.difference(lastUnread) > _unreadQueryMinInterval) {
        _lastUnreadQueryAt = now;
        _totalUnReadCount = await _conversationService.getTotalUnreadCount();
        shouldNotify = true;
      }
      if (shouldNotify) {
        notifyListeners();
      }
      TUIConversationViewModelHooks.onPageLoaded?.call(
        conversations: conversationList != null
            ? List<V2TimConversation?>.from(conversationList)
            : const <V2TimConversation?>[],
        isRefresh: isRefresh,
        nextSeq: _nextSeq,
        haveMoreData: _haveMoreData,
        hasLoadedOnce: _hasLoadedOnce,
      );
    } finally {
      _isLoadingConversationData = false;
    }

    final pending = _pendingLoadCount;
    _pendingLoadCount = null;
    if (pending != null) {
      unawaited(loadData(count: pending));
    }
  }

  void setSelectedConversation(V2TimConversation conversation) {
    DisplayNameStore.instance.applyToConversation(conversation);
    _selectedConversation = conversation;
    notifyListeners();
  }

  Future<V2TimCallback> pinConversation({
    required String conversationID,
    required bool isPinned,
  }) {
    return _conversationService.pinConversation(
        conversationID: conversationID, isPinned: isPinned);
  }

  Future<V2TimCallback?> clearHistoryMessage(
      {required String convID, required int convType}) async {
    if (_lifeCycle?.shouldClearHistoricalMessageForConversation != null &&
        await _lifeCycle!.shouldClearHistoricalMessageForConversation(convID) ==
            false) {
      return null;
    }

    globalChatModel.clearLocalHistoryAsEmptyLoaded(convID);
    _nullConversationLastMessageLocally(convID: convID, convType: convType);

    ArchiveHistoryProvider.markHistoryClearPending(convID);
    final V2TimCallback result;
    if (convType == 1) {
      result = await _messageService.clearC2CHistoryMessage(userID: convID);
    } else {
      result = await _messageService.clearGroupHistoryMessage(groupID: convID);
    }
    if (result.code == 0) {
      await ArchiveHistoryProvider.completeHistoryClear(
        isGroup: convType != 1,
        conversationID: convID,
      );
    } else {
      ArchiveHistoryProvider.clearHistoryClearPending(convID);
    }
    return result;
  }

  void _nullConversationLastMessageLocally({
    required String convID,
    required int convType,
  }) {
    final raw = convID.trim();
    if (raw.isEmpty) {
      return;
    }
    final fullId = convType == 1
        ? (raw.startsWith('c2c_') ? raw : 'c2c_$raw')
        : (raw.startsWith('group_') ? raw : 'group_$raw');
    var changed = false;
    for (final conversation in _conversationList) {
      if (conversation == null) {
        continue;
      }
      final id = conversation.conversationID.trim();
      final userId = conversation.userID?.trim() ?? '';
      final groupId = conversation.groupID?.trim() ?? '';
      final matched = id == fullId ||
          id == raw ||
          (convType == 1 && (userId == raw || 'c2c_$userId' == fullId)) ||
          (convType != 1 && (groupId == raw || 'group_$groupId' == fullId));
      if (!matched || conversation.lastMessage == null) {
        continue;
      }
      conversation.lastMessage = null;
      changed = true;
    }
    if (!changed) {
      return;
    }
    _markConversationListDirty();
    notifyListeners();
  }

  searchFriends(String searchKey) async {
    final res = await _friendshipServices.searchFriends(
        searchParam: V2TimFriendSearchParam(keywordList: [searchKey]));
    return res;
  }

  Future<V2TimCallback?> deleteConversation(
      {required String conversationID}) async {
    if (_lifeCycle?.shouldDeleteConversation != null &&
        await _lifeCycle!.shouldDeleteConversation(conversationID) == false) {
      return null;
    }
    final res = await _conversationService.deleteConversation(
        conversationID: conversationID);
    if (res.code == 0) {
      _conversationList
          .removeWhere((element) => element?.conversationID == conversationID);
      _clearSelectedIfDeleted(<String>[conversationID]);
      _markConversationListDirty();
      notifyListeners();
      TUIConversationViewModelHooks.onConversationsDeleted?.call(
        <String>[conversationID],
      );
    }
    return res;
  }

  /// Drop selection when the open conversation was removed from the list.
  void _clearSelectedIfDeleted(List<String> conversationIds) {
    final selectedId = _selectedConversation?.conversationID;
    if (selectedId == null || selectedId.isEmpty) {
      return;
    }
    for (final raw in conversationIds) {
      if (raw == selectedId) {
        _selectedConversation = null;
        return;
      }
    }
  }

  _onConversationListChanged(List<V2TimConversation> list) {
    _applyNameOverrides(list);
    for (int element = 0; element < list.length; element++) {
      int index = _conversationList.indexWhere(
          (item) => item!.conversationID == list[element].conversationID);
      if (index > -1) {
        _conversationList.setAll(
            index, [list[element]] as List<V2TimConversation?>);
      } else {
        _conversationList.add(list[element]);
      }
    }

    _markConversationListDirty();
    notifyListeners();
    TUIConversationViewModelHooks.onConversationsChanged?.call(
      list.map((e) => e).toList(growable: false),
    );
  }

  _onConversationDeleted(List<String> list) {
    for (int i = 0; i < list.length; i++) {
      int index = _conversationList
          .indexWhere((item) => item!.conversationID == list[i]);
      if (index > -1) {
        _conversationList.removeAt(index);
        _conversationList = removeDuplicates<V2TimConversation?>(
            _conversationList,
            (item1, item2) => item1?.conversationID == item2?.conversationID);
      }
    }
    _markConversationListDirty();
    notifyListeners();
    TUIConversationViewModelHooks.onConversationsDeleted?.call(
      List<String>.from(list),
    );
  }

  _addNewConversation(List<V2TimConversation> list) {
    _applyNameOverrides(list);
    _conversationList.addAll(list);
    _conversationList = removeDuplicates<V2TimConversation?>(_conversationList,
        (item1, item2) => item1?.conversationID == item2?.conversationID);
    _markConversationListDirty();
    notifyListeners();
    TUIConversationViewModelHooks.onConversationsChanged?.call(
      list.map((e) => e).toList(growable: false),
    );
  }

  setConversationListener() {
    _conversationService.addConversationListener(
        listener: _conversationListener);
  }

  removeConversationListener() {
    _conversationService.removeConversationListener(
        listener: _conversationListener);
  }

  /// Web keeps [webDraftMap]; native app draft SSOT is app-side
  /// `ConversationDraftService` (local store). Native SDK draft writes are
  /// no-ops so text-field / callers cannot dual-write when `isUseDraft` is off
  /// or when someone bypasses the text-field guard.
  Future<V2TimCallback> setConversationDraft({
    required String conversationID,
    String? draftText,
    bool isTopic = false,
    String? groupID,
    bool isAllowWeb = true,
  }) async {
    assert(!isTopic || (groupID != null && groupID.isNotEmpty),
        "When 'isTopic' is true, 'groupID' must not be null or empty.");
    if (PlatformUtils().isWeb && isAllowWeb) {
      webDraftMap[conversationID] = draftText ?? "";
      return V2TimCallback(code: 0, desc: "");
    }
    // Native: do not persist drafts to IM SDK (local-first ConversationDraftService).
    return V2TimCallback(code: 0, desc: 'native_draft_ssot_local');
  }

  clearWebDraft({
    required String conversationID,
  }) {
    webDraftMap[conversationID] = "";
  }

  String? getWebDraft({
    required String conversationID,
  }) {
    return TencentUtils.checkString(webDraftMap[conversationID]);
  }

  bool updateC2CShowName(String userID, String showName) {
    if (userID.isEmpty || showName.isEmpty) {
      return false;
    }
    DisplayNameStore.instance.setC2C(userID, showName, notify: false);
    return _updateConversationShowName(
      '$conversationC2CPrefix$userID',
      showName,
    );
  }

  /// 本地更新群会话头像并刷新列表，避免等待 SDK 会话同步。
  bool updateGroupFaceUrl(String groupID, String faceUrl) {
    if (groupID.isEmpty || faceUrl.isEmpty) {
      return false;
    }
    return _updateConversationFaceUrl(
      '$conversationGroupPrefix$groupID',
      faceUrl,
    );
  }

  /// 本地更新群会话名称并刷新列表，避免等待 SDK 会话同步。
  bool updateGroupShowName(String groupID, String groupName) {
    if (groupID.isEmpty || groupName.isEmpty) {
      return false;
    }
    DisplayNameStore.instance.setGroup(groupID, groupName, notify: false);
    return _updateConversationShowName(
      '$conversationGroupPrefix$groupID',
      groupName,
    );
  }

  bool _updateConversationFaceUrl(String conversationID, String faceUrl) {
    if (conversationID.isEmpty) {
      return false;
    }
    var updated = false;
    for (final conv in _conversationList) {
      if (conv?.conversationID == conversationID) {
        conv!.faceUrl = faceUrl;
        updated = true;
      }
    }
    if (_selectedConversation?.conversationID == conversationID) {
      _selectedConversation!.faceUrl = faceUrl;
      updated = true;
    }
    if (updated) {
      _markConversationListDirty();
      notifyListeners();
    }
    return updated;
  }

  bool _updateConversationShowName(String conversationID, String showName) {
    if (conversationID.isEmpty) {
      return false;
    }
    var updated = false;
    for (final conv in _conversationList) {
      if (conv?.conversationID == conversationID) {
        conv!.showName = showName;
        updated = true;
      }
    }
    if (_selectedConversation?.conversationID == conversationID) {
      _selectedConversation!.showName = showName;
      updated = true;
    }
    if (updated) {
      _markConversationListDirty();
      notifyListeners();
    }
    return updated;
  }

  clearData() {
    _conversationList = [];
    _markConversationListDirty();
    _selectedConversation = null;
    _nextSeq = "0";
    _haveMoreData = true;
    _hasLoadedOnce = false;
    notifyListeners();
  }

  refresh({int count = 40, bool force = false}) {
    if (!force && _hasLoadedOnce) {
      return;
    }
    _nextSeq = "0";
    _haveMoreData = true;
    loadData(count: count);
  }
}
