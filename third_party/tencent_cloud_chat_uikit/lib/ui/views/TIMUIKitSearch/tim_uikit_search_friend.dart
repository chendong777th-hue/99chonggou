// ignore_for_file: must_be_immutable

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_friend_info_result.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_friend_info_result.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_status.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_status.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/data_services/friendShip/friendship_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_folder.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/picker_user_filter.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';

class TIMUIKitSearchFriend extends StatefulWidget {
  List<V2TimFriendInfoResult> friendResultList;
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;
  final MemberPresenceLabelBuilder? friendPresenceLabelBuilder;
  final MemberPresenceLoadingChecker? friendPresenceLoadingChecker;
  final void Function(List<String> userIds)? onFriendListLoaded;
  final Listenable? presenceListenable;
  final bool pausePresenceUpdates;
  final VoidCallback? onShowAll;

  TIMUIKitSearchFriend({
    required this.friendResultList,
    Key? key,
    required this.onTapConversation,
    this.friendPresenceLabelBuilder,
    this.friendPresenceLoadingChecker,
    this.onFriendListLoaded,
    this.presenceListenable,
    this.pausePresenceUpdates = false,
    this.onShowAll,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitSearchFriendState();
}

class TIMUIKitSearchFriendState extends TIMUIKitState<TIMUIKitSearchFriend> {
  static const int defaultShowLines = 3;
  final FriendshipServices _friendshipServices =
      serviceLocator<FriendshipServices>();
  final Map<String, V2TimUserStatus> _userStatusById = {};
  String? _lastPresenceRefreshKey;

  @override
  void initState() {
    super.initState();
    _schedulePresenceForPreview();
  }

  @override
  void didUpdateWidget(covariant TIMUIKitSearchFriend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameFriendResults(oldWidget.friendResultList, widget.friendResultList)) {
      _lastPresenceRefreshKey = null;
      _schedulePresenceForPreview();
    } else if (oldWidget.pausePresenceUpdates && !widget.pausePresenceUpdates) {
      _lastPresenceRefreshKey = null;
      _schedulePresenceForPreview();
    }
  }

  bool _sameFriendResults(
    List<V2TimFriendInfoResult> oldList,
    List<V2TimFriendInfoResult> newList,
  ) {
    if (oldList.length != newList.length) {
      return false;
    }
    for (var i = 0; i < oldList.length; i++) {
      if (oldList[i].friendInfo?.userID != newList[i].friendInfo?.userID) {
        return false;
      }
    }
    return true;
  }

  List<V2TimFriendInfoResult> _filteredFriends() {
    return widget.friendResultList
        .where((friend) {
          if (shouldHideUserFromPickers(friend.friendInfo?.userID)) {
            return false;
          }
          final userId = friend.friendInfo?.userID?.trim() ?? '';
          return userId.isNotEmpty;
        })
        .toList(growable: false);
  }

  List<String> _userIdsFromResults(List<V2TimFriendInfoResult> results) {
    return results
        .map((friend) => friend.friendInfo?.userID?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  void _schedulePresenceForPreview() {
    final filtered = _filteredFriends();
    final preview = filtered.sublist(
      0,
      min(defaultShowLines, filtered.length),
    );
    _schedulePresenceRefresh(_userIdsFromResults(preview));
  }

  Future<void> _loadUserStatus(List<String> userIds) async {
    if (userIds.isEmpty) {
      return;
    }
    const chunkSize = 100;
    for (var i = 0; i < userIds.length; i += chunkSize) {
      final chunk = userIds.sublist(i, min(i + chunkSize, userIds.length));
      final statuses =
          await _friendshipServices.getUserStatus(userIDList: chunk);
      for (final status in statuses) {
        final id = status.userID?.trim() ?? '';
        if (id.isNotEmpty) {
          _userStatusById[id] = status;
        }
      }
    }
  }

  void _schedulePresenceRefresh(List<String> userIds) {
    if (userIds.isEmpty || widget.pausePresenceUpdates) {
      return;
    }
    final key = userIds.join('|');
    if (_lastPresenceRefreshKey == key) {
      return;
    }
    _lastPresenceRefreshKey = key;
    final useAppPresence = widget.friendPresenceLabelBuilder != null;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.pausePresenceUpdates) {
        return;
      }
      if (useAppPresence) {
        widget.onFriendListLoaded?.call(userIds);
        return;
      }
      await _loadUserStatus(userIds);
      if (!mounted) {
        return;
      }
      widget.onFriendListLoaded?.call(userIds);
      setState(() {});
    });
  }

