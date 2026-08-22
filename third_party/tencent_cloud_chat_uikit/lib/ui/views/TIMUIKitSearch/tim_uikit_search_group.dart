// ignore_for_file: must_be_immutable

import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_group_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_state.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_search_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_item.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_folder.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/pureUI/tim_uikit_search_showAll.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_base.dart';

class TIMUIKitSearchGroup extends StatefulWidget {
  List<V2TimGroupInfo> groupList;
  final Function(V2TimConversation, V2TimMessage?) onTapConversation;
  final VoidCallback? onShowAll;

  TIMUIKitSearchGroup({
    required this.groupList,
    Key? key,
    required this.onTapConversation,
    this.onShowAll,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => TIMUIKitSearchGroupState();
}

class TIMUIKitSearchGroupState extends TIMUIKitState<TIMUIKitSearchGroup> {
  static const int defaultShowLines = 3;

  Widget _renderShowALl(int currentLines) {
    if (currentLines <= defaultShowLines) {
      return Container();
    }
    return TIMUIKitSearchShowALl(
      textShow: TIM_t("全部群聊"),
      onClick: widget.onShowAll,
    );
  }

  Map<String, V2TimConversation> _conversationByGroupId(
    List<V2TimConversation?> conversationList,
  ) {
    final map = <String, V2TimConversation>{};
    for (final conversation in conversationList) {
      final groupId = conversation?.groupID?.trim() ?? '';
      if (groupId.isNotEmpty && conversation != null) {
        map[groupId] = conversation;
      }
    }
    return map;
  }

  @override
  Widget tuiBuild(BuildContext context, TUIKitBuildValue value) {
    final conversationList = Provider.of<TUISearchViewModel>(
      context,
      listen: false,
    ).conversationList;
    final conversationByGroupId = _conversationByGroupId(conversationList);

    final filteredGroupResultList = widget.groupList
        .where((group) {
          final groupId = group.groupID.trim();
          return groupId.isNotEmpty;
        })
        .toList(growable: false);

    final previewList = filteredGroupResultList.sublist(
      0,
      min(defaultShowLines, filteredGroupResultList.length),
    );

    if (filteredGroupResultList.isNotEmpty) {
      return TIMUIKitSearchFolder(folderName: TIM_t("群聊"), children: [
        ...previewList.map((group) {
          final conversation = resolveSearchGroupConversation(
            group: group,
            conversationByGroupId: conversationByGroupId,
          );
          final title = preferSearchGroupShowName(
            groupName: group.groupName,
            conversationShowName: conversation.showName,
            groupId: group.groupID,
          );
          return TIMUIKitSearchItem(
            onClick: () {
              widget.onTapConversation(conversation, null);
            },
            faceUrl: conversation.faceUrl ?? group.faceUrl ?? "",
            showName: "",
            lineOne: title,
          );
        }).toList(),
        _renderShowALl(filteredGroupResultList.length),
      ]);
    } else {
      return Container();
    }
  }
}
