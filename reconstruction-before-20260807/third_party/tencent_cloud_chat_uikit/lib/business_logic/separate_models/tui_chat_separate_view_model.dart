import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/utils/revoked_message_preview.dart';
import 'package:tencent_cloud_chat_demo/src/utils/conversation_preview_history_sync.dart';
import 'package:tencent_cloud_chat_demo/src/services/silent_archive_service.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_open_perf_log.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_sdk/enum/get_group_message_read_member_list_filter.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_filter_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_member_role.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_priority_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_message_read_member_list.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_message_read_member_list.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_change_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_change_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_receipt.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_receipt.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_msg_create_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_msg_create_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/life_cycle/chat_life_cycle.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/controllers/history_pagination_controller.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_ui_state_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/controllers/chat_composer_ui_state.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/group/group_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/c2c_friend_message_guard_bridge.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/archive_history_provider.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_history_peek_loader.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_history_open_layout_ready.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/sound_record.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/voice_message_path_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/archive_window_reconciler.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/logger.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/error_message_converter.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_anchor.dart';
import 'package:tencent_cloud_chat_demo/src/services/voice_to_text_service.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/voice_to_text_bridge.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/voice_message_path_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

export 'package:tencent_cloud_chat_uikit/business_logic/controllers/history_pagination_controller.dart'
    show LoadDirection;

part 'tui_chat_history_pagination_load.dart';

class _ResolvedSendTarget {
  final String receiver;
  final String groupID;
  final String normalizedConvID;

  const _ResolvedSendTarget({
    required this.receiver,
    required this.groupID,
    required this.normalizedConvID,
  });
}

class TUIChatSeparateViewModel extends ChangeNotifier {
  /// 禁言诊断。完成后关闭。
  static const bool _muteDebugEnabled = false;

  /// Permanent mute sentinel. Must stay within JS safe-integer range for web.
  static const int _kPermanentMuteUntil = 0x1FFFFFFFFFFFFF;

  void _muteDebugLog(String message) {
    if (!_muteDebugEnabled) {
      return;
    }
    debugPrint(message);
  }

  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final MessageService _messageService = serviceLocator<MessageService>();
  final GroupServices _groupServices = serviceLocator<GroupServices>();
  final TUIChatGlobalModel globalModel = serviceLocator<TUIChatGlobalModel>();
  final ChatUiStateStore chatUiStateStore = serviceLocator<ChatUiStateStore>();
  final TUIChatModelTools tools = serviceLocator<TUIChatModelTools>();
  final TUISelfInfoViewModel selfModel = serviceLocator<TUISelfInfoViewModel>();
  final TUIConversationViewModel conversationViewModel =
      serviceLocator<TUIConversationViewModel>();
  bool _notifyScheduled = false;
  bool _disposed = false;
  final HistoryPaginationController _pagination = HistoryPaginationController();

  Set<String> get _historyLoadingKeys => _pagination.historyLoadingKeys;
  bool get _previousPaginationInFlight =>
      _pagination.previousPaginationInFlight;
  set _previousPaginationInFlight(bool value) =>
      _pagination.previousPaginationInFlight = value;

  bool get isLoadingChatHistory => _pagination.isLoadingChatHistory;

  ChatLifeCycle? lifeCycle;
  int _totalUnreadCount = 0;
  bool _isInit = false;
  String conversationID = "";
  ConvType? conversationType;
  bool get haveMoreData => _pagination.haveMoreData;
  set haveMoreData(bool value) => _pagination.haveMoreData = value;
  bool get haveMoreLatestData => _pagination.haveMoreLatestData;
  set haveMoreLatestData(bool value) => _pagination.haveMoreLatestData = value;

  /// 自建后端归档「更早冷历史」是否已拉到底（避免拉空后反复请求同一段）。
  bool get _archiveOlderExhausted => _pagination.archiveOlderExhausted;
  set _archiveOlderExhausted(bool value) =>
      _pagination.archiveOlderExhausted = value;

  /// 是否已进入归档兜底分页（此后列表最老一条来自归档，不能再作为 SDK 锚点，
  /// 上翻直接走归档）。
  bool get _archiveOlderActive => _pagination.archiveOlderActive;
  set _archiveOlderActive(bool value) => _pagination.archiveOlderActive = value;

  /// 首屏 SDK 为空且未接受归档为「当前尾巴」时：禁止上拉再用归档挖旧消息
  ///（否则 tip 空会话会把已清掉的归档当成更早历史灌回来）。
  bool get _suppressArchiveUntilSdkHistory =>
      _pagination.suppressArchiveUntilSdkHistory;
  set _suppressArchiveUntilSdkHistory(bool value) =>
      _pagination.suppressArchiveUntilSdkHistory = value;

  /// 会话预加载或首屏已写入缓存时，恢复上拉分页开关。
  void syncHaveMoreDataFromCachedHistory({bool? mayHaveOlder}) {
    final cachedCount = globalModel.rawMessageCount(conversationID);
    final before = haveMoreData;
    final bool next;
    if (mayHaveOlder == true) {
      next = true;
    } else if (mayHaveOlder == false) {
      next = false;
    } else {
      next = cachedCount >= HistoryMessageDartConstant.initialOpenFetchCount;
    }
    if (before == next) {
      return;
    }
    haveMoreData = next;
    ChatHistoryTrace.log(
      'sync_have_more_from_cache',
      conversationID: conversationID,
      extras: <String, Object?>{
        'mayHaveOlder': mayHaveOlder,
        'cachedCount': cachedCount,
        'before': before,
        'after': haveMoreData,
      },
    );
  }

  String _currentPlayedMsgId = "";
  bool _voiceAutoPlayChainEnabled = false;
  GroupReceiptAllowType? _groupType;
  // List<V2TimMessage> _multiSelectedMessageList = [];
  final ChatComposerUiState _composerUi = ChatComposerUiState();
  String _jumpMsgID = "";
  bool _isGroupExist = true;
  bool _isNotAMember = false;
  bool showC2cMessageEditStatus = true;
  TIMUIKitChatConfig chatConfig = const TIMUIKitChatConfig();

  /// 会话长按预览等只读场景：不向 SDK 上报已读，避免关闭预览时清空列表未读气泡。
  bool suppressReadReporting = false;
  ValueChanged<String>? setInputField;
  String? Function(V2TimMessage message)? abstractMessageBuilder;
  Function(String userID, TapDownDetails tapDetails)? onTapAvatar;
  V2TimGroupMemberFullInfo? _currentChatUserInfo;
  V2TimGroupInfo? _groupInfo;
  String groupMemberListSeq = "0";
  List<V2TimGroupMemberFullInfo?>? groupMemberList = [];
  V2TimGroupMemberFullInfo? selfMemberInfo;
  int _groupMemberVersion = 0;
  Map<String, String> _groupUserShowName = {};
  String? _groupID;

  /// 进页只拉自己+首屏 sender；全量成员在 idle / @ / 资料时补齐。
  bool groupMemberListComplete = false;
  int _idleFullMemberLoadGeneration = 0;
  Future<void>? _fullMemberLoadInFlight;
  int _openShellGeneration = 0;

  /// 每次进会话只调度一次满窗校对 / 洞补。
  bool _archiveWindowReconcileScheduled = false;

  /// 暖开历史补齐（cloud merge + 归档校对）每开一次只调度一轮。
  bool _warmOpenHistoryReconcileScheduled = false;
  bool _warmOpenCloudMergeScheduled = false;
  Future<void>? _openShellInFlight;
  String? _openShellCompletedGid;
  static const int _openShellSenderLimit = 40;
  static const Duration _idleFullMemberLoadDelay = Duration(milliseconds: 1200);

  Map<String, String> get groupUserShowName => _groupUserShowName;

  int get groupMemberVersion => _groupMemberVersion;
  // value 的 bool 值表示是否已经延迟显示过发送进度
  final Map<String, bool> _sendingMessageIDMap = {};
  final Set<String> _cancelledOutgoingMediaIds = <String>{};
  Map<String, V2TimMessage> _readReceiptMap = {};
  Timer? _readReceiptFlushTimer;
  Timer? _groupMarkReadDebounce;
  int _lastGroupMarkReadAtMs = 0;
  static const _groupMarkReadMinIntervalMs = 5000;
  static const _groupMarkReadFrequencyBlockBackoffMs = 12000;

  set groupUserShowName(Map<String, String> value) {
    _groupUserShowName = value;
    _notify();
  }

  double get atPositionX => _composerUi.atPositionX;
  set atPositionX(double value) => _composerUi.atPositionX = value;

  double get atPositionY => _composerUi.atPositionY;
  set atPositionY(double value) => _composerUi.atPositionY = value;

  int get activeAtIndex => _composerUi.activeAtIndex;

  set activeAtIndex(int value) {
    if (_composerUi.activeAtIndex == value) {
      return;
    }
    _composerUi.activeAtIndex = value;
    _notify();
  }

  List<V2TimGroupMemberFullInfo?> get showAtMemberList =>
      _composerUi.showAtMemberList;

  set showAtMemberList(List<V2TimGroupMemberFullInfo?> value) {
    if (ChatComposerUiState.sameAtMemberList(
      _composerUi.showAtMemberList,
      value,
    )) {
      return;
    }
    _composerUi.showAtMemberList = value;
    _notify();
  }

  void clearAtPanelState({bool notify = true}) {
    final changed = _composerUi.clearAtPanel();
    if (changed && notify) {
      _notify();
    }
  }

  V2TimGroupInfo? get groupInfo => _groupInfo;

  set groupInfo(V2TimGroupInfo? value) {
    if (identical(_groupInfo, value)) {
      return;
    }
    // 同 groupID + 关键字段不变时不 notify，避免进场 loadGroupInfo 整表抖一下。
    final prev = _groupInfo;
    if (prev != null &&
        value != null &&
        prev.groupID == value.groupID &&
        prev.groupName == value.groupName &&
        prev.faceUrl == value.faceUrl &&
        prev.memberCount == value.memberCount &&
        prev.notification == value.notification &&
        prev.introduction == value.introduction &&
        prev.owner == value.owner &&
        prev.groupType == value.groupType) {
      _groupInfo = value;
      return;
    }
    _groupInfo = value;
    _notify();
  }

  int get totalUnreadCount => _totalUnreadCount;

  set totalUnreadCount(int value) {
    _totalUnreadCount = value;
    _notify();
  }

  bool get isMultiSelect => chatUiStateStore.isMultiSelect(conversationID);

  set isMultiSelect(bool value) {
    updateMultiSelectStatus(value);
  }

  String get currentPlayedMsgId => _currentPlayedMsgId;

  set currentPlayedMsgId(String value) {
    if (_currentPlayedMsgId == value) {
      return;
    }
    final previous = _currentPlayedMsgId;
    _currentPlayedMsgId = value;
    if (conversationID.isNotEmpty) {
      chatUiStateStore.markMessagesChanged(
        conversationID,
        <String>{previous, value},
      );
    }
    _notify();
  }

  bool get voiceAutoPlayChainEnabled => _voiceAutoPlayChainEnabled;

  void enableVoiceAutoPlayChain() {
    _voiceAutoPlayChainEnabled = true;
  }

  void disableVoiceAutoPlayChain() {
    _voiceAutoPlayChainEnabled = false;
  }

  /// 当前语音播完后，自动播放时间上紧随其后的下一条未播放语音。
  Future<void> tryAutoPlayNextUnplayedVoice(String completedMessageId) async {
    if (!_voiceAutoPlayChainEnabled || completedMessageId.isEmpty) {
      return;
    }
    final next = _findNextUnplayedIncomingSoundAfter(completedMessageId);
    if (next == null) {
      _voiceAutoPlayChainEnabled = false;
      return;
    }

    final msgId = TencentUtils.checkString(next.msgID);
    if (msgId == null) {
      _voiceAutoPlayChainEnabled = false;
      return;
    }
    final clientId = TencentUtils.checkString(next.id);

    if (next.localCustomInt != HistoryMessageDartConstant.read) {
      unawaited(globalModel.setLocalCustomInt(
        msgId,
        HistoryMessageDartConstant.read,
        conversationID,
      ));
      next.localCustomInt = HistoryMessageDartConstant.read;
    }

    currentPlayedMsgId = msgId;

    var playbackUrl =
        await VoiceMessagePathUtils.resolveLocalSoundPathWithDownload(
      message: next,
      globalModel: globalModel,
      messageService: _messageService,
    );
    playbackUrl ??= TencentUtils.checkString(next.soundElem?.url);
    if (playbackUrl == null || playbackUrl.isEmpty) {
      _voiceAutoPlayChainEnabled = false;
      if (currentPlayedMsgId == msgId) {
        currentPlayedMsgId = '';
      }
      return;
    }

    await SoundPlayer.restart(
      url: playbackUrl,
      messageId: msgId,
      altMessageId: clientId,
    );
  }

  bool _messageMatchesPlaybackId(V2TimMessage message, String id) {
    if (id.isEmpty) {
      return false;
    }
    return message.msgID == id || message.id == id;
  }

  int _soundMessageSeq(V2TimMessage message) {
    return int.tryParse(message.seq ?? '') ?? 0;
  }

  bool _isSoundMessageNewerThan(V2TimMessage candidate, V2TimMessage anchor) {
    final anchorTs = anchor.timestamp ?? 0;
    final candidateTs = candidate.timestamp ?? 0;
    if (candidateTs > anchorTs) {
      return true;
    }
    if (candidateTs < anchorTs) {
      return false;
    }
    return _soundMessageSeq(candidate) > _soundMessageSeq(anchor);
  }

