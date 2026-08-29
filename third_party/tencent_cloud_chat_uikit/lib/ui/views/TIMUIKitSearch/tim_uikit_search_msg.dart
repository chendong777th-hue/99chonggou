// ignore_for_file: must_be_immutable, unused_import

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_search_result_item.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message_search_result_item.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_statelesswidget.dart';
import 'package:tencent_cloud_chat_uikit/data_services/conversation/conversation_services.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_folder.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/tim_uikit_search_msg_detail.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';

class TIMUIKitSearchMsg extends TIMUIKitStatelessWidget {
  List<V2TimMessageSearchResultItem?> msgList;
  int totalMsgCount;
  String keyword;
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;
  final model = serviceLocator<TUISearchViewModel>();
  final Function(V2TimConversation, String) onEnterConversation;

  TIMUIKitSearchMsg(
      {required this.msgList,
      required this.keyword,
      required this.totalMsgCount,
      Key? key,
      required this.onTapConversation,
      required this.onEnterConversation})
      : super(key: key);

  Widget _renderShowALl(bool isShowMore) {
    return (isShowMore == true)
        ? TIMUIKitSearchShowALl(
            textShow: TIM_t("更多聊天记录"),
            onClick: () => {model.searchMsgByKey(keyword, false)},
          )
        : Container();
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final conversationList = Provider.of<TUISearchViewModel>(
      context,
      listen: false,
    ).conversationList;
    final conversationById = <String, V2TimConversation>{};
    for (final conversation in conversationList) {
      final id = conversation?.conversationID?.trim() ?? '';
      if (id.isNotEmpty && conversation != null) {
        conversationById[id] = conversation;
      }
    }

    if (msgList.isNotEmpty) {
      return TIMUIKitSearchFolder(folderName: TIM_t("聊天记录"), children: [
        ...msgList.map((conv) {
          final conversationId = conv?.conversationID?.trim() ?? '';
          if (conversationId.isEmpty) {
            return const SizedBox.shrink();
          }
          final conversation = resolveSearchConversationById(
            conversationId: conversationId,
            conversationById: conversationById,
          );
          final groupId = resolveGroupIdFromConversation(conversation) ?? '';
          String title = conversation.showName?.trim() ?? '';
          final treatAsGroup =
              groupId.isNotEmpty || isGroupConversationId(conversationId);
          if (treatAsGroup) {
            final resolvedGroupId = groupId.isNotEmpty
                ? groupId
                : (groupIdFromConversationId(conversationId) ?? conversationId);
            final searchModel = Provider.of<TUISearchViewModel>(
              context,
              listen: false,
            );
            String? matchedGroupName;
            final groups = searchModel.groupList ?? const <V2TimGroupInfo>[];
            for (final g in groups) {
              if (searchGroupIdsEquivalent(g.groupID, resolvedGroupId)) {
                matchedGroupName = g.groupName;
                break;
              }
            }
            final storeName = lookupSearchGroupStoreName(resolvedGroupId) ?? '';
            title = preferSearchGroupShowName(
              groupName: matchedGroupName,
              conversationShowName: conversation.showName,
              storeName: storeName,
              groupId: resolvedGroupId,
            );
            if (title.isNotEmpty &&
                title != (conversation.showName?.trim() ?? '')) {
              conversation.showName = title;
            }
          } else {
            // C2C：补备注/昵称，避免会话缓存缺失或 showName=userId 时露出 UID。
            final userId = (conversation.userID?.trim().isNotEmpty == true)
                ? conversation.userID!.trim()
                : (conversationId.startsWith('c2c_')
                    ? conversationId.substring(4).trim()
                    : '');
            String? friendRemark;
            String? friendNick;
            String? friendFace;
            if (userId.isNotEmpty) {
              final friends =
                  serviceLocator<TUIFriendShipViewModel>().friendList ??
                      const [];
              for (final friend in friends) {
                if (friend.userID.trim() == userId) {
                  friendRemark = friend.friendRemark;
                  friendNick = friend.userProfile?.nickName;
                  friendFace = friend.userProfile?.faceUrl;
                  break;
                }
              }
            }
            final storeName = userId.isEmpty
                ? ''
                : (DisplayNameStore.instance.c2c(userId)?.trim() ?? '');
            title = preferSearchC2cShowName(
              friendRemark: friendRemark,
              storeName: storeName,
              nickName: friendNick,
              conversationShowName: conversation.showName,
              userID: userId,
            );
            if (title.isNotEmpty &&
                title != (conversation.showName?.trim() ?? '')) {
              conversation.showName = title;
            }
            final face = (conversation.faceUrl?.trim() ?? '');
            final resolvedFace = (friendFace ?? '').trim();
            if (face.isEmpty && resolvedFace.isNotEmpty) {
              conversation.faceUrl = resolvedFace;
            }
          }
          if (title.isEmpty) {
            title = conversation.showName ?? conversationId;
          }
          final option1 = conv?.messageCount;
          return TIMUIKitSearchItem(
            onClick: () async {
              onEnterConversation(conversation, keyword);
            },
            faceUrl: conversation.faceUrl ?? "",
            showName: title,
            lineOne: title,
            lineTwo: TIM_t_para("{{option1}}条相关聊天记录", "$option1条相关聊天记录")(
                option1: option1),
          );
        }).toList(),
        _renderShowALl(model.hasMoreGlobalMessageResults)
      ]);
    } else {
      return Container();
    }
  }
}