  bool _isImOnline(String userId) {
    return _userStatusById[userId]?.statusType == 1;
  }

  String? _presenceSubtitle(String userId) {
    final builder = widget.friendPresenceLabelBuilder;
    if (builder == null) {
      return _isImOnline(userId) ? TIM_t('在线') : TIM_t('离线');
    }
    return builder(userId, _isImOnline(userId));
  }

  Map<String, V2TimConversation> _conversationByUserId(
    List<V2TimConversation?> conversationList,
  ) {
    final map = <String, V2TimConversation>{};
    for (final conversation in conversationList) {
      final userId = conversation?.userID?.trim() ?? '';
      if (userId.isNotEmpty && conversation != null) {
        map[userId] = conversation;
      }
    }
    return map;
  }

  Widget _renderShowALl(int currentLines) {
    if (currentLines <= defaultShowLines) {
      return Container();
    }
    return TIMUIKitSearchShowALl(
      textShow: TIM_t("全部联系人"),
      onClick: widget.onShowAll,
    );
  }

  Widget _buildFolder(
    List<V2TimFriendInfoResult> previewList,
    List<V2TimFriendInfoResult> filteredFriendResultList,
    Map<String, V2TimConversation> conversationByUserId,
  ) {
    return TIMUIKitSearchFolder(folderName: TIM_t("联系人"), children: [
      ...previewList.map((conv) {
        final userId = conv.friendInfo?.userID?.trim() ?? '';
        final conversation = resolveSearchC2cConversation(
          friendInfo: conv.friendInfo,
          conversationByUserId: conversationByUserId,
        );
        if (userId.isEmpty) {
          return const SizedBox.shrink();
        }
        late String? showNickName;
        if (conv.friendInfo?.friendRemark != null &&
            conv.friendInfo?.friendRemark != "") {
          showNickName = conv.friendInfo?.friendRemark;
        } else if (conv.friendInfo?.userProfile?.nickName != null &&
            conv.friendInfo?.userProfile?.nickName != "") {
          showNickName = conv.friendInfo?.userProfile?.nickName;
        } else {
          showNickName = conv.friendInfo?.userID;
        }
        final imOnline = _isImOnline(userId);
        final presenceLoading = widget.friendPresenceLoadingChecker
                ?.call(userId, imOnline) ??
            false;
        final presenceSubtitle =
            presenceLoading ? null : _presenceSubtitle(userId);
        final presenceSubtitleWidget = presenceLoading
            ? buildMemberPresenceSubtitleSkeleton(lineHeight: 19)
            : null;

        return TIMUIKitSearchItem(
          onClick: () {
            widget.onTapConversation(conversation, null);
          },
          faceUrl: conv.friendInfo?.userProfile?.faceUrl ?? "",
          showName: showNickName ?? userId,
          lineOne: showNickName!,
          lineTwo: presenceSubtitle,
          lineTwoWidget: presenceSubtitleWidget,
        );
      }).toList(),
      _renderShowALl(filteredFriendResultList.length),
    ]);
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final conversationList = Provider.of<TUISearchViewModel>(
      context,
      listen: false,
    ).conversationList;
    final conversationByUserId = _conversationByUserId(conversationList);

    final filteredFriendResultList = _filteredFriends();

    if (filteredFriendResultList.isEmpty) {
      return Container();
    }

    final previewList = filteredFriendResultList.sublist(
      0,
      min(defaultShowLines, filteredFriendResultList.length),
    );

    final folder = _buildFolder(
      previewList,
      filteredFriendResultList,
      conversationByUserId,
    );
    final listenable = widget.presenceListenable;
    if (listenable == null) {
      return folder;
    }
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) => _buildFolder(
        previewList,
        filteredFriendResultList,
        conversationByUserId,
      ),
    );
  }
}