  bool _isUnplayedIncomingSound(V2TimMessage message) {
    if (message.isSelf == true) {
      return false;
    }
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_SOUND) {
      return false;
    }
    if (message.localCustomInt == HistoryMessageDartConstant.read) {
      return false;
    }
    if (message.status == MessageStatus.V2TIM_MSG_STATUS_SENDING) {
      return false;
    }
    final msgId = TencentUtils.checkString(message.msgID);
    return msgId != null;
  }

  V2TimMessage? _findNextUnplayedIncomingSoundAfter(String completedMessageId) {
    final list = getOriginMessageList();
    V2TimMessage? anchor;
    for (final message in list) {
      if (_messageMatchesPlaybackId(message, completedMessageId)) {
        anchor = message;
        break;
      }
    }
    if (anchor == null) {
      return null;
    }

    V2TimMessage? best;
    for (final message in list) {
      if (!_isUnplayedIncomingSound(message)) {
        continue;
      }
      if (!_isSoundMessageNewerThan(message, anchor)) {
        continue;
      }
      if (best == null || _isSoundMessageNewerThan(best, message)) {
        best = message;
      }
    }
    return best;
  }

  GroupReceiptAllowType? get groupType => _groupType;

  set groupType(GroupReceiptAllowType? value) {
    _groupType = value;
    _notify();
  }

  bool get _isReadReceiptAllowedGroup =>
      _groupType == GroupReceiptAllowType.work ||
      _groupType == GroupReceiptAllowType.public ||
      _groupType == GroupReceiptAllowType.meeting;

  bool get _canUseReadReceipt {
    if (!chatConfig.isShowReadingStatus) {
      return false;
    }
    if (conversationType != ConvType.group) {
      return true;
    }
    return _isReadReceiptAllowedGroup;
  }

  bool get canUseReadReceipt => _canUseReadReceipt;

  Future<void> _ensureGroupInfoLoaded() async {
    if (conversationType != ConvType.group || _groupInfo != null) {
      return;
    }
    await loadGroupInfo(_groupID ?? conversationID);
  }

  List<V2TimMessage> getSelectedMessageList() {
    List<V2TimMessage> selectList = [];
    if (chatUiStateStore.selectedCount(conversationID) == 0) {
      return selectList;
    }

    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    for (var v2TimMessage in currentHistoryMsgList) {
      final messageKey = ChatUiStateStore.messageKeyOf(v2TimMessage);
      if (chatUiStateStore.isMessageSelected(conversationID, messageKey)) {
        selectList.add(v2TimMessage);
      }
    }

    return selectList.reversed.toList();
  }

  List<String> getSelectedMessageIDList() {
    return getSelectedMessageList()
        .map((message) => message.msgID ?? '')
        .where((msgID) => msgID.isNotEmpty)
        .toList();
  }

  V2TimMessage? get repliedMessage => _composerUi.repliedMessage;

  set repliedMessage(V2TimMessage? value) {
    _composerUi.repliedMessage = value;
    _notify();
  }

  String get jumpMsgID => _jumpMsgID;

  set jumpMsgID(String value) {
    _jumpMsgID = value;
    _notify();
  }

  bool get isGroupExist => _isGroupExist;

  set isGroupExist(bool value) {
    setGroupExist(value);
  }

  void setGroupExist(bool value, {bool notify = true}) {
    if (_isGroupExist == value) {
      return;
    }
    _isGroupExist = value;
    if (notify) {
      _notify();
    }
  }

  bool get isNotAMember => _isNotAMember;

  set isNotAMember(bool value) {
    _isNotAMember = value;
    _notify();
  }

  V2TimGroupMemberFullInfo? get currentChatUserInfo => _currentChatUserInfo;

  set currentChatUserInfo(V2TimGroupMemberFullInfo? value) {
    _currentChatUserInfo = value;
    _notify();
  }

  setLoadingMessageMap(String conversationID, V2TimMessage messageInfo) {
    if (PlatformUtils().isWeb) {
      if (globalModel.loadingMessage[conversationID] != null &&
          globalModel.loadingMessage[conversationID]!.isNotEmpty) {
        globalModel.loadingMessage[conversationID]!.add(messageInfo);
      } else {
        globalModel.loadingMessage[conversationID] = <V2TimMessage>[
          messageInfo
        ];
      }
    }
  }

  void getUserShowName(List<String> userIDs) async {
    final List<String> filteredList = userIDs
        .where((element) => !_groupUserShowName.containsKey(element))
        .toList();
    for (final element in filteredList) {
      _groupUserShowName[element] = element;
    }

    final String groupID = TencentUtils.checkString(_groupID) ?? conversationID;

    if (filteredList.isNotEmpty) {
      final res = await TencentImSDKPlugin.manager
          ?.getGroupManager()
          .getGroupMembersInfo(groupID: groupID, memberList: filteredList);
      if (res?.code == 0 && res?.data != null) {
        final data = res!.data!;
        GroupMemberStore.instance.putMembers(groupID, data);
        for (final userInfo in data) {
          final showName = TencentUtils.checkString(userInfo.nameCard) ??
              TencentUtils.checkString(userInfo.nickName) ??
              TencentUtils.checkString(userInfo.userID);
          if (TencentUtils.checkString(showName) != null) {
            _groupUserShowName[userInfo.userID] = showName ?? userInfo.userID;
          }
        }
        if (data.isNotEmpty) {
          _groupMemberVersion++;
          _notify();
        }
      }
    }
  }

  void initForEachConversation(ConvType convType, String convID,
      ValueChanged<String>? onChangeInputField,
      {String? groupID,
      List<V2TimGroupMemberFullInfo?>? preGroupMemberList}) async {
    if (_isInit) {
      syncHaveMoreDataFromCachedHistory(
        mayHaveOlder: globalModel.mayHaveOlderHistory(conversationID),
      );
      return;
    }
    setInputField = onChangeInputField;
    conversationType = convType;
    // 消息列表 / hydrate / 归档一律用裸会话 ID（@TGS#…），勿带 group_。
    conversationID = _storageConversationId(convID);
    _pagination.resetForConversationInit();

    final warmOnStorage = globalModel.rawMessageCount(conversationID);
    final warmOnRaw = globalModel.rawMessageCount(convID);
    ChatHistoryTrace.log(
      'init_conv',
      conversationID: conversationID,
      extras: <String, Object?>{
        'rawConvID': convID,
        'warmOnStorage': warmOnStorage,
        'warmOnRaw': warmOnRaw,
        'loadedStorage': globalModel.hasInitialHistoryLoaded(conversationID),
        'loadedRaw': globalModel.hasInitialHistoryLoaded(convID),
        'idMismatchRisk': warmOnStorage == 0 && warmOnRaw > 0,
      },
    );

    if (globalModel.hasInitialHistoryLoaded(conversationID) &&
        globalModel.rawMessageCount(conversationID) > 0) {
      final mayOlder = globalModel.mayHaveOlderHistory(conversationID);
      haveMoreData = mayOlder ||
          globalModel.rawMessageCount(conversationID) >=
              HistoryMessageDartConstant.initialOpenFetchCount;
    } else if (globalModel.hasInitialHistoryLoaded(convID) &&
        globalModel.rawMessageCount(convID) > 0) {
      // 兼容进页瞬间仍用旧 key（group_）写暖窗的情况。
      final mayOlder = globalModel.mayHaveOlderHistory(convID);
      haveMoreData = mayOlder ||
          globalModel.rawMessageCount(convID) >=
              HistoryMessageDartConstant.initialOpenFetchCount;
    } else {
      haveMoreData = false;
    }
    haveMoreLatestData = false;

    _disposed = false;
    _groupType = null;
    isGroupExist = true;
    _groupInfo = null;
    groupMemberList = null;
    selfMemberInfo = null;
    groupMemberListComplete = false;
    _idleFullMemberLoadGeneration++;
    _fullMemberLoadInFlight = null;
    _openShellGeneration++;
    _openShellInFlight = null;
    _openShellCompletedGid = null;
    _archiveWindowReconcileScheduled = false;
    _warmOpenHistoryReconcileScheduled = false;
    _warmOpenCloudMergeScheduled = false;

    globalModel.setCurrentConversation(
      CurrentConversation(conversationID, conversationType ?? ConvType.c2c),
      notify: false,
    );
    globalModel.lifeCycle = lifeCycle;
    if (globalModel.hasPendingScrollRestore(conversationID)) {
      globalModel.setMessageListPosition(
        conversationID,
        HistoryMessagePosition.notShowLatest,
        notify: false,
      );
    } else {
      globalModel.setMessageListPosition(
        conversationID,
        HistoryMessagePosition.bottom,
        notify: false,
      );
    }
    globalModel.setChatConfig(chatConfig);
    globalModel.clearReceivedNewMessageCount();

    if (globalModel.hasInitialHistoryLoaded(convID) &&
        globalModel.rawMessageCount(convID) > 0) {
      syncHaveMoreDataFromCachedHistory(
        mayHaveOlder: globalModel.mayHaveOlderHistory(convID),
      );
    }

    if (conversationType == ConvType.group) {
      _groupID = groupID;
      final resolvedGroupId = groupID ?? convID;
      final selfId = selfModel.loginInfo?.userID?.trim() ?? '';
      if (selfId.isNotEmpty) {
        final cachedSelf =
            GroupMemberStore.instance.memberOf(resolvedGroupId, selfId);
        if (cachedSelf != null) {
          selfMemberInfo = cachedSelf;
        }
      }
      final skipOpenNotify = globalModel.hasInitialHistoryLoaded(convID) &&
          globalModel.rawMessageCount(convID) > 0;
      if (!skipOpenNotify) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) {
            _notify();
          }
        });
      }
      Future.delayed(const Duration(milliseconds: 10), () async {
        Future.delayed(const Duration(milliseconds: 1200), () {
          globalModel.refreshGroupApplicationList();
        });
        loadGroupInfo(groupID ?? convID);
        final resolvedGid = groupID ?? convID;
        if (preGroupMemberList != null) {
          groupMemberList =
              List<V2TimGroupMemberFullInfo?>.from(preGroupMemberList);

          // Update GroupMemberStore with preGroupMemberList
          GroupMemberStore.instance.putMembers(resolvedGid, preGroupMemberList);

          final fromList = preGroupMemberList.firstWhereOrNull(
              (e) => e?.userID == selfModel.loginInfo?.userID);
          if (fromList != null) {
            selfMemberInfo = _mergeSelfMemberPreservingActiveMute(
              existing: selfMemberInfo,
              incoming: fromList,
            );
          }
          groupMemberListComplete = true;
        } else {
          if (selfMemberInfo == null) {
            await loadSelfMemberInfo(groupID: resolvedGid);
          }
          // 等冷开并行 peek 注入后再跑一次 open-shell（含 self + sender）。
          unawaited(_loadGroupMembersOpenShellOnce(groupID: resolvedGid));
          _scheduleIdleFullGroupMemberLoad(groupID: resolvedGid);
        }
        if (selfMemberInfo == null) {
          await loadSelfMemberInfo(groupID: resolvedGid);
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 10), () async {
        final List<V2TimFriendInfoResult>? friendRes =
            await _friendshipServices.getFriendsInfo(userIDList: [convID]);
        if (friendRes != null && friendRes.isNotEmpty) {
          final V2TimFriendInfoResult friendInfoResult = friendRes[0];
          currentChatUserInfo = V2TimGroupMemberFullInfo(
              userID: convID,
              faceUrl: friendInfoResult.friendInfo?.userProfile?.faceUrl,
              nickName: friendInfoResult.friendInfo?.userProfile?.nickName,
              friendRemark: friendInfoResult.friendInfo?.friendRemark);
        } else {
          final List<V2TimUserFullInfo>? userRes =
              await _friendshipServices.getUsersInfo(userIDList: [convID]);
          if (userRes != null && userRes.isNotEmpty) {
            final V2TimUserFullInfo userFullInfo = userRes[0];
            currentChatUserInfo = V2TimGroupMemberFullInfo(
              userID: convID,
              faceUrl: userFullInfo.faceUrl,
              nickName: userFullInfo.nickName,
            );
          }
        }
        _notify();
      });
    }

    final hasWarmOnStorage =
        globalModel.hasInitialHistoryLoaded(conversationID) &&
            globalModel.rawMessageCount(conversationID) > 0;
    final hasWarmOnRaw = globalModel.hasInitialHistoryLoaded(convID) &&
        globalModel.rawMessageCount(convID) > 0;
    if (hasWarmOnStorage || hasWarmOnRaw) {
      scheduleWarmOpenHistoryReconcile();
    }

    _isInit = true;
  }

  Future<bool> loadListForSpecificMessage({
    MessageAnchor? anchor,
    int? seq,
    V2TimMessage? targetMessage,
  }) async {
    bool tempHaveMoreData = false;
    bool tempHaveMoreLatestData = true;

    final resolvedAnchor = anchor ??
        MessageAnchor(
          conversationID: conversationID,
          convType: conversationType?.index ?? 0,
          seq: seq == null || seq <= 0 ? null : seq.toString(),
          msgID: TencentUtils.checkString(targetMessage?.msgID),
          localID: TencentUtils.checkString(targetMessage?.id),
          timestamp: targetMessage?.timestamp,
          sender: targetMessage?.sender ?? targetMessage?.userID,
          elemType: targetMessage?.elemType,
        );
    var resolvedTarget = targetMessage;
    final targetMsgID = TencentUtils.checkString(resolvedAnchor.msgID) ??
        TencentUtils.checkString(targetMessage?.msgID);
    final targetSeq =
        resolvedAnchor.seqInt ?? seq ?? int.tryParse(targetMessage?.seq ?? '');

    if (resolvedTarget == null && targetMsgID != null) {
      final found = await _messageService.findMessages(
        messageIDList: <String>[targetMsgID],
      );
      if (found != null && found.isNotEmpty) {
        resolvedTarget = found.first;
      }
    }

    Future<V2TimMessageListResult?> fetch(
      HistoryMsgGetTypeEnum getType, {
      int? count,
    }) {
      final resolvedCount = count ?? HistoryMessageDartConstant.getCount;
      return _messageService.getHistoryMessageListWithComplete(
        count: resolvedCount,
        getType: getType,
        userID: conversationType == ConvType.c2c ? conversationID : null,
        groupID: conversationType == ConvType.group ? conversationID : null,
        lastMsgID: targetMsgID,
        lastMsgSeq: targetMsgID == null ? max(targetSeq ?? 0, 0) : -1,
        lastMsg: resolvedTarget,
      );
    }

    var previousResponse =
        await fetch(HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG);
    var olderList = previousResponse?.messageList ?? <V2TimMessage>[];
    tempHaveMoreData = !(previousResponse?.isFinished ?? false);

    if (olderList.isEmpty) {
      previousResponse =
          await fetch(HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG);
      olderList = previousResponse?.messageList ?? <V2TimMessage>[];
      tempHaveMoreData = !(previousResponse?.isFinished ?? false);
    }

    var nextResponse =
        await fetch(HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG);
    var newerList = nextResponse?.messageList ?? <V2TimMessage>[];
    tempHaveMoreLatestData = !(nextResponse?.isFinished ?? false);

    if (newerList.isEmpty) {
      nextResponse =
          await fetch(HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG);
      newerList = nextResponse?.messageList ?? <V2TimMessage>[];
      tempHaveMoreLatestData = !(nextResponse?.isFinished ?? false);
    }

    final target = resolvedTarget ?? targetMessage;
    final merged = <V2TimMessage>[
      ...newerList.reversed,
      if (target != null) target,
      ...olderList,
    ];

    var msgList = _dedupeMessages(merged);
    if (msgList.isNotEmpty &&
        !msgList.any(resolvedAnchor.matches) &&
        target == null) {
      msgList = <V2TimMessage>[];
    }
    if (msgList.isEmpty) {
      haveMoreData = tempHaveMoreData;
      haveMoreLatestData = tempHaveMoreLatestData;
      return false;
    }

    // 搜索跳转必须进入“历史定位态”，不自动贴到底部。
    haveMoreLatestData = tempHaveMoreLatestData;
    if (!haveMoreLatestData && newerList.isEmpty) {
      // 初次窗口未拉到 target 之后的消息时，仍允许向下滑分页。
      haveMoreLatestData = true;
    }
    globalModel.setMessageListPosition(
      conversationID,
      HistoryMessagePosition.notShowLatest,
    );

    msgList = await lifeCycle?.didGetHistoricalMessageList(msgList) ?? msgList;
    msgList = _dedupeMessages(msgList);
    if (!msgList.any(resolvedAnchor.matches)) {
      haveMoreData = tempHaveMoreData;
      haveMoreLatestData = tempHaveMoreLatestData;
      return false;
    }
    globalModel.setMessageList(
      conversationID,
      msgList,
      needResetNewMessageCount: false,
    );

    await _ensureGroupInfoLoaded();

    if (_canUseReadReceipt) {
      _getMsgReadReceipt(msgList);
    }

    haveMoreData = tempHaveMoreData;
    _notify();
    return true;
  }

  /// 去掉 `group_` / `c2c_` 前缀，供 SDK / 归档 API / messageListMap 共用。
  static String _storageConversationId(String? raw) {
    var id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return '';
    }
    final lower = id.toLowerCase();
    if (lower.startsWith('group_')) {
      return id.substring(6);
    }
    if (lower.startsWith('c2c_')) {
      return id.substring(4);
    }
    if (id.startsWith('GROUP')) {
      return id.substring(5);
    }
    if (id.startsWith('C2C')) {
      return id.substring(3);
    }
    return id;
  }

  String _historyRequestKey({
    required HistoryMsgGetTypeEnum? getType,
    required int lastMsgSeq,
    required int count,
    required String? lastMsgID,
    required LoadDirection direction,
  }) {
    return '${conversationID}|${conversationType?.index}|${getType ?? ''}|$lastMsgSeq|$count|${lastMsgID ?? ''}|${direction.index}';
  }

  bool _archiveMessageStrictlyOlder(V2TimMessage m, V2TimMessage oldest) {
    final mSeq = int.tryParse(m.seq ?? '');
    final oSeq = int.tryParse(oldest.seq ?? '');
    if (mSeq != null && oSeq != null && mSeq > 0 && oSeq > 0) {
      return mSeq < oSeq;
    }
    final mt = m.timestamp ?? 0;
    final ot = oldest.timestamp ?? 0;
    return mt < ot;
  }

  List<V2TimMessage> _dedupeMessages(List<V2TimMessage> messages) {
    return TUIChatGlobalModel.dedupeMessages(messages);
  }

  V2TimMessage? _resolvePaginationAnchorInMemory({
    String? lastMsgID,
    int lastMsgSeq = -1,
  }) {
    final list = globalModel.messageListMap[conversationID];
    if (list == null || list.isEmpty) {
      return null;
    }
    final normalizedMsgID = lastMsgID?.trim() ?? '';
    if (normalizedMsgID.isNotEmpty) {
      for (final message in list) {
        if (message.msgID?.trim() == normalizedMsgID) {
          return message;
        }
      }
    }
    if (lastMsgSeq > 0) {
      for (final message in list) {
        final seq = int.tryParse(message.seq?.toString() ?? '') ?? -1;
        if (seq == lastMsgSeq) {
          return message;
        }
      }
    }
    return null;
  }

  List<V2TimMessage> _mergeWithInMemoryHistory(List<V2TimMessage> fetched) {
    return TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: globalModel.messageListMap[conversationID],
      fetched: fetched,
    );
  }

  /// 首屏 refetch 批次的稳定签名：同一窗口重复拉取时跳过重复 commit。
  /// 只取跨轮稳定的可比字段，不含本地自增 id（每次实例化会变）。
  String _peekWindowBatchSignature(List<V2TimMessage> messages) {
    final buffer = StringBuffer()
      ..write(messages.length)
      ..write(';');
    for (final message in messages) {
      buffer
        ..write(message.msgID ?? '')
        ..write(':')
        ..write(message.seq ?? '')
        ..write(':')
        ..write(message.timestamp ?? '')
        ..write(':')
        ..write(message.status ?? '')
        ..write(';');
    }
    return buffer.toString();
  }

  void _commitHistoricalMessages(
    List<V2TimMessage> fetched, {
    bool markInitialLoaded = false,
    bool? mayHaveOlder,

    /// 首屏 peek：以拉取窗口替换旧缓存，避免与历史分页内存拼成超量列表。
    bool replaceWithPeekWindow = false,
  }) {
    final merged = replaceWithPeekWindow
        ? TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
            existing: globalModel.messageListMap[conversationID],
            fetched: fetched,
          )
        : _mergeWithInMemoryHistory(fetched);
    globalModel.setMessageList(
      conversationID,
      merged,
      needResetNewMessageCount: false,
      replace: replaceWithPeekWindow,
    );
    if (markInitialLoaded) {
      globalModel.markInitialHistoryLoaded(conversationID);
    }
    if (mayHaveOlder != null) {
      globalModel.markInitialHistoryMayHaveOlder(
        conversationID,
        mayHaveOlder: mayHaveOlder,
      );
    }
  }

  // 加载聊天记录（逻辑在 HistoryPaginationLoadRunner，经 _pagination 委托）
  late final HistoryPaginationLoadRunner _historyLoadRunner = () {
    final runner = HistoryPaginationLoadRunner(this, _pagination);
    _pagination.bindLoadChatRecord(runner.loadChatRecord);
    return runner;
  }();

  Future<bool> loadChatRecord({
    HistoryMsgGetTypeEnum? getType,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    LoadDirection direction = LoadDirection.previous,
  }) {
    // Ensure runner is initialized (binds into _pagination) before delegating.
    final runner = _historyLoadRunner;
    return runner.pagination.loadChatRecord(
      getType: getType,
      lastMsgSeq: lastMsgSeq,
      count: count,
      lastMsgID: lastMsgID,
      direction: direction,
    );
  }

  Future<bool> loadDataFromController({int? count}) {
    return loadChatRecord(
      count: count ?? HistoryMessageDartConstant.getCount, //20
    );
  }

  /// 与会话预览一致：先本地、不足再云端；窗口不足时同一轮内补归档。
  /// 满窗也会异步校对一次自建后端（洞补 / 窗内缺失），不挡首屏。
  Future<List<V2TimMessage>> loadHistoryPeekStyle({
    int? count,
    String? lastMsgID,
    int lastMsgSeq = -1,
    bool scheduleWindowReconcile = true,
  }) async {
    final fetchCount =
        count ?? HistoryMessageDartConstant.initialOpenFetchCount;
    final storageId = _storageConversationId(conversationID);
    final userID = conversationType == ConvType.c2c ? storageId : null;
    final groupID = conversationType == ConvType.group ? storageId : null;
    final isWeb = PlatformUtils().isWeb;
    final isInitialWindow = lastMsgID == null && lastMsgSeq <= 0;
    ChatHistoryTrace.log(
      'load_history_peek_start',
      conversationID: conversationID,
      extras: <String, Object?>{
        'storageId': storageId,
        'fetchCount': fetchCount,
        'lastMsgID': lastMsgID ?? '',
        'lastMsgSeq': lastMsgSeq,
        'isWeb': isWeb,
      },
    );
    final peekResult =
        await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: _messageService,
      count: fetchCount,
      userID: userID,
      groupID: groupID,
      lastMsgID: lastMsgID,
      lastMsgSeq: lastMsgSeq,
    );
    var messages = peekResult.messageList;
    messages = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
      conversationID: conversationID,
      messages: messages,
    );
    if (messages.isNotEmpty) {
      final processed =
          await lifeCycle?.didGetHistoricalMessageList(messages) ?? messages;
      messages = _dedupeMessages(processed);
    }
    final sdkCount = messages.length;
    // Web 进页且 SDK 仍空：清 skip 以便必要时打归档；SDK 有首屏则保留 defer。
    if (isWeb &&
        isInitialWindow &&
        sdkCount == 0 &&
        !ArchiveHistoryProvider.isInHistoryClearGrace(conversationID)) {
      ArchiveHistoryProvider.clearArchiveFallbackSkipped(conversationID);
      _suppressArchiveUntilSdkHistory = false;
      _archiveOlderExhausted = false;
    }
    if (sdkCount > 0) {
      _suppressArchiveUntilSdkHistory = false;
    }
    final willArchive = _shouldSupplementPeekWithArchive(
      messages: messages,
      requestedCount: fetchCount,
      isPagination: !isInitialWindow,
    );
    ChatHistoryTrace.log(
      'load_history_peek_sdk',
      conversationID: conversationID,
      extras: <String, Object?>{
        'sdkCount': sdkCount,
        'willArchive': willArchive,
        ...ChatHistoryTrace.windowSummary(messages, prefix: 'sdk'),
      },
    );
    var rejectedStaleArchive = false;
    var acceptedArchive = false;
    if (willArchive) {
      // 与移动端一致：用 SDK/TIM 窗口最老一条当归档游标，只补更旧段，避免最新一条双源重叠。
      final supplement = await _fetchArchivePeekSupplement(
        currentMessages: messages,
        count: fetchCount,
      );
      ChatHistoryTrace.log(
        'load_history_peek_archive',
        conversationID: conversationID,
        extras: <String, Object?>{
          'archiveCount': supplement.messages.length,
          'archiveHasMore': supplement.hasMore,
          ...ChatHistoryTrace.windowSummary(
            supplement.messages,
            prefix: 'arch',
          ),
        },
      );
      // 与 ConversationPeekService 一致：首屏 SDK 为空时，若会话 lastMessage
      // （含本地 tip）明显新于归档最新一条，禁止用旧归档冒充首屏。
      if (isInitialWindow && sdkCount == 0 && supplement.messages.isNotEmpty) {
        final lastHint = _conversationLastMessageHint();
        rejectedStaleArchive =
            HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          supplement.messages,
          referenceTimestampSec: lastHint?.timestamp,
        );
        if (rejectedStaleArchive) {
          ChatHistoryTrace.log(
            'load_history_peek_archive_reject_stale_initial',
            conversationID: conversationID,
            extras: <String, Object?>{
              'lastMsgId': lastHint?.msgID ?? '',
              'lastMsgTs': lastHint?.timestamp ?? 0,
              'archiveFetched': supplement.messages.length,
              ...ChatHistoryTrace.windowSummary(
                supplement.messages,
                prefix: 'arch',
              ),
            },
          );
          _suppressArchiveUntilSdkHistory = true;
          ArchiveHistoryProvider.markArchiveFallbackSkipped(conversationID);
          haveMoreData = false;
          _archiveOlderActive = false;
        }
      }
      if (!rejectedStaleArchive && supplement.messages.isNotEmpty) {
        messages = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
          _dedupeMessages([
            ...supplement.messages,
            ...messages,
          ]),
        );
        messages = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
          conversationID: conversationID,
          messages: messages,
        );
        acceptedArchive = messages.any(
          HistoryPaginationAnchor.isArchiveHistoryMessage,
        );
      }
      if (!rejectedStaleArchive && supplement.hasMore) {
        haveMoreData = true;
        _archiveOlderActive = true;
        _archiveOlderExhausted = false;
      }
    }
    // 首屏 SDK 空且未接受归档：关掉上拉归档，避免 tip 空会话挖到已删冷历史。
    if (isInitialWindow && sdkCount == 0 && !acceptedArchive) {
      _suppressArchiveUntilSdkHistory = true;
      haveMoreData = false;
      _archiveOlderActive = false;
    }
    // 与会话预览一致：首屏只保留最新窗口，避免补档后条数膨胀。
    if (isInitialWindow && messages.length > fetchCount) {
      messages = messages.sublist(messages.length - fetchCount);
      // 截断说明窗口外还有更早消息，必须打开上拉分页。
      haveMoreData = true;
    } else if (isInitialWindow && messages.length >= fetchCount) {
      // 满窗口：默认可继续上拉（与会话预览 hasMoreOlder 一致）。
      haveMoreData = true;
    }
    ChatHistoryTrace.log(
      'load_history_peek_done',
      conversationID: conversationID,
      extras: <String, Object?>{
        'haveMoreData': haveMoreData,
        'rejectedStaleArchive': rejectedStaleArchive,
        'suppressArchive': _suppressArchiveUntilSdkHistory,
        ...ChatHistoryTrace.windowSummary(messages, prefix: 'final'),
      },
    );
    if (isInitialWindow &&
        !willArchive &&
        WebChatOpenPolicy.shouldScheduleSilentInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: sdkCount,
          requestedCount: fetchCount,
        )) {
      final selected = conversationViewModel.selectedConversation;
      if (selected != null) {
        SilentArchiveService.instance.scheduleInitialSupplement(
          conversation: selected,
          conversationKey: conversationID,
          sdkMessageCount: sdkCount,
          requestedCount: fetchCount,
          lifeCycle: lifeCycle,
          lastMessageHint: _conversationLastMessageHint(),
        );
      }
    }
    if (scheduleWindowReconcile && isInitialWindow && messages.isNotEmpty) {
      _scheduleArchiveWindowReconcile(fetchCount: fetchCount);
    }
    return messages;
  }

  /// 取会话列表 / 选中会话的 lastMessage，供首屏归档过期判定（对齐 Peek）。
  V2TimMessage? _conversationLastMessageHint() {
    final storageId = _storageConversationId(conversationID);
    if (storageId.isEmpty) {
      return null;
    }
    final keys = <String>{
      storageId,
      conversationID,
      if (conversationType == ConvType.group) 'group_$storageId',
      if (conversationType == ConvType.c2c) 'c2c_$storageId',
    };
    final selected = conversationViewModel.selectedConversation;
    if (selected != null) {
      final selectedBare = _storageConversationId(selected.conversationID);
      if (selectedBare == storageId || keys.contains(selected.conversationID)) {
        final last = selected.lastMessage;
        if (last != null) {
          return last;
        }
      }
    }
    for (final key in keys) {
      final last = conversationViewModel.getConversation(key)?.lastMessage;
      if (last != null) {
        return last;
      }
    }
    final warm = globalModel.messageListMap[conversationID] ??
        globalModel.messageListMap[storageId];
    if (warm != null && warm.isNotEmpty) {
      return warm.first;
    }
    return null;
  }

  bool _shouldSupplementPeekWithArchive({
    required List<V2TimMessage> messages,
    required int requestedCount,
    required bool isPagination,
  }) {
    if (!ArchiveHistoryProvider.isAvailable ||
        ArchiveHistoryProvider.shouldSkipArchiveFallback(conversationID)) {
      return false;
    }
    if (messages.isEmpty) {
      return true;
    }
    if (WebChatOpenPolicy.shouldDeferInitialArchive(
      isInitialWindow: !isPagination,
      sdkMessageCount: messages.length,
    )) {
      return false;
    }
    if (!isPagination && messages.length < requestedCount) {
      return true;
    }
    return false;
  }

  Future<ArchiveHistoryResult> _fetchArchivePeekSupplement({
    required List<V2TimMessage> currentMessages,
    required int count,
  }) async {
    final isGroup = conversationType == ConvType.group;
    // Peek loader 返回时间升序，最老一条在开头。
    final V2TimMessage? oldest =
        currentMessages.isNotEmpty ? currentMessages.first : null;
    final oldestTs = oldest?.timestamp;
    final oldestSeq = int.tryParse(oldest?.seq ?? '');
    final fetchCount =
        oldest == null ? count : max(1, count - currentMessages.length);

    ArchiveHistoryResult result;
    try {
      result = await ArchiveHistoryProvider.fetchOlder(
        ArchiveHistoryRequest(
          isGroup: isGroup,
          conversationID: _storageConversationId(conversationID),
          loginUserID: selfModel.loginInfo?.userID,
          beforeTimeMs: oldest == null
              ? null
              : ((oldestTs != null && oldestTs > 0) ? oldestTs * 1000 : null),
          beforeSeq: oldestSeq,
          beforeMsgID: oldest?.msgID,
          count: fetchCount,
        ),
      );
    } catch (e) {
      ChatHistoryTrace.log(
        'archive_peek_supplement_error',
        conversationID: conversationID,
        extras: <String, Object?>{'error': e.toString()},
      );
      return ArchiveHistoryResult.empty;
    }

    final filtered = <V2TimMessage>[];
    for (final message in result.messages) {
      if (oldest == null || _archiveMessageStrictlyOlder(message, oldest)) {
        filtered.add(message);
      }
    }
    if (filtered.isEmpty) {
      return ArchiveHistoryResult(messages: const [], hasMore: result.hasMore);
    }
    final processed =
        await lifeCycle?.didGetHistoricalMessageList(filtered) ?? filtered;
    return ArchiveHistoryResult(
      messages: _dedupeMessages(processed),
      hasMore: result.hasMore,
    );
  }

  Future<bool> _waitForWarmOpenBackgroundWindow({
    required int generation,
    required String convId,
  }) async {
    await ChatHistoryOpenLayoutReady.wait(
      convId,
      timeout: const Duration(milliseconds: 1000),
    );
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return false;
    }
    // Keep SDK/cloud reconciliation out of the route transition and the
    // message list's short post-reveal geometry stabilization window.
    await Future<void>.delayed(const Duration(milliseconds: 550));
    return !_disposed &&
        generation == _openShellGeneration &&
        convId == conversationID;
  }

  /// 暖开首屏：异步按洞 IM 云补 + 归档窗校对。
  /// 不挡首帧；每开一次会话只调度一轮。
  void scheduleWarmOpenHistoryReconcile({int? fetchCount}) {
    if (_warmOpenHistoryReconcileScheduled) {
      return;
    }
    final convId = conversationID;
    final existing = globalModel.messageListMap[convId] ??
        globalModel.rawMessageList(convId);
    if (existing == null || existing.isEmpty) {
      return;
    }
    _warmOpenHistoryReconcileScheduled = true;
    final count =
        fetchCount ?? HistoryMessageDartConstant.initialOpenFetchCount;
    final ascending =
        TUIChatGlobalModel.sortMessagesChronologicallyAsc(existing);
    final probes = _probesFromMessages(ascending);
    final isGroup = conversationType == ConvType.group;
    final gaps = ArchiveWindowReconciler.detectGaps(
      probes,
      isGroup: isGroup,
    );
    final plan = WarmOpenReconcilePlan.decide(gapCount: gaps.length);
    ChatHistoryTrace.log(
      'warm_open_reconcile_scheduled',
      conversationID: convId,
      extras: <String, Object?>{
        'gapCount': plan.gapCount,
        'willCloudMerge': plan.willCloudMerge,
        'willArchiveReconcile': plan.willArchiveReconcile,
        'rawCount': existing.length,
      },
    );
    if (plan.willCloudMerge) {
      _scheduleFillGapsFromImCloud(
        gaps: gaps,
        ascending: ascending,
        fetchCount: count,
        thenArchive: plan.willArchiveReconcile,
      );
    } else if (plan.willArchiveReconcile) {
      _scheduleArchiveWindowReconcile(fetchCount: count);
    }
  }

  List<ArchiveMessageProbe> _probesFromMessages(List<V2TimMessage> messages) {
    final probes = <ArchiveMessageProbe>[];
    for (final m in messages) {
      final ts = m.timestamp ?? 0;
      probes.add(
        ArchiveMessageProbe(
          id: m.msgID?.trim() ?? '',
          timestampSec: ts <= 0 ? 0 : (ts < 1000000000000 ? ts : ts ~/ 1000),
          seq: HistoryPaginationAnchor.messageSeq(m),
          isLocalTip: HistoryPaginationAnchor.isLocalInjectedMessage(m),
        ),
      );
    }
    return probes;
  }

  void _scheduleFillGapsFromImCloud({
    required List<ArchiveHistoryGapProbe> gaps,
    required List<V2TimMessage> ascending,
    required int fetchCount,
    bool thenArchive = false,
  }) {
    if (_warmOpenCloudMergeScheduled) {
      return;
    }
    _warmOpenCloudMergeScheduled = true;
    final generation = _openShellGeneration;
    final convId = conversationID;
    unawaited(
      _fillGapsFromImCloud(
        generation: generation,
        convId: convId,
        gaps: gaps,
        ascending: ascending,
        fetchCount: fetchCount,
        thenArchive: thenArchive,
      ),
    );
  }

  Future<void> _fillGapsFromImCloud({
    required int generation,
    required String convId,
    required List<ArchiveHistoryGapProbe> gaps,
    required List<V2TimMessage> ascending,
    required int fetchCount,
    bool thenArchive = false,
  }) async {
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return;
    }
    if (!await _waitForWarmOpenBackgroundWindow(
      generation: generation,
      convId: convId,
    )) {
      return;
    }
    if (PlatformUtils().isWeb) {
      ChatHistoryTrace.log(
        'gap_im_fill_skip',
        conversationID: convId,
        extras: <String, Object?>{'reason': 'web'},
      );
      if (thenArchive) {
        _scheduleArchiveWindowReconcile(fetchCount: fetchCount);
      }
      return;
    }

    ChatHistoryTrace.log(
      'gap_im_fill_start',
      conversationID: convId,
      extras: <String, Object?>{
        'gapCount': gaps.length,
        'reasons': gaps.map((g) => g.reason).take(6).join(','),
      },
    );

    final storageId = _storageConversationId(conversationID);
    final userID = conversationType == ConvType.c2c ? storageId : null;
    final groupID = conversationType == ConvType.group ? storageId : null;
    final isGroup = conversationType == ConvType.group;
    final collected = <V2TimMessage>[];

    try {
      for (final gap in gaps) {
        if (_disposed ||
            generation != _openShellGeneration ||
            convId != conversationID) {
          return;
        }
        if (gap.olderIndex < 0 ||
            gap.newerIndex < 0 ||
            gap.olderIndex >= ascending.length ||
            gap.newerIndex >= ascending.length) {
          continue;
        }
        final older = ascending[gap.olderIndex];
        final newer = ascending[gap.newerIndex];
        final olderSeq = HistoryPaginationAnchor.messageSeq(older);
        final newerSeq = HistoryPaginationAnchor.messageSeq(newer);
        final useSeq = isGroup && olderSeq > 0 && newerSeq > 0;

        if (useSeq) {
          collected.addAll(
            await _fillOneGapByGroupSeq(
              generation: generation,
              convId: convId,
              groupID: groupID,
              older: older,
              newer: newer,
              olderSeq: olderSeq,
              newerSeq: newerSeq,
              olderSec: gap.olderTimestampSec,
              newerSec: gap.newerTimestampSec,
            ),
          );
        } else {
          collected.addAll(
            await _fillOneGapByCloudTime(
              generation: generation,
              convId: convId,
              userID: userID,
              groupID: groupID,
              older: older,
              newer: newer,
              olderSec: gap.olderTimestampSec,
              newerSec: gap.newerTimestampSec,
            ),
          );
        }
      }
    } catch (e) {
      ChatHistoryTrace.log(
        'gap_im_fill_skip',
        conversationID: convId,
        extras: <String, Object?>{
          'reason': 'error',
          'error': e.toString(),
        },
      );
    }

    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return;
    }

    var added = 0;
    if (collected.isNotEmpty) {
      var filtered =
          await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
        conversationID: convId,
        messages: collected,
      );
      filtered = _dedupeMessages(filtered);
      if (filtered.isNotEmpty) {
        final mayCommit = await _awaitWarmOpenCommitGate(
          generation: generation,
          convId: convId,
        );
        if (!mayCommit) {
          return;
        }
        final beforeIdentity = TUIChatGlobalModel.historyIdentitySignature(
          TUIChatGlobalModel.dedupeMessages(
            List<V2TimMessage>.from(
              globalModel.messageListMap[convId] ?? ascending,
            ),
          ),
        );
        _commitHistoricalMessages(
          filtered,
          markInitialLoaded: true,
          mayHaveOlder: globalModel.mayHaveOlderHistory(convId),
          // gap 批次不是完整 peek 窗：必须 merge，禁止 replace 挤掉 tip 邻居。
          replaceWithPeekWindow: false,
        );
        ChatHistoryTrace.log(
          'gap_fill_commit_merge_not_replace',
          conversationID: convId,
          extras: <String, Object?>{
            'filtered': filtered.length,
            'generation': generation,
          },
        );
        ChatOpenPerfLog.mark(
          'gap_fill_commit_merge_not_replace',
          conversationID: convId,
          extras: <String, Object?>{
            'filtered': filtered.length,
            'generation': generation,
          },
        );
        final afterIdentity = TUIChatGlobalModel.historyIdentitySignature(
          TUIChatGlobalModel.dedupeMessages(
            List<V2TimMessage>.from(
              globalModel.messageListMap[convId] ?? const <V2TimMessage>[],
            ),
          ),
        );
        added = beforeIdentity == afterIdentity ? 0 : filtered.length;
        if (added > 0) {
          _notify();
        }
      }
    }

    final afterAsc = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
      globalModel.messageListMap[convId] ??
          globalModel.rawMessageList(convId) ??
          ascending,
    );
    final remaining = ArchiveWindowReconciler.detectGaps(
      _probesFromMessages(afterAsc),
      isGroup: isGroup,
    ).length;

    ChatHistoryTrace.log(
      'gap_im_fill_done',
      conversationID: convId,
      extras: <String, Object?>{
        'added': added,
        'collected': collected.length,
        'remainingGapsApprox': remaining,
      },
    );

    if (thenArchive &&
        !_disposed &&
        generation == _openShellGeneration &&
        convId == conversationID) {
      _scheduleArchiveWindowReconcile(fetchCount: fetchCount);
    }
  }

  Future<List<V2TimMessage>> _fillOneGapByGroupSeq({
    required int generation,
    required String convId,
    required String? groupID,
    required V2TimMessage older,
    required V2TimMessage newer,
    required int olderSeq,
    required int newerSeq,
    required int olderSec,
    required int newerSec,
  }) async {
    final missing = ArchiveWindowReconciler.missingGroupSeqs(
      olderSeq: olderSeq,
      newerSeq: newerSeq,
    );
    if (missing.isEmpty || groupID == null || groupID.isEmpty) {
      return const <V2TimMessage>[];
    }
    final out = <V2TimMessage>[];
    const batchSize = 20;
    for (var i = 0; i < missing.length; i += batchSize) {
      if (_disposed || generation != _openShellGeneration) {
        break;
      }
      final end =
          i + batchSize > missing.length ? missing.length : i + batchSize;
      final batch = missing.sublist(i, end);
      final response = await _messageService.getHistoryMessageListWithComplete(
        count: batch.length,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        groupID: groupID,
        lastMsgSeq: -1,
        messageSeqList: batch,
      );
      final page = response?.messageList ?? const <V2TimMessage>[];
      final between = ArchiveWindowReconciler.filterStrictlyBetweenSec(
        page,
        olderSec: olderSec,
        newerSec: newerSec,
        timestampSecOf: _messageTimestampSec,
      );
      // seq 列表拉取也可能缺 timestamp；按 seq 再滤一层。
      final bySeq = <V2TimMessage>[];
      for (final m in page) {
        final s = HistoryPaginationAnchor.messageSeq(m);
        if (s > olderSeq && s < newerSeq) {
          bySeq.add(m);
        }
      }
      final merged = _dedupeMessages(<V2TimMessage>[...between, ...bySeq]);
      out.addAll(merged);
      ChatHistoryTrace.log(
        'gap_im_fill_batch',
        conversationID: convId,
        extras: <String, Object?>{
          'mode': 'seq',
          'cloudCount': page.length,
          'betweenCount': merged.length,
          'page': i ~/ batchSize,
          'seqBatch': batch.length,
        },
      );
    }

    // 仍可能有漏：锚 newer 往更早翻页补。
    if (out.length < missing.length) {
      var cursor = newer;
      for (var pageIdx = 0;
          pageIdx < ArchiveWindowReconciler.maxCloudPagesPerGap;
          pageIdx++) {
        if (_disposed || generation != _openShellGeneration) {
          break;
        }
        final response =
            await _messageService.getHistoryMessageListWithComplete(
          count: HistoryMessageDartConstant.getCount,
          getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
          groupID: groupID,
          lastMsgID: cursor.msgID,
          lastMsgSeq: HistoryPaginationAnchor.messageSeq(cursor),
          lastMsg: cursor,
        );
        final page = response?.messageList ?? const <V2TimMessage>[];
        final bySeq = <V2TimMessage>[];
        for (final m in page) {
          final s = HistoryPaginationAnchor.messageSeq(m);
          if (s > olderSeq && s < newerSeq) {
            bySeq.add(m);
          }
        }
        out.addAll(bySeq);
        ChatHistoryTrace.log(
          'gap_im_fill_batch',
          conversationID: convId,
          extras: <String, Object?>{
            'mode': 'seq_page',
            'cloudCount': page.length,
            'betweenCount': bySeq.length,
            'page': pageIdx,
          },
        );
        if (page.isEmpty || (response?.isFinished ?? true)) {
          break;
        }
        final asc = TUIChatGlobalModel.sortMessagesChronologicallyAsc(page);
        if (asc.isEmpty) {
          break;
        }
        final pageOldest = asc.first;
        final pageOldestSeq = HistoryPaginationAnchor.messageSeq(pageOldest);
        if (pageOldestSeq > 0 && pageOldestSeq <= olderSeq) {
          break;
        }
        cursor = pageOldest;
      }
    }
    return _dedupeMessages(out);
  }

  Future<List<V2TimMessage>> _fillOneGapByCloudTime({
    required int generation,
    required String convId,
    required String? userID,
    required String? groupID,
    required V2TimMessage older,
    required V2TimMessage newer,
    required int olderSec,
    required int newerSec,
  }) async {
    if (olderSec <= 0 || newerSec <= 0 || newerSec <= olderSec) {
      ChatHistoryTrace.log(
        'gap_im_fill_skip',
        conversationID: convId,
        extras: <String, Object?>{'reason': 'bad_time_range'},
      );
      return const <V2TimMessage>[];
    }
    final range = ArchiveWindowReconciler.cloudTimeRangeForGap(
      olderSec: olderSec,
      newerSec: newerSec,
    );
    final out = <V2TimMessage>[];
    V2TimMessage? cursor = newer;
    for (var pageIdx = 0;
        pageIdx < ArchiveWindowReconciler.maxCloudPagesPerGap;
        pageIdx++) {
      if (_disposed || generation != _openShellGeneration) {
        break;
      }
      final response = await _messageService.getHistoryMessageListWithComplete(
        count: HistoryMessageDartConstant.getCount,
        getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
        userID: userID,
        groupID: groupID,
        lastMsgID: pageIdx == 0 ? null : cursor?.msgID,
        lastMsgSeq:
            pageIdx == 0 ? -1 : HistoryPaginationAnchor.messageSeq(cursor!),
        lastMsg: pageIdx == 0 ? null : cursor,
        timeBegin: pageIdx == 0 ? range.timeBegin : null,
        timePeriod: pageIdx == 0 ? range.timePeriod : null,
      );
      final page = response?.messageList ?? const <V2TimMessage>[];
      final between = ArchiveWindowReconciler.filterStrictlyBetweenSec(
        page,
        olderSec: olderSec,
        newerSec: newerSec,
        timestampSecOf: _messageTimestampSec,
      );
      out.addAll(between);
      ChatHistoryTrace.log(
        'gap_im_fill_batch',
        conversationID: convId,
        extras: <String, Object?>{
          'mode': 'time',
          'cloudCount': page.length,
          'betweenCount': between.length,
          'page': pageIdx,
          'timeBegin': range.timeBegin,
          'timePeriod': range.timePeriod,
        },
      );
      if (page.isEmpty || (response?.isFinished ?? true)) {
        break;
      }
      final asc = TUIChatGlobalModel.sortMessagesChronologicallyAsc(page);
      if (asc.isEmpty) {
        break;
      }
      final pageOldest = asc.first;
      if (_messageTimestampSec(pageOldest) <= olderSec) {
        break;
      }
      cursor = pageOldest;
    }
    return _dedupeMessages(out);
  }

  static int _messageTimestampSec(V2TimMessage message) {
    final ts = message.timestamp ?? 0;
    if (ts <= 0) {
      return 0;
    }
    return ts < 1000000000000 ? ts : ts ~/ 1000;
  }

  /// 暖开/进页异步校对写回门禁：等 layout reveal，或 ≤2s 超时兜底。
  /// 返回 false 表示会话已失效，调用方不得 `_commitHistoricalMessages`。
  Future<bool> _awaitWarmOpenCommitGate({
    required int generation,
    required String convId,
  }) async {
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return false;
    }
    if (ChatHistoryOpenLayoutReady.isReady(convId)) {
      ChatHistoryTrace.log(
        'warm_open_reconcile_commit_after_reveal',
        conversationID: convId,
        extras: <String, Object?>{
          'generation': generation,
          'alreadyReady': true,
        },
      );
      ChatOpenPerfLog.mark(
        'warm_open_reconcile_commit_after_reveal',
        conversationID: convId,
        extras: <String, Object?>{
          'generation': generation,
          'alreadyReady': true,
        },
      );
      return true;
    }
    ChatHistoryTrace.log(
      'warm_open_reconcile_deferred',
      conversationID: convId,
      extras: <String, Object?>{'generation': generation},
    );
    ChatOpenPerfLog.mark(
      'warm_open_reconcile_deferred',
      conversationID: convId,
      extras: <String, Object?>{'generation': generation},
    );
    final ready = await ChatHistoryOpenLayoutReady.wait(
      convId,
      timeout: const Duration(seconds: 2),
    );
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return false;
    }
    final event = ready
        ? 'warm_open_reconcile_commit_after_reveal'
        : 'warm_open_reconcile_commit_after_timeout';
    ChatHistoryTrace.log(
      event,
      conversationID: convId,
      extras: <String, Object?>{'generation': generation},
    );
    ChatOpenPerfLog.mark(
      event,
      conversationID: convId,
      extras: <String, Object?>{'generation': generation},
    );
    return true;
  }

  /// 首屏 SDK 窗上屏后异步校对自建归档（满窗也会打一次；不挡进页）。
  void _scheduleArchiveWindowReconcile({required int fetchCount}) {
    if (!ArchiveHistoryProvider.isAvailable) {
      return;
    }
    if (ArchiveHistoryProvider.isInHistoryClearGrace(conversationID)) {
      return;
    }
    if (_archiveWindowReconcileScheduled) {
      return;
    }
    _archiveWindowReconcileScheduled = true;
    final generation = _openShellGeneration;
    final convId = conversationID;
    unawaited(
      _runArchiveWindowReconcile(
        generation: generation,
        convId: convId,
        fetchCount: fetchCount,
      ),
    );
  }

  Future<void> _runArchiveWindowReconcile({
    required int generation,
    required String convId,
    required int fetchCount,
  }) async {
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return;
    }
    if (!await _waitForWarmOpenBackgroundWindow(
      generation: generation,
      convId: convId,
    )) {
      return;
    }
    var current = List<V2TimMessage>.from(
      globalModel.messageListMap[convId] ?? const <V2TimMessage>[],
    );
    if (current.isEmpty) {
      return;
    }
    current = TUIChatGlobalModel.sortMessagesChronologicallyAsc(current);
    final probes = _probesFromMessages(current);
    V2TimMessage? newestMsg;
    ArchiveMessageProbe? oldestProbe;
    ArchiveMessageProbe? newestProbe;
    for (var i = 0; i < probes.length; i++) {
      if (!ArchiveWindowReconciler.isAnchorCandidate(probes[i])) {
        continue;
      }
      oldestProbe ??= probes[i];
      newestProbe = probes[i];
      newestMsg = current[i];
    }
    if (newestMsg == null || newestProbe == null) {
      return;
    }

    final isGroup = conversationType == ConvType.group;
    final storageId = _storageConversationId(convId);
    final loginUserID = selfModel.loginInfo?.userID;
    final collected = <V2TimMessage>[];
    var filledOlderThanWindow = false;

    int timestampSecOf(V2TimMessage m) {
      final ts = m.timestamp ?? 0;
      if (ts <= 0) {
        return 0;
      }
      return ts < 1000000000000 ? ts : ts ~/ 1000;
    }

    int timestampMsOf(V2TimMessage m) {
      final sec = timestampSecOf(m);
      return sec <= 0 ? 0 : sec * 1000;
    }

    Future<ArchiveHistoryResult> fetchBefore(V2TimMessage anchor) {
      final seq = HistoryPaginationAnchor.messageSeq(anchor);
      return ArchiveHistoryProvider.fetchOlder(
        ArchiveHistoryRequest(
          isGroup: isGroup,
          conversationID: storageId,
          loginUserID: loginUserID,
          beforeTimeMs: timestampMsOf(anchor),
          beforeSeq: seq > 0 ? seq : null,
          beforeMsgID: anchor.msgID,
          count: fetchCount,
        ),
      );
    }

    Future<ArchiveHistoryResult> fetchGapRange({
      required int olderSec,
      required int newerSec,
      required int olderSeq,
      required int newerSeq,
    }) {
      if (isGroup && olderSeq > 0 && newerSeq > olderSeq + 1) {
        return ArchiveHistoryProvider.fetchOlder(
          ArchiveHistoryRequest(
            isGroup: true,
            conversationID: storageId,
            loginUserID: loginUserID,
            fromSeq: olderSeq + 1,
            toSeq: newerSeq - 1,
            count: fetchCount,
          ),
        );
      }
      if (!isGroup && olderSec > 0 && newerSec > olderSec) {
        final fromMs = olderSec * 1000 + 1;
        final toMs = newerSec * 1000 - 1;
        if (toMs >= fromMs) {
          return ArchiveHistoryProvider.fetchOlder(
            ArchiveHistoryRequest(
              isGroup: false,
              conversationID: storageId,
              loginUserID: loginUserID,
              fromTimeMs: fromMs,
              toTimeMs: toMs,
              count: fetchCount,
            ),
          );
        }
      }
      return Future<ArchiveHistoryResult>.value(ArchiveHistoryResult.empty);
    }

    try {
      final windowPage = await fetchBefore(newestMsg);
      if (_disposed || generation != _openShellGeneration) {
        return;
      }
      final oldestSec = oldestProbe?.timestampSec ?? 0;
      final newestSec = newestProbe.timestampSec;
      final windowHits = ArchiveWindowReconciler.filterForWindowReconcile(
        windowPage.messages,
        oldestSec: oldestSec,
        newestSec: newestSec,
        timestampSecOf: timestampSecOf,
      );
      for (final m in windowHits) {
        final ts = timestampSecOf(m);
        if (oldestSec > 0 && ts > 0 && ts < oldestSec) {
          filledOlderThanWindow = true;
        }
      }
      collected.addAll(windowHits);

      current = List<V2TimMessage>.from(
        globalModel.messageListMap[convId] ?? current,
      );
      current = TUIChatGlobalModel.sortMessagesChronologicallyAsc(current);
      final gapProbes = _probesFromMessages(current);
      final gaps = ArchiveWindowReconciler.detectGaps(
        gapProbes,
        isGroup: isGroup,
      );
      for (final gap in gaps) {
        var cursorAnchor = current[gap.newerIndex];
        final olderMsg = current[gap.olderIndex];
        final olderSec = gap.olderTimestampSec;
        final newerSec = gap.newerTimestampSec;
        final olderSeq = HistoryPaginationAnchor.messageSeq(olderMsg);
        final newerSeq = HistoryPaginationAnchor.messageSeq(cursorAnchor);

        final rangePage = await fetchGapRange(
          olderSec: olderSec,
          newerSec: newerSec,
          olderSeq: olderSeq,
          newerSeq: newerSeq,
        );
        if (_disposed || generation != _openShellGeneration) {
          return;
        }
        final rangeHits = ArchiveWindowReconciler.filterStrictlyBetweenSec(
          rangePage.messages,
          olderSec: olderSec,
          newerSec: newerSec,
          timestampSecOf: timestampSecOf,
        );
        collected.addAll(rangeHits);

        for (var pageIdx = 0;
            pageIdx < ArchiveWindowReconciler.maxPagesPerGap;
            pageIdx++) {
          final gapPage = await fetchBefore(cursorAnchor);
          if (_disposed || generation != _openShellGeneration) {
            return;
          }
          final between = ArchiveWindowReconciler.filterStrictlyBetweenSec(
            gapPage.messages,
            olderSec: olderSec,
            newerSec: newerSec,
            timestampSecOf: timestampSecOf,
          );
          collected.addAll(between);
          if (between.isEmpty || !gapPage.hasMore) {
            break;
          }
          final sortedPage = TUIChatGlobalModel.sortMessagesChronologicallyAsc(
            gapPage.messages,
          );
          if (sortedPage.isEmpty) {
            break;
          }
          final pageOldest = sortedPage.first;
          final pageOldestSec = timestampSecOf(pageOldest);
          if (pageOldestSec <= olderSec) {
            break;
          }
          cursorAnchor = pageOldest;
        }
      }
    } catch (e) {
      ChatHistoryTrace.log(
        'archive_window_reconcile_error',
        conversationID: convId,
        extras: <String, Object?>{'error': e.toString()},
      );
      return;
    }

    if (collected.isEmpty) {
      ChatHistoryTrace.log(
        'archive_window_reconcile_empty',
        conversationID: convId,
      );
      return;
    }
    if (_disposed ||
        generation != _openShellGeneration ||
        convId != conversationID) {
      return;
    }

    var filtered = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
      conversationID: convId,
      messages: collected,
    );
    if (filtered.isEmpty) {
      return;
    }
    filtered =
        await lifeCycle?.didGetHistoricalMessageList(filtered) ?? filtered;
    filtered = _dedupeMessages(filtered);
    if (filtered.isEmpty) {
      return;
    }

    final beforeIdentity = TUIChatGlobalModel.historyIdentitySignature(
      TUIChatGlobalModel.dedupeMessages(
        List<V2TimMessage>.from(
          globalModel.messageListMap[convId] ?? current,
        ),
      ),
    );
    final previewMerged = _mergeWithInMemoryHistory(filtered);
    final afterIdentity =
        TUIChatGlobalModel.historyIdentitySignature(previewMerged);
    if (beforeIdentity == afterIdentity) {
      ChatHistoryTrace.log(
        'archive_window_reconcile_noop',
        conversationID: convId,
        extras: <String, Object?>{
          'collected': filtered.length,
          'identity': beforeIdentity,
        },
      );
      return;
    }

    ChatHistoryTrace.log(
      'archive_window_reconcile_merge',
      conversationID: convId,
      extras: <String, Object?>{
        'added': filtered.length,
        'filledOlder': filledOlderThanWindow,
        ...ChatHistoryTrace.windowSummary(filtered, prefix: 'recon'),
      },
    );
    final mayCommit = await _awaitWarmOpenCommitGate(
      generation: generation,
      convId: convId,
    );
    if (!mayCommit) {
      return;
    }
    // 门禁等待期间列表可能已被其它路径补齐，再对一次身份避免空写。
    final beforeAfterGate = TUIChatGlobalModel.historyIdentitySignature(
      TUIChatGlobalModel.dedupeMessages(
        List<V2TimMessage>.from(
          globalModel.messageListMap[convId] ?? current,
        ),
      ),
    );
    final previewAfterGate = _mergeWithInMemoryHistory(filtered);
    if (beforeAfterGate ==
        TUIChatGlobalModel.historyIdentitySignature(previewAfterGate)) {
      ChatHistoryTrace.log(
        'archive_window_reconcile_noop',
        conversationID: convId,
        extras: <String, Object?>{
          'collected': filtered.length,
          'identity': beforeAfterGate,
          'afterGate': true,
        },
      );
      return;
    }
    _commitHistoricalMessages(
      filtered,
      markInitialLoaded: true,
      mayHaveOlder: true,
      replaceWithPeekWindow: false,
    );
    haveMoreData = true;
    _suppressArchiveUntilSdkHistory = false;
    if (filledOlderThanWindow) {
      _archiveOlderActive = true;
      _archiveOlderExhausted = false;
    }
    _notify();
  }

  Future<bool> hydrateInitialHistoryPeekStyle({
    int? count,
    List<Duration>? retryDelays,
    bool plainOpen = false,
  }) async {
    final fetchCount =
        count ?? HistoryMessageDartConstant.initialOpenFetchCount;
    final storageId = _storageConversationId(conversationID);
    final groupPrefixed = storageId.isEmpty ? '' : 'group_$storageId';

    if (plainOpen) {
      await globalModel.awaitOpenHydrateInFlight(
        conversationID,
        timeout: const Duration(milliseconds: 900),
      );
    }

    final warmCount = globalModel.rawMessageCount(conversationID);
    final warmLoaded = globalModel.hasInitialHistoryLoaded(conversationID);

    if (plainOpen &&
        WebChatOpenPolicy.canSkipHydrateRefetch(
          globalModel: globalModel,
          conversationKey: conversationID,
          preview: _conversationLastMessageHint(),
        )) {
      syncHaveMoreDataFromCachedHistory(
        mayHaveOlder: globalModel.mayHaveOlderHistory(conversationID) ||
            warmCount >= fetchCount,
      );
      ChatHistoryTrace.log(
        'hydrate_web_skip_refetch',
        conversationID: conversationID,
        extras: <String, Object?>{
          'warmCount': warmCount,
          'warmLoaded': warmLoaded,
        },
      );
      return true;
    }

    final warmCountBare = storageId == conversationID
        ? warmCount
        : globalModel.rawMessageCount(storageId);
    final warmCountGroup =
        groupPrefixed.isEmpty ? 0 : globalModel.rawMessageCount(groupPrefixed);
    final warmLoadedBare = storageId == conversationID
        ? warmLoaded
        : globalModel.hasInitialHistoryLoaded(storageId);
    final warmLoadedGroup = groupPrefixed.isEmpty
        ? false
        : globalModel.hasInitialHistoryLoaded(groupPrefixed);

    ChatHistoryTrace.log(
      'hydrate_enter',
      conversationID: conversationID,
      extras: <String, Object?>{
        'plainOpen': plainOpen,
        'storageId': storageId,
        'fetchCount': fetchCount,
        'warmCount': warmCount,
        'warmLoaded': warmLoaded,
        'warmCountBare': warmCountBare,
        'warmLoadedBare': warmLoadedBare,
        'warmCountGroup': warmCountGroup,
        'warmLoadedGroup': warmLoadedGroup,
        'mayHaveOlder': globalModel.mayHaveOlderHistory(conversationID),
        ...ChatHistoryTrace.windowSummary(
          globalModel.messageListMap[conversationID] ??
              globalModel.messageListMap[storageId],
          prefix: 'warm',
        ),
      },
    );

    // 仅跳过「已确认空会话」，避免空列表转圈。
    // 冷开并行 peek 仍在飞时绝不能 keep-empty，否则会把稍后注入的暖窗挡掉。
    if (plainOpen &&
        warmLoaded &&
        warmCount == 0 &&
        !globalModel.mayHaveOlderHistory(conversationID) &&
        !globalModel.hasOpenHydrateInFlight(conversationID)) {
      syncHaveMoreDataFromCachedHistory(mayHaveOlder: false);
      ChatHistoryTrace.log(
        'hydrate_keep_empty_confirmed',
        conversationID: conversationID,
      );
      return true;
    }

    // 进页 bootstrap 已灌入 peek 暖窗：禁止再被「空 SDK + 旧归档」整窗替换。
    // 例外：暖窗几乎全是过期归档（SDK 空时被错灌）——必须剥掉并继续 refetch。
    // 必须用 alias-aware rawMessageList：messageListMap[字面 key] 为空时
    // 会把「别名上的真实暖窗」误判成 tip-only 并写成空 list → 灰屏。
    final warmList = globalModel.rawMessageList(conversationID);
    final staleArchiveWarm = plainOpen &&
        warmCount > 0 &&
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(warmList);
    final alignedWarmWindow = plainOpen &&
        ConversationPreviewHistorySync.canSkipOpenRebootstrap(
          globalModel: globalModel,
          conversationKey: conversationID,
          preview: _conversationLastMessageHint(),
        );
    // 进页已有暖窗：keep 即返回，禁止二次 peek replace 扩 len（对标 11→13）。
    // 短于 fetchCount 也 keep；haveMore 强制可上拉，更早消息靠用户翻。
    if (plainOpen && alignedWarmWindow && warmCount > 0 && !staleArchiveWarm) {
      final warmHasSdk = HistoryPaginationAnchor.oldestSdkPaginationAnchor(
            warmList,
          ) !=
          null;
      final warmOnlyTipsOrEmpty = !warmHasSdk &&
          !(warmList?.any(HistoryPaginationAnchor.isArchiveHistoryMessage) ??
              false);
      final keptShortWindow = warmCount < fetchCount;
      if (warmOnlyTipsOrEmpty) {
        // tip 空会话：清掉历史 tip 铺满，禁止上拉归档。
        if (warmCount > 0) {
          globalModel.clearLocalHistoryAsEmptyLoaded(conversationID);
          ChatHistoryTrace.log(
            'hydrate_strip_tip_only_empty',
            conversationID: conversationID,
            extras: <String, Object?>{
              'beforeCount': warmCount,
              ...ChatHistoryTrace.windowSummary(warmList, prefix: 'stripped'),
            },
          );
        }
        _suppressArchiveUntilSdkHistory = true;
        haveMoreData = false;
        globalModel.markInitialHistoryMayHaveOlder(
          conversationID,
          mayHaveOlder: false,
        );
      } else {
        globalModel.markInitialHistoryLoaded(conversationID);
        final mayHaveOlder = globalModel.mayHaveOlderHistory(conversationID) ||
            keptShortWindow ||
            warmCount >= fetchCount;
        syncHaveMoreDataFromCachedHistory(mayHaveOlder: mayHaveOlder);
        haveMoreData = haveMoreData || mayHaveOlder;
      }
      ChatHistoryTrace.log(
        'hydrate_keep_warm_peek',
        conversationID: conversationID,
        extras: <String, Object?>{
          'warmCount': warmCount,
          'fetchCount': fetchCount,
          'keptShortWindow': keptShortWindow,
          'haveMoreData': haveMoreData,
          'warmHasSdk': warmHasSdk,
          'suppressArchive': _suppressArchiveUntilSdkHistory,
          ...ChatHistoryTrace.windowSummary(warmList, prefix: 'kept'),
        },
      );
      return true;
    }
    if (staleArchiveWarm) {
      // 不在此处立即剥离：列表已在屏上时先塌成几条再被 refetch 弹回
      //（如 60→3→62），就是进页肉眼可见的抖动。改为延迟处理：
      // refetch 拉到新窗后用 peek-window replace 一次性换掉过期归档；
      // 全部拉空才在收尾兜底剥离。
      ChatHistoryTrace.log(
        'hydrate_defer_stale_archive_strip',
        conversationID: conversationID,
        extras: <String, Object?>{
          'warmCount': warmCount,
          ...ChatHistoryTrace.windowSummary(warmList, prefix: 'warm'),
        },
      );
    }

    ChatHistoryTrace.log(
      'hydrate_will_refetch',
      conversationID: conversationID,
      extras: <String, Object?>{
        'reason': !plainOpen
            ? 'not_plain_open'
            : staleArchiveWarm
                ? 'stale_archive_warm'
                : !warmLoaded
                    ? 'warm_not_loaded'
                    : warmCount <= 0
                        ? 'warm_empty'
                        : 'unknown',
        'hintAliasMismatch':
            warmCount <= 0 && (warmCountBare > 0 || warmCountGroup > 0),
      },
    );

    // 刚清空宽限期内：避免多轮空拉转圈；若内存已有清空后新消息则直接用，
    // 内存仍为空则继续走下面单次 peek，避免漏掉宽限期内到达的新消息。
    if (plainOpen &&
        ArchiveHistoryProvider.isInHistoryClearGrace(conversationID) &&
        globalModel.hasInitialHistoryLoaded(conversationID) &&
        globalModel.rawMessageCount(conversationID) > 0) {
      final existing =
          globalModel.messageListMap[conversationID] ?? const <V2TimMessage>[];
      final kept = await ArchiveHistoryProvider.filterMessagesAfterHistoryClear(
        conversationID: conversationID,
        messages: existing,
      );
      globalModel.setMessageList(
        conversationID,
        kept,
        needResetNewMessageCount: false,
        replace: true,
      );
      syncHaveMoreDataFromCachedHistory(
        mayHaveOlder: globalModel.mayHaveOlderHistory(conversationID),
      );
      return true;
    }

    final clearedAt =
        await ArchiveHistoryProvider.historyClearedAtMs(conversationID);
    final delays = retryDelays ??
        (clearedAt > 0
            ? const <Duration>[Duration.zero]
            : (plainOpen
                ? const <Duration>[
                    Duration.zero,
                    Duration(milliseconds: 150),
                    Duration(milliseconds: 400),
                  ]
                : const <Duration>[
                    Duration.zero,
                    Duration(milliseconds: 350),
                    Duration(milliseconds: 900),
                    Duration(milliseconds: 1800),
                  ]));
    final requestKey = 'peek_hydrate_$conversationID';
    _historyLoadingKeys.add(requestKey);
    if (_historyLoadingKeys.length == 1) {
      _notify();
    }
    var committedDuringRefetch = false;
    String? committedBatchSignature;
    try {
      for (final delay in delays) {
        if (delay > Duration.zero) {
          await Future<void>.delayed(delay);
        }
        // 页面已关闭：停止向全局模型写整表。否则关页后剩余重试轮仍会
        // setMessageList → bump revision（日志里 dispose 后 400ms 还在写）。
        if (_disposed) {
          ChatHistoryTrace.log(
            'hydrate_abort_disposed',
            conversationID: conversationID,
          );
          return committedDuringRefetch;
        }
        if (plainOpen &&
            globalModel.getMessageListPosition(conversationID) ==
                HistoryMessagePosition.notShowLatest) {
          ChatHistoryTrace.log(
            'hydrate_abort_history_position',
            conversationID: conversationID,
          );
          return committedDuringRefetch;
        }
        final messages = await loadHistoryPeekStyle(
          count: fetchCount,
        );
        if (_disposed) {
          ChatHistoryTrace.log(
            'hydrate_abort_disposed',
            conversationID: conversationID,
          );
          return committedDuringRefetch;
        }
        if (plainOpen &&
            globalModel.getMessageListPosition(conversationID) ==
                HistoryMessagePosition.notShowLatest) {
          ChatHistoryTrace.log(
            'hydrate_abort_history_position',
            conversationID: conversationID,
          );
          return committedDuringRefetch;
        }
        if (messages.isEmpty) {
          continue;
        }
        final existingWarm = globalModel.messageListMap[conversationID];
        final existingNewest = existingWarm == null || existingWarm.isEmpty
            ? 0
            : (existingWarm.first.timestamp ?? 0);
        final lastHintTs = _conversationLastMessageHint()?.timestamp ?? 0;
        final staleRefTs = existingNewest > 0 ? existingNewest : lastHintTs;
        if (HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          messages,
          referenceTimestampSec: staleRefTs > 0 ? staleRefTs : null,
        )) {
          ChatHistoryTrace.log(
            'hydrate_skip_stale_archive_batch',
            conversationID: conversationID,
            extras: <String, Object?>{
              'existingNewestTs': existingNewest,
              'lastHintTs': lastHintTs,
              ...ChatHistoryTrace.windowSummary(messages, prefix: 'fetched'),
            },
          );
          _suppressArchiveUntilSdkHistory = true;
          haveMoreData = false;
          continue;
        }
        final completeWindow = messages.length >= fetchCount;
        // 不足目标窗口可能只是 SDK 漫游尚未同步，不能据此关闭更早历史。
        final mayOlder = haveMoreData || !completeWindow;
        haveMoreData = mayOlder;
        // 重试轮拉到与已 commit 轮完全相同的窗口：跳过整表重写。
        // 短会话（< fetchCount）不满窗、循环每轮都会 commit，一次进页
        // 固定 3 次 setMessageList → 3 次 revision bump → 3 次全列表重建。
        final batchSignature = _peekWindowBatchSignature(messages);
        if (committedDuringRefetch &&
            batchSignature == committedBatchSignature) {
          ChatHistoryTrace.log(
            'hydrate_skip_unchanged_batch',
            conversationID: conversationID,
            extras: <String, Object?>{'messageCount': messages.length},
          );
          if (completeWindow) {
            return true;
          }
          continue;
        }
        // 过期归档暖窗：用新窗一次性整体替换（含剥离旧归档），
        // 避免「先剥离塌缩、再补回弹开」的两段式可见抖动。
        // 首屏已确认（哪怕总量不足一窗，如只有 6 条的短会话）就标记 loaded：
        // 只标 completeWindow 会让短会话每次进页都被当成冷启动、盖空壳闪一下。
        _commitHistoricalMessages(
          messages,
          markInitialLoaded: true,
          mayHaveOlder: mayOlder,
          replaceWithPeekWindow: true,
        );
        committedDuringRefetch = true;
        committedBatchSignature = batchSignature;
        ChatHistoryTrace.log(
          'hydrate_initial_done',
          conversationID: conversationID,
          extras: <String, Object?>{
            'fetchCount': fetchCount,
            'messageCount': messages.length,
            'haveMoreData': haveMoreData,
            'plainOpen': plainOpen,
          },
        );
        _notify();
        if (completeWindow) {
          return true;
        }
      }
      // 页面已关闭：收尾的剥离/归档兜底同样不再写全局状态。
      if (_disposed) {
        ChatHistoryTrace.log(
          'hydrate_abort_disposed',
          conversationID: conversationID,
        );
        return committedDuringRefetch;
      }
      if (plainOpen &&
          globalModel.getMessageListPosition(conversationID) ==
              HistoryMessagePosition.notShowLatest) {
        return committedDuringRefetch;
      }
      // 延迟剥离兜底：refetch 全轮拉空且暖窗仍是过期归档，才剥离一次。
      if (staleArchiveWarm && !committedDuringRefetch) {
        final remainingWarm = globalModel.messageListMap[conversationID];
        final stripped =
            HistoryPaginationAnchor.withoutArchiveHistory(remainingWarm);
        globalModel.setMessageList(
          conversationID,
          stripped,
          needResetNewMessageCount: false,
          replace: true,
        );
        ChatHistoryTrace.log(
          'hydrate_strip_stale_archive_warm',
          conversationID: conversationID,
          extras: <String, Object?>{
            'beforeCount': remainingWarm?.length ?? 0,
            'afterCount': stripped.length,
            'deferred': true,
          },
        );
      }

      // SDK 全空才允许归档兜底。若内存已有 peek 暖窗，绝不用旧归档整窗覆盖。
      final existingWarm = globalModel.rawMessageCount(conversationID);
      if (existingWarm > 0) {
        // 以暖窗收尾同样算首屏已确认，否则下次进页仍走冷 gate 闪空壳。
        globalModel.markInitialHistoryLoaded(conversationID);
        syncHaveMoreDataFromCachedHistory(
          mayHaveOlder: globalModel.mayHaveOlderHistory(conversationID) ||
              existingWarm >= fetchCount,
        );
        haveMoreData = haveMoreData ||
            globalModel.mayHaveOlderHistory(conversationID) ||
            existingWarm >= fetchCount;
        _scheduleArchiveWindowReconcile(fetchCount: fetchCount);
        _notify();
        return true;
      }
      if (ArchiveHistoryProvider.isAvailable &&
          !_suppressArchiveUntilSdkHistory &&
          !ArchiveHistoryProvider.shouldSkipArchiveFallback(conversationID)) {
        final supplement = await _fetchArchivePeekSupplement(
          currentMessages: const <V2TimMessage>[],
          count: fetchCount,
        );
        final remaining = globalModel.messageListMap[conversationID];
        final memTs = remaining == null || remaining.isEmpty
            ? 0
            : (remaining.first.timestamp ?? 0);
        final lastHintTs = _conversationLastMessageHint()?.timestamp ?? 0;
        final refTs = memTs > 0 ? memTs : lastHintTs;
        final rejectStale =
            HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          supplement.messages,
          referenceTimestampSec: refTs > 0 ? refTs : null,
        );
        if (supplement.messages.isNotEmpty && !rejectStale) {
          _commitHistoricalMessages(
            supplement.messages,
            markInitialLoaded: true,
            mayHaveOlder: supplement.hasMore,
            replaceWithPeekWindow: true,
          );
          haveMoreData = supplement.hasMore;
          _archiveOlderActive = true;
          _archiveOlderExhausted = !supplement.hasMore;
          _suppressArchiveUntilSdkHistory = false;
          _notify();
          return true;
        }
        if (supplement.messages.isNotEmpty) {
          ChatHistoryTrace.log(
            'hydrate_skip_stale_archive_supplement',
            conversationID: conversationID,
            extras: <String, Object?>{
              'refTs': refTs,
              'memTs': memTs,
              'lastHintTs': lastHintTs,
              ...ChatHistoryTrace.windowSummary(
                supplement.messages,
                prefix: 'arch',
              ),
            },
          );
          _suppressArchiveUntilSdkHistory = true;
          ArchiveHistoryProvider.markArchiveFallbackSkipped(conversationID);
        }
      }
      // 空会话也标记已加载，避免下次进页继续转圈 bootstrapping。
      globalModel.markInitialHistoryLoaded(conversationID);
      // tip/空首屏且未接受归档：与移动端一致，不再开上拉挖冷历史。
      _suppressArchiveUntilSdkHistory = true;
      globalModel.markInitialHistoryMayHaveOlder(
        conversationID,
        mayHaveOlder: false,
      );
      haveMoreData = false;
      if (clearedAt > 0) {
        // clearedAt 标记已由上方 suppress 处理。
      }
      return false;
    } finally {
      _historyLoadingKeys.remove(requestKey);
      if (_historyLoadingKeys.isEmpty) {
        _notify();
      }
    }
  }

  /// Peek 风格补全首屏窗口，与内存中实时消息 merge 后写入。
  Future<void> fillHistoryWindowPeekStyle({int? targetCount}) async {
    final fetchCount = targetCount ?? HistoryMessageDartConstant.getCount;
    final messages = await loadHistoryPeekStyle(count: fetchCount);
    if (messages.isEmpty) {
      return;
    }
    _commitHistoricalMessages(
      messages,
      markInitialLoaded: true,
      mayHaveOlder: messages.length >= fetchCount,
      replaceWithPeekWindow: true,
    );
    haveMoreData = messages.length >= fetchCount;
    _notify();
  }

  Future<V2TimValueCallback<List<V2TimMessageReceipt>>> getMessageReadReceipts(
      List<String> messageIDList) {
    return _messageService.getMessageReadReceipts(messageIDList: messageIDList);
  }

  _getMsgReadReceipt(List<V2TimMessage> message) async {
    if (!_canUseReadReceipt) {
      return;
    }
    final msgID = message
        .where((e) =>
            (e.isSelf ?? true) &&
            (e.needReadReceipt ?? false) &&
            (e.status == MessageStatus.V2TIM_MSG_STATUS_SEND_SUCC))
        .map((e) => e.msgID ?? '')
        .toList();
    if (msgID.isNotEmpty) {
      final res = await getMessageReadReceipts(msgID);
      if (res.code == 0) {
        final receiptList = res.data;
        if (receiptList != null) {
          final changedMsgIDs = <String>[];
          for (var item in receiptList) {
            final msgID = item.msgID;
            if (msgID == null || msgID.isEmpty) {
              continue;
            }
            globalModel.messageReadReceiptMap[msgID] = item;
            changedMsgIDs.add(msgID);
          }
          globalModel.markMessageRowsChangedByMsgIDs(changedMsgIDs);
        }
      }
      _notify();
    }
  }

  translateText(V2TimMessage message) async {
    final String originText = message.textElem?.text ?? "";
    final String deviceLocale = TIM_getCurrentDeviceLocale();
    final String targetMessage = deviceLocale.split("-")[0];
    final translatedText =
        await _messageService.translateText(originText, targetMessage);

    final LocalCustomDataModel localCustomData = LocalCustomDataModel.fromMap(
        json.decode(TencentUtils.checkString(message.localCustomData) ?? "{}"));
    localCustomData.translatedText = translatedText;
    await _persistLocalCustomData(message, localCustomData);
  }

  Future<void> convertVoiceMessageToText(V2TimMessage message) async {
    final msgID = TencentUtils.checkString(message.msgID);
    if (msgID == null) {
      return;
    }

    final localCustomData = LocalCustomDataModel.fromMap(
      json.decode(TencentUtils.checkString(message.localCustomData) ?? "{}"),
    );
    if (TencentUtils.checkString(localCustomData.voiceToText) != null) {
      return;
    }
    if (localCustomData.voiceToTextStatus == 'loading') {
      return;
    }

    localCustomData.voiceToTextStatus = 'loading';
    await _persistLocalCustomData(message, localCustomData);

    final text = await _transcribeVoiceMessage(message, msgID);
    if (text == null || text.isEmpty) {
      localCustomData.voiceToTextStatus = 'error';
      await _persistLocalCustomData(message, localCustomData);
      serviceLocator<CoreServicesImpl>().callOnCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: _voiceToTextFailureMessage(),
        infoCode: 6660424,
      ));
      return;
    }

    localCustomData.voiceToText = text;
    localCustomData.voiceToTextStatus = 'done';
    await _persistLocalCustomData(message, localCustomData);
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendRecordingAsTextMessage({
    required String soundPath,
    required int duration,
    required String convID,
    required ConvType convType,
  }) async {
    final coreServices = serviceLocator<CoreServicesImpl>();
    coreServices.callOnCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t('转文字中…'),
      infoCode: 6660422,
    ));

    if (duration <= 0) {
      coreServices.callOnCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t('说话时间太短'),
        infoCode: 6660404,
      ));
      return null;
    }

    final text = await _transcribeLocalVoiceFile(
      soundPath,
      duration: duration,
      convID: convID,
      convType: convType,
    );
    if (text == null || text.isEmpty) {
      coreServices.callOnCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: _voiceToTextFailureMessage(),
        infoCode: 6660424,
      ));
      return null;
    }

    await discardVoiceToTextPendingUpload();
    return sendTextMessage(text: text, convID: convID, convType: convType);
  }

  String _voiceToTextFailureMessage() {
    final detail = VoiceToTextService.lastErrorMessage?.trim() ??
        VoiceToTextBridge.lastErrorMessage?.trim();
    if (detail != null && detail.isNotEmpty) {
      return detail;
    }
    return TIM_t('转文字失败，请重试');
  }

  Future<String?> transcribeLocalVoiceFile(
    String soundPath, {
    int? duration,
    String? convID,
    ConvType? convType,
  }) =>
      _transcribeLocalVoiceFile(
        soundPath,
        duration: duration,
        convID: convID,
        convType: convType,
      );

  String voiceToTextFailureMessage() => _voiceToTextFailureMessage();

  Future<void> acknowledgeVoiceToTextPendingUpload() async {
    VoiceToTextService.acknowledgePendingUpload();
  }

  bool get hasVoiceToTextPendingUpload => VoiceToTextService.hasPendingUpload;

  Future<void> discardVoiceToTextPendingUpload() async {
    final pending = VoiceToTextService.takePendingUpload();
    if (pending == null) {
      return;
    }
    final msgID = pending.msgID.trim();
    if (msgID.isEmpty) {
      return;
    }
    final res = await _messageService.deleteMessages(msgIDs: [msgID]);
    if (res.code == 0) {
      final messageList = getOriginMessageList();
      messageList.removeWhere((element) => element.msgID == msgID);
      globalModel.setMessageList(conversationID, messageList);
    }
  }

  Future<void> revokeVoiceToTextPendingUpload() =>
      discardVoiceToTextPendingUpload();

  Future<String?> _transcribeLocalVoiceFile(
    String soundPath, {
    int? duration,
    String? convID,
    ConvType? convType,
  }) async {
    VoiceToTextBridge.lastErrorMessage = null;
    if (convID == null || convType == null) {
      VoiceToTextService.lastErrorMessage = '当前会话已失效，请返回后重试';
      return null;
    }
    await discardVoiceToTextPendingUpload();
    final result = await VoiceToTextService.convertLocalFile(
      soundPath: soundPath,
      duration: duration ?? 0,
      convID: convID,
      convType: convType,
      messageService: _messageService,
      resolveUrl: _resolveSoundMessageUrl,
    );
    if (result.isSuccess) {
      return result.text;
    }
    VoiceToTextBridge.lastErrorMessage = result.errorMessage;
    return null;
  }

  Future<String?> _transcribeVoiceMessage(
      V2TimMessage message, String msgID) async {
    VoiceToTextBridge.lastErrorMessage = null;
    final result = await VoiceToTextService.convertMessage(
      message: message,
      msgID: msgID,
      resolveUrl: _resolveSoundMessageUrl,
    );
    if (result.isSuccess) {
      return result.text;
    }
    VoiceToTextBridge.lastErrorMessage = result.errorMessage;
    return null;
  }

  Future<void> _persistLocalCustomData(
    V2TimMessage message,
    LocalCustomDataModel localCustomData,
  ) async {
    message.localCustomData = json.encode(localCustomData.toMap());
    globalModel.markMessageChangedByMessage(conversationID, message);
    await globalModel.onMessageModified(message, conversationID);
    final msgID = TencentUtils.checkString(message.msgID);
    if (msgID != null) {
      await TencentImSDKPlugin.v2TIMManager.v2TIMMessageManager
          .setLocalCustomData(
        msgID: msgID,
        localCustomData: message.localCustomData ?? '',
      );
    }
    _notify();
  }

  Future<String?> _resolveSoundMessageUrl(
      V2TimMessage message, String msgID) async {
    final directUrl = TencentUtils.checkString(message.soundElem?.url);
    if (directUrl != null) {
      return directUrl;
    }

    for (var attempt = 0; attempt < 30; attempt++) {
      if (_disposed) {
        return null;
      }
      final onlineUrlResult = await _messageService.getMessageOnlineUrl(
          msgID: msgID, reportError: false);
      if (onlineUrlResult.code == 0) {
        final onlineUrl =
            TencentUtils.checkString(onlineUrlResult.data?.soundElem?.url);
        if (onlineUrl != null) {
          message.soundElem?.url = onlineUrl;
          return onlineUrl;
        }
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }

  addToMessageReadReceiptList(V2TimMessage message) {
    if (!_canUseReadReceipt || message.msgID == null) {
      return;
    }
    if (_readReceiptMap.containsKey(message.msgID!)) {
      return;
    }
    _readReceiptMap[message.msgID!] = message;
    _readReceiptFlushTimer?.cancel();
    _readReceiptFlushTimer = Timer(const Duration(milliseconds: 300), () {
      _setMsgReadReceipt(_readReceiptMap.values.toList());
    });
  }

  _setMsgReadReceipt(List<V2TimMessage> messageList) async {
    if (!_canUseReadReceipt) {
      _readReceiptMap.clear();
      return;
    }
    final msgIDList = List<String>.empty(growable: true);
    for (var item in messageList) {
      final isSelf = item.isSelf ?? true;
      final needReadReceipt = item.needReadReceipt ?? false;
      final isRead = item.isRead ?? false;
      if (!isRead && !isSelf && needReadReceipt && item.msgID != null) {
        msgIDList.add(item.msgID!);
        item.needReadReceipt = false;
      }
    }
    if (msgIDList.isNotEmpty) {
      sendMessageReadReceipts(msgIDList);
    }
  }

  sendMessageReadReceipts(List<String> messageIDList) async {
    if (!_canUseReadReceipt) {
      return null;
    }
    final res = await _messageService.sendMessageReadReceipts(
        messageIDList: messageIDList);
    return res;
  }

  void _scheduleDeferredGroupMarkRead(
      {Duration delay = const Duration(milliseconds: 1500)}) {
    _groupMarkReadDebounce?.cancel();
    _groupMarkReadDebounce = Timer(delay, () {
      if (_disposed || globalModel.isChatListUserScrolling) {
        return;
      }
      unawaited(markMessageAsRead(force: true));
    });
  }

  markMessageAsRead({bool notify = true, bool force = false}) async {
    if (suppressReadReporting) {
      return null;
    }
    final currentConversationID = conversationID;
    final currentConversationType = conversationType;
    if (currentConversationID.isEmpty || currentConversationType == null) {
      return null;
    }
    if (currentConversationType == ConvType.c2c) {
      return _messageService.markC2CMessageAsRead(
          userID: currentConversationID);
    }
    if (PlatformUtils().isWeb) {
      return null;
    }

    if (!force && globalModel.isChatListUserScrolling) {
      _scheduleDeferredGroupMarkRead();
      return null;
    }
    if (!force) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastGroupMarkReadAtMs < _groupMarkReadMinIntervalMs) {
        return null;
      }
    }

    final res = await _messageService.markGroupMessageAsRead(
        groupID: currentConversationID);
    if (res.code == 0) {
      _lastGroupMarkReadAtMs = DateTime.now().millisecondsSinceEpoch;
    } else {
      debugPrint(
        'markGroupMessageAsRead failed: code=${res.code}, desc=${res.desc}',
      );
      if (res.code == -10113) {
        _lastGroupMarkReadAtMs = DateTime.now().millisecondsSinceEpoch +
            _groupMarkReadFrequencyBlockBackoffMs;
        _scheduleDeferredGroupMarkRead(
          delay: const Duration(
              milliseconds: _groupMarkReadFrequencyBlockBackoffMs),
        );
      }
    }
    if (res.code == 10015 &&
        !_disposed &&
        conversationID == currentConversationID) {
      setGroupExist(false, notify: notify);
    }
    return res;
  }

  Future<void> loadSelfMemberInfo({required String groupID}) async {
    _muteDebugLog('[MUTE_DEBUG] loadSelfMemberInfo: START, groupID=$groupID');

    V2TimValueCallback<List<V2TimGroupMemberFullInfo>> getGroupMembersInfoRes =
        await TencentImSDKPlugin.v2TIMManager
            .getGroupManager()
            .getGroupMembersInfo(
      groupID: groupID,
      memberList: [selfModel.loginInfo?.userID ?? ""],
    );
    _muteDebugLog(
        '[MUTE_DEBUG] loadSelfMemberInfo: got response, code=${getGroupMembersInfoRes.code}');
    if (getGroupMembersInfoRes.code == 0) {
      final userList = getGroupMembersInfoRes.data;
      final newSelfMemberInfo = userList
          ?.firstWhereOrNull((e) => e.userID == selfModel.loginInfo?.userID);
      _muteDebugLog(
          '[MUTE_DEBUG] loadSelfMemberInfo: newSelfMemberInfo=${newSelfMemberInfo?.userID}, muteUntil=${newSelfMemberInfo?.muteUntil}');
      if (newSelfMemberInfo != null) {
        final prev = selfMemberInfo;
        final merged = _mergeSelfMemberPreservingActiveMute(
          existing: prev,
          incoming: newSelfMemberInfo,
        );
        final muteChanged = (prev?.muteUntil ?? 0) != (merged.muteUntil ?? 0);
        final roleChanged = prev?.role != merged.role;
        final firstAssign = prev == null;
        selfMemberInfo = merged;
        _muteDebugLog(
            '[MUTE_DEBUG] loadSelfMemberInfo: selfMemberInfo updated, muteUntil=${selfMemberInfo?.muteUntil}');
        GroupMemberStore.instance
            .putMember(groupID, selfMemberInfo, notify: false);
        final selfId = selfMemberInfo!.userID?.trim() ?? '';
        if (selfId.isNotEmpty) {
          final targetIndex =
              groupMemberList?.indexWhere((e) => e?.userID == selfId) ?? -1;
          if (targetIndex >= 0) {
            groupMemberList![targetIndex] = selfMemberInfo;
          } else {
            groupMemberList = [...?groupMemberList, selfMemberInfo];
          }
        }
        if (firstAssign || muteChanged || roleChanged) {
          _muteDebugLog(
              '[MUTE_DEBUG] loadSelfMemberInfo: Bumping _groupMemberVersion from $_groupMemberVersion');
          _groupMemberVersion++;
          _muteDebugLog(
              '[MUTE_DEBUG] loadSelfMemberInfo: Bumped _groupMemberVersion to $_groupMemberVersion');
          _notify();
        }
      }
    }
    return;
  }

  /// Updates self member info directly without fetching from server.
  /// Used to preserve local mute state when server data might be stale.
  void updateSelfMemberInfo(V2TimGroupMemberFullInfo member,
      {required String groupID}) {
    selfMemberInfo = member;

    // Also update in groupMemberList
    final selfId = member.userID?.trim() ?? '';
    if (selfId.isNotEmpty) {
      final targetIndex =
          groupMemberList?.indexWhere((e) => e?.userID == selfId) ?? -1;
      if (targetIndex >= 0) {
        groupMemberList![targetIndex] = member;
      }
    }

    // Update in GroupMemberStore
    GroupMemberStore.instance.putMember(groupID, member, notify: true);

    // Bump version to notify listeners about selfMemberInfo changes
    _groupMemberVersion++;

    // Notify listeners that self member info has changed
    _notify();
  }

  /// Updates self member's mute status from backend API response.
  /// Priority: isAllMuted > SDK data > Backend API
  /// Only updates if backend returns a valid muteUntil > 0.
  Future<void> updateSelfMuteStatus({
    required String groupID,
    required int muteUntil,
    bool isAllMuted = false,
  }) async {
    _muteDebugLog(
        '[MUTE_DEBUG] updateSelfMuteStatus: groupID=$groupID, muteUntil=$muteUntil, isAllMuted=$isAllMuted');
    final groupMuteChanged =
        _groupInfo != null && (_groupInfo?.isAllMuted ?? false) != isAllMuted;
    if (_groupInfo != null) {
      _groupInfo!.isAllMuted = isAllMuted;
    }

    // 全员禁言优先级最高
    if (isAllMuted) {
      _muteDebugLog(
          '[MUTE_DEBUG] updateSelfMuteStatus: isAllMuted=true, setting muteUntil to max');
      _setSelfMuteUntil(groupID, _kPermanentMuteUntil);
      return;
    }

    // 该接口返回的是后端权威状态；0 表示已解除禁言，需要清掉本地旧状态。
    if (muteUntil <= 0) {
      final existingMute = selfMemberInfo?.muteUntil ?? 0;
      // 本地已是未禁言时无需清除；避免进群后 0→0 的无效通知重建消息列表。
      if (selfMemberInfo != null && existingMute > 0) {
        _muteDebugLog(
            '[MUTE_DEBUG] updateSelfMuteStatus: Backend returned unmuted state, '
            'clearing existing muteUntil=$existingMute');
        _setSelfMuteUntil(groupID, 0);
        return;
      }
      if (groupMuteChanged) {
        _groupMemberVersion++;
        _notify();
      }
      return;
    }

    // 后端返回有效的禁言时间，使用后端数据
    _muteDebugLog(
        '[MUTE_DEBUG] updateSelfMuteStatus: Using backend muteUntil=$muteUntil');
    _setSelfMuteUntil(groupID, muteUntil);
  }

  /// Internal helper to update selfMemberInfo muteUntil
  void _setSelfMuteUntil(String groupID, int muteUntil) {
    final selfId =
        (selfMemberInfo?.userID ?? selfModel.loginInfo?.userID ?? '').trim();
    if (selfMemberInfo == null) {
      if (selfId.isEmpty) {
        _muteDebugLog(
            '[MUTE_DEBUG] _setSelfMuteUntil: selfMemberInfo is null and no selfId, cannot update');
        return;
      }
      _muteDebugLog(
          '[MUTE_DEBUG] _setSelfMuteUntil: selfMemberInfo is null, creating stub for $selfId');
      selfMemberInfo = V2TimGroupMemberFullInfo(
        userID: selfId,
        role: _groupInfo?.role ??
            GroupMemberRoleType.V2TIM_GROUP_MEMBER_ROLE_MEMBER,
        muteUntil: muteUntil,
      );
      GroupMemberStore.instance
          .putMember(groupID, selfMemberInfo, notify: true);
      _groupMemberVersion++;
      _notify();
      return;
    }
    // 值未变化时直接跳过，避免进群后 0→0 的无效写入 bump groupMemberVersion，
    // 触发整个消息列表（含头像）全量重建造成抖动。
    if ((selfMemberInfo!.muteUntil ?? 0) == muteUntil) {
      _muteDebugLog(
          '[MUTE_DEBUG] _setSelfMuteUntil: muteUntil unchanged ($muteUntil), skip notify');
      return;
    }

    final updatedMember = V2TimGroupMemberFullInfo(
      userID: selfMemberInfo!.userID,
      role: selfMemberInfo!.role,
      nickName: selfMemberInfo!.nickName,
      nameCard: selfMemberInfo!.nameCard,
      friendRemark: selfMemberInfo!.friendRemark,
      faceUrl: selfMemberInfo!.faceUrl,
      joinTime: selfMemberInfo!.joinTime,
      muteUntil: muteUntil,
      customInfo: selfMemberInfo!.customInfo,
    );

    selfMemberInfo = updatedMember;

    if (selfId.isNotEmpty) {
      final targetIndex =
          groupMemberList?.indexWhere((e) => e?.userID == selfId) ?? -1;
      if (targetIndex >= 0) {
        groupMemberList![targetIndex] = updatedMember;
      }
    }

    GroupMemberStore.instance.putMember(groupID, updatedMember, notify: true);

    _groupMemberVersion++;
    _notify();

    _muteDebugLog(
        '[MUTE_DEBUG] _setSelfMuteUntil: Updated selfMemberInfo muteUntil=$muteUntil');
  }

  /// SDK/成员列表可能带回过期的 muteUntil=0；保留本地仍有效的禁言截止时间。
  V2TimGroupMemberFullInfo _mergeSelfMemberPreservingActiveMute({
    required V2TimGroupMemberFullInfo? existing,
    required V2TimGroupMemberFullInfo incoming,
  }) {
    if (existing == null) {
      if (_groupInfo?.isAllMuted == true && !_isMuteExemptRole(incoming.role)) {
        return _copyMemberWithMuteUntil(incoming, _kPermanentMuteUntil);
      }
      return incoming;
    }
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final existingMute = existing.muteUntil ?? 0;
    final incomingMute = incoming.muteUntil ?? 0;
    final preferExisting = existingMute > nowSec && existingMute > incomingMute;
    final forceAllMute =
        _groupInfo?.isAllMuted == true && !_isMuteExemptRole(incoming.role);
    if (!preferExisting && !forceAllMute) {
      return incoming;
    }
    final muteUntil = forceAllMute
        ? _kPermanentMuteUntil
        : (preferExisting ? existingMute : incomingMute);
    return _copyMemberWithMuteUntil(incoming, muteUntil);
  }

  bool _isMuteExemptRole(int? role) {
    return GroupRolePolicy.isMuteExemptRole(role);
  }

  V2TimGroupMemberFullInfo _copyMemberWithMuteUntil(
    V2TimGroupMemberFullInfo source,
    int muteUntil,
  ) {
    return V2TimGroupMemberFullInfo(
      userID: source.userID,
      role: source.role,
      nickName: source.nickName,
      nameCard: source.nameCard,
      friendRemark: source.friendRemark,
      faceUrl: source.faceUrl,
      joinTime: source.joinTime,
      muteUntil: muteUntil,
      customInfo: source.customInfo,
    );
  }

  Future<void> loadGroupMemberList(
      {required String groupID, int count = 100, String? seq}) async {
    final String? nextSeq = await _loadGroupMemberListFunction(
        groupID: groupID, seq: seq, count: count);
    if (nextSeq != null && nextSeq != "0" && nextSeq != "") {
      return await loadGroupMemberList(
          groupID: groupID, count: count, seq: nextSeq);
    } else {
      final fromList = groupMemberList
          ?.firstWhereOrNull((e) => e?.userID == selfModel.loginInfo?.userID);
      if (fromList != null) {
        selfMemberInfo = _mergeSelfMemberPreservingActiveMute(
          existing: selfMemberInfo,
          incoming: fromList,
        );
        final selfId = selfMemberInfo?.userID?.trim() ?? '';
        if (selfId.isNotEmpty) {
          final targetIndex =
              groupMemberList?.indexWhere((e) => e?.userID == selfId) ?? -1;
          if (targetIndex >= 0) {
            groupMemberList![targetIndex] = selfMemberInfo;
          }
        }
      }
      GroupMemberStore.instance.putMembers(
          groupID, groupMemberList ?? const <V2TimGroupMemberFullInfo?>[]);
      groupMemberListComplete = true;
      _groupMemberVersion++;
      _notify();
    }
  }

  /// 等进页 hydrate 后再跑一次 open-shell，避免「仅 self」与「含 sender」各跑一轮。
  Future<void> _loadGroupMembersOpenShellOnce({required String groupID}) async {
    final gid = groupID.trim();
    if (gid.isEmpty || _disposed) {
      return;
    }
    final generation = _openShellGeneration;
    await globalModel.awaitOpenHydrateInFlight(
      conversationID,
      timeout: const Duration(milliseconds: 700),
    );
    if (_disposed || generation != _openShellGeneration) {
      return;
    }
    await loadGroupMembersForOpenShell(groupID: gid);
  }

  /// 进页最小成员集：自己 + 当前暖窗/首屏消息 sender（上限 [_openShellSenderLimit]）。
  /// 同一会话打开周期内只成功提交一次（in-flight 去重）。
  Future<void> loadGroupMembersForOpenShell({required String groupID}) async {
    final gid = groupID.trim();
    if (gid.isEmpty || _disposed) {
      return;
    }
    if (_openShellCompletedGid == gid) {
      return;
    }
    final existing = _openShellInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final generation = _openShellGeneration;
    final task = _loadGroupMembersForOpenShellImpl(
      groupID: gid,
      generation: generation,
    );
    _openShellInFlight = task;
    try {
      await task;
    } finally {
      if (identical(_openShellInFlight, task)) {
        _openShellInFlight = null;
      }
    }
  }

  Future<void> _loadGroupMembersForOpenShellImpl({
    required String groupID,
    required int generation,
  }) async {
    final gid = groupID.trim();
    if (gid.isEmpty ||
        _disposed ||
        generation != _openShellGeneration ||
        _openShellCompletedGid == gid) {
      return;
    }
    final selfId = selfModel.loginInfo?.userID?.trim() ?? '';
    final userIds = <String>{};
    if (selfId.isNotEmpty) {
      userIds.add(selfId);
    }
    final warm = globalModel.rawMessageList(conversationID) ??
        globalModel.rawMessageList(gid);
    if (warm != null && warm.isNotEmpty) {
      final limit = warm.length < _openShellSenderLimit
          ? warm.length
          : _openShellSenderLimit;
      for (var i = 0; i < limit; i++) {
        final message = warm[i];
        final sender = (message.sender ?? message.userID ?? '').trim();
        if (sender.isNotEmpty) {
          userIds.add(sender);
        }
      }
    }

    final merged = <String, V2TimGroupMemberFullInfo>{};
    final missing = <String>[];
    for (final userId in userIds) {
      final cached = GroupMemberStore.instance.memberOf(gid, userId);
      if (cached != null) {
        merged[userId] = cached;
      } else {
        missing.add(userId);
      }
    }

    const chunkSize = 50;
    for (var offset = 0; offset < missing.length; offset += chunkSize) {
      if (_disposed || generation != _openShellGeneration) {
        return;
      }
      final end = offset + chunkSize > missing.length
          ? missing.length
          : offset + chunkSize;
      final chunk = missing.sublist(offset, end);
      try {
        final res = await TencentImSDKPlugin.v2TIMManager
            .getGroupManager()
            .getGroupMembersInfo(groupID: gid, memberList: chunk);
        if (res.code == 0 && res.data != null) {
          for (final member in res.data!) {
            final id = member.userID?.trim() ?? '';
            if (id.isEmpty) {
              continue;
            }
            merged[id] = member;
          }
        }
      } catch (_) {
        // 最小集失败不挡进页；idle 全量仍会补。
      }
    }

    if (_disposed || generation != _openShellGeneration) {
      return;
    }

    if (selfMemberInfo != null) {
      final id = selfMemberInfo!.userID?.trim() ?? '';
      if (id.isNotEmpty) {
        merged[id] = _mergeSelfMemberPreservingActiveMute(
          existing: merged[id],
          incoming: selfMemberInfo!,
        );
      }
    } else if (selfId.isNotEmpty && !merged.containsKey(selfId)) {
      await loadSelfMemberInfo(groupID: gid);
      if (_disposed || generation != _openShellGeneration) {
        return;
      }
      if (selfMemberInfo != null) {
        final id = selfMemberInfo!.userID?.trim() ?? selfId;
        merged[id] = selfMemberInfo!;
      }
    }

    // 须可 grow：后续 full load 会 clear/append；固定长度列表会抛 set length。
    final list =
        merged.values.map((e) => e as V2TimGroupMemberFullInfo?).toList();
    groupMemberList = list;
    _openShellCompletedGid = gid;
    if (list.isNotEmpty) {
      GroupMemberStore.instance.putMembers(gid, list, notify: false);
      _groupMemberVersion++;
      _notify();
    }
    ChatHistoryTrace.log(
      'group_member_open_shell',
      conversationID: gid,
      extras: <String, Object?>{
        'requested': userIds.length,
        'resolved': list.length,
        'missingAfterStore': missing.length,
        'hasSelf': selfId.isNotEmpty && merged.containsKey(selfId),
      },
    );
    ChatOpenPerfLog.mark(
      'group_member_open_shell',
      conversationID: gid,
      extras: <String, Object?>{
        'requested': userIds.length,
        'resolved': list.length,
        'missingAfterStore': missing.length,
        'hasSelf': selfId.isNotEmpty && merged.containsKey(selfId),
      },
    );
  }

  /// 退页：取消 open-shell / idle 全量成员加载（禁言由 Chat 页 lifecycle 取消）。
  void cancelOpenSideMemberLoads() {
    _openShellGeneration++;
    _openShellInFlight = null;
    _openShellCompletedGid = null;
    _idleFullMemberLoadGeneration++;
    _fullMemberLoadInFlight = null;
  }

  void _scheduleIdleFullGroupMemberLoad({required String groupID}) {
    final gid = groupID.trim();
    if (gid.isEmpty) {
      return;
    }
    final generation = ++_idleFullMemberLoadGeneration;
    Future<void>.delayed(_idleFullMemberLoadDelay, () async {
      if (_disposed || generation != _idleFullMemberLoadGeneration) {
        return;
      }
      if (groupMemberListComplete) {
        return;
      }
      await ensureGroupMemberListComplete(groupID: gid);
    });
  }

  /// @ 面板 / 群资料 / 踢禁言刷新：保证完整成员列表。
  Future<void> ensureGroupMemberListComplete({required String groupID}) async {
    final gid = groupID.trim();
    if (gid.isEmpty || groupMemberListComplete || _disposed) {
      return;
    }
    final inFlight = _fullMemberLoadInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    ChatOpenPerfLog.mark(
      'group_member_full_load_start',
      conversationID: gid,
    );
    final fullSw = Stopwatch()..start();
    final task = () async {
      await loadGroupMemberList(groupID: gid);
    }();
    _fullMemberLoadInFlight = task;
    try {
      await task;
      ChatOpenPerfLog.mark(
        'group_member_full_load_done',
        conversationID: gid,
        extras: <String, Object?>{
          'fullLoadMs': fullSw.elapsedMilliseconds,
          'memberCount': groupMemberList?.length ?? 0,
        },
      );
    } finally {
      if (identical(_fullMemberLoadInFlight, task)) {
        _fullMemberLoadInFlight = null;
      }
    }
  }

  void processGroupMemberListEnter(
      {required String groupID,
      required List<V2TimGroupMemberInfo> memberList}) async {
    final List<V2TimGroupMemberFullInfo> fullInfoList =
        memberList.where((member) => member.userID != null).map((member) {
      return V2TimGroupMemberFullInfo(
        userID: member.userID!,
        nickName: member.nickName,
        nameCard: member.nameCard,
        friendRemark: member.friendRemark,
        faceUrl: member.faceUrl,
        onlineDevices: member.onlineDevices,
      );
    }).toList();

    for (final fullInfo in fullInfoList) {
      final exists =
          groupMemberList?.any((e) => e?.userID == fullInfo.userID) ?? false;
      if (!exists) {
        groupMemberList = [...?groupMemberList, fullInfo];
      }
    }
    GroupMemberStore.instance.putMembers(groupID, fullInfoList);
    _groupMemberVersion++;
    _notify();
  }

  void processGroupMemberListLeave(
      {required String groupID,
      required List<V2TimGroupMemberInfo> memberList}) async {
    final Set<String?> userIDsToRemove =
        memberList.map((member) => member.userID).toSet();

    groupMemberList = groupMemberList
            ?.where((member) => !userIDsToRemove.contains(member?.userID))
            .toList() ??
        groupMemberList;
    GroupMemberStore.instance
        .removeMembers(groupID, userIDsToRemove, notify: false);
    _groupMemberVersion++;
    _notify();
  }

  V2TimGroupMemberFullInfo? getGroupMember(String userID) {
    final uid = userID.trim();
    if (uid.isEmpty) {
      return null;
    }
    final fromList = groupMemberList?.firstWhereOrNull((e) => e?.userID == uid);
    if (fromList != null) {
      return fromList;
    }
    final gid = TencentUtils.checkString(_groupID) ?? conversationID;
    return GroupMemberStore.instance.memberOf(gid, uid);
  }

  String _normalizeC2CPeerID(String? value) {
    final text = value?.trim() ?? '';
    if (text.startsWith('c2c_')) {
      return text.substring(4);
    }
    return text;
  }

  String _normalizeGroupID(String? value) {
    final text = value?.trim() ?? '';
    if (text.startsWith('group_')) {
      return text.substring(6);
    }
    return text;
  }

  String _currentC2CPeerID() => _normalizeC2CPeerID(conversationID);

  String? _latestC2CName(String? userID) {
    final peerID = _normalizeC2CPeerID(userID);
    if (peerID.isEmpty) {
      return null;
    }
    final cached =
        TencentUtils.checkString(DisplayNameStore.instance.c2c(peerID));
    if (cached != null) {
      return cached;
    }
    final conversationKey = 'c2c_$peerID';
    final selected = conversationViewModel.selectedConversation;
    if (selected?.conversationID == conversationKey) {
      final showName = TencentUtils.checkString(selected?.showName);
      if (showName != null) {
        return showName;
      }
    }
    final conversation = conversationViewModel.getConversation(conversationKey);
    return TencentUtils.checkString(conversation?.showName);
  }

  String getMessageDisplayName(V2TimMessage message) {
    if (conversationType == ConvType.group) {
      final userID = TencentUtils.checkString(message.sender) ??
          TencentUtils.checkString(message.userID);
      if (userID != null) {
        final member = getGroupMember(userID);
        final name = TencentUtils.checkString(member?.nameCard) ??
            TencentUtils.checkString(member?.friendRemark) ??
            TencentUtils.checkString(member?.nickName);
        if (name != null) {
          return name;
        }
      }
    } else if (conversationType == ConvType.c2c) {
      final loginID = TencentUtils.checkString(selfModel.loginInfo?.userID);
      final sender = TencentUtils.checkString(message.sender);
      final isSelfMessage = (message.isSelf == true) ||
          (loginID != null && sender != null && sender == loginID);
      if (!isSelfMessage) {
        for (final peerID in <String?>[
          _currentC2CPeerID(),
          message.userID,
          message.sender,
        ]) {
          final name = _latestC2CName(peerID);
          if (name != null) {
            return name;
          }
        }
      }
    }
    return TencentUtils.checkString(message.friendRemark) ??
        TencentUtils.checkString(message.nameCard) ??
        MessageUtils.getDisplayName(message);
  }

  String getMessageFaceUrl(V2TimMessage message) {
    return _resolveMessageFaceUrl(message) ?? '';
  }

  String? _resolveMessageFaceUrl(V2TimMessage message) {
    final loginID = TencentUtils.checkString(selfModel.loginInfo?.userID);
    final sender = TencentUtils.checkString(message.sender) ??
        TencentUtils.checkString(message.userID);
    final isSelfMessage = (message.isSelf == true) ||
        (loginID != null && sender != null && sender == loginID);

    if (isSelfMessage) {
      return TencentUtils.checkString(selfModel.loginInfo?.faceUrl) ??
          TencentUtils.checkString(message.faceUrl);
    }

    if (conversationType == ConvType.group) {
      if (sender != null) {
        final memberFace =
            TencentUtils.checkString(getGroupMember(sender)?.faceUrl);
        if (memberFace != null) {
          return memberFace;
        }
      }
      return TencentUtils.checkString(message.faceUrl);
    }

    if (conversationType == ConvType.c2c) {
      final currentFace =
          TencentUtils.checkString(_currentChatUserInfo?.faceUrl);
      if (currentFace != null) {
        return currentFace;
      }
      for (final peerID in <String?>[
        _currentC2CPeerID(),
        message.userID,
        message.sender,
      ]) {
        final normalized = _normalizeC2CPeerID(peerID);
        if (normalized.isEmpty) {
          continue;
        }
        final conv = conversationViewModel.getConversation('c2c_$normalized');
        final convFace = TencentUtils.checkString(conv?.faceUrl);
        if (convFace != null) {
          return convFace;
        }
      }
      return TencentUtils.checkString(message.faceUrl);
    }

    return TencentUtils.checkString(message.faceUrl);
  }

  Future<void> syncMessagesFaceUrlFromSdk(List<V2TimMessage> messages) async {
    if (messages.isEmpty) {
      return;
    }

    final loginID = TencentUtils.checkString(selfModel.loginInfo?.userID);

    if (conversationType == ConvType.group) {
      final groupID = TencentUtils.checkString(_groupID) ?? conversationID;
      final pendingUserIDs = <String>{};

      for (final message in messages) {
        final cached = _resolveMessageFaceUrl(message);
        if (cached != null) {
          _applySyncedFaceUrl(message, cached);
          continue;
        }
        final userID = TencentUtils.checkString(message.sender) ??
            TencentUtils.checkString(message.userID);
        if (userID == null || userID.isEmpty) {
          continue;
        }
        if (loginID != null && userID == loginID) {
          final selfFace =
              TencentUtils.checkString(selfModel.loginInfo?.faceUrl);
          if (selfFace != null) {
            _applySyncedFaceUrl(message, selfFace);
          }
          continue;
        }
        pendingUserIDs.add(userID);
      }

      if (pendingUserIDs.isEmpty) {
        return;
      }

      final res = await TencentImSDKPlugin.manager
          ?.getGroupManager()
          .getGroupMembersInfo(
            groupID: groupID,
            memberList: pendingUserIDs.toList(),
          );
      if (res?.code != 0 || res?.data == null) {
        return;
      }

      GroupMemberStore.instance.putMembers(groupID, res!.data!);
      _groupMemberVersion++;

      for (final message in messages) {
        final faceUrl = _resolveMessageFaceUrl(message);
        if (faceUrl != null) {
          _applySyncedFaceUrl(message, faceUrl);
        }
      }
      _notify();
      return;
    }

    var peerNeedsFetch = false;
    for (final message in messages) {
      final sender = TencentUtils.checkString(message.sender) ??
          TencentUtils.checkString(message.userID);
      final isSelfMessage = (message.isSelf == true) ||
          (loginID != null && sender != null && sender == loginID);
      if (isSelfMessage) {
        final selfFace = TencentUtils.checkString(selfModel.loginInfo?.faceUrl);
        if (selfFace != null) {
          _applySyncedFaceUrl(message, selfFace);
        }
        continue;
      }
      final cached = _resolveMessageFaceUrl(message);
      if (cached != null) {
        _applySyncedFaceUrl(message, cached);
      } else {
        peerNeedsFetch = true;
      }
    }

    if (!peerNeedsFetch) {
      return;
    }

    final peerID = _currentC2CPeerID();
    if (peerID.isEmpty) {
      return;
    }

    String? peerFaceUrl;
    final friendRes =
        await _friendshipServices.getFriendsInfo(userIDList: [peerID]);
    if (friendRes != null && friendRes.isNotEmpty) {
      peerFaceUrl = TencentUtils.checkString(
          friendRes[0].friendInfo?.userProfile?.faceUrl);
      _currentChatUserInfo = V2TimGroupMemberFullInfo(
        userID: peerID,
        faceUrl: friendRes[0].friendInfo?.userProfile?.faceUrl,
        nickName: friendRes[0].friendInfo?.userProfile?.nickName,
        friendRemark: friendRes[0].friendInfo?.friendRemark,
      );
    } else {
      final userRes =
          await _friendshipServices.getUsersInfo(userIDList: [peerID]);
      if (userRes != null && userRes.isNotEmpty) {
        peerFaceUrl = TencentUtils.checkString(userRes[0].faceUrl);
        _currentChatUserInfo = V2TimGroupMemberFullInfo(
          userID: peerID,
          faceUrl: userRes[0].faceUrl,
          nickName: userRes[0].nickName,
        );
      }
    }

    if (peerFaceUrl != null) {
      for (final message in messages) {
        final sender = TencentUtils.checkString(message.sender) ??
            TencentUtils.checkString(message.userID);
        final isSelfMessage = (message.isSelf == true) ||
            (loginID != null && sender != null && sender == loginID);
        if (!isSelfMessage) {
          _applySyncedFaceUrl(message, peerFaceUrl);
        }
      }
    }
    _notify();
  }

  void _applySyncedFaceUrl(V2TimMessage message, String faceUrl) {
    if (TencentUtils.checkString(message.faceUrl) == faceUrl) {
      return;
    }
    message.faceUrl = faceUrl;
  }

  String getGroupMessageDisplayName(V2TimMessage message) {
    return getMessageDisplayName(message);
  }

  String getMergerForwardSourceName() {
    if (conversationType == ConvType.group) {
      return TencentUtils.checkString(groupInfo?.groupName) ??
          TencentUtils.checkString(_conversationShowName()) ??
          TIM_t("群聊");
    }

    final peerInfo = _currentChatUserInfo;
    return TencentUtils.checkString(peerInfo?.friendRemark) ??
        TencentUtils.checkString(peerInfo?.nickName) ??
        TencentUtils.checkString(_latestC2CName(_currentC2CPeerID())) ??
        TencentUtils.checkString(_conversationShowName()) ??
        TencentUtils.checkString(_currentC2CPeerID()) ??
        TIM_t("聊天");
  }

  String getMergerForwardTitle() {
    final sourceName = getMergerForwardSourceName();
    return TIM_t_para("{{option1}}的聊天记录", "$sourceName的聊天记录")(
      option1: sourceName,
    );
  }

  String? _conversationShowName() {
    final convID = conversationID.trim();
    if (convID.isEmpty) {
      return null;
    }
    final candidates = <String>{
      convID,
      if (conversationType == ConvType.group)
        convID.startsWith('group_') ? convID : 'group_$convID'
      else
        convID.startsWith('c2c_') ? convID : 'c2c_$convID',
    };
    final selected = conversationViewModel.selectedConversation;
    if (selected != null && candidates.contains(selected.conversationID)) {
      final showName = TencentUtils.checkString(selected.showName);
      if (showName != null) {
        return showName;
      }
    }
    for (final id in candidates) {
      final showName = TencentUtils.checkString(
        conversationViewModel.getConversation(id)?.showName,
      );
      if (showName != null) {
        return showName;
      }
    }
    return null;
  }

  void applyDisplayNameChange(DisplayNameChange change) {
    if (change.type == 'c2c') {
      if (conversationType != ConvType.c2c ||
          _currentC2CPeerID() != _normalizeC2CPeerID(change.id)) {
        return;
      }
      _groupMemberVersion++;
      _notify();
      return;
    }
    if (change.type == 'group') {
      final gid = _normalizeGroupID(
          TencentUtils.checkString(_groupID) ?? conversationID);
      if (conversationType == ConvType.group &&
          gid == _normalizeGroupID(change.id)) {
        _groupMemberVersion++;
        _notify();
      }
    }
  }

  void applyGroupMemberChange(GroupMemberChange change) {
    final gid = TencentUtils.checkString(_groupID) ?? conversationID;
    if (conversationType != ConvType.group) {
      return;
    }
    if (change.groupID.isNotEmpty && change.groupID != gid) {
      return;
    }
    final member =
        change.member ?? GroupMemberStore.instance.memberOf(gid, change.userID);
    if (member == null) {
      return;
    }
    final targetIndex =
        groupMemberList?.indexWhere((e) => e?.userID == change.userID) ?? -1;
    if (targetIndex >= 0) {
      groupMemberList![targetIndex] = member;
    } else {
      groupMemberList = [...?groupMemberList, member];
    }
    if (change.userID == selfModel.loginInfo?.userID) {
      selfMemberInfo = member;
    }
    _groupUserShowName[change.userID] =
        TencentUtils.checkString(member.nameCard) ??
            TencentUtils.checkString(member.friendRemark) ??
            TencentUtils.checkString(member.nickName) ??
            change.userID;
    _groupMemberVersion++;
    _notify();
  }

  void _notify() {
    if (_disposed) {
      return;
    }
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      _notifyNow();
      return;
    }
    if (_notifyScheduled) {
      return;
    }
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) {
        _notifyNow();
      }
    });
  }

  void _notifyNow() {
    try {
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _ensureGrowableGroupMemberList() {
    final current = groupMemberList;
    if (current != null) {
      groupMemberList = List<V2TimGroupMemberFullInfo?>.from(current);
    }
  }

  Future<String?> _loadGroupMemberListFunction(
      {required String groupID, int count = 100, String? seq}) async {
    if (seq == null || seq == "" || seq == "0") {
      groupMemberList = <V2TimGroupMemberFullInfo?>[];
    } else {
      _ensureGrowableGroupMemberList();
    }
    try {
      final res = await _groupServices.getGroupMemberList(
          groupID: groupID,
          filter: GroupMemberFilterTypeEnum.V2TIM_GROUP_MEMBER_FILTER_ALL,
          count: count,
          nextSeq: seq ?? groupMemberListSeq);
      final groupMemberListRes = res.data;
      if (res.code == 0 && groupMemberListRes != null) {
        final groupMemberListTemp = groupMemberListRes.memberInfoList ?? [];
        groupMemberList = [...?groupMemberList, ...groupMemberListTemp];
        groupMemberListSeq = groupMemberListRes.nextSeq ?? "0";
        GroupMemberStore.instance.putMembers(groupID, groupMemberListTemp);
      } else if (res.code == 10010) {
        isGroupExist = false;
      } else if (res.code == 10007) {
        isNotAMember = true;
      }
      return groupMemberListRes?.nextSeq;
    } catch (e) {
      return "";
    }
  }

  Future<(V2TimGroupInfo?, GroupReceiptAllowType?)> loadGroupInfo(
      String groupID) async {
    final groupInfoList =
        await _groupServices.getGroupsInfo(groupIDList: [groupID]);
    if (groupInfoList != null && groupInfoList.isNotEmpty) {
      final groupRes = groupInfoList.first;
      ChatHistoryTrace.log(
        'group_info_loaded',
        conversationID: groupID,
        extras: <String, Object?>{
          'resultCode': groupRes.resultCode,
          'sdkGroupType': groupRes.groupInfo?.groupType,
          'isSupportTopic': groupRes.groupInfo?.isSupportTopic,
          'memberCount': groupRes.groupInfo?.memberCount,
          'lastMessageTime': groupRes.groupInfo?.lastMessageTime,
        },
      );
      if (groupRes.resultCode == 0) {
        final previousAllMuted = _groupInfo?.isAllMuted == true;
        _groupInfo = groupRes.groupInfo;

        const groupTypeMap = {
          "Meeting": GroupReceiptAllowType.meeting,
          "Public": GroupReceiptAllowType.public,
          "Work": GroupReceiptAllowType.work,
          "Community": GroupReceiptAllowType.community,
        };
        _groupType = groupTypeMap[groupRes.groupInfo?.groupType];

        final nowAllMuted = _groupInfo?.isAllMuted == true;
        var muteApplied = false;
        if (nowAllMuted &&
            !_isMuteExemptRole(selfMemberInfo?.role ?? _groupInfo?.role)) {
          final beforeMute = selfMemberInfo?.muteUntil ?? 0;
          _setSelfMuteUntil(groupID, _kPermanentMuteUntil);
          muteApplied = beforeMute != (selfMemberInfo?.muteUntil ?? 0);
        }
        if (!muteApplied) {
          if (previousAllMuted != nowAllMuted) {
            _groupMemberVersion++;
          }
          _notify();
        }
        return (_groupInfo, _groupType);
      }
    }
    return (null, null);
  }

  Future<void> updateMessageFromController(
      {required String msgID, V2TimMessage? message}) async {
    V2TimMessage? newMessage = message ??
        await tools.getExistingMessageByID(
            msgID: msgID,
            conversationType: conversationType ?? ConvType.c2c,
            conversationID: conversationID);
    if (newMessage != null) {
      globalModel.onMessageModified(newMessage, conversationID);
    } else {
      loadChatRecord(
        count: HistoryMessageDartConstant.getCount,
      );
    }
  }

  Future<V2TimValueCallback<V2TimMessageChangeInfo>?> modifyMessage(
      {required V2TimMessage message}) async {
    return _messageService.modifyMessage(message: message);
  }

  String _stripConversationPrefix(String value, String prefix) {
    final target = value.trim();
    if (target.toLowerCase().startsWith(prefix)) {
      return target.substring(prefix.length);
    }
    return target;
  }

  ConvType _forwardConversationType(V2TimConversation conversation) {
    if (conversation.type == 1) {
      return ConvType.c2c;
    }
    if (conversation.type == 2) {
      return ConvType.group;
    }
    final id = conversation.conversationID.trim().toLowerCase();
    if (id.startsWith('group_') ||
        conversation.groupID?.trim().isNotEmpty == true) {
      return ConvType.group;
    }
    if (id.startsWith('c2c_') ||
        conversation.userID?.trim().isNotEmpty == true) {
      return ConvType.c2c;
    }
    return ConvType.none;
  }

  String _forwardConversationId(V2TimConversation conversation) {
    final targetType = _forwardConversationType(conversation);
    if (targetType == ConvType.group) {
      final groupID = conversation.groupID?.trim();
      if (groupID != null && groupID.isNotEmpty) {
        return groupID;
      }
      return _stripConversationPrefix(conversation.conversationID, 'group_');
    }
    if (targetType == ConvType.c2c) {
      final userID = conversation.userID?.trim();
      if (userID != null && userID.isNotEmpty) {
        return userID;
      }
      return _stripConversationPrefix(conversation.conversationID, 'c2c_');
    }
    return conversation.conversationID.trim();
  }

  _ResolvedSendTarget? _resolveSendTarget({
    required String convID,
    required ConvType convType,
    required String messageID,
  }) {
    final rawConvID = convID.trim();
    if (rawConvID.isEmpty || convType == ConvType.none) {
      outputLogger.i(
        'send target invalid: empty target, convType=$convType, messageID=$messageID',
      );
      return null;
    }

    if (convType == ConvType.c2c) {
      if (rawConvID.toLowerCase().startsWith('group_')) {
        outputLogger.i(
          'send target invalid: C2C target has group prefix, convID=$rawConvID, messageID=$messageID',
        );
        return null;
      }
      final receiver = _stripConversationPrefix(rawConvID, 'c2c_');
      if (receiver.isEmpty) {
        outputLogger.i(
          'send target invalid: C2C receiver empty, convID=$rawConvID, messageID=$messageID',
        );
        return null;
      }
      return _ResolvedSendTarget(
        receiver: receiver,
        groupID: '',
        normalizedConvID: receiver,
      );
    }

    if (rawConvID.toLowerCase().startsWith('c2c_')) {
      outputLogger.i(
        'send target invalid: group target has C2C prefix, convID=$rawConvID, messageID=$messageID',
      );
      return null;
    }
    final groupID = _stripConversationPrefix(rawConvID, 'group_');
    if (groupID.isEmpty) {
      outputLogger.i(
        'send target invalid: groupID empty, convID=$rawConvID, messageID=$messageID',
      );
      return null;
    }
    return _ResolvedSendTarget(
      receiver: '',
      groupID: groupID,
      normalizedConvID: groupID,
    );
  }

  V2TimValueCallback<V2TimMessage> _buildInvalidTargetResult({
    required String id,
    required String convID,
    required ConvType convType,
    V2TimMessage? messageInfo,
  }) {
    final failedMessage = messageInfo ??
        V2TimMessage(
          id: id,
          msgID: id,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_NONE,
        );
    failedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    final coreServices = serviceLocator<CoreServicesImpl>();
    coreServices.callOnCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: TIM_t('当前会话已失效，请返回后重试'),
      infoCode: 6660420,
    ));
    outputLogger.i(
      'send target invalid: convID=$convID, convType=$convType, messageID=$id',
    );
    return V2TimValueCallback<V2TimMessage>(
      code: 6660420,
      desc: 'invalid conversation target',
      data: failedMessage,
    );
  }

  V2TimValueCallback<V2TimMessage> _buildFriendRelationBlockedResult({
    required String id,
    required String convID,
    required ConvType convType,
    V2TimMessage? messageInfo,
  }) {
    const blockedCode = 20011;
    final failedMessage = messageInfo ??
        V2TimMessage(
          id: id,
          msgID: id,
          elemType: MessageElemType.V2TIM_ELEM_TYPE_NONE,
        );
    failedMessage.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
    ErrorMessageConverter.attachSendFailCode(failedMessage, blockedCode);
    final coreServices = serviceLocator<CoreServicesImpl>();
    coreServices.callOnCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: ErrorMessageConverter.friendDeletedByOtherHint,
      infoCode: blockedCode,
    ));
    outputLogger.i(
      'send blocked by friend relation: convID=$convID, convType=$convType, messageID=$id',
    );
    return V2TimValueCallback<V2TimMessage>(
      code: blockedCode,
      desc: 'friend relation blocked',
      data: failedMessage,
    );
  }

  Future<V2TimValueCallback<V2TimMessage>> _sendMessage({
    required String id,
    required String convID,
    required ConvType convType,
    V2TimMessage? messageInfo,
    OfflinePushInfo? offlinePushInfo,
    bool? onlineUserOnly = false,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
    bool? isEditStatusMessage = false,
    bool? isExcludedFromContentModeration,
  }) async {
    final target = _resolveSendTarget(
      convID: convID,
      convType: convType,
      messageID: id,
    );
    if (target == null) {
      removeSendingMessageID(id);
      final invalidResult = _buildInvalidTargetResult(
        id: id,
        convID: convID,
        convType: convType,
        messageInfo: messageInfo,
      );
      if (messageInfo != null) {
        messageInfo.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
        globalModel.updateMessage(
          invalidResult,
          convID,
          id,
          convType,
          groupType,
          setInputField,
        );
      }
      return invalidResult;
    }
    String receiver = target.receiver;
    String groupID = target.groupID;
    if (convType == ConvType.c2c && receiver.isNotEmpty) {
      final checker = C2cFriendMessageGuardBridge.canSendTo;
      if (checker != null) {
        final allowed = await checker(receiver);
        if (!allowed) {
          removeSendingMessageID(id);
          final blockedResult = _buildFriendRelationBlockedResult(
            id: id,
            convID: convID,
            convType: convType,
            messageInfo: messageInfo,
          );
          if (messageInfo != null) {
            messageInfo.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
            globalModel.updateMessage(
              blockedResult,
              convID,
              id,
              convType,
              groupType,
              setInputField,
            );
          }
          return blockedResult;
        }
      }
    }
    if (convType == ConvType.group && _groupType == null) {
      await loadGroupInfo(groupID);
    }
    final useReadReceipt =
        (needReadReceipt ?? chatConfig.isShowReadingStatus) &&
            (convType != ConvType.group || _isReadReceiptAllowedGroup);
    if (messageInfo != null) {
      setLoadingMessageMap(convID, messageInfo);
    }
    final sendMsgRes = await _messageService.sendMessage(
      priority: priority,
      localCustomData: localCustomData,
      isExcludedFromUnreadCount: isExcludedFromUnreadCount ?? false,
      id: id,
      receiver: receiver,
      needReadReceipt: useReadReceipt,
      groupID: groupID,
      offlinePushInfo: offlinePushInfo,
      onlineUserOnly: onlineUserOnly ?? false,
      isExcludedFromContentModeration: isExcludedFromContentModeration ?? false,
      cloudCustomData: cloudCustomData ??
          (showC2cMessageEditStatus == true
              ? json.encode({
                  "messageFeature": {
                    "needTyping": 1,
                    "version": 1,
                  }
                })
              : ""),
    );
    if (_isOutgoingMediaCancelled(id) ||
        _isOutgoingMediaCancelled(messageInfo?.msgID)) {
      removeSendingMessageID(id);
      _markOutgoingMediaSendFailed(
        convID: convID,
        clientId: id,
        msgID: messageInfo?.msgID,
      );
      globalModel.clearMessageProgress(id);
      globalModel.clearMessageProgress(messageInfo?.msgID);
      _clearOutgoingMediaCancelled(id);
      _clearOutgoingMediaCancelled(messageInfo?.msgID);
      return V2TimValueCallback<V2TimMessage>(
        code: -1,
        desc: 'cancelled',
        data: messageInfo,
      );
    }
    removeSendingMessageID(id);
    if (isEditStatusMessage == false) {
      globalModel.applyOutgoingSendResult(
        sendMsgRes,
        convID,
        id,
        convType,
        groupType,
        setInputField,
      );
    }
    if (lifeCycle?.messageDidSend != null) {
      lifeCycle!.messageDidSend(sendMsgRes);
    }

    return sendMsgRes;
  }

  List<V2TimMessage> getOriginMessageList() {
    return globalModel.rawMessageList(conversationID) ?? const <V2TimMessage>[];
  }

  void _prependOutgoingMessage(V2TimMessage messageInfoWithSender) {
    globalModel.markMessageEnterAnimation(
      messageInfoWithSender,
    );
    globalModel.prepareForOutgoingMessage(conversationID);
    globalModel.assignOutgoingLocalSeq(conversationID, messageInfoWithSender);
    final currentHistoryMsgList = [
      messageInfoWithSender,
      ...getOriginMessageList(),
    ];
    globalModel.setMessageList(conversationID, currentHistoryMsgList);
    globalModel.requestPinToBottom(conversationID, force: true);
  }

  void _prependOutgoingMessageWithoutNotify(
      V2TimMessage messageInfoWithSender) {
    _prependOutgoingMessageForConversation(
      conversationID,
      messageInfoWithSender,
    );
  }

  void _prependOutgoingMessageForConversation(
    String convID,
    V2TimMessage messageInfoWithSender, {
    bool skipEnterAnimation = false,
  }) {
    final targetConvID = convID.trim();
    if (targetConvID.isEmpty) {
      return;
    }
    if (!skipEnterAnimation) {
      globalModel.markMessageEnterAnimation(
        messageInfoWithSender,
      );
    }
    globalModel.prepareForOutgoingMessage(targetConvID);
    globalModel.assignOutgoingLocalSeq(targetConvID, messageInfoWithSender);
    final currentHistoryMsgList = [
      messageInfoWithSender,
      ...(globalModel.messageListMap[targetConvID] ?? <V2TimMessage>[]),
    ];
    globalModel.setMessageList(
      targetConvID,
      currentHistoryMsgList,
    );
    globalModel.requestPinToBottom(targetConvID, force: true);
  }

  int getConversationUnreadCount() {
    return globalModel.unreadCountForTongue;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendTextAtMessage(
      {required String text,
      required String convID,
      required ConvType convType,
      required List<String> atUserList}) async {
    if (text.isEmpty) {
      return null;
    }
    final textATMessageInfo = await _messageService.createTextAtMessage(
        text: text, atUserList: atUserList);
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final messageInfo = textATMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, textATMessageInfo.id!);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessage(messageInfoWithSender);

      return _sendMessage(
          convID: convID,
          id: textATMessageInfo.id as String,
          convType: ConvType.group,
          offlinePushInfo: tools.buildMessagePushInfo(
              textATMessageInfo.messageInfo!, convID, convType));
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendCustomMessage(
      {required String data,
      required String convID,
      required ConvType convType}) async {
    final customMessageInfo =
        await _messageService.createCustomMessage(data: data);
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final messageInfo = customMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, customMessageInfo.id!);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessage(messageInfoWithSender);

      return _sendMessage(
          convID: convID,
          id: customMessageInfo.id as String,
          convType: convType,
          offlinePushInfo: tools.buildMessagePushInfo(
              customMessageInfo.messageInfo!, convID, convType));
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendFaceMessage(
      {required int index,
      required String data,
      required String convID,
      required ConvType convType}) async {
    final faceMessageInfo =
        await _messageService.createFaceMessage(index: index, data: data);
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final messageInfo = faceMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, faceMessageInfo.id!);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessage(messageInfoWithSender);

      return _sendMessage(
          convID: convID,
          id: faceMessageInfo.id as String,
          convType: convType,
          messageInfo: messageInfoWithSender,
          offlinePushInfo: tools.buildMessagePushInfo(
              faceMessageInfo.messageInfo!, convID, convType));
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendSoundMessage({
    required String soundPath,
    required int duration,
    required String convID,
    required ConvType convType,
  }) async {
    final soundMessageInfo = await _messageService.createSoundMessage(
      soundPath: soundPath,
      duration: duration,
    );
    final messageInfo = soundMessageInfo?.messageInfo;
    if (soundMessageInfo == null || messageInfo == null) {
      return null;
    }

    final messageInfoWithSender =
        tools.setUserInfoForMessage(messageInfo, soundMessageInfo.id!);
    final soundElem = messageInfoWithSender.soundElem;
    if (soundElem != null && soundPath.isNotEmpty) {
      soundElem.path = soundPath;
      soundElem.localUrl ??= soundPath;
    }
    messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    addSendingMessageID(messageInfo.id);
    globalModel.setMessageProgress(soundMessageInfo.id!, 1);
    globalModel.setFileMessageLocation(soundMessageInfo.id!, soundPath);
    _prependOutgoingMessage(messageInfoWithSender);

    return _sendMessage(
      convID: convID,
      id: soundMessageInfo.id as String,
      convType: convType,
      messageInfo: messageInfoWithSender,
      offlinePushInfo: tools.buildMessagePushInfo(
        soundMessageInfo.messageInfo!,
        convID,
        convType,
      ),
    );
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendReplyMessage({
    required String text,
    required String convID,
    required ConvType convType,
    List<String>? atUserIDList,
  }) async {
    if (text.isEmpty) {
      return null;
    }
    if (_composerUi.repliedMessage != null) {
      V2TimMsgCreateInfoResult? textMessageInfo =
          await _messageService.createTextMessage(text: text);
      if (atUserIDList != null && atUserIDList.isNotEmpty) {
        textMessageInfo = await _messageService.createTextAtMessage(
            text: text, atUserList: atUserIDList);
      }
      final V2TimMessage? messageInfo = textMessageInfo!.messageInfo;
      if (messageInfo != null) {
        final replyTarget = _composerUi.repliedMessage!;
        V2TimMessage messageInfoWithSender =
            tools.setUserInfoForMessage(messageInfo, textMessageInfo.id!);
        messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
        addSendingMessageID(messageInfo.id);
        final hasNickName =
            replyTarget.nickName != null && replyTarget.nickName != "";
        final cloudCustomData = {
          "messageReply": {
            "messageID": replyTarget.msgID,
            "messageAbstract":
                tools.getMessageAbstract(replyTarget, abstractMessageBuilder),
            "messageSender":
                hasNickName ? replyTarget.nickName : replyTarget.sender,
            "messageType": replyTarget.elemType,
            "version": 1
          }
        };
        messageInfoWithSender.cloudCustomData = json.encode(cloudCustomData);
        _prependOutgoingMessage(messageInfoWithSender);

        final sendResult = await _sendMessage(
          convID: convID,
          id: textMessageInfo.id as String,
          convType: convType,
          messageInfo: messageInfoWithSender,
          offlinePushInfo: tools.buildMessagePushInfo(
              messageInfoWithSender, convID, convType),
          cloudCustomData: messageInfoWithSender.cloudCustomData,
          needReadReceipt: _canUseReadReceipt,
        );
        if (sendResult.code == 0) {
          repliedMessage = null;
        }
        return sendResult;
      }
    }
    return null;
  }

  void _notifyCreateMessageFailed(String text) {
    final coreServices = serviceLocator<CoreServicesImpl>();
    coreServices.callOnCallback(TIMCallback(
      type: TIMCallbackType.INFO,
      infoRecommendText: text,
      infoCode: 6660421,
    ));
  }

  bool _hasValidSendTarget(String convID, ConvType convType, String messageID) {
    return _resolveSendTarget(
          convID: convID,
          convType: convType,
          messageID: messageID,
        ) !=
        null;
  }

  String _safeVideoType(String? videoPath) {
    final raw = videoPath == null || !videoPath.contains('.')
        ? ''
        : videoPath.split('.').last.toLowerCase();
    const supported = {'mp4', 'mov', 'm4v', '3gp'};
    if (supported.contains(raw)) {
      return raw;
    }
    return 'mp4';
  }

  /// 立即插入图片发送中占位气泡，返回 optimistic clientId。
  /// 不做压缩 / createImageMessage / _sendMessage。
  String beginOptimisticImagePlaceholder({
    required String convID,
    required String imagePath,
    int? imageWidth,
    int? imageHeight,
  }) {
    final effectiveConvID =
        conversationID.isNotEmpty ? conversationID : convID.trim();
    Size? imageSize;
    if (imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0) {
      imageSize = Size(imageWidth.toDouble(), imageHeight.toDouble());
    }
    if (imageSize == null && imagePath.trim().isNotEmpty) {
      imageSize = readLocalImageSizeSync(imagePath);
    }
    return _prependOptimisticImageMessage(
      convID: effectiveConvID,
      imagePath: imagePath,
      imageSize: imageSize,
    );
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendImageMessage(
      {String? imagePath,
      String? imageName,
      required String convID,
      dynamic inputElement,
      required ConvType convType,
      int? imageWidth,
      int? imageHeight,
      String? existingOptimisticId}) async {
    final effectiveConvID =
        conversationID.isNotEmpty ? conversationID : convID.trim();
    final effectiveConvType = conversationType ?? convType;

    final hasKnownSize = imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0;

    var workingPath = imagePath?.trim() ?? '';
    final existingId = existingOptimisticId?.trim();
    String? optimisticId =
        (existingId != null && existingId.isNotEmpty) ? existingId : null;
    if (workingPath.isNotEmpty &&
        inputElement == null &&
        !PlatformUtils().isWeb) {
      final staged = await stageImageForChatSend(workingPath);
      if (staged != null && staged.isNotEmpty) {
        workingPath = staged;
      }
    }

    Size? knownLayoutSize;
    if (hasKnownSize) {
      knownLayoutSize = Size(imageWidth!.toDouble(), imageHeight!.toDouble());
    }
    if (knownLayoutSize == null && workingPath.isNotEmpty) {
      knownLayoutSize = readLocalImageSizeSync(workingPath);
    }

    var uploadPath = workingPath;
    final useBackgroundCompress = workingPath.isNotEmpty &&
        inputElement == null &&
        !PlatformUtils().isWeb &&
        needsChatImageBackgroundCompression(workingPath);

    if (useBackgroundCompress) {
      if (optimisticId == null) {
        optimisticId = _prependOptimisticImageMessage(
          convID: effectiveConvID,
          imagePath: workingPath,
          imageSize: knownLayoutSize,
        );
      }
      final prepared = await prepareImageForChatSend(workingPath);
      if (_isOutgoingMediaCancelled(optimisticId)) {
        _removeOutgoingMessage(
          convID: effectiveConvID,
          clientId: optimisticId,
        );
        return null;
      }
      if (prepared != null && prepared.isNotEmpty) {
        uploadPath = prepared;
      }
    }

    final effectivePath =
        uploadPath.isNotEmpty ? uploadPath : imagePath?.trim();
    final createFuture = _messageService.createImageMessage(
      imageName: imageName,
      imagePath: effectivePath,
      inputElement: inputElement,
    );
    final sizeFuture = (!hasKnownSize &&
            effectivePath != null &&
            effectivePath.isNotEmpty &&
            inputElement == null &&
            !PlatformUtils().isWeb)
        ? probeLocalImageSize(effectivePath)
        : Future<Size?>.value(null);

    final results = await Future.wait<Object?>([
      createFuture,
      sizeFuture,
    ]);
    final imageMessageInfo = results[0] as V2TimMsgCreateInfoResult?;
    final imageSize = results[1] as Size?;
    final messageInfo = imageMessageInfo?.messageInfo;
    if (imageMessageInfo == null || messageInfo == null) {
      if (optimisticId != null) {
        _removeOutgoingMessage(
          convID: effectiveConvID,
          clientId: optimisticId,
        );
      }
      _notifyCreateMessageFailed(TIM_t('图片消息创建失败，请重试'));
      return null;
    }

    final clientId = imageMessageInfo.id as String;
    if (_isOutgoingMediaCancelled(clientId) ||
        _isOutgoingMediaCancelled(optimisticId)) {
      _markOutgoingMediaSendFailed(
        convID: effectiveConvID,
        clientId: clientId,
        msgID: messageInfo.msgID,
      );
      _clearOutgoingMediaCancelled(clientId);
      _clearOutgoingMediaCancelled(optimisticId);
      if (optimisticId != null) {
        _removeOutgoingMessage(
          convID: effectiveConvID,
          clientId: optimisticId,
        );
      }
      return null;
    }

    final messageInfoWithSender =
        tools.setUserInfoForMessage(messageInfo, clientId);
    messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    final resolvedSize = _resolveImageSizeForSend(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      probedSize: imageSize,
    );
    final displayPath = uploadPath.isNotEmpty ? uploadPath : workingPath;

    if (PlatformUtils().isWeb) {
      _ensureWebOutgoingImagePreviewPath(
        messageInfo,
        previewPath: TencentUtils.checkString(displayPath),
      );
    }

    if (optimisticId != null) {
      _adoptOptimisticOutgoingImageMessage(
        convID: effectiveConvID,
        optimisticId: optimisticId,
        newMessage: messageInfoWithSender,
        filePath: displayPath,
        imageSize: resolvedSize,
      );
    } else {
      addSendingMessageID(messageInfo.id);
      globalModel.setMessageProgress(clientId, 0);
      if (displayPath.isNotEmpty) {
        globalModel.setFileMessageLocation(
          clientId,
          displayPath,
          imageSize: resolvedSize,
        );
      }
      _prependOutgoingMessageForConversation(
        effectiveConvID,
        messageInfoWithSender,
        skipEnterAnimation: true,
      );
    }

    return _sendMessage(
      convID: effectiveConvID,
      messageInfo: messageInfoWithSender,
      id: clientId,
      convType: effectiveConvType,
      offlinePushInfo: tools.buildMessagePushInfo(
        imageMessageInfo.messageInfo!,
        effectiveConvID,
        effectiveConvType,
      ),
    );
  }

  Size? _resolveImageSizeForSend({
    int? imageWidth,
    int? imageHeight,
    Size? probedSize,
  }) {
    if (imageWidth != null &&
        imageHeight != null &&
        imageWidth > 0 &&
        imageHeight > 0) {
      return Size(imageWidth.toDouble(), imageHeight.toDouble());
    }
    if (probedSize != null && probedSize.width > 0 && probedSize.height > 0) {
      return probedSize;
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendVideoMessage(
      {String? videoPath,
      int? duration,
      String? snapshotPath,
      required String convID,
      required ConvType convType,
      dynamic inputElement}) async {
    final effectiveConvID =
        conversationID.isNotEmpty ? conversationID : convID.trim();
    final effectiveConvType = conversationType ?? convType;
    if ((videoPath == null || videoPath.isEmpty) && inputElement == null) {
      _notifyCreateMessageFailed(TIM_t('视频文件不可用'));
      return null;
    }

    final resolvedSnapshotPath = await ensureVideoSnapshotForSend(
      videoPath: videoPath,
      snapshotPath: snapshotPath,
    );

    final videoMessageInfo = await _messageService.createVideoMessage(
      videoPath: videoPath,
      type: _safeVideoType(videoPath),
      duration: duration,
      inputElement: inputElement,
      snapshotPath: resolvedSnapshotPath,
    );
    final messageInfo = videoMessageInfo?.messageInfo;
    if (videoMessageInfo == null || messageInfo == null) {
      _notifyCreateMessageFailed(TIM_t('视频消息创建失败，请重试'));
      return null;
    }

    final clientId = videoMessageInfo.id as String;
    if (_isOutgoingMediaCancelled(clientId)) {
      _markOutgoingMediaSendFailed(
        convID: effectiveConvID,
        clientId: clientId,
        msgID: messageInfo.msgID,
      );
      _clearOutgoingMediaCancelled(clientId);
      return null;
    }

    final messageInfoWithSender =
        tools.setUserInfoForMessage(messageInfo, clientId);
    messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    addSendingMessageID(messageInfo.id);
    globalModel.setMessageProgress(clientId, 0);
    if (videoPath != null && videoPath.isNotEmpty) {
      globalModel.setFileMessageLocation(clientId, videoPath);
    }
    _prependOutgoingMessageForConversation(
      effectiveConvID,
      messageInfoWithSender,
      skipEnterAnimation: true,
    );

    return _sendMessage(
      convID: effectiveConvID,
      messageInfo: messageInfoWithSender,
      id: clientId,
      convType: effectiveConvType,
      offlinePushInfo: tools.buildMessagePushInfo(
        videoMessageInfo.messageInfo!,
        effectiveConvID,
        effectiveConvType,
      ),
    );
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendFileMessage(
      {String? filePath,
      String? fileName,
      int? size,
      dynamic inputElement,
      required String convID,
      required ConvType convType}) async {
    if (await tools.hasZeroSize(filePath ?? "")) {
      final CoreServicesImpl _coreServices = serviceLocator<CoreServicesImpl>();
      _coreServices.callOnCallback(TIMCallback(
          type: TIMCallbackType.INFO,
          infoRecommendText: "不支持 0KB 文件的传输",
          infoCode: 6660417));
      return null;
    }
    final fileMessageInfo = await _messageService.createFileMessage(
        inputElement: inputElement,
        fileName: fileName ?? filePath?.split('/').last ?? "",
        filePath: filePath);
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final messageInfo = fileMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, fileMessageInfo.id);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      messageInfoWithSender.fileElem!.fileSize = size;
      _prependOutgoingMessage(messageInfoWithSender);

      return _sendMessage(
        convID: convID,
        messageInfo: messageInfoWithSender,
        id: fileMessageInfo.id as String,
        convType: convType,
        offlinePushInfo: tools.buildMessagePushInfo(
            fileMessageInfo.messageInfo!, convID, convType),
      );
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendLocationMessage(
      {required String desc,
      required double longitude,
      required double latitude,
      required String convID,
      required ConvType convType}) async {
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final locationMessageInfo = await _messageService.createLocationMessage(
        desc: desc, longitude: longitude, latitude: latitude);
    final messageInfo = locationMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, locationMessageInfo.id);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessage(messageInfoWithSender);
      return _sendMessage(
        convID: convID,
        id: locationMessageInfo.id as String,
        convType: convType,
        offlinePushInfo: tools.buildMessagePushInfo(
            locationMessageInfo.messageInfo!, convID, convType),
      );
    }
    return null;
  }

  /// 逐条转发
  sendForwardMessage({
    required List<V2TimConversation> conversationList,
  }) async {
    final selectedMessages = getSelectedMessageList();
    var hasUnsupportedMessage = false;
    for (var conversation in conversationList) {
      final convID = _forwardConversationId(conversation);
      final targetConvType = _forwardConversationType(conversation);
      if (convID.isEmpty || targetConvType == ConvType.none) {
        continue;
      }
      for (var message in selectedMessages) {
        if (isWalletCardMessage(message) || isContactCardMessage(message)) {
          continue;
        }
        if (message.status == MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL) {
          hasUnsupportedMessage = true;
          continue;
        }
        if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS) {
          hasUnsupportedMessage = true;
          continue;
        }
        final sourceMsgID = message.msgID?.trim();
        final forwardMessageInfo = await _messageService.createForwardMessage(
          message: message,
          msgID: sourceMsgID?.isNotEmpty == true ? sourceMsgID : null,
          webMessageInstance: message.messageFromWeb,
        );
        final localForwardID = forwardMessageInfo?.id;
        final messageInfo = forwardMessageInfo?.messageInfo;
        if (localForwardID == null ||
            localForwardID.isEmpty ||
            messageInfo == null) {
          hasUnsupportedMessage = true;
          continue;
        }
        final messageInfoWithSender =
            tools.setUserInfoForMessage(messageInfo, localForwardID);
        messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
        addSendingMessageID(localForwardID);
        // 逐条转发也必须写入目标会话本地列表；否则转发到其他朋友/群时，
        // SDK 已发送成功但发送端打开目标聊天看不到自己的气泡。
        _prependOutgoingMessageForConversation(convID, messageInfoWithSender);
        // 多目标转发时缩短间隔，避免长时间只有遮罩看不到进度。
        final stagger = conversationList.length > 3
            ? const Duration(milliseconds: 20)
            : const Duration(milliseconds: 100);
        await Future.delayed(stagger);
        await _sendMessage(
          id: localForwardID,
          convID: convID,
          convType: targetConvType,
          messageInfo: messageInfoWithSender,
          offlinePushInfo: tools.buildMessagePushInfo(
            messageInfoWithSender,
            convID,
            targetConvType,
          ),
        );
      }
    }
    if (hasUnsupportedMessage) {
      serviceLocator<CoreServicesImpl>().callOnCallback(TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: TIM_t('部分消息不支持单条转发'),
      ));
    }
  }

  /// 合并转发
  Future<V2TimValueCallback<V2TimMessage>?> sendMergerMessage({
    required List<V2TimConversation> conversationList,
    required String title,
    required List<String> abstractList,
    required BuildContext context,
  }) async {
    final selectedMessages = getSelectedMessageList();
    final List<String> msgIDList = selectedMessages
        .map((e) => e.msgID ?? "")
        .where((element) => element.isNotEmpty)
        .toList();
    if (msgIDList.isEmpty) {
      return null;
    }

    V2TimValueCallback<V2TimMessage>? lastResult;
    final sentTargetKeys = <String>{};
    for (var conversation in conversationList) {
      final convID = _forwardConversationId(conversation);
      final targetConvType = _forwardConversationType(conversation);
      final targetKey = '${targetConvType.index}:$convID';
      if (convID.isEmpty ||
          targetConvType == ConvType.none ||
          !sentTargetKeys.add(targetKey)) {
        continue;
      }
      final mergerMessageInfo = await _messageService.createMergerMessage(
          msgIDList: msgIDList,
          title: title,
          abstractList: abstractList,
          compatibleText: TIM_t("该版本不支持此消息"));
      final messageInfo = mergerMessageInfo?.messageInfo;
      final localMergerID = mergerMessageInfo?.id;
      if (messageInfo != null &&
          localMergerID != null &&
          localMergerID.isNotEmpty) {
        final messageInfoWithSender =
            tools.setUserInfoForMessage(messageInfo, localMergerID);
        messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
        addSendingMessageID(localMergerID);
        globalModel.cacheLocalMergerMessageList(
          keys: [
            localMergerID,
            messageInfoWithSender.id,
            messageInfoWithSender.msgID,
          ],
          messages: selectedMessages,
        );
        // 合并转发也必须写入目标会话本地列表；否则转发到其他朋友/群时，
        // SDK 已发送成功但发送端打开目标聊天看不到自己的气泡。
        _prependOutgoingMessageForConversation(convID, messageInfoWithSender);
        lastResult = await _sendMessage(
          id: localMergerID,
          convID: convID,
          convType: targetConvType,
          messageInfo: messageInfoWithSender,
          offlinePushInfo: tools.buildMessagePushInfo(
              messageInfoWithSender, convID, targetConvType),
        );
        final sentMessage = lastResult?.data;
        globalModel.cacheLocalMergerMessageList(
          keys: [
            localMergerID,
            messageInfoWithSender.id,
            messageInfoWithSender.msgID,
            sentMessage?.id,
            sentMessage?.msgID,
          ],
          messages: selectedMessages,
        );
      }
    }
    return lastResult;
  }

  Future<V2TimValueCallback<V2TimMessage>?> reSendFailMessage({
    required V2TimMessage message,
    required String convID,
    required ConvType convType,
  }) async {
    final msgID = message.msgID?.trim() ?? '';
    final clientId = message.id?.trim() ?? '';
    _clearOutgoingMediaCancelled(clientId);
    _clearOutgoingMediaCancelled(msgID);

    // 发送失败且尚无服务端 msgID（如 Face/骰子仅有客户端 id）时，重建消息再发。
    if (msgID.isEmpty) {
      return _resendFailedMessageFromLocal(
        message: message,
        convID: convID,
        convType: convType,
      );
    }

    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    if (currentHistoryMsgList.isEmpty) {
      return null;
    }

    currentHistoryMsgList.removeWhere(
      (element) =>
          element.msgID == msgID ||
          (clientId.isNotEmpty && element.id == clientId),
    );
    message.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    addSendingMessageID(message.msgID);
    globalModel.markMessageEnterAnimation(
      message,
    );
    if (globalModel.getMessageListPosition(conversationID) !=
        HistoryMessagePosition.notShowLatest) {
      currentHistoryMsgList = [message, ...currentHistoryMsgList];
      globalModel.setMessageList(conversationID, currentHistoryMsgList);
    }

    final res = await _messageService.reSendMessage(
      msgID: msgID,
      onlineUserOnly: false,
    );
    removeSendingMessageID(msgID);
    if (globalModel.getMessageListPosition(conversationID) !=
        HistoryMessagePosition.notShowLatest) {
      globalModel.updateMessage(
        res,
        convID,
        msgID,
        convType,
        groupType,
        setInputField,
      );
    }

    if (lifeCycle?.messageDidSend != null) {
      lifeCycle!.messageDidSend(res);
    }
    return res;
  }

  Future<V2TimValueCallback<V2TimMessage>?> _resendFailedMessageFromLocal({
    required V2TimMessage message,
    required String convID,
    required ConvType convType,
  }) async {
    // 钱包卡 / 名片走专用重发，避免误删气泡后无法重建。
    if (isWalletCardMessage(message) || isContactCardMessage(message)) {
      return null;
    }

    final clientId = message.id?.trim() ?? '';
    final msgID = message.msgID?.trim() ?? '';
    final elemType = message.elemType;

    Future<V2TimValueCallback<V2TimMessage>?> sendAfterRemove(
      Future<V2TimValueCallback<V2TimMessage>?> Function() send,
    ) async {
      _removeOutgoingMessage(
        convID: convID,
        clientId: clientId.isEmpty ? null : clientId,
        msgID: msgID.isEmpty ? null : msgID,
      );
      return send();
    }

    final localPath = TencentUtils.checkString(
          globalModel.getFileMessageLocation(clientId),
        ) ??
        TencentUtils.checkString(globalModel.getFileMessageLocation(msgID));

    switch (elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        final data = message.faceElem?.data?.trim() ?? '';
        if (data.isEmpty) {
          return null;
        }
        return sendAfterRemove(
          () => sendFaceMessage(
            index: message.faceElem?.index ?? 0,
            data: data,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        final text = message.textElem?.text?.trim() ?? '';
        if (text.isEmpty) {
          return null;
        }
        return sendAfterRemove(
          () => sendTextMessage(
            text: text,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        final imagePath =
            localPath ?? TencentUtils.checkString(message.imageElem?.path);
        if (imagePath == null) {
          return null;
        }
        return sendAfterRemove(
          () => sendImageMessage(
            imagePath: imagePath,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        final videoPath =
            localPath ?? TencentUtils.checkString(message.videoElem?.videoPath);
        if (videoPath == null) {
          return null;
        }
        return sendAfterRemove(
          () => sendVideoMessage(
            videoPath: videoPath,
            duration: message.videoElem?.duration,
            snapshotPath: message.videoElem?.snapshotPath,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_SOUND:
        final soundPath =
            localPath ?? TencentUtils.checkString(message.soundElem?.path);
        final duration = message.soundElem?.duration ?? 0;
        if (soundPath == null || soundPath.isEmpty || duration <= 0) {
          return null;
        }
        return sendAfterRemove(
          () => sendSoundMessage(
            soundPath: soundPath,
            duration: duration,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_FILE:
        final filePath =
            localPath ?? TencentUtils.checkString(message.fileElem?.path);
        if (filePath == null || filePath.isEmpty) {
          return null;
        }
        return sendAfterRemove(
          () => sendFileMessage(
            filePath: filePath,
            fileName: message.fileElem?.fileName,
            size: message.fileElem?.fileSize,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_LOCATION:
        final loc = message.locationElem;
        if (loc == null) {
          return null;
        }
        return sendAfterRemove(
          () => sendLocationMessage(
            desc: loc.desc ?? '',
            longitude: loc.longitude,
            latitude: loc.latitude,
            convID: convID,
            convType: convType,
          ),
        );
      case MessageElemType.V2TIM_ELEM_TYPE_CUSTOM:
        final data = message.customElem?.data?.trim() ?? '';
        if (data.isEmpty) {
          return null;
        }
        return sendAfterRemove(
          () => sendCustomMessage(
            data: data,
            convID: convID,
            convType: convType,
          ),
        );
      default:
        return null;
    }
  }

  Future<V2TimValueCallback<V2TimMessage>?> sendTextMessage(
      {required String text,
      required String convID,
      required ConvType convType}) async {
    if (text.isEmpty) {
      return null;
    }
    final textMessageInfo = await _messageService.createTextMessage(text: text);
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    final messageInfo = textMessageInfo!.messageInfo;
    if (messageInfo != null) {
      final messageInfoWithSender =
          tools.setUserInfoForMessage(messageInfo, textMessageInfo.id!);
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessage(messageInfoWithSender);

      return _sendMessage(
          convID: convID,
          id: textMessageInfo.id as String,
          convType: convType,
          offlinePushInfo: tools.buildMessagePushInfo(
              textMessageInfo.messageInfo!, convID, convType));
    }
    return null;
  }

  Future<V2TimValueCallback<V2TimMessage>?>? sendMessageFromController({
    required V2TimMessage? messageInfo,

    /// Offline push info
    OfflinePushInfo? offlinePushInfo,
    MessagePriorityEnum priority = MessagePriorityEnum.V2TIM_PRIORITY_NORMAL,
    bool? onlineUserOnly,
    bool? isExcludedFromUnreadCount,
    bool? needReadReceipt,
    String? cloudCustomData,
    String? localCustomData,
  }) {
    List<V2TimMessage> currentHistoryMsgList = getOriginMessageList();
    if (messageInfo != null) {
      final messageInfoWithSender = messageInfo.sender == null
          ? tools.setUserInfoForMessage(messageInfo, messageInfo.id!)
          : messageInfo;
      messageInfoWithSender.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
      addSendingMessageID(messageInfo.id);
      _prependOutgoingMessageWithoutNotify(messageInfoWithSender);

      return _sendMessage(
        priority: priority,
        onlineUserOnly: onlineUserOnly,
        isExcludedFromUnreadCount: isExcludedFromUnreadCount,
        needReadReceipt: needReadReceipt,
        cloudCustomData: cloudCustomData,
        localCustomData: localCustomData,
        convID: conversationID,
        id: messageInfo.id as String,
        convType: conversationType ?? ConvType.c2c,
        offlinePushInfo: offlinePushInfo ??
            tools.buildMessagePushInfo(
                messageInfo, conversationID, conversationType ?? ConvType.c2c),
        isExcludedFromContentModeration:
            messageInfo.isExcludedFromContentModeration,
      );
    }
    return null;
  }

  deleteMsg(String msgID, {String? id, Object? webMessageInstance}) async {
    if (lifeCycle?.shouldDeleteMessage != null &&
        await lifeCycle!.shouldDeleteMessage(msgID) == false) {
      return;
    }
    final list =
        globalModel.messageListMap[conversationID] ?? const <V2TimMessage>[];
    for (final item in list) {
      if (item.msgID == msgID && isWalletCardMessage(item)) {
        return;
      }
    }
    final messageList = getOriginMessageList();
    final res = await _messageService.deleteMessages(
        msgIDs: [msgID], webMessageInstanceList: [webMessageInstance]);
    if (res.code == 0) {
      messageList.removeWhere((element) {
        return element.msgID == msgID || (id != null && element.id == id);
      });
      _syncConversationPreviewAfterDelete([msgID], messageList);
    }
    globalModel.setMessageList(conversationID, messageList);
  }

  /// SDK 删除最后一条消息不会更新会话 lastMessage；本地补偿会话列表预览。
  void _syncConversationPreviewAfterDelete(
    List<String> deletedMsgIDs,
    List<V2TimMessage> remaining,
  ) {
    V2TimMessage? fallback;
    for (final message in remaining) {
      if (message.elemType == 11 ||
          HistoryPaginationAnchor.isLocalInjectedMessage(message)) {
        continue;
      }
      fallback = message;
      break;
    }
    unawaited(
      ConversationSyncService.instance.onConversationMessagesDeleted(
        conversationID: conversationID,
        deletedMsgIDs: deletedMsgIDs,
        fallbackLastMessage: fallback,
      ),
    );
  }

  clearHistory() async {
    if (lifeCycle?.shouldClearHistoricalMessageList != null &&
        await lifeCycle!.shouldClearHistoricalMessageList(conversationID) ==
            false) {
      return;
    }
    // 不能只用 removeMessageList：它会清掉 initialLoaded，空列表会一直转圈。
    globalModel.clearLocalHistoryAsEmptyLoaded(conversationID);
    haveMoreData = false;
    haveMoreLatestData = false;
    _archiveOlderExhausted = true;
    _archiveOlderActive = false;
    _suppressArchiveUntilSdkHistory = true;
    _notify();
  }

  String _mergeRecallMetadata(String? raw, {required bool isAdmin}) {
    final data = <String, dynamic>{};
    final value = raw?.trim() ?? '';
    if (value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          data.addAll(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // 非 JSON 的旧自定义数据不能安全合并，保留在兼容字段中。
        data['legacyCloudCustomData'] = value;
      }
    }
    data['isRevoke'] = true;
    data['revokeByAdmin'] = isAdmin;
    return jsonEncode(data);
  }

  Future<Object?> revokeMsg(String msgID, bool isAdmin,
      [Object? webMessageInstance]) async {
    final list =
        globalModel.messageListMap[conversationID] ?? const <V2TimMessage>[];
    for (final item in list) {
      if (item.msgID == msgID && isWalletCardMessage(item)) {
        return null;
      }
    }

    if (chatConfig.isGroupAdminRecallEnabled) {
      V2TimMessage? message;
      for (final candidate
          in globalModel.messageListMap[conversationID] ?? const []) {
        if (candidate.msgID == msgID) {
          message = candidate;
          break;
        }
      }
      if (message != null) {
        final originalCloudCustomData = message.cloudCustomData;
        final originalMessageFromWeb = message.messageFromWeb;
        if (PlatformUtils().isWeb) {
          final decodedMessage = <String, dynamic>{};
          final rawWebMessage = message.messageFromWeb?.trim() ?? '';
          if (rawWebMessage.isNotEmpty) {
            try {
              final decoded = jsonDecode(rawWebMessage);
              if (decoded is Map) {
                decodedMessage.addAll(Map<String, dynamic>.from(decoded));
              }
            } catch (_) {}
          }
          decodedMessage["cloudCustomData"] = _mergeRecallMetadata(
            decodedMessage["cloudCustomData"]?.toString(),
            isAdmin: isAdmin,
          );
          message.messageFromWeb = jsonEncode(decodedMessage);
        } else {
          message.cloudCustomData = _mergeRecallMetadata(
            message.cloudCustomData,
            isAdmin: isAdmin,
          );
        }
        final result = await modifyMessage(message: message);
        if (result?.code != 0) {
          // modifyMessage 失败不能让当前端先显示成已撤回。
          message.cloudCustomData = originalCloudCustomData;
          message.messageFromWeb = originalMessageFromWeb;
          return result;
        }
        globalModel.markMessageChangedByMessage(conversationID, message);
        await ConversationSyncService.instance
            .markConversationLastMessageRevoked(
          msgID: msgID,
          conversationID: conversationID,
          isAdmin: isAdmin,
        );
        _notify();
        return result;
      }
    }

    final res = await _messageService.revokeMessage(
        msgID: msgID, webMessageInstance: webMessageInstance);
    if (res.code == 0) {
      final refreshed = globalModel.markMessageRevokedNow(
        msgID,
        convID: conversationID,
        isAdmin: isAdmin,
      );
      if (!refreshed) {
        globalModel.onMessageRevoked(msgID, conversationID);
      }
      await ConversationSyncService.instance.markConversationLastMessageRevoked(
        msgID: msgID,
        conversationID: conversationID,
        isAdmin: isAdmin,
      );
      _notify();
    }
    return res;
  }

  setMessageItemChecked(V2TimMessage message, bool isChecked) {
    final messageKey = ChatUiStateStore.messageKeyOf(message);
    if (messageKey.isNotEmpty) {
      chatUiStateStore.setMessageSelected(
        conversationID,
        messageKey,
        isChecked,
      );
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty && msgID != messageKey) {
      chatUiStateStore.bindMessageAlias(conversationID, messageKey, msgID);
    }

    _notify();
  }

  deleteSelectedMsg() async {
    List<V2TimMessage> messageList = getOriginMessageList();
    final selectedMessages = getSelectedMessageList()
        .where((message) => !isWalletCardMessage(message))
        .toList();
    if (selectedMessages.isEmpty) {
      return;
    }
    final msgIDs = selectedMessages
        .map((message) => message.msgID ?? '')
        .where((msgID) => msgID.isNotEmpty)
        .toList();
    final webMessageInstanceList =
        selectedMessages.map((message) => message.messageFromWeb).toList();

    final res = await _messageService.deleteMessages(
        msgIDs: msgIDs, webMessageInstanceList: webMessageInstanceList);
    if (res.code == 0) {
      for (var msgID in msgIDs) {
        messageList.removeWhere((element) => element.msgID == msgID);
      }
      globalModel.setMessageList(conversationID, messageList,
          isDeleteMsg: true);
      _syncConversationPreviewAfterDelete(msgIDs, messageList);
    }
  }

  updateMultiSelectStatus(bool isSelect) {
    chatUiStateStore.setMultiSelect(conversationID, isSelect);
    // setMultiSelect(false) already clears store selection.
    _notify();
  }

  Future<V2TimValueCallback<V2TimGroupMessageReadMemberList>>
      getGroupMessageReadMemberList(String messageID,
          GetGroupMessageReadMemberListFilter fileter, int nextSeq) async {
    if (!_canUseReadReceipt) {
      return V2TimValueCallback<V2TimGroupMessageReadMemberList>(
        code: 6017,
        desc: "The community group does not support message read receipt",
      );
    }
    final res = await _messageService.getGroupMessageReadMemberList(
        nextSeq: nextSeq, messageID: messageID, filter: fileter);
    return res;
  }

  Future<List<V2TimMessage>?> downloadMergerMessage(String msgID) async {
    final cached = globalModel.getLocalMergerMessageList(msgID);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    await _messageService.getHistoryMessageList(
      count: 100,
      getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
      userID: conversationType == ConvType.c2c ? conversationID : null,
      groupID: conversationType == ConvType.group ? conversationID : null,
    );
    final result = await _messageService.downloadMergerMessage(msgID: msgID);
    if (result != null && result.isNotEmpty) {
      globalModel.cacheLocalMergerMessageList(keys: [msgID], messages: result);
    }
    return result;
  }

  Future<V2TimMessage?> findMessage(String msgID) async {
    List<V2TimMessage> messageList = getOriginMessageList();
    final repliedMessage =
        messageList.where((element) => element.msgID == msgID).toList();
    if (repliedMessage.isNotEmpty) {
      return repliedMessage.first;
    }
    final message = await _messageService.findMessages(messageIDList: [msgID]);
    if (message != null && message.isNotEmpty) {
      return message.first;
    }
    return null;
  }

  showLatestUnread() {
    globalModel.flushDeferredIncomingMessages(
      conversationID,
      notify: false,
      userInitiated: true,
    );
    globalModel.unlockEntryUnreadForTongue(
      conversationID: conversationID,
      notify: false,
    );
    globalModel.clearReceivedUnreadState(conversationID: conversationID);
    markMessageAsRead(force: true);
    globalModel.setMessageListPosition(
        conversationID, HistoryMessagePosition.bottom);
  }

  // 添加发送中的消息的 id 或者 msgID(id 不存在时使用 msgID)
  void addSendingMessageID(String? id) {
    if (id?.isNotEmpty == true) {
      _sendingMessageIDMap[id!] = false;
    }
  }

  bool _isOutgoingMediaCancelled(String? id) {
    return id != null &&
        id.isNotEmpty &&
        _cancelledOutgoingMediaIds.contains(id);
  }

  void _markOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.add(id);
      globalModel.markOutgoingMediaCancelled(id);
    }
  }

  void _clearOutgoingMediaCancelled(String? id) {
    if (id != null && id.isNotEmpty) {
      _cancelledOutgoingMediaIds.remove(id);
      globalModel.clearOutgoingMediaCancelled(id);
    }
  }

  void _markOutgoingMediaSendFailed({
    required String convID,
    String? clientId,
    String? msgID,
  }) {
    final list = List<V2TimMessage>.from(
      globalModel.messageListMap[convID] ?? const <V2TimMessage>[],
    );
    var changed = false;
    for (var index = 0; index < list.length; index++) {
      final item = list[index];
      final matchesClient =
          clientId != null && clientId.isNotEmpty && item.id == clientId;
      final matchesMsgID =
          msgID != null && msgID.isNotEmpty && item.msgID == msgID;
      if (!matchesClient && !matchesMsgID) {
        continue;
      }
      item.status = MessageStatus.V2TIM_MSG_STATUS_SEND_FAIL;
      changed = true;
    }
    if (changed) {
      globalModel.setMessageList(convID, list);
    }
  }

  String _nextOptimisticClientId() {
    return '${V2TimMessage.createIDPrefix}${DateTime.now().microsecondsSinceEpoch}';
  }

  void _ensureWebOutgoingImagePreviewPath(
    V2TimMessage message, {
    String? previewPath,
  }) {
    if (previewPath == null || previewPath.isEmpty) {
      return;
    }
    message.imageElem ??= V2TimImageElem(path: previewPath);
    if (TencentUtils.checkString(message.imageElem!.path) == null) {
      message.imageElem!.path = previewPath;
    }
  }

  String _prependOptimisticImageMessage({
    required String convID,
    required String imagePath,
    Size? imageSize,
  }) {
    final optimisticId = _nextOptimisticClientId();
    final optimistic = tools.setUserInfoForMessage(
      V2TimMessage(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_IMAGE,
        imageElem: V2TimImageElem(path: imagePath),
      ),
      optimisticId,
    );
    optimistic.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    addSendingMessageID(optimisticId);
    globalModel.setMessageProgress(optimisticId, 0);
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      applyImageLayoutToMessage(optimistic, imageSize);
    }
    globalModel.setFileMessageLocation(
      optimisticId,
      imagePath,
      imageSize: imageSize,
    );
    _prependOutgoingMessageForConversation(convID, optimistic);
    return optimisticId;
  }

  void _adoptOptimisticOutgoingImageMessage({
    required String convID,
    required String optimisticId,
    required V2TimMessage newMessage,
    required String filePath,
    Size? imageSize,
  }) {
    final progress = globalModel.getMessageProgress(optimisticId);
    if (imageSize != null && imageSize.width > 0 && imageSize.height > 0) {
      applyImageLayoutToMessage(newMessage, imageSize);
    }
    final imageElem = newMessage.imageElem;
    if (imageElem != null) {
      imageElem.path = filePath;
    }
    _swapOutgoingMessage(
      convID: convID,
      oldClientId: optimisticId,
      newMessage: newMessage,
    );
    final clientId = newMessage.id;
    if (clientId != null && clientId.isNotEmpty) {
      chatUiStateStore.bindMessageAlias(
        convID,
        optimisticId,
        ChatUiStateStore.messageKeyOf(newMessage),
      );
      addSendingMessageID(clientId);
      if (progress > 0) {
        globalModel.setMessageProgress(clientId, progress);
      }
      globalModel.setFileMessageLocation(
        clientId,
        filePath,
        imageSize: imageSize,
      );
      globalModel.markMessageRowsChangedByMsgIDs([
        optimisticId,
        clientId,
        newMessage.msgID,
      ]);
    }
  }

  String _prependOptimisticVideoMessage({
    required String convID,
    required String videoPath,
    int? duration,
    String? snapshotPath,
  }) {
    final optimisticId = _nextOptimisticClientId();
    final snapshot = TencentUtils.checkString(snapshotPath);
    final optimistic = tools.setUserInfoForMessage(
      V2TimMessage(
        elemType: MessageElemType.V2TIM_ELEM_TYPE_VIDEO,
        videoElem: V2TimVideoElem(
          videoPath: videoPath,
          snapshotPath: snapshot,
          duration: duration,
        ),
      ),
      optimisticId,
    );
    optimistic.status = MessageStatus.V2TIM_MSG_STATUS_SENDING;
    addSendingMessageID(optimisticId);
    globalModel.setMessageProgress(optimisticId, 0);
    globalModel.setFileMessageLocation(optimisticId, videoPath);
    _prependOutgoingMessageForConversation(convID, optimistic);
    return optimisticId;
  }

  void _swapOutgoingMessage({
    required String convID,
    required String oldClientId,
    required V2TimMessage newMessage,
  }) {
    final list = List<V2TimMessage>.from(
      globalModel.messageListMap[convID] ?? const <V2TimMessage>[],
    );
    final index = list.indexWhere((item) => item.id == oldClientId);
    if (index >= 0) {
      list[index] = newMessage;
    } else {
      list.insert(0, newMessage);
    }
    globalModel.clearUploadProgress(oldClientId);
    removeSendingMessageID(oldClientId);
    // 已是完整替换后的列表。若走默认 merge，会把旧 optimistic 再拼回来，
    // 而 dedupe 认不出 optimisticId ≠ SDK clientId → 一图两气泡（一条发送中一条已送达）。
    globalModel.setMessageList(convID, list, replace: true);
    globalModel.requestPinToBottom(convID, force: true);
  }

  void _removeOutgoingMessage({
    required String convID,
    String? clientId,
    String? msgID,
  }) {
    final list = List<V2TimMessage>.from(
      globalModel.messageListMap[convID] ?? const <V2TimMessage>[],
    );
    list.removeWhere((item) {
      if (clientId != null && clientId.isNotEmpty && item.id == clientId) {
        return true;
      }
      if (msgID != null && msgID.isNotEmpty && item.msgID == msgID) {
        return true;
      }
      return false;
    });
    globalModel.setMessageList(convID, list, replace: true);
    globalModel.clearMessageProgress(clientId);
    globalModel.clearMessageProgress(msgID);
    if (clientId != null) {
      removeSendingMessageID(clientId);
    }
    if (msgID != null) {
      removeSendingMessageID(msgID);
    }
  }

  Future<void> cancelOutgoingMediaMessage(V2TimMessage message) async {
    final clientId = message.id;
    final msgID = message.msgID;
    final convID = conversationID;
    if (convID.isEmpty) {
      return;
    }
    _markOutgoingMediaCancelled(clientId);
    _markOutgoingMediaCancelled(msgID);
    _markOutgoingMediaSendFailed(
      convID: convID,
      clientId: clientId,
      msgID: msgID,
    );
    globalModel.clearMessageProgress(clientId);
    globalModel.clearMessageProgress(msgID);
    if (clientId != null) {
      removeSendingMessageID(clientId);
    }
    if (msgID != null) {
      removeSendingMessageID(msgID);
    }
    final sdkMsgID = TencentUtils.checkString(msgID);
    if (sdkMsgID != null) {
      try {
        await _messageService.revokeMessage(
          msgID: sdkMsgID,
          webMessageInstance: message.messageFromWeb,
        );
      } catch (_) {}
      await _messageService.deleteMessageFromLocalStorage(
        msgID: sdkMsgID,
        webMessageInstance: message.messageFromWeb,
      );
    }
    _notify();
  }

  // 移除发送中的消息的 id 或者 msgID(id 不存在时使用 msgID)
  void removeSendingMessageID(String id) {
    _sendingMessageIDMap.remove(id);
  }

  // 是否已经延迟渲染
  bool? hasDelayedRenderSendingStatus(String id) {
    if (_sendingMessageIDMap.containsKey(id)) {
      return _sendingMessageIDMap[id];
    }

    return true;
  }

  // 设置已经延迟渲染过的消息
  void setDelayedRenderSendingStatus(String id) {
    if (_sendingMessageIDMap.containsKey(id)) {
      _sendingMessageIDMap[id] = true;
    }
  }

  bool isVoteMessage(V2TimMessage message) {
    bool isVote = false;
    V2TimCustomElem? custom = message.customElem;

    if (custom != null) {
      String? data = custom.data;
      if (data != null && data.isNotEmpty) {
        try {
          Map<String, dynamic> mapData = json.decode(data);
          if (mapData["businessID"] == "group_poll") {
            isVote = true;
          }
        } catch (err) {
          // err
        }
      }
    }
    return isVote;
  }

  bool isContactCardMessage(V2TimMessage message) {
    final custom = message.customElem;
    final data = custom?.data;
    if (data == null || data.isEmpty) {
      return false;
    }
    try {
      final mapData = json.decode(data);
      if (mapData is! Map) {
        return false;
      }
      return mapData['businessID']?.toString() == 'contact_card';
    } catch (_) {
      return false;
    }
  }

  bool isWalletCardMessage(V2TimMessage message) {
    final custom = message.customElem;
    final data = custom?.data;
    if (data == null || data.isEmpty) {
      return false;
    }
    try {
      final mapData = json.decode(data);
      if (mapData is! Map) {
        return false;
      }
      final customType = mapData['customType']?.toString() ?? '';
      final legacyType = mapData['type']?.toString() ?? '';
      final businessID = mapData['businessID']?.toString() ?? '';
      if (customType == 'platform_wallet_notice' ||
          businessID == 'platform_wallet_notice' ||
          legacyType == 'platform_wallet_notice') {
        return false;
      }
      return customType == 'wallet_transfer' ||
          legacyType == 'wallet_transfer' ||
          customType == 'wallet_red_packet' ||
          legacyType == 'wallet_red_packet' ||
          businessID == 'wallet_order';
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _readReceiptFlushTimer?.cancel();
    _readReceiptFlushTimer = null;
    _groupMarkReadDebounce?.cancel();
    _groupMarkReadDebounce = null;
    cancelOpenSideMemberLoads();
    _disposed = true;
    globalModel.unlockEntryUnreadForTongue(
      conversationID: conversationID,
      notify: false,
    );
    if (!suppressReadReporting) {
      unawaited(markMessageAsRead(notify: false, force: true));
      globalModel.setUnreadCountForTongue(0, notify: false);
    }
    globalModel.clearCurrentConversation(notify: false);
    _isInit = false;
    super.dispose();
  }
}
